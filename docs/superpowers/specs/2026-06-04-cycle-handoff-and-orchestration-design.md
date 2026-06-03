# RPI 사이클 핸드오프 & 오케스트레이션 개선 — Design Spec

**Status:** active
**Date:** 2026-06-04
**Subsystem:** RPI cycle handoff / 사이클 간 제어
**Spec-lifecycle:** durable (서브시스템당 1회 inception, 사이클당 plan이 일부씩 구현 — [[harness-ssot-drift-guard]] 개정 2026-06-04 모델)

> 이 spec은 grill 재배치/drift guard와 **다른 설계 관심사**(사이클 *간* 핸드오프·제어)라 별도 durable spec으로 inception. 본 spec은 P2·P3 두 섹션을 담되, **cycle-14 plan은 P2만** 구현하고 P3는 후속 사이클 plan으로 남긴다(durable spec → many plans 시연).

---

## Problem

1단계(첫 RPIC)에서 매우 길게 작업한 뒤, 2번째 사이클부터는 사용자가 큰 흐름을 **goal 프롬프트로 제어**하고 싶을 때가 있다. 또한 사이클 사이에 보통 `/compact`를 끼우므로, 다음 사이클이 컨텍스트를 잃는다. 현재 start-rpi-cycle Closeout은 사이클을 마감하고 보고하지만 **다음 사이클을 위한 goal 초안을 산출하지 않는다.** 결과:

- 사용자가 다음 사이클을 goal로 돌리려면 매번 직접 목표·읽을 문서·진행 정책을 재구성해야 함.
- compact 직후 컨텍스트 공백 → 직전 사이클의 열린 항목·필수 문서가 유실되기 쉬움.

(참고: "재검증 R 후 spec delta 강제"는 **cycle-13(P1)에서 이미 해결** — Phase R.B ★ 이진 단언. 본 spec은 그 후속 P2·P3만 다룬다.)

## Decisions

- **D-P2 (사이클 간 goal 핸드오프 — advisory):** start-rpi-cycle Closeout Step C-1에 sub-step 7 추가. `cycle.count ≥ 1`일 때 다음 사이클 goal 초안을 emit. **하드 게이트가 아니라 advisory** — 다음 사이클 시작 시점엔 검증할 plan/spec 아티팩트가 없어 기계적으로 강제할 게 없기 때문(하드 게이트는 friction만 됨).
  - **자가-표면화 방식:** goal 초안을 Communication Protocol의 **고유 필수 필드 `next-cycle-goal`**로 둔다(unknowns에 접지 않음). 생략하면 *명명된 필수 필드*가 빠져 보고가 구조적으로 불완전해지고, 다른 필드 내용으로 대체 불가라 누락이 드러난다.
    - *(cycle-14 verify 적대 리뷰 교정)* 최초 설계는 unknowns에 접으려 했으나, unknowns가 "추가 결정 권고 + goal 초안" **복합 필드**라 다른 절반만 채워 goal 초안을 가릴 수 있는 누출이 발견됨 → 고유 필드로 분리. 사용자 의도(자가-표면화, "문서상 필수인데 표면 없이 넘어가는 케이스 제거")를 더 견고히 충족.
    - **zero-open 근거 의무:** "열린 항목 0" 출력은 4개 소스(미완료 plan task·drift 후속·non-obvious action·R/Closeout unknowns) 점검 결과를 *수집 근거와 함께* 명시. 근거 없는 빈 "제안 없음" 금지(under-collection 위장 방지).
    - **cycle%5 무조건성:** cycle%5에선 improve-codebase-architecture가 항상 열린 항목에 포함 → zero-open 경로로 빠지지 않음. (item 4는 토픽을 명명하지 않고 sub-step 7로 순수 위임 — improve-codebase-architecture 매핑은 sub-step 7 단일 소스.)
    - **3요소 구조화 (cycle-14 verify 적대 리뷰 *2차* 교정):** `next-cycle-goal` "그 외" 값은 `goal:`/`read-before:`/`autonomy:` **3개 라벨 하위줄**로 출력. 필드 분리와 동일 원리를 한 단계 안쪽(3요소)에 재적용 — 한 요소만 채우고 나머지를 가리는 *내부* 복합-마스킹 누출을 구조로 차단(라벨 누락 = 필드 누락과 동급으로 conspicuous).
      - **수락된 잔여(정지점):** 각 라벨 *내용*의 완전성(필수 문서를 빠짐없이 담았는지 등)은 hook 없이 구조로 강제 불가 → advisory 잔여로 **명시 수락**(아래 Non-Goals의 필드-레벨 잔여와 동급). 구조는 세 요소의 *존재*를 표면화하고, 내용 품질·진실성(fabrication)은 hook-free 잔여다.
  - **cycle%5 병합:** 기존 item 4의 `cycle.count % 5 == 0 → improve-codebase-architecture 제안`을 sub-step 7로 위임. cycle%5일 때 drafted goal의 주제가 곧 "improve-codebase-architecture 실행"이 된다(별도 묻기 중복 제거 → 하나의 "다음 액션" 블록).
  - **열린 항목 0:** "다음 사이클 제안 없음 (열린 항목 0)" emit.
  - **goal 초안 3요소(필수):**
    1. **상세 목표** — 한 줄 금지. 관찰가능 success criteria(무엇이 PASS인지) 포함.
    2. **post-compact 필수 읽기 문서** — `/compact`를 가정하고 다음 사이클 진입 전 반드시 읽을 문서를 *존재하는 것만* 절대경로로 나열: 작업 대상 subsystem durable spec(+관련 §), CONTEXT.md, architecture.md(+관련 ADR), 직전 plan, non-obvious.md, 관련 CLAUDE.md §섹션.
    3. **자율 best-practice 진행 directive** — goal 실행 중 선택 분기는 멈추지 말고 best-practice로 판단해 진행(scope 내). 멈춤은 진짜 사용자 결정이 필요할 때만.

- **D-P3 (ultracode workflow로 Phase I 구동 — advisory + ultracode-gated, *후속 사이클*):** Phase I에 옵션 (d) 추가. ultracode ON일 때만 표면화. canonical 2-stage 파이프라인(plan task 순): stage1 `agentType='execute-strict'`, stage2 `agentType='review-strict'`, **둘 다 schema 금지**(StructuredOutput 부재 → 실패 — [[feedback_workflow_agenttype_schema]]). wrapper는 self-spawn 불가라 execute→verify는 반드시 2 스테이지. **데이터 의존(load-bearing):** stage2(읽기전용 review-strict)는 stage1 산출(diff/파일)을 context_paths로 받아야 함(안 먹이면 stale 검증 → false PASS). 같은 파일 동시수정 ≥2면 `isolation:'worktree'` + **stage2는 짝 stage1과 같은 worktree에서 리뷰**(base 읽으면 false PASS/FAIL). 우회 불가 근거는 enforce-rpi-cycle이 PreToolUse Write|Edit 매처라 서브에이전트 execute-strict 쓰기에도 동일 발화 + 디스패치 시 plan·spec 이미 존재. ≥5 task일 때만 권장. **cycle-15에서 구현됨** (verify 적대 리뷰가 데이터-의존·worktree-스코프 누락을 잡아 보강) (plan: `docs/superpowers/plans/2026-06-04-ultracode-phase-i-option.md`).

## Non-Goals (그리고 anti-pattern 방어)

- **P2용 새 hook / 하드 게이트 — 기각.** 사용자가 "둘 다 advisory"로 명시 수락. advisory는 *의도된* 설계지 "문서상 필수인데 표면 없이 넘어가는" 미탐 실패가 아니다 — 그 구분을 spec에 명시해 둔다(미래 리뷰어가 anti-pattern으로 오플래그하지 않도록).
- **#17-class drift guard — *부분* 적용.** P2 *규칙*은 §3·README·다른 skill에 복제하지 않아 cross-doc drift는 없다. 그러나 verify 적대 리뷰가 짚었듯, next-cycle-goal **3 라벨(`goal:`/`read-before:`/`autonomy:`)은 SKILL.md 내 두 곳(sub-step 7 절차 + Communication Protocol 출력 계약)에 필연적으로 중복**된다(둘 다 필수 — 계약에 라벨 없으면 report-time 표면화 약화). dedupe 불가한 필연적 중복이므로 **#18 verify-setup 체크로 파일-내 parity 봉인**(#17 패턴의 인스턴스, generalized 프레임워크 아님). 한편 라벨 *내용* 완전성은 ephemeral 출력이라 비교 아티팩트가 없어 기계 가드 불가 → 수락된 advisory 잔여(위 자가-표면화 정지점).
- **CLAUDE.md §3 수정 — 불요.** §3 Closeout 줄은 "review-strict drift 검사 + 자산 갱신"의 고수준 요약이라 Closeout sub-step(state.json·v2/v3·non-obvious archive·verify-setup)을 *애초에 열거하지 않음*. goal-draft sub-step 추가는 §3과 모순 없음 → 캐시 비용 발생하는 §1 편집 회피.
- **README/doctor 수정 — 불요.** README line 165 Closeout 요약도 동일 granularity로 sub-step 미열거 → goal-draft 누락은 drift 아닌 일관된 추상화. doctor는 순수 prose라 무관.

## Change Set

| 파일 | 변경 | 게이트 영향 |
|---|---|---|
| `skills/start-rpi-cycle/SKILL.md` | (a) Step C-1 item 4 `cycle%5` → sub-step 7 순수 위임(토픽 무명명) (b) sub-step 7 추가(advisory, cycle≥1, 3 라벨 하위줄, zero-open 근거 의무, cycle%5 무조건) (c) Communication Protocol에 **고유 필수 필드 `next-cycle-goal`** 추가(unknowns 분리, 3 라벨) | enforce-orchestrator 골격(Phase≥3·Agent≥1·Communication Protocol) 보존, Phase R 토큰 무변경 → #17 green 유지 |
| `setup/verify-setup.sh` | 신규 check #18: next-cycle-goal 3 라벨이 sub-step 7 ↔ Communication Protocol 두 곳에 parity (파일-내 drift 봉인) | PASS 52→53; #18 green 필요 |

## Acceptance

- `bash ~/.claude/hooks/tests/run-all.sh` → 82/82, 정합 OK (hook 무변경 → 동일 기대).
- `bash ~/.claude/setup/verify-setup.sh` → FAIL=0, PASS=53, "§3 ↔ Phase R"(#17) + "next-cycle-goal 라벨 parity"(#18) 모두 green.
- `bash ~/.claude/setup/verify-all.sh` → ALL PASS.
- start-rpi-cycle Closeout Step C-1에 sub-step 7 존재: cycle≥1 게이트 + 3요소(상세목표·post-compact 필수읽기·자율 best-practice) + zero-open 처리.
- Communication Protocol에 **고유 필수 필드 `next-cycle-goal`** 존재(cycle≥1); zero-open은 수집 근거 동반; unknowns와 분리(복합 필드 누출 방지); goal 초안은 `goal:`/`read-before:`/`autonomy:` 3 라벨 하위줄(내부 누출 차단).
- item 4 cycle%5가 sub-step 7로 위임됨(중복 묻기 제거); cycle%5는 zero-open이어도 적용.

## P3 — Acceptance (구현됨 cycle-15)

- Phase I 옵션 (d) 추가: ultracode ON일 때만 표면, OFF 시 비활성(항상-on 권유 없음). 2-stage(execute-strict→review-strict, schema 금지) + wrapper self-spawn 불가 명시. **데이터 의존**(stage2가 stage1 diff를 context_paths로 수령) + **worktree 스코프**(stage2는 짝 stage1 worktree에서 리뷰) 명시. 같은 파일 동시수정 ≥2면 worktree. ≥5 task 권장.
- plan-존재·spec-before-plan 게이트(PreToolUse Write|Edit 매처)가 Workflow 서브에이전트 쓰기에도 동일 발화 + 디스패치 시 plan·spec 이미 존재 → P3 우회 불가.
- (§3 Implement 줄 "executing-plans 또는 execute-strict"는 *도구 프리미티브* 수준 요약 — (a)/(c)/(d)는 모두 execute-strict를, (d)는 review-strict(§3 Closeout 줄)도 합성 → §3 정확, 편집 불요/§1 캐시비용 회피.)
