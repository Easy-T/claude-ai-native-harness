# init-ai-ready Doc-Count SSOT Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** completed
**RPI-Cycle:** 19
**Started:** 2026-06-05

**Goal:** Reconcile every stale init-ai-ready file/template/directory **count claim** in the durable design spec (`2026-05-01-ai-native-orchestration-design.md`) so it matches reality — 13 .tpl / 13 generated files / 5 directories — using `templates/` + `SKILL.md` Phase 2/3 as the oracle; plus fix one stale comment in `verify-setup.sh`.

**Architecture:** In-place correction of a living durable spec (NOT §5 supersede — §5 append-only applies only to `docs/ai-context/architecture.md` ADRs, not superpowers design specs). All edits are byte-exact string replacements. Single-file doc edit + one 1-line script-comment fix → executed sequentially in the main session (no worktree, no parallel agents — surgical text edits need byte-exact control). Gate R surfaced 2 gaps (§3.1 resolution); both are pinned below and re-verified at Gate P.

**Tech Stack:** Markdown spec, bash (`verify-setup.sh`), `setup/verify-all.sh` for verification.

**Ground truth (oracle — confirmed by Gate R):**
- `skills/init-ai-ready-project/templates/` = **13 .tpl** (incl hidden `.gitignore.tpl`)
- `references/` = **2** (`placeholder-spec.md`, `stack-presets.md`)
- `SKILL.md` Phase 2 lists **13 files**; Phase 3 success_criteria = **"13개 파일 + 5개 디렉터리"**
- `verify-setup.sh` #11 asserts `-ge 13` / `-ge 2` (functionally correct); only its L59 comment says stale "12"

---

## Non-Goals (deliberately deferred — surfaced as cycle-20 candidates, NOT touched this cycle)

Per Surgical Changes ("every changed line traces to the request" = init-ai-ready **file-count** claims). These are **separate SSOT facts**, surfaced here so they are NOT silently skipped:

1. **Global-count drift** in the spec: `§2.1 L285` "메타 룰 6개" (real 8 — §1~§8), `§2.1 L286` "5개 등록" hooks + `§0.7`/`§8` "hook 5개" (real 9), "글로벌 skill 4개" (real 6 orchestrator + 1 contract), "약 2,800줄" doc length (real ~3094).
2. **`§2.9 L874`** "verify-setup.sh … (9개 파일 존재)" — describes verify-setup's *global-infra* checks (~19+), NOT the 13 templates. Stale but a different SSOT.
3. **`§1.4 L336`** "총 신규 파일 ~30개" — approximate global new-file total, not init-ai-ready-specific.
4. **`§5.7 L2244`** "10 active, 3 archive" — non-obvious.md rotation maturity, not a file count.
5. **§3 body sections** for the 3 PR-lifecycle templates (`scripts-check.sh`, `github-ci.yml`, `CONTEXT.md`) — they have `.tpl` files but NO `§3.x` body in the spec (0 mentions). Authoring 3 bodies is out of count-reconciliation scope. This plan lists them in §3.1 with an explicit footnote marking the bodies as deferred.

---

## File Structure

- **Modify:** `C:\Users\12132\.claude\docs\superpowers\specs\2026-05-01-ai-native-orchestration-design.md` — 18 byte-exact edits across §0.7, §2.1, §2.2, §2.3, §2.8, §2.11, §3.1, §3.15, §6.3, §6.5, §7.1.
- **Modify:** `C:\Users\12132\.claude\setup\verify-setup.sh` — 1 byte-exact edit (L59 comment).
- **Verify:** `C:\Users\12132\.claude\setup\verify-all.sh` (run; expect ALL PASS unchanged).

---

### Task 1: Spec §0–§3 count corrections (12 edits)

**Files:**
- Modify: `C:\Users\12132\.claude\docs\superpowers\specs\2026-05-01-ai-native-orchestration-design.md`

- [ ] **Step 1.1: §0.7 doc-structure index (L123) — honest "13 (본문 10 + .tpl 3)"**

old:
```
| 3 | 프로젝트 템플릿 | 9개 파일 본문 + placeholder + Mustache 형식 |
```
new:
```
| 3 | 프로젝트 템플릿 | 13개 목록 (본문 10 + PR-lifecycle 3은 .tpl) + placeholder + Mustache 형식 |
```

- [ ] **Step 1.2: §2.1 directory tree (L301) — "8 .tpl 파일" → "13 .tpl 파일"**

old:
```
│   │   ├── templates/                         # bundled (8 .tpl 파일, §3에서 본문)
```
new:
```
│   │   ├── templates/                         # bundled (13 .tpl 파일, §3에서 본문)
```

- [ ] **Step 1.3: §2.2 execute-strict example (L431) — "9개 파일" → "13개 파일"**

old:
```
  Context: 부트스트랩 시 9개 파일 생성
```
new:
```
  Context: 부트스트랩 시 13개 파일 생성
```

- [ ] **Step 1.4: §2.3 skill summary (L588) — "9개 파일" → "13개 파일"**

old:
```
  "프로젝트 초기화" 등을 말하면 무조건 사용. 9개 파일 + 디렉터리 결정론적 생성.
```
new:
```
  "프로젝트 초기화" 등을 말하면 무조건 사용. 13개 파일 + 디렉터리 결정론적 생성.
```

- [ ] **Step 1.5: §2.3 Phase 2 Generate (L612) — "*.tpl 8개 + .gitkeep 3개" → "13개 + 디렉터리 5개"**

old:
```
templates/*.tpl 8개 + .gitkeep 3개를 변수 치환 후 결정론적 생성. 병렬 호출(다른 파일이라 worktree 불필요).
```
new:
```
templates/*.tpl 13개 + 디렉터리 5개를 변수 치환 후 결정론적 생성. 병렬 호출(다른 파일이라 worktree 불필요).
```

- [ ] **Step 1.6: §2.3 Phase 3 success_criteria (L617) — "9개 파일 + 3개 디렉터리" → "13개 파일 + 5개 디렉터리"**

old:
```
      success_criteria="9개 파일 + 3개 디렉터리, CLAUDE.md ≤200줄, deny-patterns의 ❌ 마커 ≥8, hook 실행권한, settings.json jq 파싱 성공, placeholder 잔존 0")
```
new:
```
      success_criteria="13개 파일 + 5개 디렉터리, CLAUDE.md ≤200줄, deny-patterns의 ❌ 마커 ≥8, hook 실행권한, settings.json jq 파싱 성공, placeholder 잔존 0")
```

- [ ] **Step 1.7: §2.8 header (L851) — "8개 .tpl 파일" → "13개 .tpl 파일"**

old:
```
8개 .tpl 파일 + 2개 references. 본문은 §3에서 정의.
```
new:
```
13개 .tpl 파일 + 2개 references. 본문은 §3에서 정의 (PR-lifecycle 3개 본문은 cycle-20 예정 — §3.1 각주).
```

- [ ] **Step 1.8: §2.8 templates ascii tree (L855–862) — add the 5 missing .tpl**

old:
```
├── CLAUDE.md.tpl
├── architecture.md.tpl
├── runbook.md.tpl
├── deny-patterns.md.tpl
├── non-obvious.md.tpl
├── domain-glossary.md.tpl
├── project-settings.json.tpl
└── pre-commit-deny.sh.tpl
```
new:
```
├── CLAUDE.md.tpl
├── architecture.md.tpl
├── runbook.md.tpl
├── deny-patterns.md.tpl
├── non-obvious.md.tpl
├── domain-glossary.md.tpl
├── project-settings.json.tpl
├── pre-commit-deny.sh.tpl
├── .gitignore.tpl
├── state.json.tpl
├── scripts-check.sh.tpl
├── github-ci.yml.tpl
└── CONTEXT.md.tpl
```

- [ ] **Step 1.9: §2.11 §2 마감 (L975) — "템플릿 8개의 본문 (§2.6의 5개 자산 포함)" → honest 13**

(Removes the dangling "§2.6의 5개 자산" reference — Gate R confirmed §2.6 = global CLAUDE.md, not these templates.)

old:
```
- §3 — 프로젝트 템플릿 8개의 본문 (변경된 §2.6의 5개 자산 포함)
```
new:
```
- §3 — 프로젝트 템플릿 13개 목록 + 본문 10개 (PR-lifecycle 3개 본문은 §3.1 각주 참조, cycle-20)
```

- [ ] **Step 1.10: §3.1 header (L985) — "(10개)" → "(13개)"**

old:
```
### 3.1 템플릿 파일 목록 (10개)
```
new:
```
### 3.1 템플릿 파일 목록 (13개)
```

- [ ] **Step 1.11: §3.1 table — add rows 11–13 + footnote (GAP-2 resolution)**

Append 3 rows after the row-10 line and add a footnote. The 3 new rows are listed (matches `templates/` + SKILL.md Phase 2) but explicitly marked body-deferred — NO §2.6 citation.

old:
```
| 10 | `state.json.tpl` | `.claude/state.json` | 사이클 카운트 영속화 (§2.12) |
```
new:
```
| 10 | `state.json.tpl` | `.claude/state.json` | 사이클 카운트 영속화 (§2.12) |
| 11 | `scripts-check.sh.tpl` | `scripts/check.sh` | 로컬 품질 게이트 스크립트 † |
| 12 | `github-ci.yml.tpl` | `.github/workflows/ci.yml` | CI 워크플로 † |
| 13 | `CONTEXT.md.tpl` | `<root>/CONTEXT.md` | 프로젝트 컨텍스트·글로서리 (grill-with-docs) † |

† 11~13은 PR-lifecycle 자산. `.tpl`은 templates/에 존재하나 §3 본문 미수록 — 골격은 `templates/<name>.tpl` 직접 참조, 본문 작성은 cycle-20 예정.
```

- [ ] **Step 1.12: §3.1 directory list (L1000–1003) — split ".gitkeep" header, list all 5 (GAP-1 resolution)**

old:
```
추가로 디렉터리만 생성 (`.gitkeep`):
- `docs/superpowers/specs/`
- `docs/superpowers/plans/`
```
new:
```
추가로 디렉터리 5개 생성:
- `docs/superpowers/specs/` (`.gitkeep`)
- `docs/superpowers/plans/` (`.gitkeep`)
- `.claude/hooks/` (pre-commit-deny.sh가 점유)
- `scripts/` (check.sh가 점유)
- `.github/workflows/` (ci.yml이 점유)
```

---

### Task 2: Spec §3.15/§6/§7 corrections + verify-setup.sh comment (7 edits)

**Files:**
- Modify: `C:\Users\12132\.claude\docs\superpowers\specs\2026-05-01-ai-native-orchestration-design.md`
- Modify: `C:\Users\12132\.claude\setup\verify-setup.sh`

- [ ] **Step 2.1: §3.15 Phase 3 checklist #1 (L1412) — "10개 파일 … 10번" → 13**

old:
```
| 1 | 파일 존재 | 10개 파일 모두 | `[ -f docs/ai-context/architecture.md ]` 등 10번 |
```
new:
```
| 1 | 파일 존재 | 13개 파일 모두 | `[ -f docs/ai-context/architecture.md ]` 등 13번 |
```

- [ ] **Step 2.2: §3.15 Phase 3 checklist #2 (L1413) — "3개 디렉터리" → "5개 디렉터리"**

old:
```
| 2 | 디렉터리 존재 | 3개 디렉터리 (specs, plans, hooks) | `[ -d docs/superpowers/plans ]` 등 |
```
new:
```
| 2 | 디렉터리 존재 | 5개 디렉터리 (specs, plans, hooks, scripts, workflows) | `[ -d docs/superpowers/plans ]` 등 |
```

- [ ] **Step 2.3: §6.3 verify-setup check #11 (L2419) — "8 .tpl" → "13 .tpl", count "(≥13)"**

old:
```
| 11 | `~/.claude/skills/init-ai-ready-project/templates/` 8 .tpl + 2 references | 파일 카운트 |
```
new:
```
| 11 | `~/.claude/skills/init-ai-ready-project/templates/` 13 .tpl + 2 references | 파일 카운트 (≥13) |
```

- [ ] **Step 2.4: §6.5 E2E scenario step 1 (L2473) — "10개 파일 (9 .tpl + state.json) + 3개 디렉터리" → 13/5**

old:
```
| 1 | `/init-ai-ready test-ai-ready` | Phase 0~4 통과. 10개 파일 (9 .tpl + state.json) + 3개 디렉터리 (specs/plans/hooks). doctor 1회 실행. drift 보고 |
```
new:
```
| 1 | `/init-ai-ready test-ai-ready` | Phase 0~4 통과. 13개 파일 + 5개 디렉터리 (specs/plans/hooks/scripts/workflows). doctor 1회 실행. drift 보고 |
```

- [ ] **Step 2.5: §7.1 build step 2 산출물 (L2644) — "(8개)" → "(13개)"**

old:
```
| 산출물 | `~/.claude/skills/init-ai-ready-project/templates/*.tpl` (8개) + `references/*.md` (2개) |
```
new:
```
| 산출물 | `~/.claude/skills/init-ai-ready-project/templates/*.tpl` (13개) + `references/*.md` (2개) |
```

- [ ] **Step 2.6: §7.1 build step 2 주의 (L2648) — "10번째 .tpl" → "13개 .tpl 중" + PR-lifecycle note**

old:
```
| 주의 | state.json.tpl 포함 (10번째 .tpl). placeholder-spec.md와 stack-presets.md는 §3.12, §3.13 본문 그대로 |
```
new:
```
| 주의 | state.json.tpl 포함 (13개 .tpl 중 하나; scripts-check/github-ci/CONTEXT는 PR-lifecycle 추가분, 본문은 cycle-20 — §3.1 각주). placeholder-spec.md와 stack-presets.md는 §3.12, §3.13 본문 그대로 |
```

- [ ] **Step 2.7: `verify-setup.sh` L59 comment — "12 templates" → "13 templates"**

File: `C:\Users\12132\.claude\setup\verify-setup.sh`

old:
```
# 11. 12 templates + 2 references
```
new:
```
# 11. 13 templates + 2 references
```

(Assertion on L62 already `-ge 13` — comment-only fix, zero behavior change.)

---

### Task 3: Verify + commit

**Files:**
- Verify: `C:\Users\12132\.claude\setup\verify-all.sh`

- [ ] **Step 3.1: Residual stale-count grep — expect ZERO init-ai-ready current-state stale counts**

Run:
```bash
grep -nE '8 ?개? ?\.tpl|9개 파일|10개 파일|\(10개\)|10번째 \.tpl|3개 디렉터리|9 \.tpl' "$HOME/.claude/docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md"
```
Expected: no init-ai-ready current-state matches remain. (Out-of-scope global counts per Non-Goals may still match unrelated patterns — eyeball each hit; none should be an init-ai-ready template/file/dir count.)

- [ ] **Step 3.2: Confirm 13-enumeration in §2.8 tree and §3.1 table**

Run:
```bash
grep -cE 'scripts-check\.sh\.tpl|github-ci\.yml\.tpl|CONTEXT\.md\.tpl' "$HOME/.claude/docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md"
```
Expected: ≥ 6 (each of the 3 appears in both §2.8 tree and §3.1 table; previously 0).

- [ ] **Step 3.3: Run verify-all — expect ALL PASS unchanged**

Run:
```bash
bash "$HOME/.claude/setup/verify-all.sh"
```
Expected: doctor PASS · verify-setup **60/0** (#17~#24 green) · run-all 96/96 · verify-integration 8/8 · rc=0. (The verify-setup.sh comment fix does not change any assertion count.)

- [ ] **Step 3.4: Mark plan checkboxes [x] then commit + push**

```bash
cd "$HOME/.claude"
# CLAUDE.md = doctor.sh audit-marker bump (2026-06-04→05) during the Step 3.3 verify-all run.
# Accurate freshness stamp (not a conscious §1 content edit); bundled per established cycle pattern
# (git was clean at session start ⇒ prior cycles committed their marker bumps). Closeout drift Crit-7.
git add CLAUDE.md docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md setup/verify-setup.sh docs/superpowers/plans/2026-06-05-cycle19-initairready-count-ssot.md state.json
git commit -m "$(cat <<'EOF'
docs(rpi): cycle-19 init-ai-ready doc-count SSOT reconcile (8/9/10 → 13 .tpl / 13 files / 5 dirs)

Spec 2026-05-01 had init-ai-ready file/template counts stale across ~18 sites
(§0.7, §2.1, §2.2, §2.3, §2.8, §2.11, §3.1, §3.15, §6.3, §6.5, §7.1). Oracle =
templates/ (13 .tpl) + SKILL.md Phase 2/3 (13 files + 5 dirs). In-place living-spec
correction. §2.8 tree +5 entries, §3.1 table +3 rows (PR-lifecycle, body deferred
to cycle-20 via footnote — no §2.6 mis-citation). §3.1 dir list split off .gitkeep
header → 5 dirs. verify-setup.sh L59 comment 12→13 (assertion already -ge 13).
Out of scope (surfaced for cycle-20): global counts (hook/skill/meta-rule/doc-len),
§3 bodies for the 3 PR-lifecycle templates.

CLAUDE.md: doctor audit-marker bump to 2026-06-05 (verify-all side-effect).
verify-all: ALL PASS (doctor 33/0, verify-setup 60/0, hooks 96/96, integration 8/8).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
git push
```

---

## Self-Review (writing-plans checklist)

1. **Spec coverage:** All 18 spec edits + 1 script edit map 1:1 to a Gate R fix-list line. Gate R GAP-1 (§3.1 dir header) → Step 1.12. GAP-2 (§3.1 rows/§0.7/§2.11 honesty + no §2.6) → Steps 1.11, 1.1, 1.9. ✓
2. **Placeholder scan:** No TBD/TODO; every step has byte-exact old/new. ✓
3. **Count consistency:** Every "current-state" init-ai-ready count → 13 files / 13 .tpl / 5 dirs (SKILL.md Phase 3 oracle). §3.1 advertises 13 but footnote (Step 1.11) + §0.7/§2.11 wording (Steps 1.1/1.9) honestly reconcile the 10-body / 3-deferred split — no new "13-advertised-vs-10-documented" contradiction. ✓
3a. **Gap re-verification at Gate P:** Gate P MUST confirm (i) Step 1.11 footnote does NOT cite §2.6 and marks bodies deferred; (ii) Step 1.12 header is no longer ".gitkeep만" over a 5-item list; (iii) no remaining init-ai-ready stale count after all edits.
