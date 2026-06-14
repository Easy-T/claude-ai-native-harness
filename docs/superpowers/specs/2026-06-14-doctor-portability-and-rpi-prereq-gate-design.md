# Doctor 이식성 + RPI 전제조건 게이트 — Design (2026-06-14)

> **subsystem**: bootstrap/diagnostics (`setup/doctor.sh`, `setup/verify-all.sh`, `setup/install.sh`).
> **계기**: `2026-06-14-audit-reverification-2.md` §7 ⑦재현성(min) + §8 Goal초안#1 — 8차원 재점수에서 ⑦이 새 min(3)으로 확인, G7-a(하드코딩 경로)·G7-b(plugin false-green)가 가장 RED-fixable.
> **성격**: durable design spec (재진입 시 재사용). RPI cycle 33.
> **결정 모드**: 사용자 autonomy 지시(spec §8 "best-practice 자율 판단, 과한 게이트=init 마찰 주의") 하에 아래 2 결정을 best-practice로 확정 — 분기마다 정지 없이 진행.

**Status:** completed

---

## 0. 문제 (CONFIRMED, file:line 실측)

1. **G7-a 하드코딩 경로 (재현성)**: `setup/doctor.sh:13`
   `WINDOWS_CLAUDE_HOME_CANDIDATE="/mnt/c/Users/12132/.claude"` — 사용자 "12132" 하드코딩. 다른 사용자의 WSL에서는 절대 매칭 안 됨 → 타 사용자 fresh-clone 비이식. (WSL 분기 `:105-119`에서만 사용; 이 Git Bash 호스트는 `IS_WSL=0`이라 라이브에선 휴면 — 결함은 *타 사용자 WSL* 한정.)

2. **G7-b plugin false-green (관측/재현성)**: `setup/verify-all.sh`가 "ALL PASS — system meets §6.6 acceptance gate"를 출력하는데, RPI의 엔진인 superpowers 핵심 skill(brainstorming/writing-plans/executing-plans — `start-rpi-cycle` Phase R/P/I가 실제 호출)이 **부재해도** 그 메시지가 나온다. `doctor.sh:250-259`(20b)는 부재 시 WARN만 → `doctor` exit 0 → verify-all 통과. 즉 "ALL PASS"가 RPI 작동을 **거짓 보증**.

---

## 1. 결정 (2건)

### 결정 (1) — doctor.sh:13 이식 가능 유도

하드코딩을 제거하고 **우선순위 유도**로 치환:
1. 명시적 env override `WINDOWS_CLAUDE_HOME` (모든 셋업의 탈출구).
2. 없으면 Windows 상호운용으로 `%USERPROFILE%` 유도: `cmd.exe /c "echo %USERPROFILE%"` → `C:\Users\<user>` → `/mnt/<drive>/<...>/.claude` 변환 (드라이브레터 소문자, `\`→`/`).
3. 둘 다 실패/공백 → 후보 빈 문자열 유지 → 기존 `[ -d "$candidate" ]` 분기가 자연히 false → **WARN로 graceful degrade** (FAIL 경로 신설 금지 — `doctor.test.sh` Test2 exit-0 불변식 보존).

근거:
- `_common.sh`에 재사용할 경로유도 헬퍼 없음(explore A/D 확인) → net-new, but doctor.sh 자체에 자기완결(doctor는 `_common.sh`를 source 안 함).
- WSL 분기는 라이브 휴면(IS_WSL=0)이라 라이브 회귀 위험 0. 결함·수정 모두 *타 사용자 WSL* 한정.
- override를 1순위로 둬 interop 부재(cmd.exe 차단/없음) 환경도 명시 경로로 동작.

### 결정 (2) — RPI 전제조건 게이트는 verify-all STAGE 0 (doctor 아님)

`setup/verify-all.sh` 최상단에 **STAGE 0 "RPI 전제조건"** 추가:
- superpowers 핵심 트리오 `brainstorming/writing-plans/executing-plans`의 SKILL.md를
  `"$HOME"/.claude/plugins/cache/*/superpowers/*/skills/<skill>/SKILL.md` glob으로 존재 확인.
- 하나라도 부재 → 명확한 actionable 메시지(`/plugin install superpowers@claude-plugins-official`) 출력 + **exit 1** (이후 STAGE 전부 스킵 → "ALL PASS" 미출력).
- 라이브는 트리오 존재(explore E 확인: `plugins/cache/claude-plugins-official/superpowers/5.1.0/skills/<skill>/SKILL.md`) → STAGE 0 통과 → 무회귀.

**왜 doctor가 아니라 verify-all인가 (run-context 분리, explore C가 결정적 확정):**
- `install.sh:134`가 doctor를 **플러그인 설치 전에**(STEP 5/6) 호출하고 `|| {warning}`로 **FAIL이어도 중단 안 함**. 플러그인은 install.sh가 못 깖(재시작 후 `/plugin`으로 수동). ∴ doctor를 hard-gate로 만들면 *모든 fresh install이 정상 순서인데도* 시끄럽게 실패.
- doctor = **환경 진단**(install-time, 플러그인 아직 없음 → WARN가 정직). verify-all = **수용 게이트**(`/plugin install` 후 실행, "ALL PASS"는 완전 가동 보증). → 게이트는 verify-all에만.
- doctor 20b WARN는 **그대로 유지** → doctor의 PASS/WARN/FAIL 카운트·exit 불변 → `doctor.test.sh` 무영향(explore A).

**드리프트 노트**: verify-all STAGE 0 트리오 목록과 doctor 20b의 4개 목록은 *목적이 다른 의도적 부분집합*(수용-임계 트리오 vs 환경 advisory 4종) — 동일성 seal 신설 안 함(둘을 같다고 봉인하면 오히려 틀림; 과한 seal=friction). 주석으로 관계 명시.

---

## 2. 컴포넌트 / 데이터 흐름

```
install.sh (STEP5) ──run──> doctor.sh   [환경 진단; superpowers 부재→WARN; FAIL이어도 install 계속]
                                  │
                                  └─ WSL 분기(:105-119, 라이브 휴면): WINDOWS_CLAUDE_HOME_CANDIDATE
                                        = override > %USERPROFILE% 유도 > 빈값(→WARN)

verify-all.sh
  STAGE 0  RPI 전제조건   ← NEW: 트리오 glob; 부재→exit 1, "ALL PASS" 미출력
  STAGE 1  doctor / 1b doctor.test
  STAGE 2  verify-setup / 2b seal-regression / 2c failopen-surface / 2d rpi-prereq-gate(NEW test)
  STAGE 3  run-all (hook 129)
  STAGE 4  integration
  → ALL PASS (트리오 존재 + 전 STAGE green일 때만)
```

## 3. 테스트 (TDD)

### 결정 (1) — `setup/tests/doctor.test.sh`에 Test 5 추가 (source 이식성 불변식)
- **RED**: `grep -F '/mnt/c/Users/12132' doctor.sh` 가 매칭(현재 line 13) → "하드코딩된 사용자 경로 존재" → FAIL.
- **GREEN**: 치환 후 매칭 0 → PASS.
- 단언 형태: doctor.sh 소스에 사용자-특정 하드코딩 홈 경로(`/Users/12132` 리터럴)가 **없어야** 한다.
- WSL 런타임 분기 동작은 IS_WSL-gated라 비-WSL CI에서 단위 불가 → source 불변식이 "임의 사용자 fresh-clone 이식" 보증의 정확한 proxy. (override env 동작은 보조 단언으로 추가 가능하나 분기 휴면이라 핵심은 source 불변식.)

### 결정 (2) — `setup/tests/rpi-prereq-gate.test.sh` 신설 + verify-all STAGE 2d 배선
- **RED→GREEN core**: 임시 HOME(plugins/cache 無)에 verify-all.sh 복제 → 실행 → **assert: exit≠0 AND 출력에 전제조건-부재 메시지 포함 AND "ALL PASS" 미포함**.
  - 치환 전(STAGE 0 부재): bare HOME → STAGE 1 doctor가 다른 이유로 실패하나 *전제조건 메시지 없음* → 테스트 RED.
  - 치환 후: STAGE 0가 메시지+exit1 → GREEN.
- **no-false-positive**: 라이브 glob(트리오)이 실제 매칭함을 단언(라이브는 STAGE 0 통과해야 함 = 무회귀 보증).
- **witness**: 라이브 `~/.claude` 무변형(STAGE 0는 첫 블록이라 fast-fail; 임시 HOME만 사용). cksum 불변 단언.
- seal-regression/failopen 선례와 동형으로 verify-all STAGE 2d에 배선(1-레벨 중첩, 서브-verify-all은 STAGE 0에서 종료 → 무한재귀 없음).

### 무회귀 (closeout 게이트)
- `run-all.sh` ≥129/129 (이 작업은 hook 단위테스트 cases.tsv 미변경 → 129 불변 기대).
- `verify-setup.sh` ≥65/0 (#28 bash -n 통과 = 편집 2파일 문법 유효; verify-all 독립).
- `verify-all.sh` ALL PASS (라이브 트리오 존재 → STAGE 0 통과; STAGE 2d GREEN).

## 4. 에러 처리 / 엣지
- cmd.exe 부재/interop 차단 → 유도 2단계 빈 결과 → 후보 빈값 → WARN(crash 금지). `set -euo pipefail` 하에서 `cmd.exe ... 2>/dev/null || true` + 빈값 가드.
- `%USERPROFILE%` 형식 비정상(드라이브레터 없음) → 정규식 미매칭 → 후보 빈값 → WARN.
- STAGE 0 glob에 nullglob 미설정 셸 → glob 미매칭 시 리터럴 잔류 가능 → `ls ... >/dev/null 2>&1` 존재판정으로 안전화(doctor 20b와 동일 관용구).

## 5. 비목표 (YAGNI)
- skill-creator/grill-with-docs 게이트화(트리오만; start-rpi-cycle R/P/I 직접 의존분).
- doctor 20b를 FAIL로 승격(run-context상 틀림).
- 두 목록 동일성 seal 신설(의도적 부분집합).
- WSL 런타임 분기 단위테스트(환경-gated; source 불변식으로 대체).

---

> 본 spec은 R(brainstorming+explore-strict)이 도출한 2 결정의 durable 기록. spec delta = **YES**(신규 design 결정) → 본 파일이 그 기록. 다음: Gate R → writing-plans(cycle-33 plan).
