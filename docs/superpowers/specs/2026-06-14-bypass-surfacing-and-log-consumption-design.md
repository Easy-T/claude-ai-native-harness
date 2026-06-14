# 우회-사용 실시간 표면화 + 로그 소비 — Design (2026-06-14)

> **subsystem**: 보안/관측 게이트 (`hooks/enforce-rpi-cycle.sh`, `enforce-rpi-bash.sh`, `enforce-secret-scan.sh`, `hooks/_common.sh`, `setup/doctor.sh`).
> **계기**: `2026-06-14-audit-reverification-2.md` §7 ③(보안 min)·§8 Goal초안#3 — G3-a(우회-사용 RPI_SKIP/SECRET_SCAN_SKIP 실시간 표면 미해소; 현재 로그-only/stderr-only) + G6-c(로그 무소비).
> **성격**: durable design spec. RPI cycle 35. 사용자 autonomy 하 best-practice. **차단으로 바꾸지 않음 — advisory 표면화만(의도된 트레이드오프 유지). secret 값 미표시 불변식 절대 준수.**

**Status:** completed

---

## 0. 문제 (CONFIRMED, file:line)

1. **G3-a 우회-사용 무표면(③ 보안 min)**: 3 게이트의 bypass 분기 —
   - `enforce-rpi-cycle.sh:68-72`: `echo "[rpi] SKIP" >&2` (stderr; 모델 미도달=사실상 로그-only).
   - `enforce-rpi-bash.sh:25-28`: hook_log만 (무표면).
   - `enforce-secret-scan.sh:28-31`: hook_log만 (무표면).
   → 우회 사용이 세션(모델 컨텍스트)에 안 보임. rank6 fail-open 크래시는 표면화됐으나 *우회 사용*은 무표면.
2. **G6-c 로그 무소비(⑥ 관측)**: `doctor.sh:261-273`(20c)가 .log를 *로테이션만* 하고 *소비(집계)* 안 함. BLOCK/SKIP/FAILOPEN 추세가 audit 시점에 안 보임(S8 postmortem 부재).

---

## 1. 결정

### 결정 (1) — 우회-사용 additionalContext 표면화 (세션당 1회 dedup)

`_common.sh`에 헬퍼 추가:
```bash
surface_bypass() {  # <hook> <session_id> <msg> : 세션당 1회 additionalContext 표면화 (G3-a)
  local hook="$1" sid="${2:-unknown}" msg="$3" mark
  mark=$(session_marker "bypass-$hook" "$sid")
  [ -f "$mark" ] && return 0
  : > "$mark" 2>/dev/null || true
  emit_additional_context "$msg"
}
```
3 bypass 분기에서 hook_log 직후 호출(exit 0 유지 — **차단 아님**):
- rpi-cycle: `⚠ RPI 게이트 우회 (RPI_SKIP='…') — 이 세션 코드변경에 RPI 미적용; 의도 확인` (기존 stderr echo는 유지=bonus user-surface).
- rpi-bash: `⚠ RPI bash 게이트 우회 (RPI_SKIP='…') — 셸 코드작성 게이트 미적용`.
- secret-scan: `⚠ 시크릿 스캔 우회 (SECRET_SCAN_SKIP='…') — 페이로드 미검사` (**스캔 reason만; 페이로드/값 미표시**).

근거: additionalContext = 모델-컨텍스트 주입 유일 비차단 경로(_common.sh:148, surface-constitution 선례). dedup(session_marker, auto-compact-watch/verify-loop-watch 선례)로 우회-세션의 매-명령 bloat 방지 → "1줄 표면화". session_id는 input JSON에서 `json_get session_id`.

### 결정 (2) — doctor 당월 .log 집계 sub-check (G6-c, read-only)

`_common.sh`에 헬퍼:
```bash
log_summary() {  # <logfile> : verdict 카운트만 (값 미표시). "BLOCK=N SKIP=N FAILOPEN=N ALERT=N"
  local f="${1:-}"; [ -f "$f" ] || { printf 'BLOCK=0 SKIP=0 FAILOPEN=0 ALERT=0'; return 0; }
  awk -F'\t' '
    $4=="BLOCK"{b++} $4=="FAILOPEN"{fo++} $4=="ALERT"{a++}
    ($4=="PASS" && $5 ~ /^skip:/){s++}
    END{printf "BLOCK=%d SKIP=%d FAILOPEN=%d ALERT=%d", b+0, s+0, fo+0, a+0}
  ' "$f"
}
```
doctor.sh 20c 뒤(또는 내부)에 sub-check: 당월 logfile에 `log_summary` 호출 → `check "hook log 당월 집계" "PASS" "<summary>"`. **읽기 전용·카운트만**(.log은 enforce-secret-scan이 KIND만 기록=값 무존재라 안전).

---

## 2. 테스트 (TDD, 대표)

| case_id | hook | 종류 | 의미 | RED | GREEN |
|---|---|---|---|---|---|
| 150-bypass-rpibash-surface | enforce-rpi-bash | output(alert) | RPI_SKIP skip → additionalContext+"우회" | 무 additionalContext | alert |
| 151-bypass-secretscan-surface | enforce-secret-scan | output | SECRET_SCAN_SKIP skip → additionalContext+"우회" | 무 | alert |
| 152-bypass-rpicycle-surface | enforce-rpi-cycle | output | RPI_SKIP skip(code Write) → additionalContext+"우회" | stderr만(무 AC) | alert |
| 153-logsummary-counts | hooks-lib | output | 크래프트 log → "BLOCK=2 SKIP=1 FAILOPEN=1 ALERT=0" | (신규 함수 부재) | 정확 카운트 |

- output 테스트는 session_id 포함 이벤트 + 마커 rm(test_vlw/test_sc 선례). exit-code 무변(기존 36/45/06/30 skip 테스트 exit 0 불변).
- run-all 135→**139**, README cases 카운트 동기화(135→139, #20 seal 선제 반영).

### 무회귀
- 기존 skip 테스트(rpi-bash 36·secret-scan 45·rpi-cycle 06/30) exit 0 불변(surface는 stdout 추가일 뿐 exit 무변).
- secret 값 미표시 불변식: surface는 SKIP reason만, 페이로드/KIND-값 미포함. log_summary는 카운트만.
- verify-setup ≥65, verify-all ALL PASS, doctor exit 0 불변(sub-check는 PASS만).

## 3. 비목표 / 엣지
- 우회를 차단으로 변경 금지(advisory만).
- 우회를 *의미있는 것만* 필터(detection-then-skip 재구조화)는 비목표 — dedup으로 충분, 라이브 게이트 재구조화 위험 회피.
- log_summary는 secret 값 미표시(카운트만). 멀티유저 마커 충돌은 by-design(NEW-session-marker-collision 잔여, 범위 밖).
- session_id 부재 시 "unknown" 마커(graceful).

---

> spec delta = YES. 다음: writing-plans → Gate P → implement(TDD).
