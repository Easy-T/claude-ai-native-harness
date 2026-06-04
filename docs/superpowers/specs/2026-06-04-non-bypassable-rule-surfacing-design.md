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

---

## cycle-17 확장 (2026-06-04 개정 — D-F2~D-F12)

> **개정 근거:** 직전 재점검 워크플로(wirrmbi91)가 확정한 F2~F11 + 본 세션 발견 F12. 모두 본 spec thesis("문서상 필수인데 *silent-skip / 우회 / drift*로 새는 것을 기계적으로 봉인")의 인스턴스라 별도 spec 신설 대신 durable spec **in-place 개정**(Phase R.B spec-delta=YES). cycle-17 R은 brainstorming·grill-with-docs·explore-strict·claude-code-guide를 **실제 Skill/Agent 호출**로 수행(F12 자가-교정 dogfood). 실측 ground-truth + grill 교정 반영.

### Problem 확장 — 3 클래스
1. **게이트 우회(§3 enforcement 사이드도어):** `enforce-rpi-cycle.sh:31` whitelist-1의 `*/README*` **prefix-글롭**이 `is_code_path`보다 먼저 발화 → `lib/README.sh`·`README_helpers.py` 등 코드가 §3 plan 게이트 통과(F2). `redirect-targets.js`(enforce-rpi-bash의 셸 사이드도어 파서)가 `>`/`>>`/`tee`만 봐 `sed -i`·`cp`·`mv`·`python -c open(...,"w")`로 코드 밀반입 가능(F3).
2. **drift(선언≠실측):** `settings.json`↔`example` hook 이름/순서 무가드(F4); `doctor.sh` REQUIRED_HOOKS가 cycle-16 surface-constitution 누락(F4b); `last_drift_check` 무조건-today 스탬프(F5); SKILL.md 스키마 경로 dual-context 404(F7); README 카운트 정체(46 PASS·79 cases·5 E2E)(F8~F10).
3. **phase 자가-표면 부재(F12):** RPI *phase 실행*(어느 skill을 실제 호출했는가)에 자가-표면 계약이 없다. `enforce-rpi-cycle`은 plan-FILE 존재(proxy)만 검사 → R-phase skill 호출 여부를 보는 hook/verify/보고필드 0(재점검 finding #5; cycle-16 자체가 brainstorming/grill 미호출로 노출). F1/F6과 동일 "복합/암묵 표면에 접혀 silent-skip" 클래스.

### Decisions

- **D-F2 (README 글롭 확장자화):** `enforce-rpi-cycle.sh:31` `*/README*` → `*/README|*/README.rst|*/README.adoc|*/README.markdown|*/README.org`. `.md`/`.txt` README는 whitelist-1의 `*.md`/`*.txt`가 이미 통과시키므로, 이 패턴은 *비코드 doc README*만 커버. 코드-ext README(`README.sh`/`README.ts`/`README_helpers.py`)는 어느 패턴에도 안 걸려 `is_code_path`로 낙하 → plan 게이트. **불변식 복원:** "코드 확장자는 어떤 이름이어도 디렉터리/이름 면제 없음"(CODE_EXTS SSOT). bash case-glob 실증 통과(코드 README→게이트, 문서 README/`README`/`.rst`/`.adoc`→통과).

- **D-F3 (셸 파일-쓰기 타깃 파서 확장):** `redirect-targets.js`를 "리다이렉트 타깃" → **"셸로 코드파일을 쓰는 타깃"**으로 확장(헤더 주석 갱신). 추가 탐지: `sed -i[SUFFIX] … FILE`(in-place), `cp SRC DST`/`mv SRC DST`(DST가 코드-ext), `python[3] -c '…open("FILE","w"|"a"|…)…'`. 출력 계약(첫 코드-ext 타깃 문자열 또는 빈 문자열) **유지** → 유일 caller `enforce-rpi-bash.sh:32`/단위테스트(cases.tsv 75-77) 무영향. **python -c는 보수적 best-effort heuristic**(리터럴 파일명 + write 모드 + 코드-ext만; f-string·변수·exec·multiline은 **탐지 안 함** = 수락된 false-negative, Non-Goal). `enforce-secret-scan`은 명령 *전체*를 스캔하는 자체 파서(line 18-25)라 이 맹점을 **공유하지 않음**(explore 확인) → F3 범위 = redirect-targets + enforce-rpi-bash 한정.

- **D-F4 (settings↔example hook parity, #23):** verify-setup 신규 #23 — `settings.json`·`settings.example.json` 양쪽에서 `.hooks.*[].hooks[].command`의 **basename 순서+이름**만 추출(node)해 비교. **값/시크릿 비교·출력 금지**(env·model·permissions 등 무관 필드 미접근). 현재 일치하나 향후 drift 봉인(F4 goal). settings.json은 gitignore지만 로컬 실재(doctor #23이 이미 node로 읽음).

- **D-F4b (doctor hook-list 복구 + #24):** `doctor.sh:252` REQUIRED_HOOKS에 `surface-constitution.sh` 추가(9→10; `${#}` 출력 동반 변동). cycle-16이 verify-setup #8만 갱신하고 doctor를 놓친 재발 방지 → verify-setup 신규 **#24**: doctor REQUIRED_HOOKS(_common.sh 제외)가 **디스크의 모든 `hooks/*.sh`를 커버(⊇)**하는가. (하드코딩 두 배열 비교보다 견고 — disk=SSOT라 *신규 hook 파일 추가 후 doctor 미갱신*까지 잡음. #17/#18/#19 철학의 hook-list 인스턴스; generalized "모든 중복 비교" 아님.)

- **D-F5 (last_drift_check 조건부):** SKILL.md Closeout sub-step 3의 `audit.last_drift_check: today`를 **조건부**로 — Step C-1 drift review(sub-step 1)가 실제 수행된 사이클에만 갱신(abandoned/미수행 시 미갱신). 하네스 사이클은 sub-step 6(verify-setup) 결과(harness-verify)와 의미적 연동. prose 수정(advisory; hook 강제 대상 아님).

- **D-F7 (스키마 경로 dual-context 해소):** SKILL.md:172 `` `.claude/state.schema.json` `` → `` `state.schema.json` (state.json과 같은 디렉터리) ``. schema는 하네스 루트 실재; `.claude/` 접두는 프로젝트 맥락에서만 참 → "state.json의 sibling"으로 표현해 **양쪽 맥락 정답**.

- **D-F8/F9/F10 (카운트 동기 + seal):**
  - F8 README:278 `46 PASS` → **실측 PASS**(cycle-17이 #20~#24 5체크 추가 → 55+5=**60**; 구현 후 verify-setup 실행으로 재확정).
  - F9 README **:272 및 :500** 둘 다 `79` cases → **실측 cases.tsv 행수**(cycle-17 신규 케이스 포함 후 확정).
  - F10 README:279 `5개 E2E` → **8**(실측 E2E.A~H). 신규 E2E 무추가(F2/F3 회귀는 cases.tsv unit 케이스가 커버 — surface 축소). `2026-05-01` spec의 `4개`는 **point-in-time 사료라 미수정**(append-only 정합 — 당시 설계는 실제 4개).
  - **신규 seal:** verify-setup **#20**(cases.tsv 실측 == README 선언 카운트) · **#21**(verify-integration E2E 실측 == README 선언). 둘 다 README 앵커 텍스트(`` `cases.tsv` (N 케이스 ``, `N개 E2E 시나리오`)에서 숫자 추출해 grep-count와 비교 → 재드리프트 자기봉인. **PASS 카운트(#8류 self-referential)·doctor 카운트(brittle)는 seal 제외** — F8 수동 수정, F11 refute.

- **D-F11 (REFUTE):** doctor `24개`는 **유지**. 실측: distinct check 라벨 ~24-28개, 섹션 주석 #1~#24(결번·서브항목 18b/21b 존재). "24개 이상"은 방어 가능하고 doctor 자체 #24 라벨과 정합. re-review의 `18`은 재현 불가(번호 기준/check 기준 모두 18 아님). README 미변경, refute 근거 본 spec에 기록(미래 재플래그 차단).

- **D-F12 (phase-skills 자가-표면 — 본 spec 핵심 확장):**
  - **Communication Protocol 신규 전용 필수 필드 `phase-skills:`** — 각 Phase에서 호출한 skill을 `<skill>: invoked` 또는 `<skill>: skipped — <이유>`로 선언(R: brainstorming/grill-with-docs/explore-strict · P: writing-plans · I: executing-plans|execute-strict|(a)|(d) · Gate/Closeout: review-strict). 누락/무사유 skip = 명명된 필수 필드 누락 = 구조적 불완전(harness-verify·next-cycle-goal 선례 — 복합/암묵 필드로 대체 불가 → 자가-표면).
  - **Step C-1 신규 sub-step** — phase-skills 선언 요구(절차↔계약 양쪽 존재).
  - **#22 parity:** `phase-skills` 토큰이 Step C-1 ↔ Communication Protocol 두 곳 필연 중복 → verify-setup **#22**로 봉인(#18/#19 파일-내 parity 인스턴스).
  - **Phase R/P 헤더 문구 보강:** "메인이 직접 따름" = **Skill 도구로 호출**임을 명시(절차 체화 오독=cycle-16 보조원인 차단).
  - **★ hook-forcing 기각 (grill/claude-code-guide 공식 docs 확정 — load-bearing):** PreToolUse는 `Skill` 매처로 *호출*은 잡지만 (a) `/skillname` 직접입력은 **bypass**, (b) Skill `tool_input`의 skill-이름 필드 **미문서화**, (c) hook에 **이전 tool 히스토리 접근 없음**(현재 호출 + session_id/transcript_path만). "phase Y에서 skill X 필수"를 강제하려면 session_id 키 외부상태/transcript 파싱 자체구현 필요 = **과설계**. → **advisory 자가-표면이 올바른 상한**(정지점: 표면은 skip을 *눈에 띄는 선언*으로 바꿀 뿐 호출을 물리 강제하진 않음 = F1 내용-잔여와 동급 수락).

### Non-Goals 추가 (재플래그·과설계 방어)
- **F11 doctor 카운트 변경 — 기각(REFUTE).** D-F11 근거. "18로 맞춰라" 재제기 금지.
- **phase-skills hook 강제 — 기각.** D-F12 grill 근거(미문서 필드·히스토리 부재·`/skill` bypass). 미래 후보로만: session_marker 기반 *보조* 자동기록(undocumented 필드 의존이라 advisory 우선).
- **F3 python -c 완전 파싱 — 기각.** 보수적 리터럴-파일명 heuristic만. AST/동적 경로는 범위 밖(YAGNI, false-negative 수락).
- **4-way hook-list SSOT 통합(settings/example/doctor/verify-setup 단일화) — 기각.** #23·#24는 *특정 인스턴스* parity만(generalized "모든 중복 비교" 프레임워크 아님 — [[harness-ssot-drift-guard]] 기각 입장 유지).
- **count seal을 모든 카운트로 — 기각.** cases·E2E(결정적 소스+안정 앵커)만. PASS=self-referential, doctor=brittle.

### Change Set (cycle-17)
| 파일 | 변경 | 게이트 영향 |
|---|---|---|
| `hooks/enforce-rpi-cycle.sh` | line 31 README 글롭 확장자화(D-F2) | 회귀: 코드 README 차단 |
| `hooks/lib/redirect-targets.js` | sed -i/cp/mv/python-c-write 탐지 추가(D-F3), 헤더 주석 갱신 | 출력계약 유지 → caller 무영향 |
| `setup/doctor.sh` | REQUIRED_HOOKS에 surface-constitution(D-F4b) | `${#}` 9→10 |
| `setup/verify-setup.sh` | **#20** cases-seal · **#21** E2E-seal · **#22** phase-skills parity · **#23** settings↔example parity · **#24** doctor⊇disk hooks | **PASS 55→60** |
| `skills/start-rpi-cycle/SKILL.md` | `phase-skills:` 필드(Protocol) + Step C-1 sub-step + Phase R/P "Skill 호출" 명시(D-F12) + sub-step 3 조건부 stamp(D-F5) + :172 스키마 경로(D-F7) | #22 green 필요; #18/#19 awk 경계(`## Step C-1`/`## Communication Protocol`/`## Sub-cycle states`) 불변 |
| `README.md` | :272/:500 cases · :278 PASS · :279 E2E 동기(D-F8/9/10) | #20/#21 seal green |
| `hooks/tests/cases.tsv` + `run-all.sh` | F2(코드 README 차단) + F3(sed-i/cp/mv/python-c 단위·통합) 회귀 케이스 +10 (86→96) + 매칭 test 함수 | cases.tsv↔run-all 1:1; #20 seal과 README 동기 |

### Acceptance (cycle-17)
- `bash ~/.claude/setup/verify-all.sh` → **ALL PASS**.
- `verify-setup.sh` → FAIL=0, **PASS=60**, #17~#24 green(특히 신규 #20~#24).
- `run-all.sh` → 전부 PASS, cases.tsv↔run-all 1:1, **#20 seal과 README cases 일치**.
- 신규 회귀 green: (F2) `lib/README.sh` no-plan → enforce-rpi-cycle BLOCK(2); `docs/README.md` → 0. (F3) `sed -i … app.js`/`cp t deploy.sh`/`mv a.js b.sh` no-plan → enforce-rpi-bash BLOCK(2); doc 타깃 → 0.
- `phase-skills:` 필드가 Communication Protocol·Step C-1 양쪽 존재, **#22 parity green**.
- README cases(:272/:500)·PASS(:278)·E2E(:279) == 실측. doctor `24개` 유지(D-F11).
- **dogfood:** cycle-17 자체 Closeout이 `harness-verify`=PASS(#17~#24 green) + `phase-skills`(R: brainstorming/grill/explore/claude-code-guide invoked …)로 보고.
