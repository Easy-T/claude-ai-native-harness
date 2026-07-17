# ui-design Fable 재감사 — 재작업 R1~R7 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline, 단일 세션 — cold-agent 디스패치·Playwright 실측은 메인 세션 소관). Steps use checkbox (`- [ ]`) syntax.

**Status:** completed
**RPI-Cycle:** 58
**Started:** 2026-07-17
**Completed:** 2026-07-18

> **병합 정합 노트 (2026-07-18, closeout)**: 헤더 RPI-Cycle 58은 **계획 시점 값**. 동시 harness-upgrade C9(PR#28)가 클로즈아웃 중 master에 cycle 58을 선점 → 두 사이클은 별개이므로 본 사이클 실착륙 = **state 59** (state.json 공유 싱글톤·번갈아 bump 선례 — v3 병합 정합 노트 동형).

**Goal:** Fable 재감사(spec §12)가 실증한 Opus-구간 미달분 5건(R1~R5)을 수정하고, 증거 사슬 기록(R6)과 fitness L6 회귀(R7)로 design.md 수정의 재현성 불변식을 재실증한다.

**Architecture:** 재진입 사이클 — durable spec `docs/superpowers/specs/2026-07-12-ui-design-craft-upgrade-design.md` §12(Fable 재감사 Delta)가 SSOT. design.md 편집(R1-R3)은 seal #43이 강제하는 양 미러 동시 갱신, R4는 seal-regression TDD(RED→GREEN), R7은 spec §7 프로토콜의 제6 장르 적용.

**Tech Stack:** bash(seal-regression), design.md/SKILL.md 마크다운, React+Vite+Tailwind(랩), Playwright MCP(실측).

## Global Constraints

- **§0 불변**: §6 anti-slop floor **18항목**·§15 craft ceiling **9항목**·§0–§15 섹션·토큰**명**·§4 클래스 시그니처 불변. 수치 범위 정련은 F-FIT-02 선례(evidence 필수).
- **무증거 규칙 금지**: design.md 수정은 `// evidence: F-AUD-01`·`F-AUD-02` 인용 — Task 1이 FRICTION.md에 먼저 채록.
- **양 미러 동시**: design.md 편집 후 `opencode-harness/skill/ui-design/design.md` byte-copy (seal #43이 차단).
- **fitness 회귀 불변식**: design.md 수정 후 L6(제6 장르) cold agent ≤2 iter에 floor 18/18 + ceiling PASS.
- **검증**: verify-setup 81/0 · seal-regression 9/0 · run-all 172/172 · verify-all — 전부 **포그라운드 bash**.
- **동시세션 규약**: dev 서버 ephemeral 포트 5300–5999, 자기 프로세스만 종료.

## Best-Direction Check (Phase P — silent downgrade 금지)

- **R1 방향 = 레시피-우선 정합**: (a) §0-3 순수 티어-위임(수치 0개 — 서머리-vs-스펙 drift 계급 원천 제거, F-FIT-02가 고친 §9 내부 모순의 §0 잔존분을 상위 해법으로 종결) + (b) motion-base 300–550 상향(§9 자기-티어 초과 긴장 동시 해소). 대안(§0에 수치 재기술·레시피를 표에 맞춰 하향)은 각각 drift 재생산·무증거 변경이라 기각 — 채택안 == 최선안. **DOWNGRADE-DECLARED: 없음**.
- **R4 = witness 주장-실물 정합(테스트 무결성)**: 미러 추가가 유일 완결 해법. C8 귀책분(explore-strict.md·settings.example.json 부재) 이월은 스코프 판단(이 감사 범위=ui-design 커밋 2개), 방향 열화 아님.
- **R7 = spec §7 프로토콜 그대로**(제6 장르 + R6 교훈 자족 노트) — 프로토콜 약화 없음.

---

### Task 1: FRICTION F-AUD-01·F-AUD-02 채록 (evidence provenance)

**Files:**
- Modify: `_design-lab/FRICTION.md` (gitignored; `### F-FIT-03` 블록 뒤, `<!-- 이후 항목 -->` 주석 앞)

**Interfaces:**
- Produces: `F-AUD-01`(§0↔§9 충돌)·`F-AUD-02`(§9 산술 코너) — Task 2가 `// evidence:`로 인용.

- [x] **Step 1: F-AUD-01·F-AUD-02 추가** — `<!-- 이후 항목은 라운드 진행 중 채록 -->` 앞에 삽입:

```markdown
## AUD — Fable 재감사(2026-07-17)가 드러낸 문서 결함

### F-AUD-01 (충돌) — §0-3 "enter <400ms"가 §9 토큰·레시피와 모순 (F-FIT-02 동형의 §0 잔존)
- **v3 근거**: §0 Craft Manifesto 3번 "enter는 ease-out·<400ms·transform/opacity만"(:12) ↔ §9 motion-base 300–450ms(:529)·motion-hero 550–700ms(:530)·fade-up 550ms(:543)·line-rise 700ms(:552). 부수: §9 표 자체도 내적 긴장 — motion-base 용도란이 "fade-up 리빌"을 자기 티어로 명명하는데 fade-up/.reveal 레시피는 550ms로 표 상한 450 초과.
- **증거**: 재감사 실측 — L4 line-rise 550ms(L4.jsx)·L5 reveal 550ms(index.css:143)로 §4.4 게이트 전부 PASS("<400ms"는 사문). 양 SKILL.md가 "motion-base 550ms"를 예시 명기(정본:101·미러:106) — v2 저작 의도의 방증. spec §12 R1.
- **v4 방향**: (a) §0-3을 순수 티어-위임 문구로(수치 0개 — 서머리 drift 원천 제거) (b) motion-base 300–550ms로 레시피-우선 정합(레시피=F-L1-04/F-L3-04 evidence+cold-agent 2회 재현, 표 범위=독립 evidence 없음).

### F-AUD-02 (부족) — §9 2축 문구의 stagger 간격×개수 산술 코너
- **v3 근거**: §9 stagger "순차 등장은 60–120ms 간격"×"(요소 ~5개 이내)" ↔ 같은 문장 "마지막 요소의 시작 지연 ≤300ms"(:535). 상한 120ms×4간격=480ms>300ms — 5요소는 ≤75ms 간격에서만 두 축이 동시 성립.
- **증거**: L5 cold agent가 70ms 간격 선택(0/70/140/210/280ms — 280≤300 성립)으로 코너를 우연 회피(FITNESS-L5). 문서만 따른 다른 에이전트가 120ms×5요소를 선택하면 위반. spec §12 R2.
- **v4 방향**: "≤300ms" 축이 지배함을 명시 — 요소 수가 늘면 간격을 내려 마지막 지연 ≤300ms를 지킨다는 1구 추가.
```

- [x] **Step 2: 채록 확인**

Run: `grep -c "^### F-AUD-0" /c/Users/12132/.claude/_design-lab/FRICTION.md`
Expected: `2` (F-AUD-01·F-AUD-02 헤더)

---

### Task 2: design.md R1(a)(b)·R2·R3 정련

**Files:**
- Modify: `skills/ui-design/design.md` (:12 §0-3 · :529 motion-base 행 · :535 stagger 문구 · :460 §8 Mobile List Item 헤더)

**Interfaces:**
- Consumes: F-AUD-01·F-AUD-02 (Task 1).
- Produces: design.md v4 — Task 3이 미러 byte-copy, Task 7 L6 fitness가 검증.

- [x] **Step 1: R1(a) — §0-3 순수 티어-위임**

정확히 이 줄:
```
3. **물리 기반 절제 모션** — enter는 ease-out·<400ms·transform/opacity만(§9). 모션은 장식이 아니라 인과다.
```
을 다음으로 교체:
```
3. **물리 기반 절제 모션** — enter는 ease-out·transform/opacity만, 지속시간은 §9 duration 토큰 티어를 따른다. 모션은 장식이 아니라 인과다. // evidence: F-AUD-01
```

- [x] **Step 2: R1(b) — motion-base 300–550 (레시피-우선 정합)**

정확히 이 줄:
```
| motion-base | 300–450ms | fade-up 리빌, 상태 전환 |
```
을 다음으로 교체:
```
| motion-base | 300–550ms | fade-up 리빌, 상태 전환 — 표준 레시피(§9 fade-up/.reveal)는 550ms // evidence: F-AUD-01 |
```

- [x] **Step 3: R2 — §9 stagger 산술 코너 (≤300ms 지배 축 명시)**

:535의 stagger 불릿에서 정확히 이 구간:
```
*마지막 요소의 시작 지연* ≤300ms(요소 ~5개 이내)는 별개 축.
```
을 다음으로 교체:
```
*마지막 요소의 시작 지연* ≤300ms는 별개 축 — **지연 축이 지배**한다: 요소 수가 늘면 간격을 내려 마지막 지연 ≤300ms를 지킨다(5요소면 간격 ≤75ms — 120ms×5요소=480ms는 위반). // evidence: F-AUD-02
```

- [x] **Step 4: R3 — §8 Mobile List Item 인터랙티브 전제 주석**

정확히 이 줄:
```
### Mobile List Item (Montage iOS 기반)
```
을 다음으로 교체:
```
### Mobile List Item (Montage iOS 기반 — **인터랙티브 행 전제**: chevron은 이동 어포던스. 읽기 전용 정보 행에 복붙 시 chevron 제거 — §12 비인터랙티브 행 규칙)
```

- [x] **Step 5: 불변 확인 — floor 18·ceiling 9·evidence 수**

Run: `awk '/^# 6\./{f=1;next} /^# 7\./{f=0} f' /c/Users/12132/.claude/skills/ui-design/design.md | grep -cE '^- \[ \]'`
Expected: `18`
Run: `awk '/^# 15\./{f=1;next} f' /c/Users/12132/.claude/skills/ui-design/design.md | grep -cE '^- \[ \]'`
Expected: `9`
Run: `grep -o '// evidence: F-' /c/Users/12132/.claude/skills/ui-design/design.md | wc -l`
Expected: `29` (기존 26 + F-AUD-01×2 + F-AUD-02×1 — 발생 수 기준. :535는 R2 교체 후 F-FIT-02·F-AUD-02 마커 2개가 한 줄에 공존하므로 라인 수(grep -c)로는 28)

---

### Task 3: R5 미러 SKILL.md 단어 복원 + design.md 미러 byte-sync

**Files:**
- Modify: `opencode-harness/skill/ui-design/SKILL.md` (:68 "판정" 복원)
- Modify: `opencode-harness/skill/ui-design/design.md` (Task 2 결과 byte-copy)

**Interfaces:**
- Consumes: design.md v4 (Task 2).
- Produces: byte-identical 미러(#43 GREEN 유지) + 미러 SKILL.md 드리프트 0.

- [x] **Step 1: R5 — 미러 SKILL.md :68 단어 복원**

미러 `opencode-harness/skill/ui-design/SKILL.md`에서 정확히 이 줄:
```
        [floor §6 — 18항목 각각 PASS/N-A, FAIL 0]
```
을 다음으로 교체 (정본 :66과 동일화):
```
        [floor §6 — 18항목 각각 PASS/N-A 판정, FAIL 0]
```

- [x] **Step 2: design.md 미러 byte-copy**

```bash
cp -p /c/Users/12132/.claude/skills/ui-design/design.md /c/Users/12132/.claude/opencode-harness/skill/ui-design/design.md
cmp -s /c/Users/12132/.claude/skills/ui-design/design.md /c/Users/12132/.claude/opencode-harness/skill/ui-design/design.md && echo IDENTICAL || echo DIFFER
```
Expected: `IDENTICAL`

- [x] **Step 3: 의도 분기 3건 보존 확인 (A2 정정 반영)**

Run: `grep -cE "오프라인|\`task\` 도구|Playwright MCP가 없으면" /c/Users/12132/.claude/opencode-harness/skill/ui-design/SKILL.md`
Expected: ≥3 (CDN 노트·task-디스패치(백틱 `task` 표기)·Playwright-부재 SKIP — 3분기 전부 잔존)

- [x] **Step 4: 커밋**

```bash
git -C /c/Users/12132/.claude add skills/ui-design/design.md opencode-harness/skill/ui-design/
git -C /c/Users/12132/.claude commit -m "reaudit(ui-design): R1-R3 §0/§9/§8 정련(F-AUD-01/02) + R5 미러 SKILL.md 복원 + byte-sync"
```

---

### Task 4: R4 — seal-regression witness에 미러 design.md 추가 (TDD)

**Files:**
- Modify: `setup/tests/seal-regression.test.sh` (:18 witness 목록)

**Interfaces:**
- Produces: witness 주장(":9-10 every file any mutator could touch")과 실물 정합 — v3 귀책분 종결.

- [x] **Step 1: RED — 갭 실증 (witness에 미러 부재 확인)**

Run: `grep -n "opencode-harness" /c/Users/12132/.claude/setup/tests/seal-regression.test.sh | grep witness`
Expected: (출력 없음 — witness 라인에 미러 부재 = 주석의 "every file" 주장과 불일치 상태)

- [x] **Step 2: GREEN — witness 목록에 미러 추가**

정확히 이 블록:
```bash
witness() { local f; for f in state.json README.md settings.json CLAUDE.md hooks/tests/cases.tsv skills/ui-design/design.md; do
              cksum "$SRC/$f" 2>/dev/null; done; }
```
을 다음으로 교체:
```bash
witness() { local f; for f in state.json README.md settings.json CLAUDE.md hooks/tests/cases.tsv skills/ui-design/design.md opencode-harness/skill/ui-design/design.md; do
              cksum "$SRC/$f" 2>/dev/null; done; }
```

- [x] **Step 3: seal-regression 전체 GREEN (라이브 불변 증인 포함 9/0)**

Run: `cd /c/Users/12132/.claude && bash setup/tests/seal-regression.test.sh 2>&1 | tail -4`
Expected: `seal-regression: PASS=9 FAIL=0` + `live ~/.claude untouched`

- [x] **Step 4: 커밋**

```bash
git -C /c/Users/12132/.claude add setup/tests/seal-regression.test.sh
git -C /c/Users/12132/.claude commit -m "reaudit(seal): R4 witness에 opencode 미러 design.md 추가 — 'every file any mutator could touch' 주장 정합"
```

---

### Task 5: R6 — FITNESS-L5 증거 사슬 명시 (기록)

**Files:**
- Modify: `_design-lab/FITNESS-L5.md` (gitignored — 하단 append)

- [x] **Step 1: 재감사 노트 append**

```markdown

## Fable 재감사 노트 (2026-07-17, spec §12 R6)
- **격리 약점 공개**: L5.jsx는 `.reveal`/`.in-view` CSS를 자체 `<style>`로 내장하지 않고 랩 공유 index.css(:143-144, L1-era 작성)에서 상속 — L4 프로토콜("index.css 접근권 없음이 곧 문서만으로 재현 시험")보다 격리가 약함. design.md Global Setup(3항목)에 §9 모션 CSS는 없으므로 진짜 fresh 프로젝트면 진입 스태거는 무음 no-op(콘텐츠는 base 상태로 가시 — 기능 손상 없음).
- **평가 유효성**: §9 재현 중 "개별 지속 550ms" 몫은 공유 CSS 상속이고, 에이전트 자체 기여는 inline transitionDelay 축(0/70/140/210/280ms)이다. §12 3-way 분기 재현은 상속과 무관(순수 JSX 구조) — v3 정련 재현 결론은 유지되나 §9 몫의 증거 강도는 L4보다 약함을 명시.
- **후속**: L6(제6 장르) 디스패치 프롬프트에 L4-era 자족 노트("신규 CSS는 파일 내 <style>로 자족") 명시 재사용.
```

---

### Task 6: 하네스 정합 — 전체 verify (포그라운드)

**Files:** (읽기 전용 실행)

- [x] **Step 1: verify-setup** — Run: `cd /c/Users/12132/.claude && bash setup/verify-setup.sh 2>&1 | tail -3` / Expected: `PASS=81 FAIL=0` (#43 미러·#44 floor GREEN)
- [x] **Step 2: seal-regression** — Run: `bash setup/tests/seal-regression.test.sh 2>&1 | tail -3` / Expected: `PASS=9 FAIL=0`
- [x] **Step 3: run-all** — Run: `bash hooks/tests/run-all.sh 2>&1 | tail -3` / Expected: `172 / 172 passed`
- [x] **Step 4: opencode 오라클** — Run: `node opencode-harness/_oracle/skill-discovery.mjs 2>&1 | tail -2` / Expected: `OK 21 skills discoverable, 0 violations`
- [x] **Step 5: verify-all** — Run: `bash setup/verify-all.sh 2>&1 | tail -6` / Expected: ALL PASS (전 스테이지)

---

### Task 7: R7 — cold-agent fitness L6 회귀 (제6 장르: 온보딩/가입 폼)

**Files:**
- Create: `_design-lab/lab/src/pages/L6.jsx` (cold agent 산출)
- Modify: `_design-lab/lab/src/App.jsx` (`/l6` 라우트 — 메인 수행, 디자인 결정 아님)
- Create: `_design-lab/FITNESS-L6.md` (판정 기록)

**Interfaces:**
- Consumes: design.md v4 (Task 2·3 — R1(a)(b)·R2·R3 반영본).
- Produces: fitness 회귀 판정(≤2 iter, floor 18/18 + ceiling PASS) — R1-R3 수정이 재현성 무손상 실증.

- [x] **Step 1: cold agent 디스패치 (design.md v4만 제공 — R6 자족 노트 포함)**

```
Agent(subagent_type="execute-strict",
  task="스튜디오 온도의 서비스 「온도 옵스」 온보딩/가입 페이지를 React 단일 파일 컴포넌트로 제작하라.
파일: C:/Users/12132/.claude/_design-lab/lab/src/pages/L6.jsx (default export L6)
기능 요구: (a) 가입 폼 — 이름/이메일/비밀번호 + 약관 동의 체크 + 제출 CTA (b) 3단계 진행 표시(정보 입력→팀 설정→완료) (c) 좌우 분할 또는 비대칭 레이아웃의 브랜드 면 (d) 이미 계정이 있는 사용자용 로그인 링크. 콘텐츠는 실물급 한국어 카피(lorem 금지).
기술 제약: tailwind.config.js에 design 문서의 색·타이포 토큰이 이미 등록돼 있고(문서의 클래스명 그대로 사용 가능) react-coolicons가 설치돼 있다. 외부 라이브러리 추가 금지. 라우팅·테마 토글은 앱 셸이 처리하므로 페이지 컴포넌트만. 페이지 전용 CSS가 필요하면 반드시 L6.jsx 안 <style> 태그로 자족시켜라 — 외부 CSS 파일(index.css 등) 접근·의존 금지.
디자인 기준: C:/Users/12132/.claude/skills/ui-design/design.md 를 읽고 그 문서의 규칙·토큰·레시피만으로 모든 시각 결정을 하라. 문서가 요구하는 검증 항목(§6·§15)을 스스로 점검한 뒤 산출하라.",
  context_paths=["C:/Users/12132/.claude/skills/ui-design/design.md"],
  success_criteria="L6.jsx 단일 파일, design.md 토큰·클래스만(ad-hoc hex 0), 신규 CSS는 파일 내 <style> 자족, floor·ceiling 자가점검 주석 보고")
```
※ 프롬프트에 디자인 힌트(잉크·fluid·stagger 같은 용어) 금지 — 기능 명세만. (spec §7 cold-agent 격리)

- [x] **Step 2: 라우트 배선 + 렌더 스모크** — App.jsx에 `/l6` 추가(import L6 + Route), dev 서버(ephemeral 5300–5999) 기동, 콘솔 코드 에러 0 확인(favicon 404 무시).

- [x] **Step 3: 실측 게이트 (§4.4 — 메인 세션 Playwright)**

오버플로우(1440/768/390 × light/dark, root+내부 컨테이너 — sr-only 1px 클립박스·의도적 overflow-x-auto 제외)=0 · CLS(fresh load)<0.02 · reduced-motion 기능 동등(stuck 0·콘텐츠 가시) · focus-visible 2px solid(Tab 순회) · 다크 스왑 무결. **§9 검증 — R1(b)·R2 재현**: 개별 지속 ≤700ms·마지막 시작 지연 ≤300ms(요소 수×간격 산술 확인).

- [x] **Step 4: floor+ceiling 채점 (review-strict)**

```
Agent(subagent_type="review-strict",
  task="L6.jsx를 design.md v4 §6 floor 18항목 + §15 ceiling 9항목으로 채점",
  context_paths=["C:/Users/12132/.claude/skills/ui-design/design.md","C:/Users/12132/.claude/_design-lab/lab/src/pages/L6.jsx"],
  success_criteria="floor 각 항목 PASS/N-A 판정(FAIL 0)·ceiling 전항 판정·§9 모션이 파일 내 <style> 자족인지·R2 stagger 산술(마지막 지연 ≤300ms) 준수 확인")
```

- [x] **Step 5: 판정 — ≤2 iter**

iter1 ALL PASS → 합격. FAIL이면 문서 결함 역추적(F-AUD-<seq> 채록·design.md 회귀 수정·양 미러) 후 fresh cold agent로 iter2. iter2도 FAIL이면 R1-R3 정련 되돌림 검토 + 사용자 보고 승격(goal §0.4). 결과를 `_design-lab/FITNESS-L6.md`에 기록(프로토콜·게이트 표·§9/§12/R2 재현 여부·자족 격리 확인).

- [x] **Step 6: 커밋 (design.md 회귀 수정이 있었던 경우만 diff 포함)**

```bash
git -C /c/Users/12132/.claude add skills/ui-design/design.md opencode-harness/skill/ui-design/design.md 2>/dev/null
git -C /c/Users/12132/.claude commit --allow-empty -m "reaudit(fitness): L6 온보딩 회귀 — design.md v4 재현성 판정 기록 (랩 산출물 gitignored)"
```

---

### Task 8: spec §12 사후 기입 + plan 마감

**Files:**
- Modify: `docs/superpowers/specs/2026-07-12-ui-design-craft-upgrade-design.md` (§12에 L6 결과·검증 수치 1-2줄 append)
- Modify: `docs/superpowers/plans/2026-07-17-ui-design-fable-reaudit-rework.md` (체크박스 tick + Status)

- [x] **Step 1: spec §12 하단에 실행 결과 기입** — L6 판정(iterN ALL PASS 또는 결과)·최종 검증 수치(verify-setup 81/0·seal-regression 9/0·run-all 172/172)·R1-R5 커밋 해시를 §12 말미에 2-3줄 append.
- [x] **Step 2: 커밋**

```bash
git -C /c/Users/12132/.claude add docs/superpowers/specs/2026-07-12-ui-design-craft-upgrade-design.md docs/superpowers/plans/2026-07-17-ui-design-fable-reaudit-rework.md
git -C /c/Users/12132/.claude commit -m "docs(reaudit): spec §12 실행 결과 기입 + plan tick"
```

→ 이후 start-rpi-cycle Phase Closeout: closeout-pr-cycle(**MERGE_POLICY: wait** — PR 생성 후 사용자 승인 대기) + drift check + state bump + 메모리 append.

## Self-Review (writing-plans)

- **Spec coverage**: §12 REWORK 표 — R1(a)(b)=T2 S1-S2, R2=T2 S3, R3=T2 S4, R4=T4, R5=T3 S1, R6=T5, R7=T7. ACCEPT(A1-A5)는 기록 전용이라 task 없음(spec §12가 담지). 검증=T6, 사후 기입=T8. ✓
- **Placeholder scan**: 모든 교체 문구·프롬프트·명령 verbatim. TBD 0. ✓
- **Type consistency**: F-AUD-01/02 라벨이 T1 채록↔T2 인용↔spec §12 일치. 미러 경로·seal 번호(#43/#44) 일관. evidence 수 26→29 산술(T2 S1 +1, S2 +1, S3 +1; R3은 evidence 비인용 — 주석만). ✓
- **불변 검증**: T2 S5가 floor 18·ceiling 9 즉시 확인. 편집 라인 전부 서로소(Gate R 2차 확인). ✓
