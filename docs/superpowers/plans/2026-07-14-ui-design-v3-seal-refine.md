# ui-design v3 — 콘텐츠 봉인 + 정련 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline, 단일 세션) — 메인 세션이 Playwright MCP·verify 실행. Steps use checkbox (`- [ ]`) syntax.

**Status:** active
**RPI-Cycle:** 55
**Started:** 2026-07-14

**Goal:** design.md v2 투자(700줄·24 evidence·floor18/ceiling9·opencode byte-sync)를 verify-setup drift seal로 봉인하고, cold-agent fitness가 남긴 §9·§12 내적 긴장 2건을 evidence 인용과 함께 정련한다. 정련 후 design.md v3만으로 새 장르(설정 화면)가 ≤2 iter 재현됨을 실증(회귀 게이트).

**Architecture:** 재진입 사이클 — durable spec `docs/superpowers/specs/2026-07-12-ui-design-craft-upgrade-design.md`(§11 v3 Delta 반영됨)이 SSOT. 신규 seal 2종(#37 미러 byte-sync·#38 §6 floor-18)은 verify-setup의 터미널 count-seal(#36) **앞에** 삽입(카운트 포함). 각 seal은 seal-regression.test.sh의 대표 변이로 TDD(RED→GREEN). 정련은 design.md §9/§12 문구 수정 + `// evidence: F-FIT-02/03`.

**Tech Stack:** bash(verify-setup·seal-regression), awk/cmp/grep, React+Vite+Tailwind(cold-agent 랩), Playwright MCP(실측).

## Global Constraints

- **§0 불변**: §6 anti-slop floor **18항목**·§15 craft ceiling **9항목**·§0–§15 섹션·토큰명(`--color-*`·neutral 스케일·타이포 토큰)·§4 클래스 시그니처 전부 불변. 봉인+정련이지 재작성 아님.
- **무증거 규칙 금지**: §9·§12 정련은 `// evidence: F-FIT-02`·`// evidence: F-FIT-03` 인용 필수. 근거 = FITNESS-L4.md 비채점 관찰 → FRICTION 승격.
- **하위호환**: 소비 프로젝트(NICE Second Brain 등) 클래스·토큰 불변. seal은 additive — 기존 verify-setup #1–#36 항목 비접촉.
- **cold-agent fitness 회귀 불변식**: 정련 후 design.md v3만 받은 새 에이전트가 ≤2 iter에 floor 18/18 + ceiling PASS 재현. 깨지면 정련 되돌림.
- **미러 규약**: `opencode-harness/skill/ui-design/design.md` = design.md **byte-identical**(divergence 0). `SKILL.md`는 구조-sync + 의도적 분기 2건 보존(이번 사이클 SKILL.md 무변경 예상).
- **카운트 SSOT**: verify-setup 총 체크수 = README.md:284 "현재 N PASS", 런타임 #36 self-count(`EXPECTED_TOTAL=$((PASS+FAIL+1))`). seal 2개 추가 → 73→75, README:284 동기 필수(미동기 시 #36 FAIL).
- **#36은 터미널**: 신규 seal은 반드시 `# 36.` 블록 **앞에** 물리 삽입(라벨 #37/#38, 위치는 #36 앞).
- **동시-세션 격리**: harness-upgrade 세션이 verify-setup·seal-regression 병렬 편집 가능. 최신 seal 번호 실측 확인 완료(#36 max, #26 burned → #37/#38 여유). dev 서버는 ephemeral 포트 5300–5999, 자기 PID만 종료.
- **#26 재사용 금지** (의도적 소각).

---

### Task 1: FRICTION F-FIT-02 · F-FIT-03 채록 (evidence provenance)

**Files:**
- Modify: `_design-lab/FRICTION.md` (gitignored; `## FIT` 섹션 F-FIT-01 뒤, `<!-- 이후 항목 -->` 주석 앞)

**Interfaces:**
- Produces: `F-FIT-02`(§9 충돌)·`F-FIT-03`(§12 과광역) — Task 2 정련이 `// evidence:`로 인용.

- [ ] **Step 1: F-FIT-02·F-FIT-03 추가**

`_design-lab/FRICTION.md`에서 `### F-FIT-01` 블록의 마지막 줄(`- **v2 방향(즉시 회귀)**: §3에 "가로 스크롤 컨테이너는 `relative` 필수" 1줄.`) 뒤, `<!-- 이후 항목은 라운드 진행 중 채록 -->` 앞에 삽입:

```markdown

### F-FIT-02 (충돌) — §9 "총 안무 <700ms"가 700ms line-rise 레시피와 내적 모순
- **v2 근거**: §9 stagger 규칙 "총 안무 <700ms"(L535) ↔ §9 표준 레시피 `.line-mask > span { animation: line-rise 700ms }`(L552). 단일 요소가 이미 700ms인데 stagger 순차 등장이면 총 길이가 구조적으로 700ms 초과 — "총 안무"가 *개별 요소 지속*과 *시퀀스 spread*를 미분리.
- **증거**: `FITNESS-L4.md` 비채점 관찰-1 (design.md §9 L535 vs L552). cold-agent가 이 모순을 만나면 "총 <700ms" 준수 위해 line-rise를 임의 단축하거나 stagger 포기 → 재현 분기.
- **v3 방향**: 2축 분리 — 개별 요소 지속 ≤700ms(motion-hero) + 마지막 요소 시작 지연 ≤300ms → 체감 총 ≤~1000ms. "총 안무 <700ms" 문구 대체(§9 stagger 규칙).

### F-FIT-03 (과광역) — §12 hover "목록 행" 스코프가 인터랙티브/비인터랙티브 미분리
- **v2 근거**: §12 Hover "목록 행: 배경 1단차 + 보조 신호 1개(화살표 슬라이드 등)"(L657). "목록 행"이 클릭-이동 내비 행과 읽기 전용 데이터 표/정보 행을 구분 안 함 — 후자에 화살표 슬라이드(이동 어포던스)를 주면 거짓 어포던스.
- **증거**: `FITNESS-L4.md` 비채점 관찰-2 (design.md §12 L657). 설정·표 화면에서 비인터랙티브 행에 방향 신호가 붙는 슬롭 위험.
- **v3 방향**: 인터랙티브 행(배경+보조 신호) vs 비인터랙티브 행(배경 1단차만·방향 신호 금지) 분기(§12 Hover 절).
```

- [ ] **Step 2: 커밋**

```bash
git -C /c/Users/12132/.claude add _design-lab/FRICTION.md 2>/dev/null || true   # gitignored — add 무효(정상), 추적성만
git -C /c/Users/12132/.claude commit --allow-empty -m "docs(friction): F-FIT-02(§9 충돌)·F-FIT-03(§12 과광역) 채록 — v3 정련 evidence" 2>&1 | tail -2
```
(FRICTION.md은 gitignored라 실제 커밋 안 됨 — 이 커밋은 사이클 마커. 증거는 durable spec §11 + design.md evidence 인용이 담지.)

---

### Task 2: design.md §9 · §12 정련 (F-FIT-02 · F-FIT-03)

**Files:**
- Modify: `skills/ui-design/design.md` (§9 L535 stagger 규칙 · §12 L657 Hover 목록 행)

**Interfaces:**
- Consumes: F-FIT-02·F-FIT-03 (Task 1).
- Produces: design.md v3 (§9 2축 분리 · §12 인터랙티브/비인터랙티브 분기). Task 3이 미러로 byte-copy.

- [ ] **Step 1: §9 stagger 규칙 정련 (F-FIT-02)**

`skills/ui-design/design.md`에서 정확히 이 줄:
```
- **stagger**: 순차 등장은 60–120ms 간격 (KPI 카드 60ms·hero 행 120ms 실측). 총 안무 <700ms.
```
을 다음으로 교체:
```
- **stagger**: 순차 등장은 60–120ms 간격 (KPI 카드 60ms·hero 행 120ms 실측). **안무 예산은 2축**이다 — *개별 요소 지속* ≤700ms(motion-hero 상한)와 *마지막 요소의 시작 지연* ≤300ms(요소 ~5개 이내)는 별개 축. 체감 총 길이 = 개별 지속 + 시작 지연 spread ≤ **~1000ms**. (v2 "총 안무 <700ms"는 700ms line-rise 레시피와 모순 — 개별 지속과 시퀀스 spread를 혼동했음.) // evidence: F-FIT-02
```

- [ ] **Step 2: §12 Hover 목록 행 정련 (F-FIT-03)**

`skills/ui-design/design.md`에서 정확히 이 줄:
```
- 목록 행: 배경 1단차 (`hover:bg-neutral-100`, 서브틀 배경 위에선 `hover:bg-neutral-0` 반전) + 보조 신호 1개(인덱스 primary화·화살표 슬라이드 등 transform ≤8px).
```
을 다음 2줄로 교체:
```
- **인터랙티브 목록 행**(클릭 시 이동·선택되는 내비/리스트 행): 배경 1단차 (`hover:bg-neutral-100`, 서브틀 배경 위에선 `hover:bg-neutral-0` 반전) + 보조 신호 1개(인덱스 primary화·화살표 슬라이드 등 transform ≤8px). 화살표 슬라이드는 *이동 어포던스*이므로 이동하는 행에만.
- **비인터랙티브 행**(읽기 전용 데이터 표·정보 행): 배경 1단차만 (`hover:bg-neutral-100`) — 방향 신호(화살표)는 거짓 어포던스라 금지. 행이 클릭 대상이 아니면 hover는 "읽는 위치" 표시일 뿐이다. // evidence: F-FIT-03
```

- [ ] **Step 3: floor 카운트 불변 확인 (§6 미접촉)**

Run: `awk '/^# 6\./{f=1;next} /^# 7\./{f=0} f' /c/Users/12132/.claude/skills/ui-design/design.md | grep -cE '^- \[ \]'`
Expected: `18` (정련이 §6 미접촉 확인 — #38 대비).

- [ ] **Step 4: evidence 인용 수 확인**

Run: `grep -c '// evidence: F-' /c/Users/12132/.claude/skills/ui-design/design.md`
Expected: `26` (기존 24 + F-FIT-02 + F-FIT-03).

- [ ] **Step 5: 커밋**

```bash
git -C /c/Users/12132/.claude add skills/ui-design/design.md
git -C /c/Users/12132/.claude commit -m "refine(ui-design): §9 안무 2축 분리(F-FIT-02)·§12 hover 인터랙티브 분기(F-FIT-03)" 2>&1 | tail -2
```

---

### Task 3: opencode 미러 byte-sync (design.md)

**Files:**
- Modify: `opencode-harness/skill/ui-design/design.md` (design.md byte-copy)

**Interfaces:**
- Consumes: design.md v3 (Task 2).
- Produces: byte-identical 미러 → Task 4 seal #37이 강제.

- [ ] **Step 1: design.md → 미러 byte-copy**

```bash
cp -p /c/Users/12132/.claude/skills/ui-design/design.md /c/Users/12132/.claude/opencode-harness/skill/ui-design/design.md
```

- [ ] **Step 2: byte-identity 검증**

Run: `cmp -s /c/Users/12132/.claude/skills/ui-design/design.md /c/Users/12132/.claude/opencode-harness/skill/ui-design/design.md && echo IDENTICAL || echo DIFFER`
Expected: `IDENTICAL`

- [ ] **Step 3: SKILL.md 미러 분기 무변경 확인**

정련은 §9/§12 *내용*만 수정 — SKILL.md는 §9/§12를 일반 참조하므로 무변경. opencode SKILL.md 분기 2건(오프라인 CDN 노트·task-도구 디스패치) 보존.
Run: `diff <(sed -n '1,10p' /c/Users/12132/.claude/skills/ui-design/SKILL.md) <(sed -n '1,10p' /c/Users/12132/.claude/opencode-harness/skill/ui-design/SKILL.md) >/dev/null && echo "head同" || echo "head異(분기 존재-정상)"`
(참고용 — SKILL.md는 이번 미변경.)

- [ ] **Step 4: 커밋**

```bash
git -C /c/Users/12132/.claude add opencode-harness/skill/ui-design/design.md
git -C /c/Users/12132/.claude commit -m "sync(opencode): design.md v3 미러 byte-copy" 2>&1 | tail -2
```

---

### Task 4: Seal #37 — opencode 미러 byte-sync (TDD)

**Files:**
- Modify: `setup/tests/seal-regression.test.sh` (make_replica 확장 + mut_mirror_drift + assert)
- Modify: `setup/verify-setup.sh` (# 36 앞에 # 37 삽입)
- Modify: `README.md:284` (73→74)

**Interfaces:**
- Produces: verify-setup #37 (미러 부재 시 vacuous-PASS · 존재+상이 시 FAIL). Task 5가 #38 추가.

- [ ] **Step 1: make_replica가 미러 design.md 복제하도록 확장**

`setup/tests/seal-regression.test.sh`의 `make_replica()` 안, `cp -a "$SRC/docs/superpowers/plans/." ...` 줄 **뒤**(`rm -rf "$C/hooks/.log"` 앞)에 삽입:
```bash
  # v3: replicate opencode mirror (design.md만 — seal #37이 비교하는 유일 파일) so 미러-sync seal 검증 가능.
  if [ -f "$SRC/opencode-harness/skill/ui-design/design.md" ]; then
    mkdir -p "$C/opencode-harness/skill/ui-design"
    cp -p "$SRC/opencode-harness/skill/ui-design/design.md" "$C/opencode-harness/skill/ui-design/design.md"
  fi
```

- [ ] **Step 2: witness에 design.md 추가 + mut_mirror_drift + assert**

(a) `witness()` 함수의 파일 목록 `state.json README.md settings.json CLAUDE.md hooks/tests/cases.tsv`에 `skills/ui-design/design.md` 추가(신규 mutator가 만지는 파일 → 라이브 불변 증인 확장):
```bash
witness() { local f; for f in state.json README.md settings.json CLAUDE.md hooks/tests/cases.tsv skills/ui-design/design.md; do
              cksum "$SRC/$f" 2>/dev/null; done; }
```
(b) `mut_readme_cases` 블록 뒤(assert 호출들 앞)에 mutator 추가:
```bash
# Mutator 4 — seal #37 (opencode 미러 byte-sync): 미러만 발산(비-floor 편집) → 정본≠미러, §6 카운트 불변.
mut_mirror_drift() { printf '\n<!-- v3 seal-regression mirror-drift probe -->\n' >> "$1/opencode-harness/skill/ui-design/design.md"; }
```
(c) `assert_seal_fires "readme_cases" ...` 줄 뒤에 추가:
```bash
assert_seal_fires "mirror_sync"     mut_mirror_drift       "opencode 미러 design.md drift"
```

- [ ] **Step 3: seal-regression 실행 → RED 확인**

Run: `HOME=/c/Users/12132 bash /c/Users/12132/.claude/setup/tests/seal-regression.test.sh 2>&1 | tail -8`
Expected: `mutant[mirror_sync]` FAIL (verify-setup에 #37 미존재 → 미러 발산이 안 잡힘 → rc=0 → «opencode 미러 design.md drift» 부재). `seal-regression: PASS=? FAIL≥1`. (control·기존 3 mutant은 PASS.)

- [ ] **Step 4: verify-setup에 # 37 삽입 (# 36 앞)**

`setup/verify-setup.sh`에서 `# 36. verify-setup 총 체크수` 주석 블록 **앞**에 삽입:
```bash
# 37. opencode 미러 byte-sync (v3 — design.md 콘텐츠 무검사 봉인): 미러 design.md가 정본과 byte-동일.
#     미러 부재(fresh-clone/설치본) 시 vacuous-PASS로 카운트 결정성 보존, 존재+상이 시 FAIL(편도 편집 차단).
#     #23 two-file parity 계열. design.md 편집 시 양 미러 동시 갱신 강제.
SRC37="$HOME/.claude/skills/ui-design/design.md"
MIR37="$HOME/.claude/opencode-harness/skill/ui-design/design.md"
if [ ! -f "$MIR37" ]; then
  ok "opencode 미러 부재 — design.md byte-sync N/A (vacuous PASS)"
elif [ ! -f "$SRC37" ]; then
  fail "정본 design.md 부재 ($SRC37)"
elif cmp -s "$SRC37" "$MIR37"; then
  ok "opencode 미러 design.md byte-sync"
else
  fail "opencode 미러 design.md drift (정본과 상이 — 양 미러 동시 갱신 필요)"
fi

```

- [ ] **Step 5: README:284 카운트 73→74**

`README.md`에서 `verify-setup.sh                   §6.3 file/structure 체크 (현재 73 PASS)` → `... (현재 74 PASS)`.

- [ ] **Step 6: seal-regression 실행 → GREEN**

Run: `HOME=/c/Users/12132 bash /c/Users/12132/.claude/setup/tests/seal-regression.test.sh 2>&1 | tail -8`
Expected: `mutant[mirror_sync]: exit≠0 + seal FAIL «opencode 미러 design.md drift»`. control PASS. `FAIL=0`.

- [ ] **Step 7: verify-setup 실행 → 74/0**

Run: `bash /c/Users/12132/.claude/setup/verify-setup.sh 2>&1 | tail -3`
Expected: `verify-setup: PASS=74 FAIL=0` (#37 미러 byte-sync PASS + #36 카운트 74==74).

- [ ] **Step 8: 커밋**

```bash
git -C /c/Users/12132/.claude add setup/verify-setup.sh setup/tests/seal-regression.test.sh README.md
git -C /c/Users/12132/.claude commit -m "feat(seal): #37 opencode 미러 design.md byte-sync + seal-regression 변이 (TDD)" 2>&1 | tail -2
```

---

### Task 5: Seal #38 — §6 anti-slop floor-18 (TDD)

**Files:**
- Modify: `setup/tests/seal-regression.test.sh` (mut_floor_shrink + assert)
- Modify: `setup/verify-setup.sh` (# 36 앞, # 37 뒤에 # 38)
- Modify: `README.md:284` (74→75)

**Interfaces:**
- Produces: verify-setup #38 (§6 체크박스 == 18 강제).

- [ ] **Step 1: mut_floor_shrink + assert 추가**

(a) `mut_mirror_drift` 블록 뒤에 mutator 추가 (양 미러 동시 삭제 → #37 clean, #38만 발화):
```bash
# Mutator 5 — seal #38 (§6 floor-18): §6 첫 체크박스를 정본·미러 양쪽에서 삭제(byte-동일 유지 → #37 불감, #38만 발화).
mut_floor_shrink() {
  local F
  for F in "skills/ui-design/design.md" "opencode-harness/skill/ui-design/design.md"; do
    [ -f "$1/$F" ] || continue
    awk '/^# 6\./{d=1} /^# 7\./{d=0} d && /^- \[ \]/ && !x {x=1; next} {print}' "$1/$F" > "$1/$F.t" && mv "$1/$F.t" "$1/$F"
  done
}
```
(b) `assert_seal_fires "mirror_sync" ...` 줄 뒤에 추가:
```bash
assert_seal_fires "floor_18"        mut_floor_shrink       "§6 floor 카운트 drift"
```

- [ ] **Step 2: seal-regression 실행 → RED 확인**

Run: `HOME=/c/Users/12132 bash /c/Users/12132/.claude/setup/tests/seal-regression.test.sh 2>&1 | tail -8`
Expected: `mutant[floor_18]` FAIL (verify-setup에 #38 미존재 → §6 17로 줄어도 안 잡힘; #37은 양쪽 동일 삭제라 PASS → rc=0 → «§6 floor 카운트 drift» 부재). `FAIL≥1`.

- [ ] **Step 3: verify-setup에 # 38 삽입 (# 37 뒤, # 36 앞)**

`setup/verify-setup.sh`의 방금 추가한 # 37 블록 **뒤**, `# 36.` 앞에 삽입:
```bash
# 38. §6 anti-slop floor 카운트 봉인 (v3 — §0.1/§6.2 "삭제 절대 금지" 강제): §6 스코프(# 6.~# 7.)의
#     '- [ ]' 체크박스가 정확히 18. floor 가감은 seal 동반 갱신 = 의도적 governance(tripwire). §6 밖
#     편집(evidence 인용·§9~§15 문구)엔 불감(awk 섹션 스코프).
DESIGN38="$HOME/.claude/skills/ui-design/design.md"
FLOOR38=$(awk '/^# 6\./{f=1;next} /^# 7\./{f=0} f' "$DESIGN38" 2>/dev/null | grep -cE '^- \[ \]')
if [ "$FLOOR38" -eq 18 ]; then
  ok "design.md §6 anti-slop floor = 18 항목"
else
  fail "design.md §6 floor 카운트 drift: $FLOOR38 (기대 18 — §6.2 '삭제 절대 금지' 위반?)"
fi

```

- [ ] **Step 4: README:284 카운트 74→75**

`README.md`에서 `... (현재 74 PASS)` → `... (현재 75 PASS)`.

- [ ] **Step 5: seal-regression 실행 → GREEN**

Run: `HOME=/c/Users/12132 bash /c/Users/12132/.claude/setup/tests/seal-regression.test.sh 2>&1 | tail -10`
Expected: `mutant[floor_18]: exit≠0 + seal FAIL «§6 floor 카운트 drift»`. `mutant[mirror_sync]` GREEN 유지. control PASS. live witness stable. `seal-regression: PASS=7 FAIL=0`.

- [ ] **Step 6: verify-setup 실행 → 75/0**

Run: `bash /c/Users/12132/.claude/setup/verify-setup.sh 2>&1 | tail -3`
Expected: `verify-setup: PASS=75 FAIL=0` (#37·#38 PASS + #36 카운트 75==75).

- [ ] **Step 7: 커밋**

```bash
git -C /c/Users/12132/.claude add setup/verify-setup.sh setup/tests/seal-regression.test.sh README.md
git -C /c/Users/12132/.claude commit -m "feat(seal): #38 §6 anti-slop floor-18 봉인 + seal-regression 변이 (TDD)" 2>&1 | tail -2
```

---

### Task 6: 하네스 정합 — 전체 verify

**Files:** (읽기 전용 실행)

- [ ] **Step 1: verify-setup 최종**

Run: `bash /c/Users/12132/.claude/setup/verify-setup.sh 2>&1 | tail -3`
Expected: `PASS=75 FAIL=0`.

- [ ] **Step 2: seal-regression 최종**

Run: `HOME=/c/Users/12132 bash /c/Users/12132/.claude/setup/tests/seal-regression.test.sh 2>&1 | tail -4`
Expected: `seal-regression: PASS=7 FAIL=0`.

- [ ] **Step 3: run-all 유닛**

Run: `bash /c/Users/12132/.claude/hooks/tests/run-all.sh 2>&1 | tail -5`
Expected: ALL PASS (기존 카운트 유지 — seal은 verify-setup/seal-regression에만, cases.tsv 미접촉).

- [ ] **Step 4: verify-all (가능 시)**

Run: `bash /c/Users/12132/.claude/setup/verify-all.sh 2>&1 | tail -8`
Expected: ALL PASS. (MSYS PATH 아티팩트로 백그라운드 행 시 → 구성 스테이지(verify-setup·run-all·verify-integration standalone) 개별 실행으로 대체.)

- [ ] **Step 5: opencode skill-discovery (미러 무결)**

Run: `cmp -s /c/Users/12132/.claude/skills/ui-design/design.md /c/Users/12132/.claude/opencode-harness/skill/ui-design/design.md && echo MIRROR_OK || echo MIRROR_DRIFT`
Expected: `MIRROR_OK`.

---

### Task 7: cold-agent fitness 회귀 — 설정 화면 (Phase Verify)

**Files:**
- Create: `_design-lab/lab/src/pages/L5.jsx` (cold agent 산출 — 설정 화면)
- Modify: `_design-lab/lab/src/App.jsx` (라우트 `/l5`)
- Create: `_design-lab/FITNESS-L5.md` (판정 기록)

**Interfaces:**
- Consumes: design.md v3 (정련 반영).
- Produces: fitness 회귀 판정(≤2 iter, floor 18/18 + ceiling PASS) — 정련이 재현성 무손상 실증.

- [ ] **Step 1: cold agent 디스패치 (design.md v3만 제공)**

`Agent(subagent_type="execute-strict", task="design.md v3만 컨텍스트로 설정(Settings) 화면 1페이지를 lab/src/pages/L5.jsx로 생성 — 인터랙티브 설정 행(클릭→하위 페이지, 화살표)과 읽기 전용 정보 행(계정 ID·플랜 등, 방향 신호 없음)을 모두 포함해 정련된 §12를 자극. Vite+React+Tailwind, ad-hoc hex 금지, §1 토큰만, reduced-motion 분기, focus-visible. App.jsx에 /l5 라우트 추가.", context_paths=["skills/ui-design/design.md"], success_criteria="콘솔 에러 0·ad-hoc hex 0·§12 인터랙티브/비인터랙티브 행 구분 반영·floor 18 위반 0")`

- [ ] **Step 2: review-strict 채점 (floor 18 + ceiling)**

`Agent(subagent_type="review-strict", task="L5.jsx를 design.md §6 floor 18 + §15 ceiling으로 채점", context_paths=["skills/ui-design/design.md","_design-lab/lab/src/pages/L5.jsx"], success_criteria="floor 각 항목 PASS/N-A(FAIL 0)·ceiling 해당 항목 판정·§12 인터랙티브/비인터랙티브 hover 구분 확인")`

- [ ] **Step 3: Playwright 실측 (메인 세션)**

dev 서버 ephemeral 포트(5300–5999) 기동 → `/l5` 캡처 1440/768/390 × light/dark. 측정: 오버플로우 0(root+내부 컨테이너)·다크 스왑 무결·reduced-motion 기능 동등·CLS<0.02·focus-visible 가시. FAIL 항목 수정 → 재실측. **자기 PID만 종료**.

- [ ] **Step 4: 판정 — ≤2 iter**

iter1 결과 기록. FAIL 지점이 **문서 결함**이면(정련이 재현성 저해) 정련 되돌림/문서 회귀 후 iter2. floor 18/18 + ceiling PASS + 실측 게이트 전부 PASS면 회귀 통과. `_design-lab/FITNESS-L5.md`에 기록.

- [ ] **Step 5: 회귀 판정 기록**

FITNESS-L5.md에: 정련(§9 2축·§12 분기)이 재현성을 깼는가(회귀 게이트 결과). 통과 = design.md v3 봉인+정련이 cold-agent fitness 불변식 유지 실증.

---

### Task 8: 교차패밀리 적대 리뷰 (best-effort · Phase Verify)

**Files:**
- Modify: `_design-lab/FITNESS-L5.md` (리뷰 결과 또는 SKIP 사유)

- [ ] **Step 1: ccs 프록시 헬스 확인**

메모리 경고([[project_ccs_codex_token_family_revocation]]·codex 400 reasoning 비호환) 준수 — **토큰 패밀리 revoke 위험 있는 codex 무리 시도 금지**. ccs 가용성만 가볍게 확인(파일 참조 프롬프트, `-p` E2BIG 회피). 안전 패밀리(glm/kimi 프로필)가 즉시 가용하면 1회 refute-by-default 리뷰.

- [ ] **Step 2: 결과 또는 SKIP 기록**

가용 → design.md v3 §9/§12 정련 + seal 설계에 대한 적대 리뷰 1회, 결과를 FITNESS-L5.md에. 불가/위험 → SKIP 사유 기록(spec §7 "가능 시"; 다중 review-strict 패스로 편향 부분 중화 — Gate R/P + Task 2·7 review-strict). **인프라 디버깅은 범위 밖.**

---

## Best-Direction Check (Phase P — silent downgrade 금지)

- **Seal 선택**: explore 안정성 분석의 top-2(미러 byte-sync + design.md 구조 앵커). 미러 byte-sync(#37)=goal 최우선 지시 + 유일 무검사 갭 + 0 거짓발화 + #23 SSOT 선례. 두 번째는 §9-§15 헤더 대신 **§6 floor-18(#38)** 확정 — §0.1 최우선 불변식("floor 삭제 절대 금지")을 *직접* 보호하고(헤더-존재는 gross 소실만 잡고 subtle 항목 erosion은 놓침), 현 make_replica로 TDD 가능(구현 단순성 우위). **DOWNGRADE 없음** — 알려진 최고 방향(결정론적·governance tripwire·특정 인스턴스 앵커).
- **정련**: §9 2축 분리·§12 인터랙티브/비인터랙티브 분기는 두 모순의 *직접·최소* 해소. 우회(문구 삭제)·부분해결(한쪽만) 미채택. DOWNGRADE 없음.
- **단일 사이클**: goal 권장 + 봉인/정련 응집(둘 다 "v2 공고화"). C1/C2 분할은 ceremony 순증이라 미채택 — 스코프 판단이지 방향 downgrade 아님.

## Self-Review

**Spec coverage** (durable spec §11 v3 Delta 대비):
- 콘텐츠 seal 신설(#37 미러·#38 floor) → Task 4·5 ✓
- §9·§12 정련(F-FIT-02/03) → Task 2 ✓ (evidence Task 1)
- 미러 byte-sync 유지 → Task 3 ✓
- cold-agent fitness 회귀(설정 화면) → Task 7 ✓
- 교차패밀리 리뷰 best-effort → Task 8 ✓
- 카운트 SSOT 동기(README 73→75) → Task 4·5 ✓

**Placeholder scan**: 모든 seal/mutator/정련 코드 verbatim. TBD 0.

**Type consistency**: seal 라벨(#37/#38)·mutator명(mut_mirror_drift/mut_floor_shrink)·needle 문자열("opencode 미러 design.md drift"/"§6 floor 카운트 drift")이 verify-setup fail() 문자열과 seal-regression assert needle 간 일치. FLOOR38 awk 스코프(`# 6.`~`# 7.`)와 mut_floor_shrink awk 스코프 동형.

**TDD**: 각 seal은 RED(Step 3/2)→GREEN(Step 6/5). mut_floor는 양 미러 동시 삭제로 #37 clean 유지(#38만 발화). mut_mirror는 미러만 편집으로 #38 clean 유지(#37만 발화).

**#36 터미널 불변**: #37/#38은 물리적으로 #36 앞 삽입 → #36 self-count가 75 포함.
