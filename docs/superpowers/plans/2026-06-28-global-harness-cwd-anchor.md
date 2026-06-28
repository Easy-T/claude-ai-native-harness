# 글로벌 하네스 트랙: cwd-drift 앵커 + fitness 배선 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** active

**Goal:** `~/.claude` 하네스의 RPI 게이트를 cwd-상대 단일레벨에서 git-루트/상위탐색 앵커로 교정하고(item ①), 이미 cwd-독립인 worktree-teardown의 고아 테스트를 수용 게이트에 배선하며(item ②), 동시세션 격리 규약을 인코딩(item ③)한다.

**Architecture:** 단일 앵커 헬퍼 `_common.sh::resolve_project_root`를 SSOT로 두고 `has_active_plan`·`enforce-rpi-cycle.sh`가 소비. worktree-teardown.sh 훅은 무편집(이미 마커 fallback). 고아 `worktree-teardown.test.sh`를 verify-all.sh STAGE 3b로 배선. 동시세션 규약은 SECURITY.md/CONTEXT.md 문서. fitness 4종을 verify-setup.sh #31~#34에 추가.

**Tech Stack:** bash(POSIX sh 호환), git, node(hook 런타임), powershell(Windows worktree 테스트). 모두 fail-open 설계.

## Global Constraints

- `~/.claude/CLAUDE.md`(글로벌 규약) 수정 금지(§1 캐시안정성) — 본 작업은 hooks/*·setup/*·SECURITY.md·CONTEXT.md만.
- 프로젝트 repo(`C:/Users/12132/Documents/second_brain_project`) 무접촉 — 읽기 연구만, 변경 0.
- 모든 hook 변경은 fail-open 유지(자기 고장이 작업 차단 금지). `bash -n` 문법 통과 필수(verify-setup #28).
- `rev-parse --show-toplevel` 리터럴은 `_common.sh::resolve_project_root` 한 곳만(DRY).
- `resolve_project_root`는 회귀 0: plans 미발견 시 원래 cwd 반환(기존 cwd-상대 동작 보존).
- has_active_plan 계약 불변: 여전히 `<cwd>` 인자(4 호출자 무상처).
- 변경은 `global-harness-cwd-anchor` 브랜치 커밋. merge는 사용자 승인(전역 규약).

---

### Task 1: `resolve_project_root` 앵커 + `has_active_plan` 소비 (item ①, `_common.sh`)

**Files:**
- Modify: `~/.claude/hooks/_common.sh` (has_active_plan L104-121 인접에 resolve_project_root 신설 + has_active_plan 본문)

**Interfaces:**
- Produces: `resolve_project_root <cwd>` → stdout=앵커 루트(항상 0 exit). `has_active_plan <cwd>` → 계약 불변(active plan 경로 출력+return 0, 없으면 return 1).
- Consumes: 기존 `normalize_path`, `plan_status`.

- [ ] **Step 1: Write the failing test** — 서브디렉터리 cwd에서 루트 plans를 찾는지 직접 단언(temp 비-git 트리, 상위탐색 경로).

```bash
# /tmp 격리 트리: <root>/docs/superpowers/plans/p.md(active) + <root>/app/frontend
T=$(mktemp -d); mkdir -p "$T/docs/superpowers/plans" "$T/app/frontend"
printf '# p\n**Status:** active\n' > "$T/docs/superpowers/plans/p.md"
bash -c 'source "$HOME/.claude/hooks/_common.sh"; has_active_plan "$1"' _ "$T/app/frontend"; echo "exit=$?"
rm -rf "$T"
# 기대(수정 후): exit=0 (서브디렉터리 cwd에서 루트 active plan 발견). 수정 전: exit=1(FAIL).
```

- [ ] **Step 2: Run to verify it fails** — 수정 전 `exit=1`(현 cwd-상대 단일레벨이 `app/frontend/docs/...`만 보고 미발견).

- [ ] **Step 3: Implement** — `_common.sh`의 `has_active_plan` 정의(L109) **앞**에 `resolve_project_root` 추가하고, `has_active_plan` 본문 첫 줄에서 호출하도록 교체:

```bash
# --- resolve_project_root <cwd>: cwd(또는 그 상위)에서 프로젝트 루트를 앵커로 해소 (cwd-drift 봉인) ---
# enforce-rpi-cycle/bash·has_active_plan 이 공유하는 SSOT. 서브디렉터리 cwd(app/frontend 등)에서도
# 루트의 plans/specs 를 찾도록: ① git rev-parse --show-toplevel(워크트리 루트=git 루트, plans 가 거기 위치)
# ② 비-git 또는 git-루트에 plans 부재 시 docs/superpowers/plans 를 만날 때까지 상위탐색(git top 까지 bound)
# ③ 둘 다 실패 시 원래 cwd 반환(회귀 0 — 기존 cwd-상대 동작 보존). 항상 0 exit(fail-open).
resolve_project_root() {
  local cwd; cwd=$(normalize_path "${1:-.}")
  local top; top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) && top=$(normalize_path "$top") || top=""
  local d="$cwd"
  while [ -n "$d" ]; do
    [ -d "$d/docs/superpowers/plans" ] && { printf '%s' "$d"; return 0; }
    [ "$d" = "$top" ] && break          # git 루트 위로 안 나감(비-git이면 FS 루트까지)
    case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac
  done
  printf '%s' "${top:-$cwd}"
}
```

그리고 `has_active_plan` 본문에서 plan_dir 산정을 앵커 기반으로 교체:

```bash
has_active_plan() {
  local cwd="${1:-.}"
  local root; root=$(resolve_project_root "$cwd")   # cwd-drift 앵커 (서브디렉터리 cwd 수용)
  local plan_dir="$root/docs/superpowers/plans"
  [ -d "$plan_dir" ] || return 1
  local plan
  for plan in "$plan_dir"/*.md; do
    [ -f "$plan" ] || continue
    case "$(plan_status "$plan")" in
      active|in_progress) printf '%s' "$plan"; return 0 ;;
    esac
  done
  return 1
}
```

- [ ] **Step 4: Run to verify it passes** — Step 1 스니펫 재실행 → `exit=0`. 추가 회귀 단언:

```bash
# (a) plans 부재 트리 → 여전히 미발견(과개방 0):
T=$(mktemp -d); mkdir -p "$T/app"; bash -c 'source ~/.claude/hooks/_common.sh; has_active_plan "$1"' _ "$T/app"; echo "noplan exit=$? (기대 1)"; rm -rf "$T"
# (b) git 워크트리 경로 앵커(실 repo): 서브디렉터리서 git top 해소
bash -c 'source ~/.claude/hooks/_common.sh; resolve_project_root "$HOME/.claude/hooks"' ; echo " <- 기대 ~/.claude (git top)"
bash -n ~/.claude/hooks/_common.sh && echo "syntax OK"
```

- [ ] **Step 5: Commit**

```bash
cd ~/.claude && git add hooks/_common.sh
git commit -m "fix(rpi): cwd-drift 앵커 — resolve_project_root(git top→상위탐색) + has_active_plan 소비 (item①)"
```

---

### Task 2: `enforce-rpi-cycle.sh` ROOT 1회 해소 → spec·plan 양 게이트 (item ①)

**Files:**
- Modify: `~/.claude/hooks/enforce-rpi-cycle.sh` (L16 CWD 해소 직후 ROOT 추가; L22 spec 게이트; L81 PLAN_DIR; L95 has_active_plan)

**Interfaces:**
- Consumes: `resolve_project_root`(Task 1). Produces: 없음(훅 종단).

- [ ] **Step 1: Write the failing test** — 서브디렉터리 cwd + 루트 active plan에서 코드 Edit가 통과하는지(E2E 훅):

```bash
T=$(mktemp -d); mkdir -p "$T/docs/superpowers/plans" "$T/app/frontend/src"
printf '# p\n**Status:** active\n' > "$T/docs/superpowers/plans/p.md"
B=$'a\nb\nc\nd\ne\nf\ng'   # 7라인(non-trivial)
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"},"cwd":"%s"}' "$T/app/frontend/src/x.ts" "$B" "$T/app/frontend" | bash ~/.claude/hooks/enforce-rpi-cycle.sh; echo "exit=$? (기대 0)"
rm -rf "$T"
```

- [ ] **Step 2: Run to verify it fails** — 수정 전 `exit=2`(PLAN_DIR=`$T/app/frontend/docs/...` 부재 → no-plans-dir 차단). Task 1만으론 미해소(enforce-rpi-cycle은 자체 PLAN_DIR 사용).

- [ ] **Step 3: Implement** — 4개 편집:

(a) L16 직후(CWD 해소 다음 줄)에 ROOT 추가:
```bash
CWD=$(echo "$INPUT" | resolve_cwd) || { hook_log "enforce-rpi-cycle" "$FILE_PATH" "PASS" "no-cwd-failopen"; exit 0; }
ROOT=$(resolve_project_root "$CWD")   # cwd-drift 앵커: spec/plan 게이트 공유 (서브디렉터리 cwd 수용, item①)
```

(b) spec-before-plan 게이트(L22) `$CWD` → `$ROOT`:
```bash
    if [ -z "${RPI_SKIP:-}" ] && ! ls "$ROOT/docs/superpowers/specs"/*.md >/dev/null 2>&1; then
```

(c) PLAN_DIR(L81) `$CWD` → `$ROOT`:
```bash
PLAN_DIR="$ROOT/docs/superpowers/plans"
```

(d) has_active_plan 호출(L95) `$CWD` → `$ROOT`:
```bash
if ACTIVE=$(has_active_plan "$ROOT"); then
```

- [ ] **Step 4: Run to verify it passes** — Step 1 재실행 → `exit=0`. 회귀 가드:

```bash
# (a) plan 부재 서브디렉터리 → 여전히 exit 2(과개방 0):
T=$(mktemp -d); mkdir -p "$T/docs/superpowers/plans" "$T/app/frontend/src"; B=$'a\nb\nc\nd\ne\nf\ng'
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"},"cwd":"%s"}' "$T/app/frontend/src/x.ts" "$B" "$T/app/frontend" | bash ~/.claude/hooks/enforce-rpi-cycle.sh; echo "noplan exit=$? (기대 2)"; rm -rf "$T"
# (b) spec-dir 게이트 서브디렉터리: plan Write + specs 부재 → exit 2
T=$(mktemp -d); mkdir -p "$T/docs/superpowers/plans" "$T/app/frontend"; PB=$'# Plan\n**Status:** active\n- [ ] s'
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"},"cwd":"%s"}' "$T/docs/superpowers/plans/new.md" "$PB" "$T/app/frontend" | bash ~/.claude/hooks/enforce-rpi-cycle.sh; echo "nospec exit=$? (기대 2)"
mkdir -p "$T/docs/superpowers/specs"; printf '# d\n' > "$T/docs/superpowers/specs/x.md"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"},"cwd":"%s"}' "$T/docs/superpowers/plans/new.md" "$PB" "$T/app/frontend" | bash ~/.claude/hooks/enforce-rpi-cycle.sh; echo "withspec exit=$? (기대 0)"; rm -rf "$T"
bash -n ~/.claude/hooks/enforce-rpi-cycle.sh && echo "syntax OK"
# (c) 기존 hook unit 테스트 무회귀:
bash ~/.claude/hooks/tests/run-all.sh >/tmp/ra.txt 2>&1; tail -3 /tmp/ra.txt
```

- [ ] **Step 5: Commit**

```bash
cd ~/.claude && git add hooks/enforce-rpi-cycle.sh
git commit -m "fix(rpi): enforce-rpi-cycle ROOT 앵커 — spec(L22)·plan(L81)·active(L95) 게이트 동기 (item①)"
```

---

### Task 3: verify-setup.sh #31(static)·#32(exec) — item ① fitness

**Files:**
- Modify: `~/.claude/setup/verify-setup.sh` (L268 `state.json` 체크 뒤, L270 echo 앞에 #31/#32 삽입)

- [ ] **Step 1: Write the fitness (will be GREEN now that Task 1/2 done)** — 단, fitness-first 증명을 위해 먼저 #31만 임시로 `_common.sh` 백업본에 대고 RED 확인은 생략하고, Task 1/2 완료 상태에서 GREEN 단언. L268과 L270 사이에 삽입:

```bash
# 31. cwd-drift 앵커 (item①·non-obvious:152 재발3): 공유 루트해소가 git rev-parse --show-toplevel 앵커 사용 +
#     enforce-rpi-cycle 이 그 앵커(resolve_project_root)를 소비. 미이행 시 즉시 RED(앵커 부재=cwd-상대 단일레벨 회귀).
A31A=$(grep -c 'rev-parse --show-toplevel' "$HOME/.claude/hooks/_common.sh" 2>/dev/null || echo 0)
A31B=$(grep -c 'resolve_project_root' "$HOME/.claude/hooks/enforce-rpi-cycle.sh" 2>/dev/null || echo 0)
if [ "$A31A" -ge 1 ] && [ "$A31B" -ge 1 ]; then
  ok "cwd-drift 앵커: _common rev-parse($A31A) + enforce-rpi-cycle resolve_project_root($A31B)"
else
  fail "cwd-drift 앵커 미이행 (_common rev-parse=$A31A, enforce-rpi-cycle resolve_project_root=$A31B — cwd-상대 단일레벨 회귀)"
fi

# 32. cwd-drift 서브디렉터리 회귀 (item①, 실측): 임시 git repo + 루트 active plan, cwd=$repo/app/frontend 에서
#     plan-dir 게이트(코드 Edit exit0 / plan부재 exit2) + spec-dir 게이트(plan Write·spec부재 exit2 / spec존재 exit0).
T32=$(mktemp -d)
git -C "$T32" init -q 2>/dev/null; git -C "$T32" -c user.email=t@t -c user.name=t commit -q --allow-empty -m i 2>/dev/null
mkdir -p "$T32/docs/superpowers/plans" "$T32/app/frontend/src"
printf '# p\n**Status:** active\n' > "$T32/docs/superpowers/plans/p.md"
B32=$'a\nb\nc\nd\ne\nf\ng'
ev32(){ printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"},"cwd":"%s"}' "$1" "$2" "$3"; }
R32_OK=$(ev32 "$T32/app/frontend/src/x.ts" "$B32" "$T32/app/frontend" | bash "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
printf '# p\n**Status:** completed\n' > "$T32/docs/superpowers/plans/p.md"
R32_NO=$(ev32 "$T32/app/frontend/src/x.ts" "$B32" "$T32/app/frontend" | bash "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
PB32=$'# Plan\n**Status:** active\n- [ ] s'
R32_NOSPEC=$(ev32 "$T32/docs/superpowers/plans/new.md" "$PB32" "$T32/app/frontend" | bash "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
mkdir -p "$T32/docs/superpowers/specs"; printf '# d\n' > "$T32/docs/superpowers/specs/x.md"
R32_SPEC=$(ev32 "$T32/docs/superpowers/plans/new.md" "$PB32" "$T32/app/frontend" | bash "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
rm -rf "$T32"
if [ "$R32_OK" = 0 ] && [ "$R32_NO" = 2 ] && [ "$R32_NOSPEC" = 2 ] && [ "$R32_SPEC" = 0 ]; then
  ok "cwd-drift subdir 게이트: plan(0/2) + spec(2/0) — 서브디렉터리 cwd 회귀 가드"
else
  fail "cwd-drift subdir 게이트 회귀: plan-ok=$R32_OK(want0) plan-no=$R32_NO(want2) spec-no=$R32_NOSPEC(want2) spec-yes=$R32_SPEC(want0)"
fi
```

- [ ] **Step 2: Run** — `bash ~/.claude/setup/verify-setup.sh; echo "exit=$?"` → #31/#32 PASS, 전체 `FAIL=0`.

- [ ] **Step 3: (fitness-first 증명) RED 재현** — `_common.sh`의 `rev-parse --show-toplevel`를 임시 주석처리한 복제본이 #31 FAIL을 내는지 1회 확인(증명 후 원복):

```bash
cp ~/.claude/hooks/_common.sh /tmp/_cb.sh
sed 's/rev-parse --show-toplevel/rev-parse XXdisabledXX/' /tmp/_cb.sh > ~/.claude/hooks/_common.sh
bash ~/.claude/setup/verify-setup.sh 2>&1 | grep -E '#?31|cwd-drift 앵커'; 
cp /tmp/_cb.sh ~/.claude/hooks/_common.sh   # 원복
bash ~/.claude/setup/verify-setup.sh 2>&1 | grep 'cwd-drift 앵커'   # 원복 후 GREEN 재확인
```

- [ ] **Step 4: Commit**

```bash
cd ~/.claude && git add setup/verify-setup.sh
git commit -m "test(verify-setup): #31 cwd-drift 앵커 static + #32 subdir 게이트 실측 (item① fitness)"
```

---

### Task 4: item ③ 동시세션 격리 규약 (SECURITY.md + CONTEXT.md) + verify-setup #34

**Files:**
- Modify: `~/.claude/SECURITY.md` (worktree-teardown 안전모델 절 뒤에 신규 절)
- Modify: `~/.claude/CONTEXT.md` (Terms에 1항)
- Modify: `~/.claude/setup/verify-setup.sh` (#34)

- [ ] **Step 1: SECURITY.md 절 추가** — `## worktree-teardown 안전 모델` 절 **끝** 다음에:

```markdown
## 동시-세션 격리 (concurrent-session isolation)
- 단일 운영자라도 **병렬 Claude 세션**은 ambient 싱글톤을 공유한다: Playwright MCP chrome user-data-dir,
  dev 포트(`:8000`/`:5173`), dev서버 프로세스(node/esbuild/vite/uvicorn/python). 대상 repo
  `docs/ai-context/non-obvious.md`("2026-06-16 Playwright 프로필 동시점유")가 상호 차단·상호 kill 위험을 기록.
- **규약(상호 파괴 방지)**: 동시 세션은 **상대 세션의 chrome/uvicorn/vite/dev서버 프로세스를 kill 금지**.
  잠금 충돌 시 (a) 대기, 또는 (b) 세션-고유 `--isolated`/ephemeral 프로필 + 세션별 포트로 회피.
- **안전 패턴 = 경로-스코프 kill**: `worktree-teardown.sh` STEP A는 프로세스 CommandLine이 *자기* 워크트리
  절대경로를 포함할 때만 kill(타세션·메인 무영향) — 광역 이름 매칭 kill 금지의 준거.
- 강제는 hook이 아닌 규약(차단 대상 tool-콜이 모호하고 정당 kill 오살 위험) — 단일 운영자 가정의 수락 상한.
```

- [ ] **Step 2: CONTEXT.md Terms 1항 추가** — `### worktree teardown` 항목 뒤(파일 끝)에:

```markdown
### 동시-세션 격리 (concurrent-session isolation)
병렬 Claude 세션이 공유하는 ambient 싱글톤(Playwright chrome 프로필·dev 포트·dev서버 프로세스)에 대한 규약:
동시 세션은 상대 프로세스를 kill하지 않고(상호 파괴 방지) 대기 또는 isolated/ephemeral 프로필+세션별 포트로 회피.
경로-스코프 kill(worktree-teardown STEP A: 자기 워크트리 경로 매칭만)이 안전 준거. SECURITY.md에 안전모델 명시.
_Avoid_: "프로세스 정리"(광역 kill 함의), "stale-process kill"(단일세션 시간축과 혼동 — 이쪽은 다중세션 공간축).
```

- [ ] **Step 3: verify-setup #34 추가** — Task 3의 #32 뒤에:

```bash
# 34. 동시-세션 격리 규약 (item③·non-obvious:93): SECURITY.md 에 "상대 프로세스 kill 금지" 규약 실재.
if grep -q '동시-세션 격리' "$HOME/.claude/SECURITY.md" 2>/dev/null \
   && grep -q 'kill 금지' "$HOME/.claude/SECURITY.md" 2>/dev/null; then
  ok "동시-세션 격리 규약 SECURITY.md 실재 (상대 프로세스 kill 금지)"
else
  fail "동시-세션 격리 규약 SECURITY.md 부재 (item③ 미인코딩)"
fi
```

- [ ] **Step 4: Run** — `bash ~/.claude/setup/verify-setup.sh; echo exit=$?` → #34 PASS, FAIL=0.

- [ ] **Step 5: Commit**

```bash
cd ~/.claude && git add SECURITY.md CONTEXT.md setup/verify-setup.sh
git commit -m "docs(security): 동시-세션 격리 규약 인코딩 + verify-setup #34 (item③)"
```

---

### Task 5: worktree-teardown.test.sh 배선 (item ②) — verify-all STAGE 3b + verify-setup #33

**Files:**
- Modify: `~/.claude/setup/verify-all.sh` (STAGE 3 직후 STAGE 3b 삽입)
- Modify: `~/.claude/setup/verify-setup.sh` (#33)

- [ ] **Step 1: verify-all.sh STAGE 3b 추가** — `=== STAGE 3: hook unit tests ===` 블록(L39-40) 직후, `=== STAGE 4 ===`(L42) 앞에:

```bash
echo "=== STAGE 3b: worktree-teardown E2E (Windows 정션·powershell 가드) ==="
if command -v powershell >/dev/null 2>&1; then
  bash "$HOME/.claude/hooks/tests/worktree-teardown.test.sh" || { echo "FAIL worktree-teardown.test"; exit 1; }
else
  echo "[stage3b] skip — powershell 부재(비-Windows): worktree-teardown E2E는 Windows 정션 전용"
fi
echo
```

- [ ] **Step 2: verify-setup #33 추가** — Task 4의 #34 뒤에:

```bash
# 33. worktree-teardown E2E 배선 + 핵심 단언 (item②·non-obvious:211): 고아화 봉인.
#     (a) verify-all.sh 에 worktree-teardown.test.sh 배선됨 (b) 테스트가 stale-정리(마커 fallback)+정션-불변 단언 보유.
WTT="$HOME/.claude/hooks/tests/worktree-teardown.test.sh"
if grep -q 'worktree-teardown.test.sh' "$HOME/.claude/setup/verify-all.sh" 2>/dev/null \
   && grep -q '마커 fallback' "$WTT" 2>/dev/null \
   && grep -q 'junction NOT followed' "$WTT" 2>/dev/null; then
  ok "worktree-teardown E2E 배선(verify-all 3b) + Ta(마커 fallback)·T1(정션 불변) 단언 실재"
else
  fail "worktree-teardown E2E 미배선 또는 핵심 단언 부재 (item② 고아화 — verify-all 배선/Ta/T1 확인)"
fi
```

- [ ] **Step 3: Run** — verify-setup #33 GREEN + STAGE 3b 실행:

```bash
bash ~/.claude/setup/verify-setup.sh 2>&1 | grep -E 'worktree-teardown E2E|FAIL='; echo "---"
command -v powershell >/dev/null 2>&1 && bash ~/.claude/hooks/tests/worktree-teardown.test.sh 2>&1 | tail -3
```
기대: #33 PASS; worktree-teardown.test `FAIL=0`.

- [ ] **Step 4: Commit**

```bash
cd ~/.claude && git add setup/verify-all.sh setup/verify-setup.sh
git commit -m "test(verify): worktree-teardown.test.sh를 verify-all STAGE 3b로 배선 + #33 봉인 (item②)"
```

---

### Task 6: verify-all.sh 전체 PASS + Closeout

**Files:** 없음(검증·문서)

- [ ] **Step 1: 전체 acceptance 게이트** — `bash ~/.claude/setup/verify-all.sh 2>&1 | tail -20` → `ALL PASS`. 실패 시 systematic-debugging.

- [ ] **Step 2: 프로젝트 무접촉 확인** — `git -C "$HOME/.claude" status --short`에 프로젝트 경로 0. `git -C /c/Users/12132/Documents/second_brain_project status --short`가 본 세션 전후 불변(읽기만 함).

- [ ] **Step 3: review-strict drift** — Agent(review-strict)로 spec ↔ 구현 drift 검사: resolve_project_root 앵커·2게이트·배선·규약·fitness 4종이 spec 명세와 일치, 회귀 0.

- [ ] **Step 4: plan Status flip** — 본 plan을 `**Status:** completed`로(verify-setup #27 stale-active 방지 — ~/.claude active ≤1 유지).

- [ ] **Step 5: PR 생성(merge는 사용자 승인)** — `gh pr create`로 PR. 전역 규약: AI는 merge 금지.

- [ ] **Step 6: 프로젝트 세션 신호** — SendMessage(main) "글로벌트랙 완료 · 앵커 commit=<sha> · 검증커맨드". non-obvious.md ①②③ "fixed·앵커=~/.claude <sha>" 갱신 + blocked-on-global-track 해제 + 재발 카운터 동결용.

## Self-Review

- **Spec coverage**: 항목①=Task1/2/3, ②=Task5, ③=Task4, fitness #31~#34=Task3/4/5, verify-all=Task5/6. 전 spec 섹션 매핑됨.
- **Placeholder scan**: 모든 step에 실 코드/커맨드 실재. TBD 없음.
- **Type consistency**: `resolve_project_root`/`has_active_plan` 시그니처 Task1 정의 ↔ Task2/3 사용 일치. `$ROOT` 명명 일관.
