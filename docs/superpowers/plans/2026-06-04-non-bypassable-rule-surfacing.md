**Status:** completed
**RPI-Cycle:** 16
**Started:** 2026-06-04

# cycle-16 — 거버넌스 규칙 회피-불가 표면화 (F1 + ADOPT) 구현 Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline).

**Goal:** (F1) start-rpi-cycle Communication Protocol에 verify-setup PASS 전용 필수 필드 `harness-verify:` 추가 + verify-setup #19 parity로 cycle-14 마스킹 재발(F6) 봉인. (ADOPT) §5/§8 의무를 매칭 액션 순간 `additionalContext`로 환기하는 advisory hook `surface-constitution.sh` 신설(세션당 §별 1회). 둘 다 "문서상 필수 규칙 → 회피-불가 표면" 원리의 인스턴스.

**Architecture:** spec `docs/superpowers/specs/2026-06-04-non-bypassable-rule-surfacing-design.md` (durable, D-F1 + D-ADOPT). 새 hook 1개 + _common.sh 헬퍼 1개 + SKILL.md/verify-setup/settings/README/tests 정합 편집. CLAUDE.md 무변경(§1 캐시비용 회피 — §5/§8 *내용*은 이미 §에 있고, 표면화 메커니즘만 추가).

**Phase I 방식:** 옵션 (a)/(c) — 메인 세션 직접 surgical 편집 + Gate별 review-strict. **(d) 미채택 이유:** verify-setup.sh(2 관심사)·settings 쌍·cases.tsv↔run-all 강결합 + governance 고폭발반경 → 단일 컨텍스트 순차 편집이 worktree 병합 위험 회피. (자율 best-practice 판단.)

**Tech Stack:** bash(hook), node(JSON emit, _common 헬퍼), markdown(skill/README), bash(verify/test).

---

## Task 1: `_common.sh` — `emit_additional_context()` 헬퍼

**Files:** Modify `hooks/_common.sh` (line 130 `emit_system_message` 형제로)

- [x] **Step 1:** line 130 다음에 추가:
      `emit_additional_context() { MSG="$1" node -e 'process.stdout.write(JSON.stringify({hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:process.env.MSG}}))'; }`
- [x] **Step 2:** 한 줄 주석으로 용도 명시(모델 컨텍스트 주입용, systemMessage와 구분).
- **검증:** `bash -n hooks/_common.sh` OK; `MSG=x node -e ...` 형태가 valid JSON 출력.

## Task 2: `hooks/surface-constitution.sh` — 신규 advisory hook

**Files:** Create `hooks/surface-constitution.sh` (+ chmod +x)

- [x] **Step 1:** stable-claude-md.sh 골격 미러: `source _common.sh` → `require_node` → `read_input` → `json_get tool_input.file_path` → `normalize_path`. file_path 비면 exit 0.
- [x] **Step 2:** `session_id` 추출(비면 "unknown").
- [x] **Step 3:** §5 트리거 case — 매니페스트 파일명(package.json·go.mod·requirements.txt·pyproject.toml·Cargo.toml·pom.xml·build.gradle(.kts)·Gemfile·composer.json·*.csproj·pubspec.yaml). 매칭 시: `session_marker surface-adr $SID` 존재하면 exit 0; 아니면 touch marker → `hook_log` → `emit_additional_context "[§5 ADR] ..."` → exit 0.
- [x] **Step 4:** §8 트리거 case — UI 확장자(*.tsx·*.jsx·*.vue·*.svelte·*.css·*.scss·*.sass·*.less·*.styl). 매칭 시: `session_marker surface-ui $SID` dedup → `hook_log` → `emit_additional_context "[§8 UI] ..."` → exit 0.
- [x] **Step 5:** 비매칭 → `exit 0`(무출력). `chmod +x`.
- **검증:** `bash -n`; package.json 입력 → stdout JSON에 §5 + exit 0; .tsx → §8; 일반.md → 무출력 exit 0; 동일 SID 2회 → 2회차 무출력.

## Task 3: settings 배선 (example + 실제)

**Files:** Modify `settings.example.json` (line 47 뒤), `settings.json` (동일 배열)

- [x] **Step 1:** `settings.example.json` `Write|Edit|NotebookEdit` matcher 배열에 `{"type":"command","command":"$HOME/.claude/hooks/surface-constitution.sh"}` 추가(기존 4개 뒤 5번째).
- [x] **Step 2:** `settings.json` 동일 배열에 동일 항목 추가. **시크릿 값 절대 미변경/미노출** — surface-constitution 항목만 삽입.
- **검증:** 두 파일 모두 valid JSON(`node -e 'JSON.parse(...)'`); surface-constitution 항목 존재; 기존 hook/프록시 설정 불변.

## Task 4: `verify-setup.sh` — #8 목록 + #19 신설

**Files:** Modify `setup/verify-setup.sh`

- [x] **Step 1:** #8 루프(line 49 `for h in ...`)에 `surface-constitution` 추가; 주석 `# 8. 8 hook scripts` → `9 hook scripts`.
- [x] **Step 2:** line 131(#18 블록 끝) 뒤·line 133(최종 echo) 앞에 **#19** 추가 — #18 awk-parity 미러: Step C-1 블록(`/^## Step C-1/`~`/^## Sub-cycle states/`)과 Communication Protocol 블록을 추출, 토큰 `harness-verify`가 둘 다에 존재하면 `ok "harness-verify 필드 ↔ sub-step 6/Communication Protocol parity"` 아니면 `fail`. 추출 실패 시 fail("#19 섹션 추출 실패").
- **검증:** Task 5 후 `bash setup/verify-setup.sh` → PASS=55, #19 green. RED-path: SKILL.md에서 harness-verify 임시 제거 시 #19 fail 확인.

## Task 5: `SKILL.md` — harness-verify 전용 필드 + sub-step 6 참조

**Files:** Modify `skills/start-rpi-cycle/SKILL.md`

- [x] **Step 1:** sub-step 6(line 188-189)에 1줄 추가: "→ 결과는 Communication Protocol `harness-verify:` 전용 필드로 보고(복합 evidence에 접지 않음)."
- [x] **Step 2:** Communication Protocol(line 224 `next-cycle-goal` 블록 뒤)에 `harness-verify:` 추가 — **고유 필수 필드 (모든 사이클)**. 정확히 둘 중 하나: `PASS=<N> FAIL=0 (#17·#18·#19 green)`(하네스 수정) / `N/A — ~/.claude 미수정`(비-하네스). 생략 = 구조적 불완전. 토큰 `harness-verify`가 sub-step 6과 이 필드 양쪽에 존재(#19 parity).
- **검증:** enforce-orchestrator 골격(Phase≥3·Agent≥1·Communication Protocol) 보존; #17 green 유지(Phase R 토큰 무변경); #19 green.

## Task 6: 테스트 (cases.tsv + run-all.sh)

**Files:** Modify `hooks/tests/cases.tsv`, `hooks/tests/run-all.sh`

- [x] **Step 1:** run-all.sh의 advisory stdout 테스트 패턴(test_vlw 미러) 확인 후, surface-constitution용 test 함수 작성(합성 file_path + session_id 입력 → stdout grep + exit 0 단언). dedup 영향 없이 emit 보이도록 고유 session_id 사용.
- [x] **Step 2:** cases.tsv에 4행 추가(§5 emit·§8 emit·비매칭 silent·dedup-silent) + run-all.sh에 매칭 case_id `grep -qF` 가능하도록 함수/디스패치 추가. **cases.tsv↔run-all 1:1 정합 필수**(run-all 575-586 strict).
- **검증:** `bash hooks/tests/run-all.sh` → 전부 PASS, 정합 OK.

## Task 7: `README.md` 정합

**Files:** Modify `README.md`

- [x] **Step 1:** line 28 `### 8개 hook (활성)` → `9개`; 표(line 32-39)에 surface-constitution 행 추가(역할: §5/§8 JIT advisory, advisory).
- [x] **Step 2:** helper 목록(line 256 부근)·구조 트리에 hook 1개 반영(있으면).
- **검증:** README hook 개수·표·구조 일관.

## Task 8: 검증 (gates)

- [x] **Step 1:** `bash hooks/tests/run-all.sh` → 신규 3 포함 전부 PASS.
- [x] **Step 2:** `bash setup/verify-setup.sh` → FAIL=0, PASS=55, #17·#18·#19 green. (#19 RED-path 실측 1회.)
- [x] **Step 3:** `bash setup/verify-all.sh` → ALL PASS.
- [x] **Step 4:** surface-constitution fixture 수동 검증(§5/§8/silent/dedup) + review-strict로 spec↔구현 일치.

## Task 9: Closeout

- [x] **Step 1:** review-strict drift 점검(자산 갱신/scope).
- [x] **Step 2:** state.json cycle.count 15→16, last_completed_at/last_drift_check 2026-06-04.
- [x] **Step 3:** plan Status active→completed.
- [x] **Step 4:** spec Acceptance 체크 + 메모리(`project_harness_ssot_drift_guard`에 #19, 신규 메모 또는 p2p3 메모에 cycle-16) + MEMORY.md 동기.
- [x] **Step 5:** master-direct commit + push. Communication Protocol 보고에 **harness-verify=PASS 증거(dogfood)** + next-cycle-goal(cycle-17 = F2~F11) 포함.
