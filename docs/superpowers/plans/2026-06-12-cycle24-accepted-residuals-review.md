# cycle-24: 수락 잔여 재평가 (#23 matcher-parity 승격 + 전건 판정 기록) Implementation Plan

> **For agentic workers:** 경량 사이클 — 메인이 executing-plans 절차로 직접 수행. TDD: RED 실측 → GREEN.

**Status:** active
**RPI-Cycle:** 24
**Started:** 2026-06-12

**Goal:** cycle-23이 기록한 수락 잔여(spec :52 + plan 수락 잔여 절, 합집합 6건)를 "결정론적 안정 앵커 + 무오탐 검증식이 생겼는가" 기준으로 전건 ADOPT/KEEP 판정하고, ADOPT분(#23 승격 1건)만 TDD 구현. 판정 근거는 spec "Revision — cycle-24" 절(신설) + SECURITY.md에 기록.

**판정 (R: explore-strict 실측 a8cb969e 기반):**
- ① verify-setup #23 basename-only → **ADOPT(승격)**: S3 install.sh isHarness(`/\.claude\/hooks\/[^/]+\.sh/`)가 "하네스 hook entry 한정" 무오탐 앵커 신설 — 병합 불변식(하네스 hook은 항상 템플릿 entry에만 존재)으로 matcher가 거버넌스 사실로 고정됨. live↔example 트리플(phase|matcher|basename) EQUAL 실측. 승격 = matcher drift 감지 + 커스텀 hook 오탐 동시 제거(현행은 커스텀 추가 시 오탐 FAIL — S3 보존 병합과 비일관).
- ② state.schema.json 무검증 → **KEEP**: 소비자 1(verify-loop-watch.sh)·필드 2의 8줄 파일에 검증자는 과잉, 새 앵커 없음.
- ③ verify-all doctor-선행 자가치유 → **KEEP**: 치료-후-검증은 doctor 설계 자체(spec §2.7 diagnose-treat-rediagnose) — 순서 변경은 seal이 아니라 설계 변경.
- ④ redirect python-c 변수 파일명 등 → **KEEP**: 변수 해석은 정적 파싱의 구조 상한(섀도 실행 필요) — 결정론 앵커 존재 불가.
- ⑤ §1 stable-claude-md stderr → **KEEP**: spec :58이 "사용자-타이밍 관심사라 stderr 정당"으로 기각 사유 기록 — 변동 없음.
- ⑥ (d) 물리 TDD 강제 불가 → **KEEP**: PreToolUse는 Workflow stage 프롬프트 검사 불가(F12급 프롬프트 계약 상한) — cycle-23 verbatim 규칙이 advisory 상한.

**부수 발견(drift):** CONTEXT.md:29 "drift seal … #17~#25 실재"가 cycle-23 신설 #27·#28 미반영 — 정정 대상.

---

### Task 1: verify-setup #23 승격 — isHarness 한정 (phase|matcher|basename) 트리플 parity

**Files:**
- Modify: `setup/verify-setup.sh:173-189` (#23 블록 in-place 교체 — PASS 수 불변 63)

- [x] **Step 1: RED 실측** — 승격판 추출식을 /tmp 사본(example 복사 후 matcher 1개 변조 `Write|Edit|NotebookEdit`→`Write|Edit`)과 원본에 단독 실행 → 트리플 CSV 불일치 검출 확인. 현행 #23(basename-only)은 같은 변조를 **통과**(미감지) 실측 — 이것이 RED 증거. ✓ 실측: mktemp 사본 — `RED confirmed: 현행 basename-only는 matcher 변조를 통과(미감지)` / `GREEN-extractor: 승격판은 같은 변조를 검출` / `커스텀 hook 추가에 무오탐(출력 불변)`.
- [x] **Step 2: GREEN 구현** — `sj_hooks()`를 isHarness 필터 + 트리플 출력으로 교체: ✓ 실측: plan 코드 그대로 in-place 교체(if/elif 골격 유지, 라벨 갱신).

```bash
# 23. settings.json ↔ settings.example.json 하네스 hook (phase|matcher|basename) parity (값/시크릿 미접근).
#     isHarness 한정(cycle-24 승격): S3 보존 병합 불변식(하네스 hook=템플릿 entry에만) 위에서 matcher drift 감지
#     + 사용자 커스텀 hook 오탐 제거. (구 basename-only는 matcher 축소를 미감지 — cycle-23 수락 잔여 ① 이행.)
sj_hooks() {
  node -e '
    let c={}; try{c=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))}catch(e){process.exit(0)}
    const isHarness=h=>/\.claude\/hooks\/[^/]+\.sh/.test(String((h||{}).command||""));
    const out=[]; for(const [ph,es] of Object.entries(c.hooks||{})) for(const e of es) for(const h of (e.hooks||[]))
      if(isHarness(h)) out.push(ph+"|"+String(e.matcher??"")+"|"+String(h.command||"").split("/").pop());
    process.stdout.write(out.join(","));
  ' "$1" 2>/dev/null
}
```

(비교 if/elif 골격·라벨 위치는 유지, ok 라벨만 "settings.json ↔ example harness-hook matcher parity"로.)
- [x] **Step 3: GREEN 확인** — verify-setup → PASS=63 FAIL=0 (#23 신라벨 ✓). 변조 probe 재실행 → 승격판이 불일치 검출(FAIL 경로) 확인 후 probe 제거. ✓ 실측: `✓ settings.json ↔ example harness-hook matcher parity` PASS=63 FAIL=0 → example matcher 변조 시 `✗ harness-hook drift` PASS=62 FAIL=1 → git checkout 복원 후 다시 63/0 (E2E FAIL 경로 검증).

### Task 2: CONTEXT.md drift seal 범위 정정

- [x] **Step 1**: CONTEXT.md:29 `(#17~#25 실재; #26은 미채택·번호 소각)` → `(#17~#25·#27·#28 실재; #26은 미채택·번호 소각)`. (.md — 게이트 무관.) ✓ 실측: 정정 적용.

### Task 3: spec Revision — cycle-24 절 신설 + SECURITY.md 수락 잔여 갱신

- [x] **Step 1**: spec "## Non-Goals" 앞에 `## Revision — cycle-24 (2026-06-12): 수락 잔여 재평가` 절 — 6건 판정표(①ADOPT 근거=isHarness 앵커 / ②~⑥ KEEP 근거) + CONTEXT.md drift 정정 기록. ✓ 실측: 절 신설(헤더 보존 — Non-Goals 직전 삽입).
- [x] **Step 2**: SECURITY.md "검증 커버리지 수락 잔여 (cycle-23)" 불릿에서 ①을 "(cycle-24 이행: #23 matcher-parity 승격)"으로 표시, ②③ 유지. ✓ 실측: "(cycle-23 → cycle-24 재평가)"로 갱신, ① 취소선+이행 표시, ②③ KEEP 근거 병기.

### Task 4: 게이트 + Closeout

- [x] **Step 1: 게이트** — run-all 113/113 · verify-setup PASS=63 FAIL=0 · verify-integration 8/8 · verify-all ALL PASS. ✓ 실측: 4게이트 전부 green(113/113 · 63/0 · 8/8 · ALL PASS).
- [x] **Step 2: 구현 커밋** — `feat(harness): seal #23 matcher-parity 승격(isHarness 한정) + 수락잔여 6건 판정 기록 (cycle-24)` (명시 staging). ✓ 실측: 명시 staging(verify-setup.sh·CONTEXT.md·spec·SECURITY.md·plan) 커밋.
- [ ] **Step 3: C-0/C-1** — C-0: master 직커밋 → WARN 후 진행. C-1: review-strict 실호출(판정 기록 3사이트 일치 + plan 체크박스).
- [ ] **Step 4: flip + state** — 이 plan Status → completed; 루트 state.json 23→24(양 날짜=2026-06-12).
- [ ] **Step 5: closeout 커밋** — `docs(rpi): cycle-24 closeout — plan completed, state 24` (plan+state.json만).
