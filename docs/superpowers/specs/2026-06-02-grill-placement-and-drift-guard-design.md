# grill 재배치 + 문서-강제 Drift Guard — Design Spec

**Status:** active
**Date:** 2026-06-02
**RPI-Cycle:** 12

---

## Problem

두 개의 결함이 발견됨 (둘 다 "문서상 필수인데 강제·상시 표면이 없어 넘어간다"는 같은 메타-실패).

1. **grill 배치 결함.** `start-rpi-cycle` Phase R가 `A(grill) → B(brainstorming) → C(explore)`로 grill을 맨 앞에 두지만, 실제 세션은 거의 항상 brainstorming으로 시작한다. 원인 4겹(검증 완료, conf 0.92~1.0):
   - CLAUDE.md §3(상시 로드)이 grill을 누락하고 `Research: brainstorming + explore-strict`로 brainstorming을 맨 앞에 명시.
   - grill-first를 강제·환기하는 hook 0개 (UserPromptSubmit 없음; RPI hook은 "코드 쓸 때 active plan"만 검사).
   - grill 자신의 description이 "stress-test a plan"이라 task 시작 시점에 매칭 안 됨(narrow).
   - superpowers using-superpowers가 "brainstorming first"를 상시 명시.
   추가로 grill은 native상 **이미 형성 중인 design을 도메인 모델에 비춰 stress-test**하는 도구이며(원전 확인), 산출물은 `CONTEXT.md`+ADR뿐 — **spec 문서를 건드리지 않는다.**

2. **§3 누락의 근본 원인 = SSOT drift (시스템/프로세스, 사람/AI 아님).** RPI phase sequence가 CLAUDE.md §3 / start-rpi-cycle SKILL.md / README scenario 2 / explore-strict 헤더에 **손으로 4중 복사**돼 있는데, **복사본 일치를 검사하는 장치가 0개.** verify-setup.sh는 **개수만**(§마커 8, hook 8, template 13) 검사하고 **내용은 절대 비교 안 함.** 2026-05-19 통합이 skill·README는 고쳤지만 §3은 누구의 "수정 파일 목록"에도 없어 stale로 남음. 같은 공백으로 README 안 `12 파일`(line 22) vs `13개 파일`(line 8·139) 모순도 생존 중.

## Decisions

- **D-placement (B):** Phase R를 `① brainstorming → ② grill → (③ spec 역류) → ④ explore`로 재배치. grill은 brainstorming이 만든 design을 stress-test. (판정단 3개 만장일치)
- **D1 (spec 역류 강제 = Gate R 검증 + 기계적 바닥):** grill 결과를 spec에 역류(reconcile)시키는 단계를 명시하고, Gate R를 review-strict **차단형**으로 격상해 spec↔CONTEXT.md/grill 일관성을 검증. 추가로 enforce-rpi-cycle을 확장해 **plans/*.md 작성 시 specs/*.md 존재를 요구**(기계적 spec→plan 바닥; 새 hook 없이 기존 hook 확장).
- **D2 (ADR SSOT = architecture.md):** 하네스 §5 유지. start-rpi-cycle 본문에서 grill ADR을 `docs/ai-context/architecture.md`(append-only)에 기록하도록 유도. grill SKILL.md 본문은 외부 스킬이라 미수정.
- **D-rootcause (#17 mechanical drift guard):** verify-setup.sh에 content-drift 체크 추가 — start-rpi-cycle Phase R가 named한 도구 집합 ⊆ CLAUDE.md §3 Research 줄. 불일치 시 `fail()` → verify-all RED. skill body = SSOT, §3 = superset. (원래 누락을 잡아냈을 것이며 현재 트리에서도 RED — 실측 확인됨.) count-drift(README 12/13)는 해당 인스턴스를 수동 수정하고, 일반 count 체크는 follow-up으로 명시.

## Non-Goals

- grill-with-docs SKILL.md 본문 재작성 (외부 스킬, upstream 위임).
- 일반화된 "모든 중복 사실 비교" 프레임워크 (#18 generalized) — 과설계, false-positive 위험. 패턴(#17)만 확립하고 확장 여지를 남김.
- UserPromptSubmit 환기 hook 신설 (노이즈 대비 실익 낮음; §3+#17로 충분).

## Change Set

| 파일 | 변경 | drift-check 영향 |
|---|---|---|
| `setup/verify-setup.sh` | 신규 check #17 (§3 ↔ start-rpi-cycle Phase R 도구 superset) | §3 수정 전까지 RED(의도) |
| `hooks/enforce-rpi-cycle.sh` | plans/*.md 작성 시 specs/*.md 존재 요구 (spec-before-plan 바닥, RPI_SKIP 우회) | — |
| `hooks/tests/cases.tsv` + `run-all.sh` | 신규 케이스 28(no-spec block)/29(spec pass)/30(skip) | 정합 게이트 통과 필요 |
| `skills/start-rpi-cycle/SKILL.md` | Phase R 재배치(brainstorm→grill→spec역류→explore) + Gate R review-strict 격상 + ADR→architecture.md 유도 + Closeout에 verify-setup 실행 | enforce-orchestrator 골격 유지 |
| `README.md` | scenario 2(162) 순서 정정 + `12 파일`(22)→13 정정 | — |
| `CLAUDE.md §3` | `Research: brainstorming → grill-with-docs → explore-strict` 로 정합 (**세션 끝, §1**) | #17 green 전환 |

## Acceptance

- `bash ~/.claude/hooks/tests/run-all.sh` → pass rate ≥95%, 정합 OK (신규 28/29/30 포함).
- `bash ~/.claude/setup/verify-setup.sh` → §3 수정 후 PASS=0 FAIL (이전엔 #17으로 RED).
- `bash ~/.claude/setup/verify-all.sh` → ALL PASS (§3 수정 후).
- start-rpi-cycle Phase R가 brainstorm→grill→spec역류→explore 순; Gate R가 spec↔CONTEXT.md 검증을 차단 기준으로 명시.
