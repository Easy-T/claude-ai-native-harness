#!/usr/bin/env bash
set -uo pipefail
PASS=0
FAIL=0
fail() { echo "✗ $1"; FAIL=$((FAIL+1)); }
ok()   { echo "✓ $1"; PASS=$((PASS+1)); }

# 1. CLAUDE.md exists + ≤200 lines
L=$(wc -l < "$HOME/.claude/CLAUDE.md" 2>/dev/null || echo 9999)
[ -f "$HOME/.claude/CLAUDE.md" ] && [ "$L" -le 200 ] && ok "CLAUDE.md exists, $L lines" || fail "CLAUDE.md size $L"

# 2. 8 meta rule markers
R=$(grep -c '^## §[1-8]\.' "$HOME/.claude/CLAUDE.md" 2>/dev/null || echo 0)
[ "$R" -eq 8 ] && ok "8 meta rules present" || fail "meta rules=$R"

# 3. 3 wrapper agents
for a in explore-strict review-strict execute-strict; do
  [ -f "$HOME/.claude/agents/$a.md" ] && ok "agent: $a" || fail "agent missing: $a"
done

# 4. agents have skills:[common-agent-contract]
for a in explore-strict review-strict execute-strict; do
  grep -q 'common-agent-contract' "$HOME/.claude/agents/$a.md" 2>/dev/null && ok "$a has contract" || fail "$a missing contract"
done

# 5. agents model:opus — 실행자·검증자 frontmatter 물리 기본값 (C17 Option 1, spec §16.1 — 무지정 위임의
#    안전 기본. 회귀 시 hook 의 "무지정=opus" 평가(§16.2)가 거짓이 된다. frontmatter 블록-스코프 판별
#    (C17 §16.8 C6 — 본문 코드블록의 model: 라인 오매치 차단). 슬롯2 C1/C2 강화: 열림 구분자는 1행
#    고정 + 닫힘 구분자 필수(부재 시 유효 frontmatter 없음 = FAIL) + CRLF 내성(\r 제거 후 정확 매치).
#    explore-strict 는 #45 가 별도 봉인)
for a in review-strict execute-strict; do
  if FM5=$(awk 'NR==1{if($0!~/^---\r?$/)exit 1; next} /^---\r?$/{ok=1; exit} {sub(/\r$/,""); print} END{if(!ok) exit 1}' "$HOME/.claude/agents/$a.md" 2>/dev/null) \
     && printf '%s\n' "$FM5" | grep -q '^model: opus$'; then
    ok "$a model:opus"
  else
    fail "$a model"
  fi
done

# 6. 7 tracked global skills (grill-with-docs는 doctor가 upstream에서 auto-install → gitignore라 제외)
for s in common-agent-contract create-orchestrator-skill init-ai-ready-project start-rpi-cycle closeout-pr-cycle improve-codebase-architecture ui-design; do
  [ -f "$HOME/.claude/skills/$s/SKILL.md" ] && ok "skill: $s" || fail "skill missing: $s"
done

# 7. orchestrator marker triple (위 7개 중 common-agent-contract는 contract라 마커 없음 — opt-out, 그래서 6개 검사)
for s in create-orchestrator-skill init-ai-ready-project start-rpi-cycle closeout-pr-cycle improve-codebase-architecture ui-design; do
  f="$HOME/.claude/skills/$s/SKILL.md"
  if grep -q '^orchestrator_skill: true$' "$f" 2>/dev/null \
    && grep -q '^generated_by:' "$f" 2>/dev/null \
    && grep -q '^orchestrator_version:' "$f" 2>/dev/null; then
    ok "$s marker triple"
  else
    fail "$s missing marker triple"
  fi
done

# 8. 12 hook scripts executable
for h in enforce-orchestrator stable-claude-md auto-compact-watch enforce-rpi-cycle enforce-rpi-bash enforce-secret-scan enforce-session-budget verify-loop-watch session-start-audit surface-constitution surface-model-policy worktree-teardown; do
  [ -x "$HOME/.claude/hooks/$h.sh" ] && ok "hook: $h" || fail "hook missing or non-executable: $h"
done

# 9. _common.sh exists
[ -f "$HOME/.claude/hooks/_common.sh" ] && ok "_common.sh" || fail "_common.sh missing"

# 10. /init-ai-ready command
[ -f "$HOME/.claude/commands/init-ai-ready.md" ] && ok "command: init-ai-ready" || fail "command missing"

# 11. 13 templates + 2 references
T=$(find "$HOME/.claude/skills/init-ai-ready-project/templates/" -maxdepth 1 -type f 2>/dev/null | wc -l)
R=$(find "$HOME/.claude/skills/init-ai-ready-project/references/" -maxdepth 1 -type f 2>/dev/null | wc -l)
[ "$T" -ge 13 ] && [ "$R" -ge 2 ] && ok "templates=$T, refs=$R" || fail "templates=$T (need 13), refs=$R"
# 11b. PR lifecycle templates specifically
[ -f "$HOME/.claude/skills/init-ai-ready-project/templates/scripts-check.sh.tpl" ] \
  && ok "template: scripts-check.sh.tpl" || fail "template missing: scripts-check.sh.tpl"
[ -f "$HOME/.claude/skills/init-ai-ready-project/templates/github-ci.yml.tpl" ] \
  && ok "template: github-ci.yml.tpl" || fail "template missing: github-ci.yml.tpl"

# 11c. runbook.md.tpl has PR lifecycle sections
grep -q 'Local Quality Gate' "$HOME/.claude/skills/init-ai-ready-project/templates/runbook.md.tpl" 2>/dev/null \
  && ok "runbook.tpl: Local Quality Gate" || fail "runbook.tpl missing: Local Quality Gate"
grep -q 'Merge Policy' "$HOME/.claude/skills/init-ai-ready-project/templates/runbook.md.tpl" 2>/dev/null \
  && ok "runbook.tpl: Merge Policy" || fail "runbook.tpl missing: Merge Policy"
grep -q 'AI는 merge를 결정하지 않는다' "$HOME/.claude/skills/init-ai-ready-project/templates/runbook.md.tpl" 2>/dev/null \
  && ok "runbook.tpl: merge policy principle" || fail "runbook.tpl missing merge policy principle"

# 12. setup scripts executable
for s in doctor.sh verify-setup.sh verify-integration.sh verify-all.sh; do
  [ -x "$HOME/.claude/setup/$s" ] && ok "setup: $s" || fail "setup missing: $s"
done

# 13. .installed marker
[ -f "$HOME/.claude/setup/.installed" ] && ok ".installed marker" || fail ".installed missing"

# 14. settings.json has >=9 hook command entries (실측 12: 1 PreToolUse `*`(budget) + 5 W|E|N + 2 Bash + 1 PostToolUse + 1 SessionStart + 1 Stop + 1 SessionEnd — >=9는 하한 게이트)
COUNT=$(node -e '
  const cfg = JSON.parse(require("fs").readFileSync(process.env.HOME + "/.claude/settings.json", "utf8"));
  const all = [];
  for (const phase of Object.values(cfg.hooks||{})) for (const e of phase) for (const h of (e.hooks||[])) all.push(h.command);
  console.log(all.filter(c => /\.claude\/hooks\/.*\.sh/.test(c)).length);
' 2>/dev/null || echo 0)
[ "$COUNT" -ge 9 ] && ok "settings.json: $COUNT hooks" || fail "settings.json hooks=$COUNT"

# 15. SECURITY.md threat-model doc exists
[ -f "$HOME/.claude/SECURITY.md" ] && ok "SECURITY.md" || fail "SECURITY.md missing"

# 16. hooks/lib extracted parsers (load-bearing — hooks fail-open silently if missing)
for j in redirect-targets skeleton-scan transcript-usage model-window workflow-spawns; do
  [ -f "$HOME/.claude/hooks/lib/$j.js" ] && ok "lib: $j" || fail "hooks/lib/$j.js missing"
done

# 17. RPI phase vocabulary: CLAUDE.md §3 must name every tool start-rpi-cycle Phase R names.
#     content drift guard — skill body = SSOT, §3 asserted as superset. "§3 omits grill" 클래스 봉인.
SK17="$HOME/.claude/skills/start-rpi-cycle/SKILL.md"
PR17=$(awk '/^# Phase R/{f=1;next} /^# Phase /{f=0} f' "$SK17" 2>/dev/null)
S3_17=$(awk '/^## §3\./{f=1;next} /^## §[0-9]/{f=0} f' "$HOME/.claude/CLAUDE.md" 2>/dev/null)
if [ -z "$PR17" ] || [ -z "$S3_17" ]; then
  fail "drift-guard #17: Phase R 또는 §3 섹션 추출 실패 (헤더 변경?)"
else
  MISS17=""
  for t in grill-with-docs brainstorming explore-strict; do
    printf '%s' "$PR17" | grep -q "$t" && ! printf '%s' "$S3_17" | grep -q "$t" && MISS17="$MISS17 $t"
  done
  [ -z "$MISS17" ] && ok "§3 ↔ start-rpi-cycle Phase R tools agree" || fail "§3 omits Phase-R tool(s):$MISS17 (drift vs start-rpi-cycle)"
fi

# 18. next-cycle-goal 라벨 parity: sub-step 7(절차)와 Communication Protocol(출력 계약)이 같은 3 라벨을 열거해야.
#     둘 다 설계상 필수(계약에 라벨 없으면 report-time 표면화 약화)라 dedupe 불가 → #17 패턴의 파일-내 인스턴스로 봉인.
#     ("모든 중복 비교" generalized 프레임워크 아님 — 특정 인스턴스, grill spec이 남긴 확장 여지 내.)
SK18="$HOME/.claude/skills/start-rpi-cycle/SKILL.md"
C1_18=$(awk '/^## Step C-1/{f=1;next} /^## Sub-cycle states/{f=0} f' "$SK18" 2>/dev/null)
CP_18=$(awk '/^## Communication Protocol/{f=1} f' "$SK18" 2>/dev/null)
if [ -z "$C1_18" ] || [ -z "$CP_18" ]; then
  fail "drift-guard #18: Step C-1 또는 Communication Protocol 섹션 추출 실패 (헤더 변경?)"
else
  MISS18=""
  for t in 'goal:' 'read-before:' 'autonomy:'; do
    printf '%s' "$C1_18" | grep -q "$t" && printf '%s' "$CP_18" | grep -q "$t" || MISS18="$MISS18 $t"
  done
  [ -z "$MISS18" ] && ok "next-cycle-goal 라벨 ↔ sub-step 7/Communication Protocol parity" || fail "next-cycle-goal 라벨 drift:$MISS18 (sub-step 7 ↔ Communication Protocol 불일치)"
fi

# 19. harness-verify 필드 parity: sub-step 6(verify-setup 실행 절차)과 Communication Protocol(출력 계약)이
#     같은 'harness-verify' 토큰을 가져야. 둘 다 필수 — 계약에 토큰 없으면 verify-setup PASS가 복합 evidence에
#     접혀 cycle-14 마스킹 클래스 재발(F1/F6) → dedupe 불가 → #18 패턴의 파일-내 인스턴스로 봉인.
SK19="$HOME/.claude/skills/start-rpi-cycle/SKILL.md"
C1_19=$(awk '/^## Step C-1/{f=1;next} /^## Sub-cycle states/{f=0} f' "$SK19" 2>/dev/null)
CP_19=$(awk '/^## Communication Protocol/{f=1} f' "$SK19" 2>/dev/null)
if [ -z "$C1_19" ] || [ -z "$CP_19" ]; then
  fail "drift-guard #19: Step C-1 또는 Communication Protocol 섹션 추출 실패 (헤더 변경?)"
else
  if printf '%s' "$C1_19" | grep -q 'harness-verify' && printf '%s' "$CP_19" | grep -q 'harness-verify'; then
    ok "harness-verify 필드 ↔ sub-step 6/Communication Protocol parity"
  else
    fail "harness-verify 필드 drift (sub-step 6 ↔ Communication Protocol 불일치)"
  fi
fi

# 20. cases.tsv 실측 == README 선언 카운트 (재드리프트 봉인). README 가 cases.tsv 를 언급한 줄의
#     '<N> 케이스/case' 숫자가 실측과 다르면 FAIL. (historical "원안 65개"는 케이스/case 미동반이라 비매칭.)
ACT_CASES=$(grep -vcE '^[[:space:]]*(#|$)' "$HOME/.claude/hooks/tests/cases.tsv")
BAD20=$(grep -E 'cases\.tsv' "$HOME/.claude/README.md" 2>/dev/null \
        | grep -oE '[0-9]+ ?(케이스|cases?)' | grep -oE '^[0-9]+' | grep -vx "$ACT_CASES" | head -1)
[ -z "$BAD20" ] && ok "README cases 카운트 == 실측($ACT_CASES)" || fail "README cases drift: 선언 $BAD20 ≠ 실측 $ACT_CASES"

# 21. verify-integration E2E 실측 == README 선언 카운트.
ACT_E2E=$(grep -cE 'ok "E2E\.' "$HOME/.claude/setup/verify-integration.sh")
BAD21=$(grep -oE '[0-9]+개 E2E' "$HOME/.claude/README.md" 2>/dev/null | grep -oE '^[0-9]+' | grep -vx "$ACT_E2E" | head -1)
[ -z "$BAD21" ] && ok "README E2E 카운트 == 실측($ACT_E2E)" || fail "README E2E drift: 선언 $BAD21 ≠ 실측 $ACT_E2E"

# 22. phase-skills 필드 parity: Step C-1(sub-step 8) ↔ Communication Protocol 두 곳 'phase-skills' 토큰 필연 중복 (#18/#19 인스턴스).
SK22="$HOME/.claude/skills/start-rpi-cycle/SKILL.md"
C1_22=$(awk '/^## Step C-1/{f=1;next} /^## Sub-cycle states/{f=0} f' "$SK22" 2>/dev/null)
CP_22=$(awk '/^## Communication Protocol/{f=1} f' "$SK22" 2>/dev/null)
if [ -z "$C1_22" ] || [ -z "$CP_22" ]; then
  fail "drift-guard #22: Step C-1 또는 Communication Protocol 섹션 추출 실패"
elif printf '%s' "$C1_22" | grep -q 'phase-skills' && printf '%s' "$CP_22" | grep -q 'phase-skills'; then
  ok "phase-skills 필드 ↔ Step C-1/Communication Protocol parity"
else
  fail "phase-skills 필드 drift (Step C-1 ↔ Communication Protocol 불일치)"
fi

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
HA=$(sj_hooks "$HOME/.claude/settings.json")
HB=$(sj_hooks "$HOME/.claude/settings.example.json")
if [ -z "$HB" ]; then
  fail "settings.example.json hook 추출 실패"
elif [ "$HA" = "$HB" ]; then
  ok "settings.json ↔ example harness-hook matcher parity"
else
  fail "settings/example harness-hook drift (phase/matcher/이름 불일치)"
fi

# 24. doctor REQUIRED_HOOKS 가 디스크의 모든 hooks/*.sh 를 커버하는가 (F4b 재발 방지; disk=SSOT, _common 제외).
DISK_H=$(for f in "$HOME/.claude/hooks/"*.sh; do basename "$f" .sh; done | grep -v '^_common$' | sort -u)
DOC_H=$(awk '/REQUIRED_HOOKS=\(/{f=1;next} /^\)/{f=0} f' "$HOME/.claude/setup/doctor.sh" 2>/dev/null \
        | grep -oE '[a-z_-]+\.sh' | sed 's/\.sh$//' | grep -v '^_common$' | sort -u)
MISS24=$(comm -23 <(printf '%s\n' "$DISK_H") <(printf '%s\n' "$DOC_H"))
[ -z "$MISS24" ] && ok "doctor REQUIRED_HOOKS ⊇ hooks/*.sh" || fail "doctor REQUIRED_HOOKS omits:$(printf ' %s' $MISS24)"

# 25. verify-integration.sh per-run 격리 봉인 (cycle-18 회귀 방지): 메인 TEST_DIR이
#     mktemp -d로 할당 + 고정 $HOME 경로 미사용. 서브픽스처(BAD_SKILL=/FRESH_F=/VL=)는
#     ^TEST_DIR= 앵커로 비매칭 → 메인 격리만 단언. (#17/#19/#22 content-drift 패턴 + 부정 단언.)
VI="$HOME/.claude/setup/verify-integration.sh"
if grep -qE '^TEST_DIR=\$\(mktemp -d\)' "$VI" 2>/dev/null \
   && ! grep -qE '^TEST_DIR=.*\$HOME' "$VI" 2>/dev/null; then
  ok "verify-integration TEST_DIR mktemp-isolated (고정 \$HOME 없음)"
else
  fail "verify-integration TEST_DIR 격리 drift (mktemp 부재 또는 고정 \$HOME 복원 — cycle-18 회귀)"
fi

# 27. plan lifecycle 봉인 (D-LIFECYCLE, cycle-23): 모든 plans/*.md 명시 Status 보유 + active ≤ 1.
#     Closeout step-2(Status flip) silent-skip이 게이트를 영구 개방하던 stale-active 재발 방지.
#     (#26은 미채택·번호 소각 — spec-count parity, 안정 앵커 부재.)
NOSTAT27=""; ACT27=0
for p27 in "$HOME/.claude/docs/superpowers/plans"/*.md; do
  [ -f "$p27" ] || continue
  ST27=$(head -20 "$p27" | grep -m1 -iE '^\*?\*?status:?\*?\*?' \
    | sed -E 's/^\*?\*?[Ss]tatus:?\*?\*?[[:space:]]*//' | awk '{print tolower($1)}' | tr -d '*')
  [ -z "$ST27" ] && NOSTAT27="$NOSTAT27 $(basename "$p27")"
  case "$ST27" in active|in_progress) ACT27=$((ACT27+1)) ;; esac
done
if [ -z "$NOSTAT27" ] && [ "$ACT27" -le 1 ]; then
  ok "plan lifecycle: 전 plan 명시 Status + active=$ACT27 (≤1)"
else
  fail "plan lifecycle drift: Status 없는 plan:${NOSTAT27:-없음} / active=$ACT27 (stale-active 의심 — Closeout step-2 누락?)"
fi

# 28. hooks/*.sh + setup/*.sh bash -n 문법 (fail-open 무표면 방지, D-FAILOPEN-SURFACE cycle-23)
SYN28=""
for f28 in "$HOME/.claude/hooks/"*.sh "$HOME/.claude/setup/"*.sh; do
  bash -n "$f28" 2>/dev/null || SYN28="$SYN28 $(basename "$f28")"
done
[ -z "$SYN28" ] && ok "bash -n: hooks+setup 문법 OK" || fail "bash -n 실패:$SYN28"

# 29. install.sh REQUIRED ⊇ verify-setup item-6 7 tracked skill (신선-클론 install이 광고한 게이트를
#     스스로 검증 — 누락 skill이 install PASS인데 verify-all FAIL 나던 drift 봉인, cycle-27 NEW-install-required-skills).
INSTALL29="$HOME/.claude/setup/install.sh"
MISS29=""
for s29 in common-agent-contract create-orchestrator-skill init-ai-ready-project start-rpi-cycle closeout-pr-cycle improve-codebase-architecture ui-design; do
  grep -qF "skills/$s29/SKILL.md" "$INSTALL29" 2>/dev/null || MISS29="$MISS29 $s29"
done
[ -z "$MISS29" ] && ok "install.sh REQUIRED ⊇ 7 tracked skills" || fail "install.sh REQUIRED skill 누락:$MISS29 (verify-setup item6와 drift)"

# 30. state.json ↔ state.schema.json 검증 (dead-spec 활성화 — closeout이 쓴 state 무결성, cycle-28 NEW-state-schema-unverified).
#     스키마-구동: 스키마 파일을 읽어 사용된 draft-07 부분집합(required/type/minimum/format:date)으로 재귀 검사 → 스키마 변경 자동 추종.
#     C19 슬롯2 M1: node 오라클 crash(예: state.json 이 JSON primitive "x" — 'in' 연산자 TypeError)가
#     2>/dev/null+빈 ERR30 으로 false-green 되던 창을 rc-캡처로 봉인. ${ERR30:-} 라 정상 오류 문안은 보존.
ERR30=$(SCHEMA="$HOME/.claude/state.schema.json" DATA="$HOME/.claude/state.json" node -e '
  const fs=require("fs");
  let sc,d;
  try{ sc=JSON.parse(fs.readFileSync(process.env.SCHEMA,"utf8")); }catch(e){ process.stdout.write("schema 파싱 실패"); process.exit(0); }
  try{ d=JSON.parse(fs.readFileSync(process.env.DATA,"utf8")); }catch(e){ process.stdout.write("state.json 파싱 실패"); process.exit(0); }
  const errs=[], isDate=s=>/^\d{4}-\d{2}-\d{2}$/.test(s);
  (function chk(schema,val,path){
    if(schema.required) for(const k of schema.required) if(!val||!(k in val)) errs.push(path+"."+k+" 누락(required)");
    if(schema.properties&&val&&typeof val==="object") for(const [k,ps] of Object.entries(schema.properties)){
      if(!(k in val)) continue; const v=val[k], p=path+"."+k;
      if(ps.type==="integer"&&!Number.isInteger(v)) errs.push(p+" 정수 아님");
      else if(ps.type==="string"&&typeof v!=="string") errs.push(p+" 문자열 아님");
      else if(ps.type==="boolean"&&typeof v!=="boolean") errs.push(p+" 불리언 아님");
      else if(ps.type==="object"){ if(typeof v!=="object"||v===null) errs.push(p+" 객체 아님"); else chk(ps,v,p); }
      if(ps.type==="integer"&&typeof ps.minimum==="number"&&v<ps.minimum) errs.push(p+" < minimum "+ps.minimum);
      if(ps.format==="date"&&typeof v==="string"&&!isDate(v)) errs.push(p+" 날짜형식(YYYY-MM-DD) 아님");
    }
  })(sc,d,"state");
  process.stdout.write(errs.join("; "));
' 2>/dev/null) || ERR30="${ERR30:-validator crash(rc=$?) — state.json 비객체 등 스크립트 예외를 FAIL 로 표면화(C19 슬롯2 M1)}"
#     C19 §18.2 #13·G5: 이 검사는 **스키마-구동**이라 스키마가 비면 검사도 빈다 — required-배열 **내용** 앵커
#     conjunct 를 같은 ok/fail 에 결합해 오라클 침묵을 봉인한다(변이 M22). 리터럴 존재-검사 3종은
#     '"required": []' 값-약화가 우회(G5 실증 — cycle/count 는 properties 이름으로 잔존)라 배열 내용을 앵커한다.
#     새 ok/fail 을 만들지 않으므로 카운트 불변.
SCH30="$HOME/.claude/state.schema.json"
SCHEMA30_OK=1
grep -qE '"required":[[:space:]]*\[[^]]*"cycle"' "$SCH30" 2>/dev/null || SCHEMA30_OK=0
grep -qE '"required":[[:space:]]*\[[^]]*"count"' "$SCH30" 2>/dev/null || SCHEMA30_OK=0
if [ -z "$ERR30" ] && [ "$SCHEMA30_OK" -eq 1 ]; then ok "state.json ↔ schema 검증"; else fail "state.json schema 위반: ${ERR30:-required-배열 앵커 결손(cycle·count — C19 #13)}"; fi

# 31. cwd-drift 앵커 (item①·non-obvious:152 재발3): 공유 루트해소가 git rev-parse --show-toplevel 앵커 사용 +
#     enforce-rpi-cycle 이 그 앵커(resolve_project_root)를 소비. 미이행 시 즉시 RED(cwd-상대 단일레벨 회귀).
A31A=$(grep -c 'rev-parse --show-toplevel' "$HOME/.claude/hooks/_common.sh" 2>/dev/null || echo 0)
A31B=$(grep -c 'resolve_project_root' "$HOME/.claude/hooks/enforce-rpi-cycle.sh" 2>/dev/null || echo 0)
if [ "$A31A" -ge 1 ] && [ "$A31B" -ge 1 ]; then
  ok "cwd-drift 앵커: _common rev-parse($A31A) + enforce-rpi-cycle resolve_project_root($A31B)"
else
  fail "cwd-drift 앵커 미이행 (_common rev-parse=$A31A, enforce-rpi-cycle resolve_project_root=$A31B — cwd-상대 단일레벨 회귀)"
fi

# 32. cwd-drift 서브디렉터리 회귀 (item①, 실측): 임시 git repo + 루트 active plan, cwd=$repo/app/frontend 에서
#     plan-dir 게이트(코드 Write exit0 / plan부재 exit2) + spec-dir 게이트(plan Write·spec부재 exit2 / spec존재 exit0).
#     주: JSON content 는 node JSON.stringify 로 이스케이프(printf+리터럴 개행=무효 JSON→no-cwd-failopen 위양성 회피).
T32=$(mktemp -d)
git -C "$T32" init -q 2>/dev/null
git -C "$T32" -c user.email=t@t -c user.name=t commit -q --allow-empty -m i 2>/dev/null
mkdir -p "$T32/docs/superpowers/plans" "$T32/app/frontend/src"
printf '# p\n**Status:** active\n' > "$T32/docs/superpowers/plans/p.md"
ev32(){ FP="$1" CT="$2" CW="$3" node -e 'console.log(JSON.stringify({tool_name:"Write",tool_input:{file_path:process.env.FP,content:process.env.CT},cwd:process.env.CW}))'; }
B32=$'a\nb\nc\nd\ne\nf\ng'
R32_OK=$(ev32 "$T32/app/frontend/src/x.ts" "$B32" "$T32/app/frontend" | bash "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
printf '# p\n**Status:** completed\n' > "$T32/docs/superpowers/plans/p.md"
R32_NO=$(ev32 "$T32/app/frontend/src/x.ts" "$B32" "$T32/app/frontend" | bash "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
printf '# p\n**Status:** active\n' > "$T32/docs/superpowers/plans/p.md"
PB32=$'# Plan\n**Status:** active\n- [ ] s'
R32_NOSPEC=$(ev32 "$T32/docs/superpowers/plans/new.md" "$PB32" "$T32/app/frontend" | bash "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
mkdir -p "$T32/docs/superpowers/specs"; printf '# d\n' > "$T32/docs/superpowers/specs/x.md"
R32_SPEC=$(ev32 "$T32/docs/superpowers/plans/new.md" "$PB32" "$T32/app/frontend" | bash "$HOME/.claude/hooks/enforce-rpi-cycle.sh" >/dev/null 2>&1; echo $?)
rm -rf "$T32"
if [ "$R32_OK" = 0 ] && [ "$R32_NO" = 2 ] && [ "$R32_NOSPEC" = 2 ] && [ "$R32_SPEC" = 0 ]; then
  ok "cwd-drift subdir 게이트: plan(0/2)+spec(2/0) — 서브디렉터리 cwd 회귀 가드"
else
  fail "cwd-drift subdir 게이트 회귀: plan-ok=$R32_OK(want0) plan-no=$R32_NO(want2) spec-no=$R32_NOSPEC(want2) spec-yes=$R32_SPEC(want0)"
fi

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

# 34. 동시-세션 격리 규약 (item③·non-obvious:93): SECURITY.md 에 "상대 프로세스 kill 금지" 규약 실재.
if grep -q '동시-세션 격리' "$HOME/.claude/SECURITY.md" 2>/dev/null \
   && grep -q 'kill 금지' "$HOME/.claude/SECURITY.md" 2>/dev/null; then
  ok "동시-세션 격리 규약 SECURITY.md 실재 (상대 프로세스 kill 금지)"
else
  fail "동시-세션 격리 규약 SECURITY.md 부재 (item③ 미인코딩)"
fi

# 35. Best-Direction Mandate 토큰 parity (GAP-001, #17 동형): start-rpi-cycle 본문에
#     Phase P 필수 필드 'Best-Direction Check'(Phase P + Gate P = >=2)와 'DOWNGRADE-DECLARED'(>=1) 실재.
SRC_SKILL="$HOME/.claude/skills/start-rpi-cycle/SKILL.md"
BD_CNT=$(grep -c 'Best-Direction Check' "$SRC_SKILL" 2>/dev/null || true)
DG_CNT=$(grep -c 'DOWNGRADE-DECLARED' "$SRC_SKILL" 2>/dev/null || true)
if [ "${BD_CNT:-0}" -ge 2 ] && [ "${DG_CNT:-0}" -ge 1 ]; then
  ok "Best-Direction Mandate 토큰: start-rpi-cycle 'Best-Direction Check' x${BD_CNT}(>=2) + 'DOWNGRADE-DECLARED' x${DG_CNT}(>=1)"
else
  fail "Best-Direction Mandate 토큰 부재/부족 (GAP-001): 'Best-Direction Check' x${BD_CNT:-0}(<2) 또는 'DOWNGRADE-DECLARED' x${DG_CNT:-0}(<1) — skills/start-rpi-cycle/SKILL.md"
fi

# 37. scaffold-registry ⊇ live hook/skill parity (GAP-005 C4, 노화 방지 트리거): registry 존재 +
#     모든 live hook(−_common) basename·모든 live skill dir 이 registry 에 등재. 신규 구성요소를
#     registry 에 안 적으면 FAIL — 무한 누적만 하던 스캐폴드에 제거-리뷰 앵커. (#36 앞에 배치 = 총계 포함.)
REG="$HOME/.claude/docs/ai-context/scaffold-registry.md"
if [ ! -f "$REG" ]; then
  fail "scaffold-registry 부재 (GAP-005): docs/ai-context/scaffold-registry.md 생성 필요"
else
  REG_MISS=""
  for _hf in "$HOME/.claude/hooks"/*.sh; do
    _hb=$(basename "$_hf"); [ "$_hb" = "_common.sh" ] && continue
    grep -qF "$_hb" "$REG" 2>/dev/null || REG_MISS="$REG_MISS $_hb"
  done
  for _sk in "$HOME/.claude/skills"/*/; do
    [ -d "$_sk" ] || continue
    _sb=$(basename "$_sk")
    grep -qF "$_sb" "$REG" 2>/dev/null || REG_MISS="$REG_MISS $_sb"
  done
  if [ -z "$REG_MISS" ]; then
    ok "scaffold-registry ⊇ live hook/skill (노화 registry 최신)"
  else
    fail "scaffold-registry 미등재 (GAP-005 — registry 갱신 필요):$REG_MISS"
  fi
fi

# 38. memory-policy.md 존재 + 통합/프루닝/검증 3규약 (GAP-004 D6 L3): 메모리 수명주기 규약이 사라지면 FAIL
#     (문서화된 거버넌스 사실 drift 봉인 — #37 registry 동형). seal-regression 이 docs/ai-context 스테이징(C4)→자동 커버.
MPOL="$HOME/.claude/docs/ai-context/memory-policy.md"
if [ ! -f "$MPOL" ]; then
  fail "memory-policy 부재 (GAP-004): docs/ai-context/memory-policy.md 생성 필요"
elif grep -qE '통합|Consolidation' "$MPOL" && grep -qE '프루닝|Pruning' "$MPOL" && grep -qE '검증|Verification' "$MPOL"; then
  ok "memory-policy 3규약(통합/프루닝/검증) 존재"
else
  fail "memory-policy 3규약 불완전 (GAP-004): 통합/프루닝/검증 중 누락"
fi

# 39. settings.example autocompact 트리거 rot-정렬 (GAP-018 D3 L4 + C11 세트 확장): PCT_OVERRIDE ≤40 **AND**
#     CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000 세트. 2026-07-25 회귀 근본원인=WIN 라인 소실 시 PCT 단독 완전 inert
#     (한쪽만은 침묵 무효 — memory project_autocompact_proxy_display). WINDOW=1M 전제([1m] suffix).
EX_PCT=$(grep -oE '"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE"[[:space:]]*:[[:space:]]*"?[0-9]+"?' "$HOME/.claude/settings.example.json" 2>/dev/null | grep -oE '[0-9]+' | head -1)
EX_WIN=$(grep -cE '"CLAUDE_CODE_AUTO_COMPACT_WINDOW"[[:space:]]*:[[:space:]]*"1000000"' "$HOME/.claude/settings.example.json" 2>/dev/null)
if [ -z "$EX_PCT" ]; then
  fail "settings.example CLAUDE_AUTOCOMPACT_PCT_OVERRIDE 부재 (GAP-018)"
elif [ "$EX_PCT" -le 40 ] 2>/dev/null && [ "$EX_WIN" -ge 1 ]; then
  ok "settings.example autocompact PCT(${EX_PCT})≤40 + WINDOW=1000000 세트 (GAP-018+C11)"
else
  fail "settings.example autocompact 세트 붕괴 (GAP-018+C11): PCT≤40 AND WINDOW=1000000 필요 (PCT=${EX_PCT:-부재} WIN라인=${EX_WIN:-0}) — 한쪽만은 완전 inert"
fi

# 40. plugin-pins.md 존재 + SKILL.md cksum 핀 (GAP-011 D11 L4 절반): 공급망 핀이 사라지면 FAIL.
#     rug-pull 방어 앵커(session-start-audit 드리프트 검사가 이 cksum 을 소비). bash grep(#38/#39 동형, staged-safe).
PINS="$HOME/.claude/docs/ai-context/plugin-pins.md"
if [ ! -f "$PINS" ]; then
  fail "plugin-pins 부재 (GAP-011): docs/ai-context/plugin-pins.md 생성 필요"
elif grep -qE 'skill-cksum:[[:space:]]*[0-9]+' "$PINS"; then
  ok "plugin-pins SKILL.md cksum 핀 존재"
else
  fail "plugin-pins cksum 핀 부재 (GAP-011): skill-cksum: <N> 라인 필요"
fi

# 41. explore-strict(웹-읽기 reader) 쓰기도구 미부여 = Rule-of-Two 봉인 (GAP-013 D11 L4):
#     lethal trifecta(untrusted 웹+시크릿+쓰기) 구조분리 — reader tools 에 Write/Edit/Bash/NotebookEdit 부여 시 FAIL. bash grep(staged-safe).
ES_TOOLS=$(grep -E '^tools:' "$HOME/.claude/agents/explore-strict.md" 2>/dev/null | head -1)
if [ -z "$ES_TOOLS" ]; then
  fail "explore-strict tools 라인 부재 (GAP-013)"
elif echo "$ES_TOOLS" | grep -qE '\bWebFetch\b' && ! echo "$ES_TOOLS" | grep -qE '\b(Write|Edit|NotebookEdit|Bash)\b'; then
  ok "explore-strict reader 쓰기도구 미부여 (Rule-of-Two)"
else
  fail "explore-strict Rule-of-Two 위반 (GAP-013): reader tools 에 쓰기도구 부여 또는 WebFetch 부재 — lethal trifecta 표면"
fi

# 42. settings.example deny 최후방어선 존재 (GAP-007a D11 L4): 자격증명 read·파괴명령 deny 규칙이 사라지면 FAIL.
#     bypassPermissions 에서도 유효한 층(02 §4). bash grep(staged-safe).
EX_SET="$HOME/.claude/settings.example.json"
if [ ! -f "$EX_SET" ]; then
  fail "settings.example.json 부재 (GAP-007a)"
elif grep -qE '"deny"' "$EX_SET" && grep -qE 'credentials|\.env|id_rsa' "$EX_SET" && grep -qE 'rm -rf' "$EX_SET"; then
  ok "settings.example deny 최후방어선(자격증명·파괴명령) 존재"
else
  fail "settings.example deny 최후방어선 부재 (GAP-007a): permissions.deny 에 자격증명 read·파괴명령 규칙 필요"
fi

# 43. opencode 미러 byte-sync (v3 — design.md 콘텐츠 무검사 봉인): 미러 design.md가 정본과 byte-동일.
#     미러 부재(fresh-clone/설치본) 시 vacuous-PASS로 카운트 결정성 보존, 존재+상이 시 FAIL(편도 편집 차단).
#     #23 two-file parity 계열. design.md 편집 시 양 미러 동시 갱신 강제.
SRC43="$HOME/.claude/skills/ui-design/design.md"
MIR43="$HOME/.claude/opencode-harness/skill/ui-design/design.md"
if [ ! -f "$MIR43" ]; then
  ok "opencode 미러 부재 — design.md byte-sync N/A (vacuous PASS)"
elif [ ! -f "$SRC43" ]; then
  fail "정본 design.md 부재 ($SRC43)"
elif cmp -s "$SRC43" "$MIR43"; then
  ok "opencode 미러 design.md byte-sync"
else
  fail "opencode 미러 design.md drift (정본과 상이 — 양 미러 동시 갱신 필요)"
fi

# 44. §6 anti-slop floor 카운트 봉인 (v3 — §0.1/§6.2 "삭제 절대 금지" 강제): §6 스코프(# 6.~# 7.)의
#     '- [ ]' 체크박스가 정확히 18. floor 가감은 seal 동반 갱신 = 의도적 governance(tripwire). §6 밖
#     편집(evidence 인용·§9~§15 문구)엔 불감(awk 섹션 스코프).
DESIGN44="$HOME/.claude/skills/ui-design/design.md"
FLOOR44=$(awk '/^# 6\./{f=1;next} /^# 7\./{f=0} f' "$DESIGN44" 2>/dev/null | grep -cE '^- \[ \]')
if [ "$FLOOR44" -eq 18 ]; then
  ok "design.md §6 anti-slop floor = 18 항목"
else
  fail "design.md §6 floor 카운트 drift: $FLOOR44 (기대 18 — §6.2 '삭제 절대 금지' 위반?)"
fi

# 45. 역할×모델 매트릭스 물화 봉인 (tri-model C11, spec 2026-07-25 §6): conjunctive —
#     ① model-policy.md 존재+행 앵커(execute→opus·explore→sonnet) ② explore-strict frontmatter sonnet+xhigh+WebSearch (C13)
#     ③ execute/review `model: opus`(C17 Option 1 물리 기본값) + review-strict effort 키 부재
#        (무지정 위임의 안전 기본 앵커. 토큰-존재 상한 수용 — §16.4-3: frontmatter 블록-스코프 판별은 #5 가 담당)
#     ④ settings.example 에 Agent 매처+hook 배선(#23 이 live 와 parity) ⑤ start-rpi-cycle 토큰(재생성 소실 표면화).
#     C12: canonical workflow(rpi-implement.js 앵커)+Workflow 매처 conjunct 확장 (spec §10).
#     bash grep only (staged-safe).
MP_DOC="$HOME/.claude/docs/ai-context/model-policy.md"
MP_OK=1
#     C19 §18.2 #14·G4: conjunct ① 앵커를 **열-스코프**로 구체화 — 광역 grep 은 'execute-strict.*opus' 6행
#     (:16/:17/:21/:29/:30/:37)·'explore-strict.*sonnet' 3행(:18/:31/:37)에 매칭해 표적 행 삭제에도 GREEN 이었고,
#     행-선두만으로는 비고 셀의 opus 리터럴이 모델-셀 변조(opus→sonnet)를 가렸다(슬롯1 G4 실증). 변이 M21 이 RED 실증.
{ [ -f "$MP_DOC" ] && grep -qE '^\| 구현 heavy [^|]*\| *execute-strict *\| *\*\*opus\*\*' "$MP_DOC" && grep -qE '^\| 탐색 [^|]*\| *explore-strict *\| *\*\*sonnet\*\*' "$MP_DOC"; } || MP_OK=0
grep -qE '^model:[[:space:]]*sonnet' "$HOME/.claude/agents/explore-strict.md" 2>/dev/null || MP_OK=0
grep -qE '^effort:[[:space:]]*xhigh' "$HOME/.claude/agents/explore-strict.md" 2>/dev/null || MP_OK=0
grep -qE '^tools:.*WebSearch' "$HOME/.claude/agents/explore-strict.md" 2>/dev/null || MP_OK=0
grep -qE '^model:[[:space:]]*opus[[:space:]]*\r?$' "$HOME/.claude/agents/execute-strict.md" 2>/dev/null || MP_OK=0
grep -qE '^model:[[:space:]]*opus[[:space:]]*\r?$' "$HOME/.claude/agents/review-strict.md" 2>/dev/null || MP_OK=0
if grep -qE '^effort:' "$HOME/.claude/agents/review-strict.md" 2>/dev/null; then MP_OK=0; fi
grep -q 'surface-model-policy' "$HOME/.claude/settings.example.json" 2>/dev/null || MP_OK=0
grep -A2 "agentType: 'execute-strict'," "$HOME/.claude/workflows/rpi-implement.js" 2>/dev/null | grep -qE "model: 'opus'" || MP_OK=0
grep -A2 "agentType: 'review-strict'," "$HOME/.claude/workflows/rpi-implement.js" 2>/dev/null | grep -qE "model: 'opus'" || MP_OK=0
grep -qE "effort: t\.effort \?\? \(t\.heavy \? 'xhigh' : 'high'\)" "$HOME/.claude/workflows/rpi-implement.js" 2>/dev/null || MP_OK=0
grep -qE '"matcher":[[:space:]]*"Agent\|Workflow"' "$HOME/.claude/settings.example.json" 2>/dev/null || MP_OK=0
grep -q 'model-policy' "$HOME/.claude/skills/start-rpi-cycle/SKILL.md" 2>/dev/null || MP_OK=0
if [ "$MP_OK" -eq 1 ]; then
  ok "역할×모델 매트릭스 물화 (model-policy.md·frontmatter·Agent 매처·skill 토큰)"
else
  fail "역할×모델 매트릭스 봉인 붕괴 (C11): model-policy.md 앵커/explore frontmatter/opus 기본값/review effort 부재/Agent 매처/skill 토큰 중 결손 — spec §6"
fi

# 46. hooks/lib/*.js 매니페스트 자동 봉인 (C14-A, spec §13.8): 디스크가 SSOT.
#     로드-베어링 파서가 매니페스트에서 빠지면 부재해도 침묵 통과한다 — M1(doctor 21b)·M7(witness)이
#     그 실증(C13 신규 workflow-spawns.js 가 4곳 중 2곳에서 누락). seal #24(doctor⊇hooks/*.sh) 동형
#     확장 — 하드코딩 목록이 아니라 디스크와 대조하므로 다음 lib 신설 때 자동 발화한다. bash 파일옵스만.
DISK_LIB=$(for f in "$HOME/.claude/hooks/lib/"*.js; do basename "$f" .js; done | sort -u)
#     ★C14 GPT 교차리뷰 정정: 파일 **전문** grep 은 주석이 매니페스트를 가린다(이 블록의 설명 주석에도
#     'workflow-spawns' 가 있어, 실제 목록에서 지워도 통과했다). 주석·설명을 제거한 **실효 라인**에서만 찾는다.
lib_missing_in() {  # $1=파일 경로 — 그 파일의 비-주석 텍스트에 없는 lib 이름을 출력
  local hay; hay=$(sed -e 's/#.*$//' -e 's|//.*$||' "$1" 2>/dev/null)
  local n; for n in $DISK_LIB; do case "$hay" in *"$n"*) ;; *) printf '%s ' "$n" ;; esac; done
}
MISS46=""
for mf in setup/doctor.sh setup/verify-setup.sh setup/install.sh setup/tests/failopen-surface.test.sh; do
  m=$(lib_missing_in "$HOME/.claude/$mf")
  [ -n "$m" ] && MISS46="$MISS46 $mf:[$m]"
done
if [ -z "$MISS46" ]; then
  ok "hooks/lib 매니페스트 봉인: 디스크 $(printf '%s\n' $DISK_LIB | wc -l | tr -d ' ')종이 doctor·verify-setup·install·witness 전부에 등재"
else
  fail "hooks/lib 매니페스트 drift (C14-A): 누락 —$MISS46. 디스크가 SSOT — 신규 파서는 4곳 모두에 등재해야 함(spec §13.8)"
fi

# 47. Rule C3 제외목록 봉인 (C14-D, spec §13.3 ①축): agents/*.md 에서 model 을 **선언**하는(=inherit 이
#     아닌) wrapper 는 세션을 상속하지 않으므로 C3 대상이 아니다 — 그 이름이 hook 의 제외 목록에
#     포함되어야 한다(⊆ 방향; 등호 아님 — execute/review-strict 는 Rule C·C2 전담이라는 설계 결정이고
#     '*' 는 동적 판정이라 디스크 대응물이 없다). 새 wrapper 가 하위 모델을 선언하며 추가될 때
#     hook 갱신 누락을 발화한다. bash 파일옵스만.
MISS47=""
for af in "$HOME/.claude/agents/"*.md; do
  an=$(basename "$af" .md)
  am=$(grep -m1 -E '^model:' "$af" 2>/dev/null | sed -E 's/^model:[[:space:]]*//' | tr -d '\r')
  { [ -n "$am" ] && [ "$am" != "inherit" ]; } || continue
  # ★C14 GPT 교차리뷰 정정: 전문 grep 은 hook 의 설명 주석이 제외목록을 가린다(주석에도 explore-strict 가
  # 있어 실제 case arm 에서 지워도 통과했다). **실효 case arm** 에서만 찾는다.
  grep -qE "^[[:space:]]*[a-z|'*-]*${an}[a-z|'*-]*\)[[:space:]]*;;" "$HOME/.claude/hooks/surface-model-policy.sh" 2>/dev/null || MISS47="$MISS47 $an"
done
if [ -z "$MISS47" ]; then
  ok "Rule C3 제외목록 봉인: model 선언 wrapper 가 hook 제외 목록에 등재됨"
else
  fail "Rule C3 제외목록 drift (C14-D): hook 미등재 —$MISS47. model 을 선언하는 wrapper 는 세션 상속이 아니므로 C3 제외 목록에 추가해야 함(spec §13.3)"
fi

# 48. skill context_paths 조건부 선언 봉인 (C14-J, spec §13.8): 부재가 정상인 스캐폴드 산출물 경로를
#     지시하는 skill 은 "실재하는 것만 전달" 선언을 동반해야 한다. 경로 실재를 요구하지 않는다 —
#     그러면 대상-프로젝트 겸용 skill 이 깨진다(§13.4). 지시와 선언의 **동반**만 검사한다.
#     RED 재현자: 선언 문구를 지우면 발화(seal-regression mut_skill_conditional).
MISS48=""
for sk in start-rpi-cycle closeout-pr-cycle improve-codebase-architecture; do
  sf="$HOME/.claude/skills/$sk/SKILL.md"
  [ -f "$sf" ] || continue
  grep -qE 'docs/ai-context/(architecture|domain-glossary|deny-patterns|runbook)' "$sf" || continue
  grep -q '실재하는' "$sf" || MISS48="$MISS48 $sk"
done
if [ -z "$MISS48" ]; then
  ok "skill context_paths 조건부 선언 봉인 (스캐폴드 산출물 경로 지시 ↔ '실재하는 것만' 선언 동반)"
else
  fail "skill context_paths 무조건 지시 (C14-J): 선언 누락 —$MISS48. 하네스엔 부재가 정상인 경로이므로 '실재하는 것만 전달' 선언 필요(spec §13.4·§13.8)"
fi

# 49. layer-yield 필드 parity + 대장 존재 (C16 spec §15.3, #19 동형): Step C-1 절차와 Communication
#     Protocol 출력 계약이 layer-yield 를 각각 **절차 단계**와 **필수 필드**로 갖고, 축적 대장
#     review-yield.md 가 실재해야. 누락 시 per-layer 수율이 복합 evidence 에 접혀 축적이 죽는다.
#     ★앵커는 bare 'layer-yield' 토큰이 아니라 **구별 리터럴 2종**(C18 슬롯2 #12): C18 이 같은 파일에
#     layer-yield 언급을 2곳 추가(sub-step 6 SKIP 사유·§17.4 초안-위임)한 뒤로는, bare 토큰 존재만 세면
#     그 언급들이 **sub-step 9 본문·CP 필드 정의행의 삭제를 마스킹**한다(격리-사본 실험으로 확정 —
#     정의행만 지운 변이가 GREEN 이었다). #46/#47 주석-마스킹 봉인과 동형 클래스. bash grep only.
SK49="$HOME/.claude/skills/start-rpi-cycle/SKILL.md"
C1_49=$(awk '/^## Step C-1/{f=1;next} /^## Sub-cycle states/{f=0} f' "$SK49" 2>/dev/null)
CP_49=$(awk '/^## Communication Protocol/{f=1} f' "$SK49" 2>/dev/null)
if printf '%s' "$C1_49" | grep -qF 'layer-yield 계량' \
   && printf '%s' "$CP_49" | grep -qF -- '- layer-yield: **고유 필수 필드**' \
   && [ -f "$HOME/.claude/docs/ai-context/review-yield.md" ] \
   && grep -q 'C15' "$HOME/.claude/docs/ai-context/review-yield.md"; then
  ok "layer-yield 절차/필드 앵커 (sub-step 9 'layer-yield 계량' · CP '고유 필수 필드' 정의행) + review-yield.md 대장 (C16 §15.3)"
else
  fail "layer-yield drift (C16): Step C-1 'layer-yield 계량' 또는 Communication Protocol '- layer-yield: **고유 필수 필드**' 정의행 결손, 또는 review-yield.md 대장/C15 행 결손 — spec §15.3"
fi

# 50. 집필-위임 규약 토큰 봉인 (C18 spec §17.1~§17.3, #49 동형): §17.7-2 가 재작성 상한·골격 계약의
#     hook 강제를 수용 잔여로 뒀으므로, 문서-토큰 드리프트 seal 이 이 규약의 **유일한 물리 봉인**이다
#     (skill 재생성·문면 재작성으로 규약이 소실되면 여기서 표면화 — #45 skill 토큰 parity 선례).
#     conjunctive: ①정본 start-rpi-cycle 서두 '집필은 opus 집필-위임 가능'+'재작성 ≤2회'+'FABLE-TAKEOVER'
#     +'골격 계약' ②cross-family-review §2 '판정은 메인, 증거 수집은 위임 가능'(★긍정-구절 전체 —
#     bare '증거 수집' 은 '위임 금지' 로 반전돼도 잔존해 GREEN 을 남긴다: 금지-반전 마스킹, 슬롯2 #3)
#     ③opencode 미러 start-rpi-cycle 'FABLE-TAKEOVER'(미러 **토큰** 존재 — 정본과의 diff-parity 검사가
#     아니다; 미러 부재(설치본/신선-클론) 시 vacuous 로 카운트 결정성 보존, #43 선례) ④**부정-단언**:
#     구 위임-금지 단정 '위임 X' 가 정본·미러 어디에도 되살아나지 않을 것(#25 선례 — 긍정 토큰만 세면
#     신·구 문면이 공존하는 half-landing/롤백-혼입을 통과시킨다). bash grep only.
C18_OK=1
SK50="$HOME/.claude/skills/start-rpi-cycle/SKILL.md"
CF50="$HOME/.claude/docs/ai-context/cross-family-review.md"
MIR50="$HOME/.claude/opencode-harness/skill/start-rpi-cycle/SKILL.md"
grep -qF '집필은 opus 집필-위임 가능' "$SK50" 2>/dev/null || C18_OK=0
grep -qF '재작성 ≤2회' "$SK50" 2>/dev/null || C18_OK=0
grep -q 'FABLE-TAKEOVER' "$SK50" 2>/dev/null || C18_OK=0
grep -q '골격 계약' "$SK50" 2>/dev/null || C18_OK=0
if grep -q '위임 X' "$SK50" 2>/dev/null; then C18_OK=0; fi
grep -qF '판정은 메인, 증거 수집은 위임 가능' "$CF50" 2>/dev/null || C18_OK=0
if [ -f "$MIR50" ]; then
  grep -q 'FABLE-TAKEOVER' "$MIR50" 2>/dev/null || C18_OK=0
  if grep -q '위임 X' "$MIR50" 2>/dev/null; then C18_OK=0; fi
fi
# C19 §18.3·G6: §18.4 가 create-orchestrator :24 의 위임-금지 단정을 소멸시킨 이후로는, 그 2파일에서의
# '위임 X' 부활도 start-rpi 와 **동일한 회귀**다 — 부정-단언 arm 을 정본+미러로 확장하고, 리터럴 부정-단언의
# 재서술 미탐(#19 클래스 상한)을 긍정-토큰 arm('집필-위임 가능'·'FABLE-TAKEOVER')으로 간접 백스톱한다
# (재서술 시 긍정 토큰이 함께 소실될 개연 — start-rpi 의 긍정 4토큰과 보호 수준 정렬).
CO50="$HOME/.claude/skills/create-orchestrator-skill/SKILL.md"
MCO50="$HOME/.claude/opencode-harness/skill/create-orchestrator-skill/SKILL.md"
if grep -q '위임 X' "$CO50" 2>/dev/null; then C18_OK=0; fi
grep -qF '집필-위임 가능' "$CO50" 2>/dev/null || C18_OK=0
grep -q 'FABLE-TAKEOVER' "$CO50" 2>/dev/null || C18_OK=0
if [ -f "$MCO50" ]; then
  if grep -q '위임 X' "$MCO50" 2>/dev/null; then C18_OK=0; fi
  grep -qF '집필-위임 가능' "$MCO50" 2>/dev/null || C18_OK=0
  grep -q 'FABLE-TAKEOVER' "$MCO50" 2>/dev/null || C18_OK=0
fi
if [ "$C18_OK" -eq 1 ]; then
  ok "집필-위임 규약 토큰 봉인 (start-rpi-cycle 집필-위임-가능/재작성-상한/FABLE-TAKEOVER/골격 계약 · cross-family '판정은 메인, 증거 수집은 위임 가능' · 미러 토큰 · 구 '위임 X' 부활 없음)"
else
  fail "집필-위임 규약 토큰 drift (C18): start-rpi-cycle '집필은 opus 집필-위임 가능'·'재작성 ≤2회'·'FABLE-TAKEOVER'·'골격 계약' / cross-family-review '판정은 메인, 증거 수집은 위임 가능' / opencode 미러 'FABLE-TAKEOVER' 중 결손, 또는 구 단정 '위임 X' 부활·create-orchestrator 긍정-토큰 결손(정본+미러) — spec §17.1~§17.3, §18.3"
fi

# 36. verify-setup 총 체크수 <-> README 선언 parity (GAP-009 M1 봉인, 런타임 자기-카운트):
# 51. 모드팩 L3 정책 오라클 (C20 spec §19.3) — 프로세스-경계 정책 공백의 유일한 정적 지점.
#     모델-정책 매처(Rule A/B/C)는 Agent|Workflow 한정이라 Orca 워커의 CLI --model 을 못 본다.
MP_ORACLE="$HOME/.claude/setup/lib/modepack-oracle.sh"
if [ -f "$MP_ORACLE" ]; then
  # shellcheck source=/dev/null
  . "$MP_ORACLE"
  # C21 I3: stderr 를 버리지 않고 포획 — 위반 상세(파일·워커·티어)가 stderr 로만 나오므로
  # 2>/dev/null 은 FAIL 을 재현 불가로 만든다. 원 목적(오라클 부재 시 소음 억제)은 :618 가드가 담당.
  MP_ERR=$(mktemp); MP_OUT=$(modepack_oracle_scan "$HOME/.claude/modes" 2>"$MP_ERR"); MP_RC=$?
  MP_DETAIL=$(cat "$MP_ERR" 2>/dev/null); rm -f "$MP_ERR"
  MP_TOTAL=$(printf '%s' "$MP_OUT" | grep -oE 'TOTAL=[0-9]+' | cut -d= -f2)
  MP_DYN=$(printf '%s' "$MP_OUT" | grep -oE 'DYNAMIC=[0-9]+' | cut -d= -f2)
  if [ "$MP_RC" -eq 0 ] && [ "${MP_TOTAL:-0}" -gt 0 ]; then
    ok "모드팩 오라클: 워커 ${MP_TOTAL} (동적/면제 ${MP_DYN:-0} — 계수됨) 위반 0"
  elif [ "${MP_TOTAL:-0}" -eq 0 ]; then
    fail "모드팩 오라클: 검사 대상 0 (modes/*.json 부재 — vacuous seal 방지, spec §19.3)"
  else
    fail "모드팩 오라클: 정책 위반 검출 — review-only 워커가 floor max(작업자,opus) 미만 — 상세: ${MP_DETAIL:-없음}"
  fi
else
  fail "모드팩 오라클 스크립트 부재: setup/lib/modepack-oracle.sh"
fi

# 52. 경로-전달 규약 (C21, non-obvious #3 SMART ① — 기한 "C21 초입"): setup/tests/·hooks/tests/ 의
#     인라인 인터프리터 소스(node -e / python -c)에 리터럴 /tmp/ 또는 (겹따옴표 소스의) 셸 변수 보간이
#     있으면 FAIL. MSYS 에서 bash 가 만든 경로를 네이티브 python/node 가 C:\tmp\x 로 오해석해 픽스처가
#     조용히 미생성되고, 계수기형 오라클이 그 빈 입력을 "위반 없음"으로 보고하던 클래스(C20 T6 라이브 재현).
#     ★vacuous 방지: 대상 0(TOTAL=0)이면 FAIL — #51 선례(계수기형은 "대상 0"과 "위반 0"이 동형).
#     ★C21 슬롯2(GPT #12·#13·#15) 정정 — 3종 부정확을 봉인:
#       #13 우회: 겹따옴표 소스 안의 `\"` 는 **JS/py 문자열 구문**이지 소스 종결이 아니다. 구 스캐너는
#          첫 `\"` 에서 잘라 뒤쪽 `$VAR` 를 못 봤다(실측 VIOLATION=0). → 이스케이프-인식 종결자 탐색.
#       #15 거짓 FAIL: ⓐ `\$` 는 겹따옴표 안에서 **리터럴 $** 라 보간이 아니다 ⓑ 인라인 주석(`# …`)
#          안의 호출은 실행되지 않는다 ⓒ 소스 끝을 건너뛰지 않아 소스 *내부* 텍스트를 2차 호출로 재계수.
#       #12 TOTAL 오염: 계수는 유지하되, 위 ⓐ~ⓒ 제거로 TOTAL 이 실제 호출에 근접한다.
#     ★수용 잔여(정직 공개 — 이 seal 은 셸 파서가 아니라 어휘 스캐너다):
#       ① TOTAL 은 **실행되는 호출 수가 아니라 어휘 출현 수**다. 문자열을 *조립*하기만 하는 줄
#          (예: seal-regression 의 mut_pathpass_interp 정의행 — 실측 TOTAL=1 VIOLATION=0)도 계수된다.
#          따라서 "TOTAL>0" 은 "실제 인라인 호출이 존재한다"의 **상계**이며, vacuous 가드의 강도는
#          그만큼 약하다(GPT #12 REAL — 완전 봉인은 셸 파싱을 요구하므로 이번 사이클 범위 밖).
#       ② 미탐: 줄-연속(`\` 개행)·멀티라인 소스·`--eval=`/`-c"…"`(공백 없는 형태)·따옴표 씌운 실행
#          파일명(`"node" -e`)·`node.exe`·`$1`/`$@` 등 위치 매개변수·backtick 명령 치환(GPT #14 REAL,
#          미정정). 글롭도 `*/tests/*.sh` 직계만 본다(하위 디렉터리 미포함 — 의도).
#       ③ awk 종료 상태 미확인(GPT #16) — summary 출력 후 nonzero 종료하는 환경 오류는 감지 못 한다.
PP_OUT=$(awk '
  # ★순서 주의: awk 정규식 /\\\\/ 는 **단일 백슬래시**를 매치한다. 백슬래시 규칙을 먼저 돌리면
  #   `\$`·`\"` 의 백슬래시를 먼저 먹어 뒤 규칙이 매치할 대상을 없앤다(실측). 2문자 시퀀스가 먼저다.
  function unesc(s) { gsub(/\\\$/, "\002", s); gsub(/\\"/, "\003", s); gsub(/\\\\/, "\001", s); return s }
  /^[[:space:]]*#/ { next }
  { line = $0
    # ⓑ 인라인 주석 절단: 따옴표 밖의 " #" 이후는 실행되지 않는다(따옴표 상태를 추적해 오절단 방지)
    inq = ""; cut = 0
    for (k = 1; k <= length(line); k++) {
      ch = substr(line, k, 1); prev = (k > 1) ? substr(line, k-1, 1) : ""
      if (prev == "\\") continue
      if (inq == "") { if (ch == "\047" || ch == "\"") inq = ch
                       else if (ch == "#" && (k == 1 || substr(line, k-1, 1) ~ /[[:space:]]/)) { cut = k; break } }
      else if (ch == inq) inq = ""
    }
    if (cut > 0) line = substr(line, 1, cut - 1)
    pos = 1
    while (match(substr(line, pos), /(python3?|node)[ \t]+-[ce][ \t]+/)) {
      st = pos + RSTART - 1; pos = st + RLENGTH; rest = substr(line, pos); q = substr(rest, 1, 1)
      if (q == "\047") { i = index(substr(rest, 2), "\047"); src = (i > 0) ? substr(rest, 2, i - 1) : substr(rest, 2); interp = 0
                         pos += (i > 0) ? i + 1 : length(rest) }        # ⓒ 소스 끝으로 전진
      else if (q == "\"") {                                              # #13: \" 를 건너뛰며 종결자 탐색
        body = substr(rest, 2); e = 0
        for (j = 1; j <= length(body); j++) {
          c = substr(body, j, 1)
          if (c == "\\") { j++; continue }
          if (c == "\"") { e = j; break }
        }
        src = (e > 0) ? substr(body, 1, e - 1) : body; interp = 1
        pos += (e > 0) ? e + 1 : length(rest) }
      else { src = rest; interp = 0; pos += length(rest) }
      TOTAL++
      probe = unesc(src)                                                 # ⓐ \$ → \002 로 중화(리터럴 $)
      if (index(probe, "/tmp/") > 0 || (interp && probe ~ /\$[A-Za-z_{(]/)) { V++; printf "%s:%d ", FILENAME, FNR }
    } }
  END { printf "\nTOTAL=%d VIOLATION=%d\n", TOTAL + 0, V + 0 }
' "$HOME/.claude/hooks/tests"/*.sh "$HOME/.claude/setup/tests"/*.sh 2>/dev/null)
PP_RC=$?   # GPT #16: summary 를 출력하고도 nonzero 로 죽는 awk/환경 오류를 OK 로 넘기지 않는다
PP_TOTAL=$(printf '%s' "$PP_OUT" | tail -1 | grep -oE 'TOTAL=[0-9]+' | cut -d= -f2)
PP_VIOL=$(printf '%s' "$PP_OUT" | tail -1 | grep -oE 'VIOLATION=[0-9]+' | cut -d= -f2)
PP_SITES=$(printf '%s' "$PP_OUT" | head -1)
if [ "$PP_RC" -ne 0 ]; then
  fail "경로-전달 seal: 스캐너 비정상 종료 (awk rc=$PP_RC) — 판정 불가를 PASS 로 위장하지 않는다 (GPT #16)"
elif [ "${PP_TOTAL:-0}" -eq 0 ]; then
  fail "경로-전달 seal: 검사 대상 0 (인라인 인터프리터 호출 부재 — vacuous seal 방지, #51 선례)"
elif [ "${PP_VIOL:-0}" -eq 0 ]; then
  ok "경로-전달 규약: 인라인 인터프리터 ${PP_TOTAL}건 위반 0 (non-obvious #3 SMART ①)"
else
  fail "경로-전달 규약 위반 ${PP_VIOL}건 — 인라인 소스의 리터럴 /tmp/ 또는 변수 보간 경로: ${PP_SITES}. argv/stdin 으로 전달할 것 (non-obvious #3)"
fi

# 53. 부작용-차단 주입 명시 (C23, non-obvious #5 SMART ①② — 기한 "C23 Phase P"):
#     docs/superpowers/plans/*.md + docs/ai-context/*.md 의 **증거 단위**(연속 비-공백 줄의 최대 런)에
#     커맨드-위치 캐리어 부작용 호출이 있으면, 그 호출 줄 자신 또는 **앞 15줄 이내**에
#     ⓐ ORCA_RPI_DRYRUN= (단독 충분) 또는 ⓑ ORCA_CLI_COMMAND= + ORCA_RPI_RUNDIR=(동반 필수)
#     가 있어야 한다. 없으면 FAIL. 라이브가 *목적*인 단위는 LIVE-INTENT(<6자 이상 사유>) 로 면제된다.
#     ★문단 단위인 이유: 펜스 모델은 중첩 펜스로 패리티가 깨진다(C22 plan 실측 — 오탐 1건).
#     ★근접 창인 이유: 공백줄 없는 긴 절에서 토큰 1개가 절 전체를 세탁한다(non-obvious.md 실측 87줄 단일 문단).
#     ★vacuous 방지: TOTAL=0 → FAIL 을 쓰지 않는다(캐리어 호출 없는 미래 사이클을 거짓 FAIL).
#       대신 **런타임 조립 자기-시험 픽스처**(ISO 1 + NOISO 1)로 탐지자가 양방향 판별함을 매번 증명한다.
#     ★1회성 예외 대장: C22 plan 6단위는 *이미 실행된 기록*이라 소급 편집이 왜곡/허위 재분류다.
#       개수가 아니라 **호출 줄 집합의 cksum 을 동결**한다(치환 우회 차단).
S53_AWK='
# 파일 단위 2-상 처리: 수집(라인 순회) → 분류(파일 끝). LIVE-INTENT 는 호출 **뒤**에도 올 수 있어
# (마크다운에서 선언은 보통 코드블록 다음 Expected 줄에 붙는다) 한 번에 판정할 수 없다.
# 격리 토큰은 **같은 단위 + 앞 15줄**. LIVE-INTENT 는 **같은 단위이거나 앞 15줄** + **줄 전체가 선언**
# 일 때만 인정한다(거리만으로는 *언급*과 *선언*이 구분되지 않는다 — spec §11.10 ③ 7차 정정).
BEGIN { QQ = "[\"" sprintf("%c", 39) "]+" }   # 양끝에서 벗길 따옴표(", '\'')
function classify(  i,j,d,cli,rd,iso,live,st) {
  for (i = 1; i <= nc; i++) {
    cli = 0; rd = 0; iso = 0; live = 0
    for (j = 1; j <= nt; j++) {
      if (tu[j] != cu[i]) continue
      d = cl[i] - tl[j]
      if (d < 0 || d > 15) continue
      if (tk[j] == "DRY") iso = 1
      else if (tk[j] == "CLI") cli = 1
      else if (tk[j] == "RD") rd = 1
    }
    for (j = 1; j <= nv; j++) {
      d = cl[i] - vl[j]
      if (vu[j] == cu[i] || (d >= 0 && d <= 15)) live = 1
    }
    st = (iso || (cli && rd)) ? "ISO" : (live ? "LIVE" : "NOISO")
    # 필드: STATUS \t FILE \t LINE \t RC \t UNIT \t TEXT (TEXT 가 마지막 — 탭 포함 시에도 잘리지 않게)
    printf "%s\t%s\t%d\t%d\t%d\t%s\n", st, CURF, cl[i], (rcu[cu[i]] ? 1 : 0), cu[i], ct[i]
  }
  nc = 0; nt = 0; nv = 0; unit = 0; split("", rcu, ":")
}
function callof(line,  s,n,a,i,t,nx,em,sk) {
  s = line
  sub(/^[ \t]*/, "", s)
  if (s ~ /^#/) return ""
  if (substr(s, 1, 1) == "`") return ""
  gsub(/\$\(/, " ", s)
  n = split(s, a, /[ \t]+|[;&|()]+/)
  em = 0; sk = 0
  for (i = 1; i <= n; i++) {
    # ★따옴표는 **양끝** 모두 벗긴다(슬롯 1 B4 실측). 선두만 벗기면
    # `bash "$HOME/.claude/bin/orca-rpi.sh" run …` 이 닫는 따옴표 때문에 경로 정규식에서 탈락해
    # **호출 자체가 스캔에 들어오지 않는다**(awk 실행으로 출력 0줄 확인). 이건 고의 우회가 아니라
    # 관용적 표기이고 — 이 plan 의 Task 5 도 `bash "$CARRIER"` 형태다 — 통째로 침묵하는 미탐이다.
    t = a[i]; gsub("^" QQ, "", t); gsub(QQ "$", "", t)
    if (t == "") continue
    # env 의 자기 옵션은 건너뛴다 — `env -u WT_SEL bash …/orca-rpi.sh spawn` 을 놓치면
    # 격리 없는 호출이 통째로 미탐된다(C23 Phase P 실측: 이 형태가 코퍼스에 다수).
    if (sk) { sk = 0; continue }
    if (t == "env") { em = 1; continue }
    if (em && t == "-u") { sk = 1; continue }
    if (em && t ~ /^-/) continue
    if (t == "bash" || t == "sh" || t == "exec" || t == "time") continue
    if (t ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
    if (t ~ /(^|\/)orca-rpi\.sh$/) {
      nx = a[i+1]; gsub("^" QQ, "", nx); gsub(QQ "$", "", nx)
      if (nx ~ /^(run|task|spawn|wait|handoff|release|gate|preflight|gpt)$/) return line
      return ""
    }
    return ""
  }
  return ""
}
FNR == 1 { if (NR > 1) classify(); CURF = FILENAME; nc = 0; nt = 0; nv = 0; unit = 1; split("", rcu, ":") }
/^[ \t]*$/ { unit++; next }
{
  c = callof($0)
  if (c != "") { nc++; cl[nc] = FNR; cu[nc] = unit; ct[nc] = c }
  # ★격리 토큰은 ①주석 줄이 아니고 ②`=` 뒤에 비-공백 값이 있어야 인정한다(슬롯 1 A3 실측).
  #   캐리어의 술어는 `[ -n "${ORCA_RPI_DRYRUN:-}" ]` 라 **빈 대입은 라이브 실행**인데 문자열 존재만
  #   보면 ISO 로 오분류한다. 더 넓게는 `# ORCA_RPI_DRYRUN=1` **주석 한 줄**만으로도 세탁됐다.
  #   탐지자와 런타임 술어가 어긋나면 seal 은 「PASS 하는데 Run 이 생기는」 최악의 방향으로 틀린다.
  ls = $0; sub(/^[ \t]*/, "", ls)
  if (substr(ls, 1, 1) != "#") {
    if ($0 ~ /ORCA_RPI_DRYRUN=[^ \t]/)  { nt++; tl[nt] = FNR; tu[nt] = unit; tk[nt] = "DRY" }
    if ($0 ~ /ORCA_CLI_COMMAND=[^ \t]/) { nt++; tl[nt] = FNR; tu[nt] = unit; tk[nt] = "CLI" }
    if ($0 ~ /ORCA_RPI_RUNDIR=[^ \t]/)  { nt++; tl[nt] = FNR; tu[nt] = unit; tk[nt] = "RD" }
  }
  # ★LIVE-INTENT 는 **줄 전체가 선언**일 때만 센다(공백·백틱 제외 후 그것 하나만 남아야 한다).
  #   거리로는 언급과 선언이 안 갈린다 — 「예시 문자열은 `LIVE-INTENT(…)` 이다」 같은 산문이
  #   11줄 뒤 호출을 면제해 버린다(슬롯 1 B5, spec §11.10 ③ 7차 정정).
  lv = $0; gsub(/^[ \t`]+/, "", lv); gsub(/[ \t`]+$/, "", lv)
  if (lv ~ /^LIVE-INTENT\([^)][^)][^)][^)][^)][^)]+\)$/) { nv++; vl[nv] = FNR; vu[nv] = unit }
  if ($0 ~ /rc=/) rcu[unit] = 1
}
END { classify() }
'
S53_TMP=$(mktemp -d)
printf '%s' "$S53_AWK" > "$S53_TMP/s53.awk"

# --- 자기-시험 픽스처(런타임 조립 — 리터럴로 두면 이 파일 자신이 코퍼스 오염원이 된다) ---
S53_CARRIER_TOKEN="bin/orca-rpi.sh"
{ printf 'ISO probe\n'
  printf 'ORCA_CLI_COMMAND=/x ORCA_RPI_RUNDIR=/y bash %s spawn --run r --task t\n' "$S53_CARRIER_TOKEN"
  printf '\n'
  printf 'NOISO probe\n'
  printf 'bash %s spawn --run r --task t\n' "$S53_CARRIER_TOKEN"
  printf '\n'
  # ★따옴표 감싼 경로 — 이 형태가 통째로 미탐이던 회귀를 봉인한다(슬롯 1 B4).
  printf 'NOISO quoted probe\n'
  printf 'bash "$HOME/.claude/%s" run --objective x\n' "$S53_CARRIER_TOKEN"
  printf '\n'
  # ★빈 대입은 격리가 아니다 — 캐리어 술어가 -n 이라 라이브로 실행된다(슬롯 1 A3).
  printf 'NOISO empty-assign probe\n'
  printf 'ORCA_RPI_DRYRUN= bash %s run --objective x\n' "$S53_CARRIER_TOKEN"
  printf '\n'
  # ★주석 줄은 격리원이 될 수 없다(슬롯 1 A3 — 대조 노동에서 추가 발견).
  printf 'NOISO commented-token probe\n'
  printf '# ORCA_RPI_DRYRUN=1\n'
  printf 'bash %s run --objective x\n' "$S53_CARRIER_TOKEN"
  printf '\n'
} > "$S53_TMP/fixture.md"
S53_FIX=$(awk -f "$S53_TMP/s53.awk" "$S53_TMP/fixture.md" 2>/dev/null | cut -f1 | tr '\n' ',')
if [ "$S53_FIX" != "ISO,NOISO,NOISO,NOISO,NOISO," ]; then
  fail "부작용-차단 seal: 자기-시험 픽스처 판별 실패(기대 'ISO,NOISO,NOISO,NOISO,NOISO,' 실측 '${S53_FIX:-빈값}') — 탐지자가 죽었다면 위반 0 은 무의미하다"
else
  S53_LEDGER="$HOME/.claude/docs/superpowers/plans/2026-08-17-c22-orca-carrier-landing.md"
  S53_ALL=$(awk -f "$S53_TMP/s53.awk" "$HOME/.claude/docs/superpowers/plans"/*.md "$HOME/.claude/docs/ai-context"/*.md 2>/dev/null)
  S53_BAD=$(printf '%s\n' "$S53_ALL" | awk -F'\t' -v L="$S53_LEDGER" '$1=="NOISO" && $2!=L {print $2":"$3}' | tr '\n' ' ')
  # 호출 텍스트는 마지막 필드다 — 앞 5필드를 잘라내 탭 포함 텍스트도 온전히 얻는다.
  S53_LED_CK=$(printf '%s\n' "$S53_ALL" | awk -F'\t' -v L="$S53_LEDGER" '$1=="NOISO" && $2==L { l=$0; sub(/^([^\t]*\t){5}/, "", l); print l }' | sed 's/[[:space:]][[:space:]]*/ /g' | sort | cksum | tr -d ' ')
  S53_LIVE_N=$(printf '%s\n' "$S53_ALL" | awk -F'\t' '$1=="LIVE"{print $2"\t"$5}' | sort -u | awk -F'\t' '{c[$1]++} END{for (f in c) printf "%s=%d ", f, c[f]}')
  S53_CLAIM=$(printf '%s\n' "$S53_ALL" | awk -F'\t' '$1=="NOISO" && $4==1 {print $2"\t"$5}' | sort -u | wc -l)
  S53_PARITY=""
  for _f in $(printf '%s\n' "$S53_ALL" | awk -F'\t' '$1=="LIVE"{print $2}' | sort -u); do
    # 계수 단위는 **증거 단위**다(호출 수가 아니라) — 한 블록 안의 여러 호출은 1건으로 센다.
    _k=$(printf '%s\n' "$S53_ALL" | awk -F'\t' -v F="$_f" '$1=="LIVE" && $2==F {print $5}' | sort -u | wc -l)
    _d=$(grep -oE 'LIVE-INTENT-총계: *[0-9]+' "$_f" 2>/dev/null | grep -oE '[0-9]+' | tail -1)
    [ "${_d:-없음}" = "$_k" ] || S53_PARITY="$S53_PARITY $_f(선언=${_d:-부재}≠실측=$_k)"
  done
  rm -rf "$S53_TMP"
  if [ -n "$S53_BAD" ]; then
    fail "부작용-차단 주입 누락 — 격리 토큰도 LIVE-INTENT 도 없는 캐리어 호출: ${S53_BAD}(non-obvious #5 SMART ①)"
  elif [ "$S53_LED_CK" != "3763352650710" ]; then
    fail "1회성 예외 대장 drift — C22 plan 의 미격리 호출 줄 집합이 바뀌었다(동결=3763352650710 실측=$S53_LED_CK). 소급 편집·치환 모두 여기서 잡힌다"
  elif [ -n "$S53_PARITY" ]; then
    fail "LIVE-INTENT 총계 parity 불일치 —${S53_PARITY} (자기-면제는 같은 파일 안에서 'LIVE-INTENT-총계: k' 로 표면화해야 한다)"
  else
    ok "부작용-차단 주입 명시: 미격리 캐리어 호출 0 · 실행-주장 단위 ${S53_CLAIM} · LIVE-INTENT ${S53_LIVE_N:-0건} (non-obvious #5 SMART ①②)"
  fi
fi

#     이 시점까지의 PASS+FAIL+1(이 체크 자신) == README "(현재 N PASS)" 선언. 체크 추가 시 README 미동기가 자동 FAIL.
EXPECTED_TOTAL=$((PASS + FAIL + 1))
README_DECL=$(grep -oE '현재 [0-9]+ PASS' "$HOME/.claude/README.md" 2>/dev/null | grep -oE '[0-9]+' | tail -1)
if [ -n "$README_DECL" ] && [ "$README_DECL" -eq "$EXPECTED_TOTAL" ]; then
  ok "verify-setup 카운트 seal: README 선언(${README_DECL}) == 런타임 실측(${EXPECTED_TOTAL})"
else
  fail "verify-setup 카운트 drift (GAP-009 M1): README 선언(${README_DECL:-부재}) != 런타임 실측(${EXPECTED_TOTAL}) — README.md '현재 N PASS' 동기 필요"
fi

echo
echo "verify-setup: PASS=$PASS FAIL=$FAIL"
exit $FAIL
