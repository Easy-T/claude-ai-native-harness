**Status:** active
**RPI-Cycle:** 2
**Started:** 2026-05-19

# grill-with-docs Harness Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `grill-with-docs`를 Phase R 첫 단계로 통합해 모든 RPIC 전에 CONTEXT.md 도메인 어휘가 확립되도록 강제하고, 하네스 전체가 CONTEXT.md + domain-glossary.md를 함께 참조하게 한다.

**Architecture:** Matt Pocock의 외부 스킬을 재작성 없이 사용하고 doctor.sh로 자동 설치. start-rpi-cycle Phase R을 A(grill) → B(brainstorming) → C(explore-strict)로 확장. CONTEXT.md(순수 vocabulary) + domain-glossary.md(포인터+메타데이터)를 이중 참조하도록 모든 관련 context_paths 갱신.

**Tech Stack:** Bash, Markdown, Claude Code skill 시스템

**Spec:** `docs/superpowers/specs/2026-05-19-grill-with-docs-integration-design.md`

---

## File Map

| 역할 | 파일 | 변경 |
|---|---|---|
| 신규 bootstrap 템플릿 | `skills/init-ai-ready-project/templates/CONTEXT.md.tpl` | Create |
| glossary 포맷 교체 | `skills/init-ai-ready-project/templates/domain-glossary.md.tpl` | Modify |
| bootstrap 파일 목록·검증 | `skills/init-ai-ready-project/SKILL.md` | Modify |
| Phase R 확장 + C-1 drift | `skills/start-rpi-cycle/SKILL.md` | Modify |
| CONTEXT.md 이중 참조 | `skills/improve-codebase-architecture/SKILL.md` | Modify |
| grill-with-docs 자동 설치 | `setup/doctor.sh` | Modify |
| 템플릿 카운트 갱신 | `setup/verify-setup.sh` | Modify |
| 의존성·구조 갱신 | `README.md` | Modify |
| 용어 확인 규칙 갱신 | `CLAUDE.md` | Modify (세션 끝) |

---

## Task 1: CONTEXT.md.tpl 신규 생성

**Files:**
- Create: `~/.claude/skills/init-ai-ready-project/templates/CONTEXT.md.tpl`

- [ ] **Step 1: 파일 생성**

`~/.claude/skills/init-ai-ready-project/templates/CONTEXT.md.tpl` 내용:

```markdown
# {{PROJECT_NAME}}

> {{PROJECT_NAME}}의 도메인 어휘 사전. `grill-with-docs`가 관리.
> 구현 세부사항·스펙·ADR 기록 금지 — 순수 용어 정의만.

## Language

(부트스트랩 시 비어 있음. Phase R의 grill-with-docs 세션에서 채워집니다.)

<!--
용어 등록 형식:
**TermName**:
한 문장 정의 — what it IS (not what it does)
_Avoid_: 동의어1, 동의어2
-->

## Relationships

(도메인 개념 간 관계. grill-with-docs 세션에서 채워집니다.)

<!--
관계 표기 형식:
- An **Order** produces one or more **Invoices**
- An **Invoice** belongs to exactly one **Customer**
-->

## Example dialogue

(도메인 전문가와 개발자 간의 대화 예시. grill-with-docs 세션에서 채워집니다.)

<!--
형식:
> **Dev:** "When a **Customer** places an **Order**, do we create the **Invoice** immediately?"
> **Expert:** "No — an **Invoice** is only generated once a **Fulfillment** is confirmed."
-->

## Flagged ambiguities

(모호하게 사용된 용어와 해소 내역. grill-with-docs 세션에서 채워집니다.)
```

- [ ] **Step 2: 파일 존재 확인**

```bash
ls ~/.claude/skills/init-ai-ready-project/templates/CONTEXT.md.tpl
```
Expected: 파일 경로 출력

- [ ] **Step 3: 커밋**

```bash
cd ~/.claude
git add skills/init-ai-ready-project/templates/CONTEXT.md.tpl
git commit -m "feat(bootstrap): add CONTEXT.md.tpl for grill-with-docs vocabulary stub"
```

---

## Task 2: domain-glossary.md.tpl 포인터+메타데이터 포맷으로 교체

**Files:**
- Modify: `~/.claude/skills/init-ai-ready-project/templates/domain-glossary.md.tpl`

- [ ] **Step 1: 현재 내용 확인**

```bash
cat ~/.claude/skills/init-ai-ready-project/templates/domain-glossary.md.tpl
```

- [ ] **Step 2: 전체 내용 교체**

새 내용:

```markdown
# Domain Glossary — {{PROJECT_NAME}}

> 도메인 어휘 정의는 프로젝트 루트의 `CONTEXT.md`가 소유.
> 이 파일은 하네스 메타데이터(confidence·RPIC·코드 식별자)만 관리.

## Primary Vocabulary
→ [CONTEXT.md](../../CONTEXT.md) 참조 (grill-with-docs 관리)

## Harness Metadata

| 용어 | 첫 등장 날짜 | RPIC | Confidence | 코드 식별자 |
|---|---|---|---|---|

(부트스트랩 시 비어 있음. Phase R grill-with-docs 완료 후 메인이 기록)

## Flagged for Review

(미해소 모호 용어. CONTEXT.md "Flagged ambiguities"와 연동)
```

- [ ] **Step 3: 커밋**

```bash
cd ~/.claude
git add skills/init-ai-ready-project/templates/domain-glossary.md.tpl
git commit -m "feat(bootstrap): replace domain-glossary.md.tpl with pointer+metadata format"
```

---

## Task 3: init-ai-ready-project/SKILL.md — 파일 목록 13개, §8, 검증 기준 갱신

**Files:**
- Modify: `~/.claude/skills/init-ai-ready-project/SKILL.md`

- [ ] **Step 1: Phase 0 메타 룰 카운트 수정**

찾기: `메타 룰 6개 마커 존재 (\`## §1\` ~ \`## §6\`)`
교체: `메타 룰 8개 마커 존재 (\`## §1\` ~ \`## §8\`)`

- [ ] **Step 2: Phase 2 설명 및 파일 목록 수정**

찾기: `# Phase 2 — Generate (12개 파일 + 디렉터리)`
교체: `# Phase 2 — Generate (13개 파일 + 디렉터리)`

기존 파일 12번 아래에 13번 추가:
```
13. `<root>/CONTEXT.md` ← templates/CONTEXT.md.tpl
```

- [ ] **Step 3: Phase 3 검증 카운트 + CONTEXT.md 항목 추가**

찾기: `- 12개 파일 + 5개 디렉터리 모두 존재`
교체: `- 13개 파일 + 5개 디렉터리 모두 존재`

success_criteria 블록 안에 항목 추가:
```
        - CONTEXT.md 존재 (프로젝트 루트)
```
(`CLAUDE.md ≤200줄` 바로 아래 줄에 삽입)

- [ ] **Step 4: 변경 확인**

```bash
grep -n "13개\|CONTEXT.md\|§8" ~/.claude/skills/init-ai-ready-project/SKILL.md
```
Expected: 3개 이상의 매칭 라인 출력

- [ ] **Step 5: 커밋**

```bash
cd ~/.claude
git add skills/init-ai-ready-project/SKILL.md
git commit -m "feat(bootstrap): expand generated files to 13 (CONTEXT.md), fix §8 meta rule count"
```

---

## Task 4: start-rpi-cycle/SKILL.md — Phase R A→B→C 확장

**Files:**
- Modify: `~/.claude/skills/start-rpi-cycle/SKILL.md`

- [ ] **Step 1: Phase R 전체 교체**

찾기 (정확히 일치하는 블록):
```
# Phase R — Research

A. brainstorming skill 절차 (메인이 직접 따름) — 외향적 (요구·접근법·디자인)
   → 산출물: docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md

B. Agent(subagent_type="explore-strict",
        task="<요청 분석>",
        context_paths=["docs/ai-context/architecture.md",
                       "docs/ai-context/domain-glossary.md",
                       "docs/ai-context/non-obvious.md",
                       "docs/ai-context/deny-patterns.md"],
        success_criteria="발견사항·영향 모듈·신규 도메인 용어·deny pattern 충돌 식별")
   ※ CLAUDE.md는 메인이 자동 로드하므로 context_paths에 미포함 (중복 회피)
   ※ A와 B는 병렬·교차 가능

## Gate R
- 새 도메인 용어 confidence < 80% → 사용자 확인 → glossary 자동 추가 (메인이 직접 Edit)
- 아키텍처 영향 → ADR 초안 작성 권유 (architecture.md append-only)
```

교체:
```
# Phase R — Research

A. grill-with-docs skill 절차 (메인이 직접 따름) — 도메인 용어 확립
   ※ 미설치 시: `bash ~/.claude/setup/doctor.sh` 로 자동 설치
   → 산출물: CONTEXT.md 갱신 (프로젝트 루트), docs/adr/*.md (조건부)
   → grill 세션 종료 후 메인이 직접: domain-glossary.md 메타데이터 테이블에 신규 용어 기록

B. brainstorming skill 절차 (메인이 직접 따름) — 외향적 (요구·접근법·디자인)
   ※ CONTEXT.md에 확정된 용어를 언어 기반으로 사용
   → 산출물: docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md

C. Agent(subagent_type="explore-strict",
        task="<요청 분석>",
        context_paths=["CONTEXT.md",
                       "docs/ai-context/architecture.md",
                       "docs/ai-context/domain-glossary.md",
                       "docs/ai-context/non-obvious.md",
                       "docs/ai-context/deny-patterns.md"],
        success_criteria="발견사항·영향 모듈·신규 도메인 용어·deny pattern 충돌 식별")
   ※ CLAUDE.md는 메인이 자동 로드하므로 context_paths에 미포함 (중복 회피)
   ※ B와 C는 병렬·교차 가능 (A 완료 후)

## Gate R
- CONTEXT.md 갱신 확인 (A 완료 검증)
- 신규 도메인 용어 confidence < 80% → 사용자 확인 → domain-glossary.md 메타데이터 추가
- 아키텍처 영향 → ADR 초안 작성 권유 (architecture.md append-only)
```

- [ ] **Step 2: Phase R 변경 확인**

```bash
grep -n "grill-with-docs\|CONTEXT.md\|B와 C는 병렬" ~/.claude/skills/start-rpi-cycle/SKILL.md
```
Expected: 3개 이상 매칭

- [ ] **Step 3: Closeout C-1 context_paths에 CONTEXT.md 추가**

찾기:
```
        context_paths=["docs/ai-context/architecture.md",
                       "docs/ai-context/domain-glossary.md",
                       "docs/ai-context/non-obvious.md"],
        success_criteria="
          - architecture.md 갱신 (모듈/의존성 변경 반영) 또는 변경 없음 확인
          - domain-glossary.md 갱신 또는 변경 없음 확인
```

교체:
```
        context_paths=["CONTEXT.md",
                       "docs/ai-context/architecture.md",
                       "docs/ai-context/domain-glossary.md",
                       "docs/ai-context/non-obvious.md"],
        success_criteria="
          - CONTEXT.md 갱신 (신규 용어 추가됨) 또는 변경 없음 확인
          - architecture.md 갱신 (모듈/의존성 변경 반영) 또는 변경 없음 확인
          - domain-glossary.md 갱신 또는 변경 없음 확인
```

- [ ] **Step 4: Closeout 변경 확인**

```bash
grep -n "CONTEXT.md" ~/.claude/skills/start-rpi-cycle/SKILL.md
```
Expected: Phase R(C step)과 Closeout C-1 두 곳에서 출력

- [ ] **Step 5: 커밋**

```bash
cd ~/.claude
git add skills/start-rpi-cycle/SKILL.md
git commit -m "feat(rpi): extend Phase R to A(grill)→B(brainstorm)→C(explore), add CONTEXT.md to C-1 drift check"
```

---

## Task 5: improve-codebase-architecture/SKILL.md — CONTEXT.md 이중 참조

**Files:**
- Modify: `~/.claude/skills/improve-codebase-architecture/SKILL.md`

- [ ] **Step 1: Phase 1 context_paths에 CONTEXT.md 추가**

찾기:
```
        context_paths=[
        "docs/ai-context/architecture.md",
        "docs/ai-context/domain-glossary.md",
        "docs/ai-context/non-obvious.md"
      ]
```

교체 (들여쓰기 원본 그대로 유지):
```
        context_paths=[
        "CONTEXT.md",
        "docs/ai-context/architecture.md",
        "docs/ai-context/domain-glossary.md",
        "docs/ai-context/non-obvious.md"
      ]
```

- [ ] **Step 2: Phase 4 입력 파일 목록에 CONTEXT.md 추가**

찾기:
```
- docs/ai-context/architecture.md (아키텍처 다이어그램, 모듈 설명)
- docs/ai-context/domain-glossary.md (도메인 용어)
```

교체:
```
- CONTEXT.md (canonical 용어 — README에서 일관된 vocabulary 사용)
- docs/ai-context/architecture.md (아키텍처 다이어그램, 모듈 설명)
- docs/ai-context/domain-glossary.md (도메인 용어 메타데이터)
```

- [ ] **Step 3: 변경 확인**

```bash
grep -n "CONTEXT.md" ~/.claude/skills/improve-codebase-architecture/SKILL.md
```
Expected: 2개 매칭 (Phase 1, Phase 4)

- [ ] **Step 4: 커밋**

```bash
cd ~/.claude
git add skills/improve-codebase-architecture/SKILL.md
git commit -m "feat(arch): add CONTEXT.md to Phase 1 + Phase 4 context_paths"
```

---

## Task 6: doctor.sh — grill-with-docs 자동 설치 check #20

**Files:**
- Modify: `~/.claude/setup/doctor.sh`

- [ ] **Step 1: check #20 블록 추가**

`# Report` 주석 줄 바로 위에 삽입:

```bash
# 20. grill-with-docs skill (auto-install from mattpocock/skills)
GRILL_SKILL="$CLAUDE_HOME/skills/grill-with-docs/SKILL.md"
if [ -f "$GRILL_SKILL" ]; then
  check "grill-with-docs skill" "PASS" ""
else
  echo "[doctor] grill-with-docs 미설치 — mattpocock/skills에서 설치 시도..."
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    mkdir -p "$CLAUDE_HOME/skills/grill-with-docs"
    INSTALL_OK=1
    for gf in SKILL.md CONTEXT-FORMAT.md ADR-FORMAT.md; do
      node -e "
        const {execSync} = require('child_process');
        try {
          const out = execSync('gh api repos/mattpocock/skills/contents/skills/engineering/grill-with-docs/$gf', {encoding:'utf8'});
          const b64 = JSON.parse(out).content.replace(/\n/g,'');
          process.stdout.write(Buffer.from(b64,'base64').toString('utf8'));
        } catch(e) { process.exit(1); }
      " 2>/dev/null > "$CLAUDE_HOME/skills/grill-with-docs/$gf" || { INSTALL_OK=0; break; }
    done
    if [ "$INSTALL_OK" -eq 1 ] && [ -f "$GRILL_SKILL" ]; then
      check "grill-with-docs skill" "PASS" "auto-installed from mattpocock/skills"
    else
      check "grill-with-docs skill" "WARN" "auto-install 실패 — 수동: https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs"
    fi
  else
    check "grill-with-docs skill" "WARN" "gh 미인증 — 수동: https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs"
  fi
fi

```

- [ ] **Step 2: bash 문법 검사**

```bash
bash -n ~/.claude/setup/doctor.sh
```
Expected: 출력 없음 (문법 오류 없음)

- [ ] **Step 3: 커밋**

```bash
cd ~/.claude
git add setup/doctor.sh
git commit -m "feat(doctor): add check #20 — grill-with-docs auto-install from mattpocock/skills"
```

---

## Task 7: verify-setup.sh — 템플릿 카운트 12→13

**Files:**
- Modify: `~/.claude/setup/verify-setup.sh`

- [ ] **Step 1: 카운트 임계값 수정**

찾기:
```bash
[ "$T" -ge 12 ] && [ "$R" -ge 2 ] && ok "templates=$T, refs=$R" || fail "templates=$T (need 12), refs=$R"
```

교체:
```bash
[ "$T" -ge 13 ] && [ "$R" -ge 2 ] && ok "templates=$T, refs=$R" || fail "templates=$T (need 13), refs=$R"
```

- [ ] **Step 2: verify-setup.sh 전체 실행**

```bash
bash ~/.claude/setup/verify-setup.sh 2>&1
```
Expected: `verify-setup: PASS=43 FAIL=0` (또는 CONTEXT.md.tpl 생성된 경우 PASS=44)

- [ ] **Step 3: 커밋**

```bash
cd ~/.claude
git add setup/verify-setup.sh
git commit -m "chore(verify): update template count threshold 12→13 for CONTEXT.md.tpl"
```

---

## Task 8: README.md — 의존성 및 구조 트리 갱신

**Files:**
- Modify: `~/.claude/README.md`

- [ ] **Step 1: 필수 플러그인 표에 mattpocock/skills 추가**

찾기:
```
| `claude-md-management` (선택) | claude-plugins-official | CLAUDE.md 점검 자동화 |
```

아래에 삽입:
```
| `mattpocock/skills` | [mattpocock/skills](https://github.com/mattpocock/skills) | grill-with-docs — Phase R.A 도메인 어휘 확립 (doctor.sh 자동 설치) |
```

- [ ] **Step 2: 구조 트리에 CONTEXT.md.tpl 추가**

찾기:
```
│   │   ├── templates/                    12 .tpl 파일
```

교체:
```
│   │   ├── templates/                    13 .tpl 파일 (CONTEXT.md.tpl 포함)
```

- [ ] **Step 3: 시나리오 2 Phase R 설명에 grill-with-docs 추가**

찾기:
```
1. **Phase R (Research)**: brainstorming + explore-strict — 요구사항·접근법·디자인 정리
```

교체:
```
1. **Phase R (Research)**: grill-with-docs(도메인 어휘 확립) + brainstorming + explore-strict — 요구사항·접근법·디자인 정리
```

- [ ] **Step 4: 커밋**

```bash
cd ~/.claude
git add README.md
git commit -m "docs(readme): add mattpocock/skills dependency, CONTEXT.md.tpl in structure, grill-with-docs in scenario 2"
```

---

## Task 9: CLAUDE.md §6 — 용어 확인 규칙 갱신

**Files:**
- Modify: `~/.claude/CLAUDE.md`

> ⚠️ §1 Cache Stability: CLAUDE.md 수정은 세션 종료 직전에만. 이 Task는 마지막에 실행.

- [ ] **Step 1: §6 내용 수정**

찾기:
```
- 확인된 용어 + 코드 식별자 매핑 → glossary 자동 추가
- 같은 단어 다른 컨텍스트 → "Identical-Looking" 섹션에
```

교체:
```
- 확인된 용어 → CONTEXT.md 갱신 → domain-glossary.md 메타데이터 sync
- 같은 단어 다른 컨텍스트 → CONTEXT.md "Flagged ambiguities"에
```

- [ ] **Step 2: CLAUDE.md 줄 수 확인 (≤200줄)**

```bash
wc -l ~/.claude/CLAUDE.md
```
Expected: ≤200

- [ ] **Step 3: 커밋**

```bash
cd ~/.claude
git add CLAUDE.md
git commit -m "docs(claude-md): update §6 to reference CONTEXT.md as vocabulary source"
```

---

## Task 10: 최종 검증 + Push

- [ ] **Step 1: verify-setup.sh 전체 실행**

```bash
bash ~/.claude/setup/verify-setup.sh 2>&1
```
Expected: `verify-setup: PASS=44 FAIL=0`

- [ ] **Step 2: doctor.sh 문법 최종 확인**

```bash
bash -n ~/.claude/setup/doctor.sh && echo "syntax OK"
```
Expected: `syntax OK`

- [ ] **Step 3: grill-with-docs 스킬 설치 확인 (doctor.sh 실행)**

```bash
bash ~/.claude/setup/doctor.sh 2>&1 | grep -E "grill|PASS|FAIL|WARN"
```
Expected: `✓ grill-with-docs skill` (PASS 또는 auto-installed)

- [ ] **Step 4: push**

```bash
cd ~/.claude && git push origin master
```
Expected: `master -> master`
