# cycle-21: genesis-record 노트 (Model 1+) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:execute-strict to apply the two byte-exact edits below. 단일 파일(`2026-05-01-ai-native-orchestration-design.md`) 문서 편집이라 메인세션 순차 + execute-strict 위임. master-direct+push 기존 워크플로 — finishing-a-development-branch 미적용, Closeout이 마감.

**Status:** completed

**Goal:** genesis 설계 spec의 글로벌-카운트(hook/skill/메타룰 ~40곳)를 Model 1(genesis-record)로 확정 — 상단에 **숫자-0 genesis 포인터 노트 1개** 추가로 모든 v1 카운트를 "의도된 역사 기록"으로 재프레이밍하고, 현재 카운트 SSOT가 README + verify-setup #2/#6/#8 seal임을 명시. global-count drift 후보를 non-drift로 종결.

**Architecture:** 노트는 **컴포넌트 숫자를 일절 재기술하지 않는다**(self-referential + seal 참조만 → 노트 자체 드리프트 표면 0). 동시에 Gate R가 식별한 §A.4 changelog 긴장을 해소: A.4를 in-place 정정 로그로 명시 연결하고 cycle-19(선례) + cycle-21(본 변경) 행을 정합.

**Tech Stack:** Markdown 편집 (execute-strict), 검증 = `setup/verify-all.sh` + grep.

**RPI-Cycle:** 21 · Gate R PASS(C1–C5) · Gate P 대기.

---

## Phase R 근거 (확정 사실)

- **stop-point (a) 미발동:** 스펙은 living/current 자기선언 0건; 자기서술 전부 2026-05-01 날짜고정. genesis-record 프레이밍 충돌 없음. (`### A.4 변경 이력`은 genesis 행 1개만 — dormant stub.)
- **stop-point (b) 미발동:** genesis 5 hook / 4 신규 skill(ccs 제외) / 6 메타룰(§1–§6, 레거시 4 prose 제외) / 13단계. 내부 정합, git genesis(e2b990f) 일치. 명시-숫자 하드코딩 비권장(스코핑 뉘앙스) → **self-referential 채택**.
- **live SSOT:** 9 hook / 7 tracked skill(6 orch + 1 contract) / 8 메타룰. seal #2=메타룰·#6=skill·#8=hook. 노트는 숫자 재기술 금지, seal+README **참조**로만.

## File Structure

- Modify: `docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md`
  - Edit A: 메타블록 직후(L6 다음) genesis 포인터 노트 삽입.
  - Edit B: `### A.4 변경 이력`(L3082) 표에 cycle-19 백필 + cycle-21 행.
- Create: 본 plan 문서.
- 무변경(의도적 defer): §0.7/§1.2/§2.1/§2.3/§2.5/§2.6/§4/§6/§7/§8/§2.9 글로벌-카운트 본문 + L3092 "약 2,800줄".

---

## Task A: genesis-record 노트 + A.4 정합

**Files:**
- Modify: `docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md`

- [ ] **Step 1: Edit A — genesis 포인터 노트 삽입**

`old_string`:
```
**Spec location:** `~/.claude/docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md`

---
```

`new_string`:
```
**Spec location:** `~/.claude/docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md`

> **📍 문서 성격 — genesis 설계 기록 (v1).** 이 문서는 2026-05-01 AI-native 오케스트레이션 인프라의 **최초(genesis) 설계 기록**이다. 본문이 기술하는 컴포넌트 수량(hook·skill·메타룰·빌드 단계 등)은 *설계 당시(v1)의 상태*이며 역사 기록으로 보존된다 — 시간이 지나며 늘어난 현재 수량으로 in-place 현행화하지 않는다.
>
> **현재 활성 카운트의 SSOT:** `README.md` + `setup/verify-setup.sh`의 봉인 검사 **#2(메타룰)·#6(skill)·#8(hook)**. 이후 추가·확장된 컴포넌트는 이 live SSOT와 `docs/superpowers/specs/`의 후속 spec에서 추적된다. 본문의 v1 수량과 현재 수량이 다른 것은 drift가 아니라 *의도된 genesis-vs-현재 구분*이다.
>
> **in-place 정정 경계:** 이 genesis 기록에 허용되는 수정은 두 종류뿐이다 — (1) genesis 설계 *내부*의 자기모순 교정(예: 같은 문서 안에서 서로 다른 산출물 카운트를 주장하던 init-ai-ready를 cycle-19에서 통일), (2) 본 노트 같은 상단 해석/포인터 추가. 둘 다 v1 설계 수량 자체는 건드리지 않는다. 컴포넌트 수량의 *현행화*는 본문 재작성이 아니라 위 live SSOT가 담당한다. 주요 in-place 정정 이력은 §A.4에 기록한다.

---
```

- [ ] **Step 2: Edit B — A.4 변경 이력 정합 (cycle-19 백필 + cycle-21)**

`old_string`:
```
| 일자 | 변경 |
|---|---|
| 2026-05-01 | 최초 작성 (브레인스토밍 합의 후) |
```

`new_string`:
```
| 일자 | 변경 |
|---|---|
| 2026-05-01 | 최초 작성 (브레인스토밍 합의 후) |
| 2026-06-05 | cycle-19: init-ai-ready 산출물 카운트 genesis-내부 정합 (문서 내 자기모순 교정, in-place). |
| 2026-06-05 | cycle-21: 상단 genesis-record 노트 추가 + global-count를 Model-1(genesis 보존, 현재 카운트 SSOT=README+verify-setup #2/#6/#8)로 확정. v1 설계 수량 본문 무변경. |
```

- [ ] **Step 3: 글로벌-카운트 본문 무변경 확인 (grep diff)**

Run: `git -C C:/Users/12132/.claude diff --stat docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md`
Expected: 1 파일, 추가 행만(노트 ~6행 + A.4 2행), 기존 카운트 토큰("Hook 5","Skill 4","메타 룰 6","약 2,800줄" 등) 삭제/수정 0.

- [ ] **Step 4: 노트·A.4 행 존재 grep 확인**

Run: `grep -c '문서 성격 — genesis 설계 기록' docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md` → 1
Run: `grep -c 'cycle-21: 상단 genesis-record 노트' docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md` → 1

- [ ] **Step 5: verify-all ALL PASS(61/0) 불변 확인**

Run: `bash C:/Users/12132/.claude/setup/verify-all.sh`
Expected: doctor rc=0, verify-setup 61 PASS / 0 FAIL, run-all.sh 96/96, verify-integration 8/8, 최종 "ALL PASS". (이 spec은 verify-setup 어떤 체크의 대상도 아니므로 카운트 cascade 없음 — 61 불변.)

- [ ] **Step 6: Commit + push**

```bash
git -C C:/Users/12132/.claude add docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md docs/superpowers/plans/2026-06-05-cycle21-genesis-record-note.md state.json
git -C C:/Users/12132/.claude commit -m "$(cat <<'EOF'
docs(rpi): cycle-21 global-count Model-1 genesis-record 노트 + A.4 정합

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
git -C C:/Users/12132/.claude push
```

---

## Non-Goals (의도적 defer — silent-skip 아님)

- **글로벌-카운트 본문 in-place 수정(~40곳):** Model 1로 보존. live 카운트는 이미 verify-setup #2/#6/#8 + README로 봉인됨 → 미봉인 케이스 0. genesis-vs-현재 차이는 노트가 자기설명.
- **L3092 "약 2,800줄":** genesis-era 근사 → 노트 clause-1 커버, 무변경.
- **§3 본문 3개(scripts-check/github-ci/CONTEXT):** init-ai-ready 내부 완결성 갭, 별도 후보(genesis-내부 교정 클래스).
- **나머지 historical 커밋(925f78f/b1a93a9/a82009e/6a897f2)의 A.4 백필:** 미세 내부 리파인이라 "주요 in-place 정정"에 비해당 → A.4는 *주요* 정정만 기록(노트 문구 일치).

## Self-Review

1. **Spec coverage:** goal=노트 1개+드리프트 종결 → Task A Step 1이 구현. SSOT 명시 → 노트 clause-2. ✓
2. **Placeholder scan:** byte-exact old/new_string 완비, TBD 0. ✓
3. **Consistency:** 노트 "주요 in-place 정정 이력은 §A.4에 기록" ↔ Edit B가 cycle-19(선례)+cycle-21 행 추가로 정합. seal 라벨 #2/#6/#8 ↔ Phase R 확인치 일치. ✓
4. **Drift-proofing:** 노트에 컴포넌트 숫자 0개 → verify-setup이 단일 숫자 SSOT 유지. ✓
