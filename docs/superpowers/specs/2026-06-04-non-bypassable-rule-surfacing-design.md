# 거버넌스 규칙 회피-불가 표면화 — Design Spec

**Status:** active
**Date:** 2026-06-04
**Subsystem:** Non-bypassable rule surfacing / 규칙 회피-불가 표면화
**Spec-lifecycle:** durable (서브시스템당 1회 inception; 사이클당 plan이 일부 구현 — [[harness-ssot-drift-guard]] 모델)

> 직전 재점검 워크플로(wirrmbi91)가 확정한 발견 **F1/F6**(verify-setup PASS가 복합 evidence 필드에 접힌 cycle-14 마스킹 클래스 재발) + **ADOPT**(구글 Tricorder "항상-렌더 표면" → §5/§8 JIT advisory)를 **한 설계 관심사**로 통합. 사이클-핸드오프 spec(`2026-06-04-cycle-handoff-and-orchestration-design.md`)과는 다른 design concern(규칙을 *회피-불가 표면*에 둠 — 핸드오프가 아님)이라 별도 durable spec으로 inception.

---

## Problem

CLAUDE.md §1~§8 중 절반(**§4·§5·§6·§7·§8**)이 "항상/반드시"라고 명시돼 있으나 어떤 hook·verify 체크·상시 표면도 받쳐주지 않는 **순수 prose**다(재점검 맵 "필수 규칙 × 강제 표면" 격자 — surface=none). 또한 start-rpi-cycle Closeout **sub-step 6**(전역 하네스 수정 시 `verify-setup.sh` PASS 확인)은 *필수*지만 Communication Protocol에 **전용 필드가 없어 복합 `evidence` 필드에 접힌다** — cycle-14에서 `next-cycle-goal`을 `unknowns`에서 떼어낸 바로 그 마스킹 클래스의 재발(F6). 둘 다 "문서상 필수인데 위반·누락 시 표면이 없다"는 동일 안티패턴.

(직전 워크플로가 정확히 refuted한 후보·EX1~EX3(과거 오진)은 본 spec 범위에서 제외 — 재제기 금지.)

## Decisions

- **D-F1 (구조적 표면 — verify-setup PASS 전용 필드):** start-rpi-cycle Communication Protocol에 **고유 필수 필드 `harness-verify:`** 추가. 정확히 둘 중 하나:
  - 하네스 수정 사이클 → `PASS=<N> FAIL=0` (+ `#17·#18·#19 green` 명시) — `verify-setup.sh` 실행 결과.
  - 비-하네스 사이클 → `N/A — 이번 사이클은 ~/.claude(전역 하네스)를 수정하지 않음`.
  - 생략 = 명명된 필수 필드 누락 = 보고 구조적 불완전(복합 `evidence`로 대체 불가 → 자가-표면화). `next-cycle-goal` 선례 그대로.
  - **항상 필수 (cycle.count 무관):** 모든 사이클이 둘 중 하나를 *능동 선언* → 침묵 누락 불가. (next-cycle-goal은 cycle≥1 게이트지만 harness-verify는 비-하네스 사이클도 "N/A"를 명시해야 하므로 항상.)
  - sub-step 6에 "결과는 Communication Protocol `harness-verify:` 필드로 보고(evidence에 접지 않음)" 1줄 참조 추가.
  - **#19 parity:** `harness-verify` 토큰이 Step C-1(sub-step 6) ↔ Communication Protocol 두 곳에 필연 중복(둘 다 필수 — 계약에 토큰 없으면 report-time 표면화 약화) → verify-setup **#19**로 파일-내 parity 봉인(#18 패턴 인스턴스, generalized 아님).

- **D-ADOPT (상시 표면 — §5/§8 JIT advisory hook):** 새 PreToolUse hook `hooks/surface-constitution.sh`. 매칭 액션 순간 해당 § 조항을 **모델 컨텍스트로** 환기.
  - **emit 메커니즘 (★ grill 교정 — load-bearing):** stderr가 **아니라** `hookSpecificOutput.additionalContext`(stdout JSON, exit 0). 공식 Claude Code hooks 문서 확정(claude-code-guide): PreToolUse 성공 시 **stdout JSON만 파싱**되고 `additionalContext`="String added to Claude's context"(모델이 읽음), `systemMessage`="shown to the user"(사용자만), **stderr는 성공 경로에서 모델에 도달하지 않음**. 여러 hook의 additionalContext는 **모두 합쳐져** Claude에 전달. → stable-claude-md의 stderr 패턴을 미러링하면 §5/§8 환기가 *에이전트에 안 닿으므로* additionalContext 사용. `_common.sh`에 `emit_additional_context()` 헬퍼 추가(`emit_system_message` 형제).
  - **토큰 상시세 회피 (dedup):** §5·§8 **각각 1세션 1회**만 emit(`session_marker` — verify-loop-watch 패턴). 최대 2 injection/세션 → "UserPromptSubmit로 헌법 매-턴 재주입"(재점검 critic이 REJECT한 ~200토큰/턴 상시세)과 구분.
  - **트리거 (결정적 경로/확장자만):**
    - §5(ADR) = 의존성 매니페스트 파일명: `package.json` `go.mod` `requirements.txt` `pyproject.toml` `Cargo.toml` `pom.xml` `build.gradle(.kts)` `Gemfile` `composer.json` `*.csproj` `pubspec.yaml`.
    - §8(UI) = UI 확장자: `*.tsx` `*.jsx` `*.vue` `*.svelte` `*.css` `*.scss` `*.sass` `*.less` `*.styl`.
    - 비매칭 파일 = **무출력 no-op**(소음 0).
  - **차단 아님(advisory, exit 0):** §5는 "변경 직후" ADR 허용, §8 하드게이트는 오탐(버전 범프 등) → advisory가 정합. 재점검 critic도 차단형 governance를 단일사용자 범위 밖으로 판정.
  - **전역 작동:** 글로벌 settings 배선 → 사용자 *실제 프로젝트*에서 발화. 하네스 repo엔 매니페스트/UI 파일이 없어 자기-세션엔 사실상 침묵 → **테스트는 fixture(합성 file_path)로**(루트 대상 파일 없음, explore 확인).

## Non-Goals (anti-pattern 방어)

- **§4 non-obvious / §6 도메인용어 / §7 응답언어 — 제외.** 결정적 파일-경로 트리거가 없는 *의미 판단* 의무 → JIT 경로-매칭 hook으로 표면화 불가(수락된 ND3 클래스). §5/§8만 기계 트리거 보유. (미래 리뷰어가 "§4/§6/§7도 hook 걸어라"로 오플래그하지 않도록 명시.)
- **하드 게이트(차단) — 기각.** advisory(exit 0)만. §5/§8 차단은 오탐·friction.
- **stable-claude-md를 additionalContext로 이전 — 범위 밖(surgical).** §1은 *사용자-타이밍* 관심사라 stderr(사용자 표면)도 정당. cycle-16은 신규 표면만 추가, 기존 hook 미변경. (별도 신규 관찰: §1 advisory가 모델 컨텍스트엔 안 닿음 — cycle-17+ 검토 후보로만 기록. **EX1**(글로벌-제외 경로형 오진)과는 무관한 별개 사실.)
- **#19를 generalized "모든 중복 비교" 프레임워크로 — 기각.** #17/#18처럼 특정 인스턴스(harness-verify 토큰 parity)만.

## Change Set

| 파일 | 변경 | 게이트 영향 |
|---|---|---|
| `hooks/_common.sh` | `emit_additional_context()` 헬퍼 추가(line 130 형제) | 가산적, 무영향 |
| `hooks/surface-constitution.sh` | **신규** advisory PreToolUse hook(§5/§8, additionalContext, 세션 dedup) | verify-setup #8 목록 +1, settings 배선 +1 |
| `settings.json` / `settings.example.json` | `Write\|Edit\|NotebookEdit` 배열에 surface-constitution 배선(둘 동기) | #14 ≥9 유지(→10); 값 노출 금지 |
| `setup/verify-setup.sh` | #8 hook 목록·주석에 surface-constitution(8→9); **#19** harness-verify parity 신설(line 131 뒤) | **PASS 53→55**(#8 +1, #19 +1) |
| `skills/start-rpi-cycle/SKILL.md` | Communication Protocol에 `harness-verify:` 전용 필수 필드; sub-step 6에 필드 참조 1줄 | #19 green 필요; enforce-orchestrator 골격(Phase≥3·Agent≥1·Communication Protocol) 보존 |
| `hooks/tests/cases.tsv` + `run-all.sh` | surface-constitution 케이스 4종(§5 emit·§8 emit·비매칭 silent·dedup-silent) + 매칭 test 함수(test_vlw 미러) | 케이스 +4, cases.tsv↔run-all 1:1 |
| `README.md` | "8개 hook"→"9개" + 표 행 + helper 목록/구조트리 동기 | 문서 정합 |

## Acceptance

- `bash ~/.claude/hooks/tests/run-all.sh` → 신규 3 케이스 포함 전부 PASS, cases.tsv↔run-all 1:1 정합.
- `bash ~/.claude/setup/verify-setup.sh` → FAIL=0, **PASS=55**, #17·#18·**#19** green.
- `bash ~/.claude/setup/verify-all.sh` → ALL PASS.
- `surface-constitution.sh`: `package.json` 입력 → stdout에 §5 additionalContext + exit 0; `.tsx` 입력 → §8 additionalContext; 일반 `.md` → 무출력 exit 0; 동일 세션 2회 → 2회차 suppressed.
- SKILL.md Communication Protocol에 `harness-verify:` 전용 필수 필드 존재(둘 중 하나 강제); sub-step 6이 이 필드로 보고하도록 참조.
- **dogfood:** cycle-16 자체 Closeout이 `harness-verify` = PASS 증거(#17·#18·#19 green)로 보고.
