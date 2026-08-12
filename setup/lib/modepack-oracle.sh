#!/usr/bin/env bash
# modepack-oracle.sh — L3 정적 오라클: Orca 모드팩 워커의 모델 티어 판정 (C20 spec §19.3).
#
# 왜 L3 인가: 하네스 훅 *자체*는 별도 프로세스(Orca 워커)에도 발화하지만,
# 모델-정책 매처(Rule A/B/C/C2/C3)는 `Agent|Workflow` 도구 호출 한정이라
# (hooks/surface-model-policy.sh:18) CLI `--model` 인자의 티어 선언을 관측하지 못한다.
# 그 선언을 잡을 수 있는 유일한 정적 지점이 모드팩 JSON 이다.
#
# 3값 계약(hooks/lib/workflow-spawns.js 승계): 리터럴 / `-`=부재 / `*`=동적.
# 면제는 안전 인증이 아니라 판정 불가의 정직 표기 → 계수해서 보고한다.
#
# ★소비자 의무: 이 함수는 **검사 대상 0(TOTAL=0)에도 exit 0** 을 낸다 — 계수기이지
#   판정자가 아니기 때문이다. 따라서 "위반 0"과 "대상 0"이 exit code 로는 구분되지 않는다.
#   **호출자가 TOTAL=0 을 반드시 처분해야 한다**(vacuous 방지). verify-setup seal 이 그
#   의무를 이행하는 선례다(`MP_TOTAL -eq 0 → fail`). 이 구분을 빠뜨리면 픽스처 생성 실패·
#   디렉터리 오인이 "통과"로 읽힌다 — C20 T6 실사고(bash 가 만든 /tmp 를 네이티브 python 이
#   C:	mp 로 해석 → 빈 디렉터리 스캔 → VIOLATION=0 exit=0).

modepack_oracle_scan() {
  local dir="${1:-$HOME/.claude/modes}"
  [ -d "$dir" ] || { echo "TOTAL=0 LITERAL=0 DYNAMIC=0 VIOLATION=0"; return 0; }
  command -v node >/dev/null 2>&1 || { echo "TOTAL=0 LITERAL=0 DYNAMIC=0 VIOLATION=0"; return 0; }

  MP_DIR="$dir" node - <<'JS'
const fs=require('fs'), path=require('path');
const dir=process.env.MP_DIR;
const TIER={haiku:1,sonnet:2,opus:3,fable:4};
let total=0, literal=0, dynamic=0, violation=0; const details=[];

let files=[]; try{ files=fs.readdirSync(dir).filter(f=>f.endsWith('.json')); }catch(e){}
for(const f of files){
  let m; try{ m=JSON.parse(fs.readFileSync(path.join(dir,f),'utf8')); }catch(e){
    details.push(`${f}: JSON 파싱 실패 — ${e.message}`); violation++; continue;
  }
  const workers=Array.isArray(m.workers)?m.workers:[];
  // 작업자 티어 = review-only 아닌 워커들의 최댓값
  let workerTier=0;
  for(const w of workers){
    if((w.ownership||'')==='review-only') continue;
    const t=tierOf(String(w.command||''));
    if(t.kind==='literal' && TIER[t.model]>workerTier) workerTier=TIER[t.model];
  }
  const floor=Math.max(workerTier, TIER.opus);   // 판단-게이트 floor = max(작업자, opus)

  for(let i=0;i<workers.length;i++){
    const w=workers[i]; total++;
    const t=tierOf(String(w.command||''));
    if(t.kind!=='literal'){ dynamic++; continue; }
    literal++;
    if((w.ownership||'')==='review-only' && TIER[t.model]<floor){
      violation++;
      details.push(`${f}: workers[${i}] (role=${w.role||'?'}) review-only 인데 ${t.model}(tier ${TIER[t.model]}) < floor ${floor}`);
    }
  }
}
function tierOf(cmd){
  if(!cmd.trim()) return {kind:'absent'};
  // 문자 클래스에 $ { } % 포함 — 없으면 `--model $VAR` 가 매칭 자체에 실패해
  // absent 로 떨어지고 아래 동적 판정이 죽은 코드가 된다(3값 계약 붕괴).
  const mm=cmd.match(/--model[= ]+"?([A-Za-z0-9._${}%()-]+)"?/);
  if(!mm) return {kind:'absent'};                       // `-` : 선언 부재(상속)
  const raw=mm[1].toLowerCase();
  if(/[${}%]/.test(raw)) return {kind:'dynamic'};       // `*` : 셸/env 확장
  for(const k of Object.keys(TIER)) if(raw.includes(k)) return {kind:'literal', model:k};
  return {kind:'dynamic'};                              // 미지 리터럴 = 판정 불가
}
process.stdout.write(`TOTAL=${total} LITERAL=${literal} DYNAMIC=${dynamic} VIOLATION=${violation}\n`);
if(details.length) process.stderr.write(details.map(d=>'  '+d).join('\n')+'\n');
process.exit(violation?1:0);
JS
}
