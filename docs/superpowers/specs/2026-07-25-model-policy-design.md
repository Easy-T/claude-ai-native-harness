# Durable Spec — 3-모델 역할분담 정책 (model-policy subsystem)

> **Subsystem**: 역할×모델×effort 디스패치 정책 + 강제 계층 (L1 문서/skill · L2 hook · L3 seal)
> **생성**: 2026-07-25 (goal: tri-model-orchestration — Fable 오케스트레이션 / Opus 구현 / GPT 검증)
> **지위**: durable spec (서브시스템당 1개, 사이클마다 재사용·in-place 개정). 이 파일이 설계 SSOT,
> 런타임 규범 SSOT는 `docs/ai-context/model-policy.md` (본 spec §3의 증류본).

## §0. 배경·문제

Fable 5 공식 제공으로 티어 3층(Fable=Opus 2배 비용). 사용자 주 사용 모델=fable. 문제: wrapper agent
3종이 전부 `model: inherit`라 fable 세션의 모든 서브에이전트가 fable을 상속 — 기계적 실행·탐색에
플래그십 비용을 지불한다. 요구: **작업 생성·종합·판단=세션 모델(fable), 구현=opus, 탐색=sonnet(경량
effort), 검증=상속(하향 금지)+GPT 교차패밀리(기존 규약)** 를 하네스로 물화·강제.

사용자 확정 사항 (2026-07-25, goal 문서보다 우선):
- 구현(implementation)은 **경량 작업도 opus** — "구현단계는 opus가 가장 효율적" (sonnet/GPT 구현 대비).
  sonnet 구현은 per-task 선언적 override로만.
- 사용자 시나리오 3종: ①fable+ultracode ②fable+max(비-ultracode) ③opus(기본 상속). ①②의 최적화가
  ③에도 이득이면 적용 허용(예: explorer 하향, GPT closeout 리뷰 — 후자는 기존 규약이 이미 세션-모델 무관).
- **reload/upgrade 내성** (사용자 지시 2026-07-25): skill/plugin은 재생성·업그레이드될 수 있다 —
  강제는 skill 텍스트에만 의존하면 안 된다. §5 배치 원칙 참조.

## §1. 실측 사실 (2026-07-25 probe — goal 파일은 gitignored이므로 여기 영구화)

CC 2.1.220, Windows/MSYS, CLIProxy 라우팅(haiku 티어=gpt-5.6-luna) 환경 실측:

1. **frontmatter `effort:` 키 실지원 (E2E 확정)**: `.claude/agents/*.md`에 `effort: low` → 해당
   서브에이전트의 PreToolUse hook stdin에 `"effort":{"level":"low"}` 캡처(세션 effortLevel=xhigh를
   override하고 전파). enum {low,medium,high,xhigh,max} (바이너리 zod 스키마 "Reasoning effort level
   for this agent"). **무효값 내성**: frontmatter 무효값(`banana`)은 필드만 무시되고 에이전트는 정상
   동작(등록 탈락 아님) — CC 업그레이드로 키 지원이 사라져도 에이전트는 살아남고 effort 힌트만 소실
   (fail-open 성질, §5 내성 원칙의 근거). 단 `--agents` CLI JSON에서는 무효값이 에이전트 등록 자체를
   탈락시킴(스키마 hard-reject) — frontmatter와 검증 강도가 다르다.
2. **PreToolUse(Agent 매처) hook stdin shape (캡처 원문 보존)**:
   `{"session_id":…,"transcript_path":…,"cwd":…,"permission_mode":…,"effort":{"level":"xhigh"},
   "hook_event_name":"PreToolUse","tool_name":"Agent","tool_input":{"description":…,"prompt":…,
   "subagent_type":"claude","model":"haiku","run_in_background":false},"tool_use_id":…}`
   — `tool_input.model`(호출 인자)·`subagent_type`·세션 `effort` 직접 가용. **세션 모델은 미포함** →
   transcript tail에서 `"model":"claude-fable-5"` 패턴 grep으로 저비용 판별(실측: 메인 transcript
   assistant 턴에 canonical id가 기록됨; `[1m]` suffix는 wire-strip되어 미출현). 강제 hook 실현 가능.
3. **Agent(model:'haiku') wire 모델**: modelUsage에 `gpt-5.6-luna` 실소비 기록 — haiku 티어 매핑이
   서브에이전트에도 그대로 적용됨(교차패밀리 luna가 Agent 도구로 도달 가능함의 확정).
4. **call-arg model이 frontmatter model에 우선** (Agent 도구 공식 문서 + probe 정합): frontmatter는
   기본값, 호출 인자는 override. frontmatter model 값은 enum 이름(sonnet 등)으로 동작(haiku 실측).
5. 기존 이월 사실(재실측 불필요): Workflow `agent()` opts = model+effort per-call 지원.
   **Agent 도구 호출 인자에는 effort가 없다** — 비-ultracode 경로의 per-call effort 제어는 불가능
   (frontmatter 정적값 또는 상속만). 티어 라이브 매핑: fable→claude-fable-5[1m] /
   opus→claude-opus-5[1m] / sonnet→claude-sonnet-5[1m] / haiku→gpt-5.6-luna / custom→gpt-5.6-sol.

## §2. 결정 (approaches 비교 후 채택)

- **채택**: explorer는 frontmatter 기본값(model+effort), executor는 L1 호출 규칙(caller가 model 명시)
  + L2 advisory hook, verifier는 무변경(상속) + L3 물리 봉인. 정적·문서화 정책 — 모델 재량 아님.
- 기각 1 — variant agent 증설(execute-heavy/light 등): 표면 증가(에이전트 5종+), skill 참조처 증가,
  "wrapper 3종" 단순성 훼손. call-arg model override가 이미 같은 힘을 제공.
- 기각 2 — executor frontmatter `model: opus` 고정: sonnet 세션(사용자가 의도적으로 저비용 선택)의
  구현 위임이 opus로 **조용히 상향** — 비용 방향이 반대인 silent escalation. 세션-조건부 기본값은
  frontmatter로 표현 불가하므로 L1 규칙+L2 hook이 올바른 자리.
- 기각 3 — 오케스트레이터 동적 모델 재량: cross-family-review.md §3 기각 사유 유지(self-pass 우회).
  이 spec의 하향은 전부 **정적 표** — 판단 지점이 없다.
- 기각 4 — PreToolUse에서 tool_input 변조(자동 모델 주입): CC는 `hookSpecificOutput.updatedInput`으로
  입력 치환을 **지원**하나(2026-07-26 GPT 리뷰 정정 — 바이너리 실측 확인) 기각 유지. 사유 교체: 자동
  주입은 ①정당한 선언적 override(per-task sonnet 등)를 hook이 식별 못 해 덮어씀 ②조용한 행동 변경 =
  silent-mutation 표면(자가-표면화 교리 위반). advisory 환기가 올바른 상한.

## §3. 정책 매트릭스 (SSOT — `docs/ai-context/model-policy.md`로 증류)

정책 키 = **(세션 모델, ultracode 여부)**. 역할별:

| 역할 | 담당 agent | 모델 | effort | 근거 |
|---|---|---|---|---|
| 오케스트레이션·판단·종합·게이트 해석 | 메인 세션 | 세션 모델 | 세션 effort | Fable의 존재 이유 — 위임 금지 |
| 구현 (heavy: 코드/TDD/다파일) | execute-strict | **opus** (fable 세션 한정 호출 인자 명시 — 비-fable 세션은 모드 C 상속) | ultracode: **high** / 비-ultracode: 상속 | 사용자 확정 "구현은 opus" |
| 구현 (light: 기계적 편집/문서 생성) | execute-strict | **opus** (동일 — sonnet 구현은 선언적 override만) | ultracode: **medium** / 비-ultracode: 상속 | 동상 |
| 탐색 (읽기 전용 발견·전수조사) | explore-strict | **sonnet** (frontmatter 기본) | **medium** (frontmatter 기본) | 기계적 스코프 탐색 — model 상향은 호출 인자로 허용. effort는 frontmatter 고정(§1.5 제약)이므로 **판단-heavy 탐색은 explore-strict가 아니라 builtin Explore(상속 — 단 CC가 Opus 상한을 걸 수 있어 fable 세션은 fable 미보장, GPT 리뷰 지적) 또는 메인 직접**이 탈출구 |
| 검증 (게이트/드리프트/적대) | review-strict | **상속** (하향 금지 — 상향 명시는 허용) | **상속** (하향 금지) | 검증자 티어 ≥ **세션**(오케스트레이터) 보장. 실행자를 세션 위로 상향한 경우(예: sonnet 세션+opus 실행)는 검증자<실행자 잔여 — 그때는 검증자도 동반 상향 권고(L1, hook 미검출 수용) |
| 교차 검증 (고-스테이크 closeout) | GPT (codex CLI/CCS) | 기존 규약 | — | cross-family-review.md 소비, 신설 금지 |

- **상향은 항상 허용**(사유 불요), **하향은 검증자에 한해 금지**·실행자는 이 표 자체가 선언이다.
  표 밖 하향(예: 구현을 haiku로)은 DOWNGRADE-DECLARED 동형 선언 필요 — hook Rule A는 부재/fable만
  감지하므로 haiku 명시 등은 L2 미검출(수용 잔여, L1이 담당; "검증자 금지"와 hook 메시지의
  DOWNGRADE-DECLARED 언급은 모순 아님 — 금지의 유일 탈출구가 그 선언+사용자 승인이다).
- 모드 분기: **(A) fable+ultracode** → start-rpi-cycle Phase I (d) Workflow stage1
  `agentType:'execute-strict', model:'opus', effort:'high'|'medium'`(heavy|light — plan task가 코드
  변경/TDD 포함이면 heavy, 순수 문서·기계 편집이면 light), stage2 `agentType:'review-strict'`
  **model/effort 무지정**(상속). goal 원문의 "stage2 GPT 규약 분기" 대안은 **기각(grill 확정)**:
  GPT quota는 사이클당 1회 상한(cross-family §2)인데 stage2는 task마다 발화 — 양립 불가. GPT 검증은
  closeout 지점 1회 유지. **(B) fable 비-ultracode** → (a)/(b)/(c) 세 경로 공통 규칙이되, skill 문구는
  execute-strict 위임이 실제 발생하는 (a)/(c)에 배치 — (b) executing-plans는 메인 직접 실행이라
  execute-strict 위임 자체가 없음(경로 명시 차이는 모순 아님, 2026-07-26 리뷰 정정) — execute-strict
  위임 시 `model:'opus'` 명시(effort는 플랫폼 제약으로 상속 — §1.5). **(C) 비-fable 세션** → 현행
  상속 유지. 단 explorer frontmatter 기본값(sonnet+medium)은 전 세션 공유(opus 세션도 이득 — 사용자
  승인 취지). haiku/custom(GPT) 세션에서의 RPIC 사이클은 비권장(검증자 상속이 GPT가 되어 교차패밀리
  전제가 뒤집힘) — 정책 문서에 1줄 명기.
- builtin 에이전트(Explore, general-purpose 등)는 hook 범위 밖 — 같은 표를 L1 지침으로만 준용.

## §4. 산출물·변경 지점

1. **`docs/ai-context/model-policy.md`** (신규): §3 증류본 — 매트릭스·모드 분기·상향/하향 규칙·
   플랫폼 제약(Agent 인자 effort 부재)·비권장 세션 1줄. 짧고 규범적(runbook형).
2. **`agents/explore-strict.md`**: frontmatter `model: inherit` → `model: sonnet` + `effort: medium`
   추가. 본문에 1줄: 기본값 근거 + 상향 호출 인자 허용. (execute/review는 frontmatter 무변경.)
3. **`skills/start-rpi-cycle/SKILL.md`**: Phase I (d) ultracode 절에 stage1 model/effort 표 반영,
   (a)/(c) 경로에 fable-세션 execute `model:'opus'` 규칙, Phase R step C 예시에 explorer 기본값 주석.
   model-policy.md 포인터 1개(중복 서술 금지 — drift guard #17 교훈: 사실은 SSOT 1곳+포인터).
4. **`hooks/surface-model-policy.sh`** (신규, advisory): §5.
5. **`settings.json` + `settings.example.json`**: PreToolUse `"Agent"` 매처 블록 신규 + hook 배선
   (양쪽 동기 — #23 parity).
6. **`setup/verify-setup.sh`**: 신규 seal(§6) + **#39 확장**(PCT≤40 **AND** WIN==1000000 세트 —
   2026-07-25 autocompact 회귀 근본원인 재발 방지). README 카운트 동기(#36/#20 parity).
7. **`hooks/tests/run-all.sh`**: hook 케이스 추가(§7 TDD).
8. **`docs/ai-context/scaffold-registry.md`**: hook 1행 등재.
8b. **`docs/ai-context/cross-family-review.md` §3 문구 동기화** (Gate R 발견): "wrapper 3종
   frontmatter에 model 필드 없음" → 실물은 명시적 `model: inherit`이며 본 사이클 후 explore-strict는
   `model: sonnet`. 검증자 원칙 문장만 정밀화(원칙 불변): "검증자(review-strict)는 `model: inherit`
   유지가 티어 ≥ 작업자를 보장; 실행자·탐색자 기본값은 model-policy.md 매트릭스" — spec delta+ADR로
   허용된 정밀화(goal §0.2).
9. CONTEXT.md 용어 등록(§8) + 메모리 `project_tri_model_policy` (closeout).

## §5. L2 hook 설계 — `surface-model-policy.sh` + 배치 원칙 (reload/upgrade 내성)

**배치 원칙 (사용자 지시의 물화)**: 정책의 *강제*는 skill/plugin 재생성·업그레이드에 살아남는 층에만
둔다 — ① L2 hook은 settings 배선(live는 gitignored — **추적본은 settings.example.json**이고 seal #23이
live↔example hook parity를 별도 강제하므로 live 소실도 표면화) + **라이브 tool_input 관측**이라 skill
텍스트와 무관,
② agents frontmatter는 git-추적이고 plugin 업그레이드가 건드리지 않음, ③ L1 skill 텍스트는 가장 약한
층이므로 L3 seal의 **토큰 parity가 소실을 표면화**(skill이 재생성되어 정책 문구가 사라지면 seal FAIL),
④ plugins/cache는 정책 캐리어로 절대 사용 금지(재생성 가능물 — C7 cksum이 변조만 감시), ⑤ CC 업그레이드로
hook stdin shape가 변하면: hook은 fail-open(워크플로 무파괴). 픽스처는 구-shape 고정이라 shape 변경
자체는 미검출(GPT 리뷰 정정 — 픽스처가 잡는 건 hook 로직 회귀뿐) → 라이브 shape 드리프트의 관측 지점은
hook_log ALERT 빈도 소멸(runlog_summary, closeout GAP-003 소비)이며 완전 자동 검출은 수락된 잔여.

**로직** (advisory 전용, 항상 exit 0, `_common.sh` 소비):
- 입력: stdin JSON에서 `tool_input.subagent_type`·`tool_input.model`·`transcript_path` 파싱.
- 세션 모델: `tail -c 200000 "$transcript"` 후 awk로 `"type":"assistant"` 라인의 **라인-내 첫**
  `"model":"claude-…"` 매치, 마지막 assistant 라인 값 채택 (구현 동기 2026-07-26 — assistant JSON은
  model이 content 앞이라 첫-매치가 본문 내 모델 id 인용에 면역; 픽스처 08이 봉인). 판별 불가/파일
  부재 → 조용히 exit 0 (fail-open).
- **Rule A (fable 실행자 하향 미적용)**: 세션=claude-fable-5* AND subagent_type==execute-strict AND
  (model 부재 OR model==fable) → `hook_log ALERT` + additionalContext:
  "정책: fable 세션의 실행자는 model:'opus' 명시 — docs/ai-context/model-policy.md" (1세션 1회 dedup,
  surface-constitution 패턴).
- **Rule B (검증자 하향)**: subagent_type==review-strict AND model 인자 존재 AND tier(model) <
  tier(세션) → ALERT + additionalContext "검증자 하향 감지 — DOWNGRADE-DECLARED 필요 (cross-family §3)"
  (1세션 1회 dedup, claude-* 세션 전체 적용 — 시나리오 ③도 혜택. haiku/custom 티어의 GPT wire 세션은
  transcript model이 claude-* 패턴 밖이라 판별 불가 → fail-open 종료 = §3 "GPT 세션 RPIC 비권장"과
  정합하는 수용 잔여).
  tier: fable=4, opus=3, sonnet=2, haiku=1 (custom 미대상). 1세션 1회 dedup은 의도 트레이드오프
  (surface-constitution 동형 — 환기 목적엔 1회로 충분, 위반별 전수 관측은 hook_log가 아닌 회고 몫).
- 비매칭/비대상 subagent_type → 무출력 no-op. 차단 없음 — goal 지시 "오탐 0 우선, advisory 후퇴".
  차단 승격은 **오탐 0 실증 후 별도 사이클** (이번 사이클 비범위).
- **커버리지 한계 (정직 공개)**: Workflow `agent()` 내부 스폰은 Agent *도구* 호출이 아니므로 이 hook에
  잡히지 않는다 — ultracode (d) 경로의 강제는 L1(start-rpi-cycle (d) 절 문구)+L3(토큰 parity seal)이
  담당하고, L2 hook은 비-ultracode Agent 도구 경로 전담. 계층별 커버가 상보적임을 model-policy.md에 명기.

## §6. L3 seal 설계 (신규 번호는 closeout 직전 origin/master 실측 — 동시세션 선점 교훈)

한 seal(단일 ok/fail, conjunctive)로: ① `docs/ai-context/model-policy.md` 존재 + 핵심 토큰
(`execute-strict` 행에 opus, `explore-strict` 행에 sonnet) ② `agents/explore-strict.md` frontmatter
`model: sonnet`+`effort: medium` ③ `agents/execute-strict.md`+`agents/review-strict.md` frontmatter
`model: inherit` 유지 + **review-strict에 `effort:` 키 부재**(검증자 상속의 물리 앵커) ④
settings.example.json에 Agent 매처+surface-model-policy.sh 배선 ⑤ start-rpi-cycle SKILL.md에
model-policy 토큰 존재(skill 재생성 소실 표면화 — §5 원칙 ③; 토큰은 *존재* 감지이지 규칙 문면 무결성
검증이 아님 — 문면 훼손·model:'opus' 삭제 등 세부 drift는 미검출 수용 잔여, 전체-재생성=토큰 소실이
주 위협 모델). **#39 확장**: 기존 PCT≤40 판정에
`CLAUDE_CODE_AUTO_COMPACT_WINDOW`==1000000 존재를 AND 결합(세트 봉인 — 단독 PCT는 침묵 무효).
bash grep/파일옵스만(staged-safe — seal 검사는 bash 파일옵스만 교훈).

## §7. 검증 계획

- **TDD**: run-all에 hook 케이스 선작성(RED) → hook 구현(GREEN). 픽스처 stdin은 §1.2 **실측 캡처
  shape verbatim** 재현(합성-shape 마스킹 교훈 — cycle-40) + mktemp 임시 transcript(#25 격리).
  케이스: (a) fable transcript+execute+model 부재→ALERT+additionalContext (b) 동+model:'opus'→무출력
  (c) review+model:'sonnet' under fable→ALERT (d) review 무인자→무출력 (e) sonnet transcript+execute
  무인자→무출력 (f) 깨진 stdin→exit 0 (g) transcript 부재→exit 0 무출력.
- **라이브 실증** (goal §3 "위반 호출→hook 발화 캡처"): settings.json 배선 후 headless probe 1회 —
  fable 세션에서 execute-strict를 model 미지정 호출 → additionalContext 발화를 transcript/캡처로 확인.
- verify-setup(신규 seal+#39 확장 포함)·seal-regression·run-all **포그라운드** ALL PASS(백그라운드=MSYS
  hang). 기준선 81/0, 178케이스 — 증가분 README 동기.
- 교차패밀리 GPT 리뷰 1회(이 spec+model-policy.md 대상 — 고-스테이크 거버넌스): 기존 규약 probe→가용
  시 stdin 파이프·트리아지, 불가 시 SKIP+사유.
- closeout drift review-strict + 이 사이클 자체가 정책의 dogfood(이 세션=fable: 탐색은 sonnet으로
  위임했고, 구현은 opus로 위임한다).

## §8. CONTEXT.md 등록 용어 (grill 확정)

- **실행자 하향 위임 (executor downshift)**: fable 세션이 execute/explore 위임을 정책표의 하위
  모델+effort로 디스패치하는 정적·문서화 정책. 검증자는 대상 아님.
  _Avoid_: "동적 모델 선택"(기각된 재량), "모델 다운그레이드"(품질 열화 함의).
- **역할×모델 매트릭스 (role-model matrix)**: (세션 모델, ultracode) 2키로 역할별 모델·effort를
  정하는 정적 표. SSOT=model-policy.md.
  _Avoid_: "모델 정책"(범위 불명 — 라우팅 env 설정과 혼동).

## §9. 비범위 (이번 사이클)

- opencode-harness 미러 skill 동기화: 회사 opencode 환경은 CCS/모델 라우팅 부재 — 정책 이식 무의미.
  SKIP 사유 여기 기록.
- 차단 hook 승격(advisory→block): 오탐 0 실증 후 별도 사이클.
- builtin 에이전트(Explore 등) hook 커버: L1 준용만.
- Workflow 일반(비-RPIC) 경로의 model/effort 정책: ultracode (d) 경로만 이번 범위.
