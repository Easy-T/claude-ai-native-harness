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
- **effort 품질-우선 상향** (사용자 지시 2026-07-26, C12 T4 실행 중 — 비용 감수·"결과물이 완벽해야"):
  ultracode 구현 stage effort를 heavy `high`→**`xhigh`** / light `medium`→**`high`**(Opus 5 기본값)로
  상향. 근거(공식 docs): Opus 5 기본 high·에이전트 코딩/멀티파일 대공사는 xhigh가 권장 시작점·비용
  무관 작업 max (공식 가이드는 워크로드별 스윕 권고 — 단조 향상 보장 주장이 아님; GPT [D]1 정정).
  종전 high/medium 하드코딩은 비-ultracode 경로(세션 effort xhigh/max 상속)보다 낮아지는 **역전
  결함**이었음(발견 공로: 사용자). light를 xhigh로 안 올리는 이유: 순수 문서·기계 편집(verbatim
  쓰기)은 추론 깊이가 품질 상한이 되기 어렵다는 *판단*(실측 스윕 아님 — [D]2 정직화; per-task
  override가 탈출구) — 사용자 인용 표의 "일반 코딩=medium"보다도 한 단계 위인 high가 no-regrets 기본. canonical args에 per-task
  `effort` 명시 필드 허용 = 선언적 override(양방향 — max 상향 포함; 명시=선언이므로 DOWNGRADE 규율 정합).
  **GPT 교차리뷰도 동일 확정(같은 날)**: 리뷰 본호출 `-c model_reasoning_effort=xhigh`(codex 실측 —
  무효값 400·xhigh OK; 탐지 스모크는 기본 유지) — cross-family-review.md §2에 반영.
- **GPT 리뷰 상향 2차 — sol 고정 + ultra + priority + verbosity** (사용자 확정 2026-07-27, 위 항목을
  **대체**): codex GPT 슬롯을 **최상위 `gpt-5.6-sol` 고정**(사용자: "codex 토큰이 많이 남는다")으로
  선언하고, 그 전제 위에서 `model_reasoning_effort=ultra` + `service_tier="priority"`(TUI `/fast`의
  비대화형 등가) + `model_verbosity=high` + `-o` 를 canonical 커맨드로 채택. 2026-07-27 라이브 실측
  전 조합 완주(14,854 토큰). **판단 이력(정직 기록)**: 조사는 `max`/`ultra` 가 모델별 비호환(5.5/5.4
  400·luna 침묵 강등)이라 버전-무관 원칙과 충돌한다고 반대했으나, **사용자가 sol 고정을 선언해 그
  전제 자체를 제거** → 반대 근거 소멸. 대신 `-m gpt-5.6-sol` 리터럴이 이 파일의 **선언된 예외**이며
  슬롯 변경 시 §2 전체 재검증이 조건으로 붙는다. 신규 발견 `model_verbosity`(sol 기본 low → high 시
  산출 2.6배, A/B 실측)가 "GPT 사용이 제한적"의 실제 원인이었다 — effort 축이 아니라 분량 축.
  부수 실측 2건: `-o` 3개 실패 모드(stale 잔존·exit 0 침묵 손실·다중 메시지 중 마지막만) / 미지 `-c`
  키는 `--strict-config` 없이 침묵 무시 → 커맨드 수정 시 무료 오라클 검증 의무화(§2).
- **버전-무관 alias 원칙** (사용자 지시 2026-07-26, 3번째): 정책·디스패치 계층은 bare alias
  (fable/opus/sonnet/haiku)·와일드카드(`claude-opus-*`)만 — 구체 버전 바인딩은 settings.json env
  단일 지점(모델 세대 교체 시 1파일 갱신). 감사 결과 디스패치 계층은 이미 준수(agents frontmatter
  `sonnet`·hook `claude-*-*` glob+bare·workflow `'opus'`·seal grep 전부 무버전); 위반 2건 정정 =
  cross-family §1 경로 B probe의 `gpt-5.6-sol` 리터럴(→`${ANTHROPIC_CUSTOM_MODEL_OPTION:-…}` env
  간접화)+model-policy.md 헤더에 불변식 명문화. spec·memory의 버전 표기는 실측 역사 기록이라 예외
  (genesis-record 모델 동형). CLAUDE.md·통계 로그는 비대상.

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
| 구현 (heavy: 코드/TDD/다파일) | execute-strict | **opus** (fable 세션 한정 호출 인자 명시 — 비-fable 세션은 모드 C 상속) | ultracode: **xhigh** / 비-ultracode: 상속 | 사용자 확정 "구현은 opus"+effort 품질-우선(§0) |
| 구현 (light: 기계적 편집/문서 생성) | execute-strict | **opus** (동일 — sonnet 구현은 선언적 override만) | ultracode: **high** / 비-ultracode: 상속 | 동상. per-task `effort` 명시(max 포함)=선언적 override |
| 탐색 (읽기 전용 발견·전수조사) | explore-strict | **sonnet** (frontmatter 기본) | **medium** (frontmatter 기본) | 기계적 스코프 탐색 — model 상향은 호출 인자로 허용. effort는 frontmatter 고정(§1.5 제약)이므로 **판단-heavy 탐색은 explore-strict가 아니라 builtin Explore(상속 — 단 CC가 Opus 상한을 걸 수 있어 fable 세션은 fable 미보장, GPT 리뷰 지적) 또는 메인 직접**이 탈출구 |
| 검증 (게이트/드리프트/적대) | review-strict | **상속** (하향 금지 — 상향 명시는 허용) | **상속** (하향 금지) | ⚠**§12.1이 supersede**(2026-07-27): 기준선은 세션 단독이 아니라 `max(세션, 작업자)`. 아래 원문은 C11 시점 기록. 검증자 티어 ≥ **세션**(오케스트레이터) 보장. 실행자를 세션 위로 상향한 경우(예: sonnet 세션+opus 실행)는 검증자<실행자 잔여 — 그때는 검증자도 동반 상향 권고(L1, hook 미검출 수용) |
| 교차 검증 (고-스테이크 closeout) | GPT (codex CLI/CCS) | 기존 규약 | — | cross-family-review.md 소비, 신설 금지 |

- **상향은 항상 허용**(사유 불요), **하향은 검증자에 한해 금지**(⚠**§12.1이 supersede**: 기준선은 세션 단독이 아니라 `max(세션, 작업자)`)·실행자는 이 표 자체가 선언이다.
  표 밖 하향(예: 구현을 haiku로)은 DOWNGRADE-DECLARED 동형 선언 필요 — hook Rule A는 부재/fable만
  감지하므로 haiku 명시 등은 L2 미검출(수용 잔여, L1이 담당; "검증자 금지"와 hook 메시지의
  DOWNGRADE-DECLARED 언급은 모순 아님 — 금지의 유일 탈출구가 그 선언+사용자 승인이다).
- 모드 분기: **(A) fable+ultracode** → start-rpi-cycle Phase I (d) Workflow stage1
  `agentType:'execute-strict', model:'opus', effort:'xhigh'|'high'`(heavy|light — plan task가 코드
  변경/TDD 포함이면 heavy, 순수 문서·기계 편집이면 light; 원안 high|medium은 §0 품질-우선 상향으로
  2026-07-26 대체 — 비-ultracode 상속 대비 역전 결함), stage2 `agentType:'review-strict'`
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
- 세션 모델: `tail -c 1000000 "$transcript"` 후 awk로 `"type":"assistant"` 라인의 **라인-내 첫**
  `"model":[[:space:]]*"claude-…"` 매치(키 뒤 공백 허용 — GPT [B]5 정정), 마지막 assistant 라인 값
  채택 (구현 동기 2026-07-26 — assistant JSON은 model이 content 앞이라 첫-매치가 본문 내 모델 id
  인용에 면역; 픽스처 08·19가 봉인). tail 창은 1MB(마지막 assistant 라인이 창 밖이면 미판별 —
  수용 잔여). 판별 불가/파일 부재 → 조용히 exit 0 (fail-open).
- **Rule A (fable 실행자 하향 미적용)**: 세션=claude-fable-* AND subagent_type==execute-strict AND
  (model 부재 OR model∈{inherit, fable, claude-fable-*} — [B]8 정정) → `hook_log ALERT` + additionalContext:
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
- **커버리지 한계 (C11 시점 정직 공개 — §10이 C12에서 부분 해소)**: Workflow `agent()` 내부 스폰은
  Agent *도구* 호출이 아니므로 Rule A/B에 잡히지 않는다. C11은 이를 L1+L3에 위임하고 L2는 비-ultracode
  Agent 도구 경로 전담이었으나, C12가 `Workflow` 매처+Rule C(실행자)+Rule C2(검증자)를 추가해 L2가
  스크립트 *텍스트* 수준에서도 커버(휴리스틱 한계는 §10). 계층별 커버가 상보적임을 model-policy.md에 명기.

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

## §9. 비범위 (C11 사이클 시점)

- opencode-harness 미러 skill 동기화: 회사 opencode 환경은 CCS/모델 라우팅 부재 — 정책 이식 무의미.
  SKIP 사유 여기 기록.
- 차단 hook 승격(advisory→block): 오탐 0 실증 후 별도 사이클.
- builtin 에이전트(Explore 등) hook 커버: L1 준용만.
- ~~Workflow 일반(비-RPIC) 경로의 model/effort 정책: ultracode (d) 경로만 이번 범위~~ → **§10이 C12에서
  해소** (사용자 직접 지시 2026-07-26: "동적 생성 서브에이전트도 opus 고정 — 굉장히 중요").

## §10. Workflow 경로 거버넌스 (C12 in-place 개정, 2026-07-26 — L2 커버리지 한계 §5의 해소)

**문제**: C11의 정직 공개 잔여 — Workflow `agent()` 내부 스폰은 Agent 도구 호출이 아니라 L2 hook 미커버.
ad-hoc 워크플로 스크립트가 `agent()`를 model 없이 부르면 메인루프 모델(fable)을 상속해 stage 전체가
플래그십 비용으로 역류. L1 문구+L3 토큰만으로는 "감독이 매번 스크립트를 옳게 쓴다"에 의존.

**실측 (2026-07-26 probe — 픽스처 전제)**: PreToolUse `Workflow` 매처 stdin shape =
`{"session_id":…,"transcript_path":…,"effort":{"level":…},"hook_event_name":"PreToolUse",
"tool_name":"Workflow","tool_input":{"script":"<전체 스크립트 텍스트>"},…}` — scriptPath 변형은
`tool_input.scriptPath` (파일 경로만, 내용 없음). 세션 모델 미포함 → 기존 transcript awk 판별 재사용.

**해소 3층 (정책 자체는 §3 불변 — 캐리어 확장)**:
1. **canonical 구현 워크플로** `workflows/rpi-implement.js` (git-추적, 신규 디렉터리): (d) 경로의
   2-stage 파이프라인을 **코드로 고정** — stage1 `agentType:'execute-strict', model:'opus',
   effort: task.effort ?? (task.heavy?'xhigh':'high')` (§0 품질-우선 상향; per-task effort=선언적
   override, max 포함) / stage2 `agentType:'review-strict'` model·effort 무지정.
   `args` = task 배열 `[{title, promptVerbatim, files[], successCriteria, heavy, effort?}]`
   (필수 필드는 스크립트가 검증 — heavy boolean 필수로 silent light 강등 차단, effort enum 검증;
   worktree 필드는 2026-07-26 트리아지로 **제거** — [C]3, 아래 한계 참조).
   TDD-verbatim(stage1=promptVerbatim 원문)·stage2 데이터 의존(stage1 보고에 diff 원문 포함 요구 +
   review-strict가 실파일·git diff 직접 실행 대조)·RED/GREEN 증거 요구·stage2 verdict 첫 줄
   PASS/FAIL 강제(절단-안전)·schema 금지·같은-파일 task 자동 감지 순차 실행 — start-rpi-cycle (d)의
   ※규칙을 코드에 물화.
   (d)는 이 파일을 **절대경로** `scriptPath`로 호출(도구는 `~` 미확장 — 실측) — **재생성·기억 의존
   제거**. 스크립트에서 정책 토큰이 소실되면 L3가 잡는다(토큰 존재 감지 — 토큰을 남긴 로직 변조는
   L3 범위 밖, run-all 픽스처+리뷰 몫).
   실행 격리: 커밋은 워크플로 에이전트가 하지 않는다(병렬 커밋 index.lock 경합) — 메인이 그룹 커밋.
2. **L2 Rule C/C2** (surface-model-policy.sh 확장 + settings `Workflow` 매처 배선; GPT 교차리뷰
   트리아지로 2026-07-26 강화): 스크립트 텍스트(인라인=tool_input.script, scriptPath=파일 read —
   부재 시 fail-open; `~/` 접두는 방어적 $HOME 확장 — 도구 자체는 ~ 미확장이라 절대경로가 규범) 대상.
   - **Rule C** (fable 세션): `execute-strict` 스폰 객체(같은-중괄호 `[^}]*` 근사, 키 순서 양방향,
     따옴표 키 `"model":` 허용)에 model 부재 **또는 model=fable/inherit** → ALERT(1세션 1회, rule-c).
   - **Rule C2** (전 claude 세션): `review-strict` 스폰 객체에 하향 model 리터럴(티어 < 세션 티어)
     → ALERT(1세션 1회, rule-c2) — Workflow 경로의 검증자 하향도 Rule B 동형 커버.
   - 저-오탐 설계(원안 "오탐 0"은 휴리스틱과 양립 불가라 정정): execute/review-strict 없는 스크립트
     (순수 리서치 fan-out)는 무발화 — 일반 워크플로의 model-less agent()는 플랫폼 기본(메인루프 상속)이
     정당하므로 hook 비대상, L1 지침만. 같은-객체 model 선언이 있으면(opus든 선언적 override든) 무발화.
   - fail-open 불변식: `trap 'exit 0' ERR` + 파이프 대신 bash `[[ =~ ]]`(SIGPIPE·pipefail 면역).
3. **L3 seal #45 conjunct 확장** (+카운트 불변): rpi-implement.js 존재+`model: 'opus'` 토큰+effort
   분기 토큰 / settings.example `Workflow` 매처+hook 배선. run-all 픽스처 11케이스(실측 shape
   verbatim): Rule C 5(무model ALERT/opus 무/scriptPath ALERT/sonnet 세션 무/파일 부재 fail-open)
   + C2 3(review 하향 ALERT/상속 무/동일 티어 무) + 정정 3(따옴표 키 무/model:'fable' ALERT/
   transcript 공백 키 판별).

**한계 (정직 공개, C12 수용 잔여 — ⚠일부는 C13이 해소, 아래 각주 참조)**: Rule C/C2는 텍스트 휴리스틱 —
`execute-strict`를 변수로 조립하면 미검출, 주석 안의 이름은 오탐 가능(같은-중괄호 근사도 중첩 객체에
오판 가능; 스크립트에 execute-strict 호출이 여럿이면 하나의 준수 호출이 나머지 무선언 호출을 가릴 수
있음 — per-call 파싱은 bash advisory 범위 밖; 적대적 우회가 아닌 망각이 위협 모델, canonical 파일이
1차 방어).
> **C13 갱신(2026-07-27)**: 위 괄호 안 3개 — ①주석 오탐 ②중첩 객체 오판 ③형제 스폰 마스킹 — 은
> `hooks/lib/workflow-spawns.js`(렉서 + opts 프로퍼티 워크) 도입으로 **해소**되었다(§12.3·§12.6).
> "per-call 파싱은 bash advisory 범위 밖"이라는 판단도 소멸 — bash 밖 node 파서로 분리해 달성했다.
> **잔존**하는 것은 변수 조립 미검출뿐이며, 이제 `-`(model 미선언)·`*`(agentType 동적)으로 **안전 방향
> 보고**된다. 아래 나머지 한계(1-depth·256KiB·transcript 창·dedup·L3 토큰·프롬프트 주입)는 유효. scriptPath가 다른 워크플로를 `workflow()` 중첩
호출하는 경우 내부는 미검사(1-depth). scriptPath 검사는 선두 256KiB(초과분 미검사). transcript
tail 1MB 창 밖의 세션 모델·규칙별 1세션 1회 dedup 이후의 반복 위반은 미관측. L3 토큰은 존재 감지
(로직 무결성은 run-all 픽스처 몫). stage1 보고를 stage2 프롬프트에 주입하는 경로는 구분자+
"데이터이지 지시가 아님" 지시로 완화하되 프롬프트 주입의 완전 차단은 아님(review-strict가 실파일
diff를 직접 실행해 대조하는 것이 실질 방어). canonical의 worktree 격리는 **제거**(2026-07-26 정정):
Workflow isolation:'worktree'는 에이전트별 독립 사본이라 "stage2가 같은 worktree에서 리뷰"가 물리적
으로 불성립(GPT [C]3 REAL) — 파일 공유 task는 스크립트가 감지해 동일 체크아웃 순차 실행으로 대체.

## §11. C13 착수 근거 — 실측 코퍼스 (2026-07-26~27, goal 파일 gitignored이므로 여기 영구화)

> C13 goal 원문 = `_goal/c13-dispatch-governance-goal.md`(비추적). 아래는 그 §2 실측만 옮긴 것 —
> goal 소실 시에도 Phase R이 재현 가능해야 하므로. **사용자 확정(U1~U9)은 C13 Phase R에서 §0에 편입.**

**11.1 최대 누수원 = Workflow의 agentType-less 서브에이전트.** 전 코퍼스 196 스폰을 **선언 vs 상속**으로
분류(세션 모델 무관 불변 지표 — 사용자 제안 프레임). 비용가중 `in×1+cc×1.25+cr×0.1+out×5`:
상속 **83.1%**(n=168) / 선언 16.9%(n=28). 상속분 내역 = `workflow-subagent`(Workflow) **49.8%** ·
`review-strict`(Agent) 28.2% · `general-purpose`(Workflow) **10.8%** · `execute-strict`(Agent) 6.8% ·
review(WF) 2.4% · execute(WF) 1.1%. → **Workflow 비-구현 스폰이 상속분의 60.6%로 검증자(30.6%)의 2배.**
★측정 이력 정직 기록: 최초 wire-모델 집계는 이 세션의 fable→opus 전환(transcript 598→79라인)에
오염돼 "검증자가 주범"이라 오판했고, 사용자가 전환을 지적하며 위 프레임을 제안해 재측정한 것이 현 수치다.

**11.2 커버리지 공백 라이브 재현**(스테이징 HOME, 7 probe): `surface-model-policy.sh:48` 게이트 때문에
①순수 fan-out ②`agentType:'explore-strict'` ③`'general-purpose'` ④review+model-less ⑤마스킹(준수 1건이
무선언을 가림) ⑦변수 조립 = **전부 SILENT**, ⑥무선언 execute-strict 대조군만 ALERT. 게이트가 원인임을
로그 부재가 아닌 **재현 실험**으로 확정(로그 0건은 당시 세션이 opus라 과잉결정 구간이었음).

**11.3 상속 메커니즘 + 반례.** agentType-less는 3개 세션 모델에서 전부 상속(opus-4-8→213/213 ·
opus-5→3/3 · **gpt-5.5 세션→gpt-5.5**, 비-Claude까지). **반례**: builtin `Explore` 32건은 opus-4-8
세션에서 전부 `gpt-5.4-mini`(haiku 티어) = **비상속** → "미지정=상속"은 **agentType-less 한정**.
해소 우선순위(바이너리): `SUBAGENT_MODEL env > opts.model > frontmatter > inherit`.
**★frontmatter는 fail-safe가 아니라 fail-to-parent** — allowlist 검증 실패 시 경고 후 부모 모델 상속
(`…is not in the availableModels allowlist; inheriting the parent model instead`). CCS 프록시+커스텀
모델 ID 환경이 정확히 그 위험 구간.

**11.4 역류 실제 발생 = 0건, 노출은 확정.** 전 이력 112 Workflow 디스패치 중 fable 세션 하는 5건,
그중 리서치 fan-out 0건. 안 터진 이유는 하네스 방어가 아니라 `settings.json` 기본값이 `opus`이기
때문 — **fable 주력 전환 시 즉시 발현**.

**11.5 신규 결함 — Rule C 정규식 제3 오탐면**(§10 기지 한계와 다른 축): `RE_EX_MODEL_BEFORE`의 `[^}]*`
스팬이 **프롬프트 문자열을 가로질러** 설정 객체의 `model:'opus'`와 `execute-strict` 토큰을 결합해
`EX_HAS_MODEL=1` **준수 오판**. 실측 재현 시 Rule C 미발화 + Rule C2만 발화. 같은 메커니즘이 진짜
위반 은폐(false-negative)로도 작동 → C13-A는 이것부터 고쳐야 확장이 얹힌다.

**11.6 탐색 티어 공식 근거.** Opus 4.5 System Card §2.7.1 서브에이전트 정보검색 벤치 =
**Haiku 87.0 / Sonnet 85.4 / Opus 92.3** (정보검색은 Sonnet이 Haiku보다도 낮은 유일 항목) ·
§2.7.2 *"asymmetric model selection (capable orchestrators with cost-effective subagents)"* =
"탐색=하위 모델" 공식 권고 실재. **Sonnet 5 기본 effort = `high`**(공식 2출처) → C11의 `effort: medium`은
**기본값 아래 하향**(역전 결함, C12 동형). effort 가이드 "When to adjust": xhigh =
*"extended exploration, such as repeated tool calling and detailed search"*. **반대 근거(정직)**:
*"Sonnet 5 at medium is comparable … to Sonnet 4.6 at high"* + *"for most tasks use the model's default"*.

**11.7 WebSearch 부재 = 도구 문제(티어 문제 아님).** explore-strict tools에 WebSearch 없음. 공식:
WebFetch는 *"lossy by design"*, WebSearch는 *"It doesn't fetch the result pages"*(2단 파이프라인).
**검색엔진 URL WebFetch 우회 실측 실패**(Google/DDG/Bing 전부 무의미). ★문제 재정의: 웹 근거 조달이
**규약 밖 경로(builtin `claude-code-guide`=haiku)로 새고 있었다** → "경로 부재"가 아니라 "티어 무관리".
**보안 정정**: explore-strict는 Read+WebFetch로 **이미 exfil 채널 보유**(SECURITY.md:76 egress 필터링
범위 밖) → "trifecta 2-of-3 유지" 논거 폐기, "수락된 잔여에 인입 표면 추가"로 재서술.

**11.6-정정 (C13 Phase R, 2026-07-27) — System Card 수치 오인용 폐기.** 위 11.6의
"Haiku 87.0 / Sonnet 85.4 / Opus 92.3 = 서브에이전트 티어별 정보검색 벤치"는 **오독이다**. 원문(BrowseComp-Plus,
System Card §2.7.1 pp.22-24) 실제 구조:
| 구성 | 점수 |
|---|---|
| Opus 4.5 오케스트레이터 + **Haiku 4.5 서브에이전트** | **87.0%** |
| Opus 4.5 오케스트레이터 + **Sonnet 4.5 서브에이전트** | **85.4%** |
| Opus 4.5 단독(서브에이전트 없음) | 74.8% |
| **Sonnet 4.5 오케스트레이터** + Sonnet 4.5 서브에이전트 | 66.5% |
**92.3은 서브에이전트 축이 아니라 오케스트레이터 축 수치**(Opus vs Sonnet 오케스트레이터 비교, 85.4와 짝)이며
11.6이 이를 "Opus 서브에이전트" 칸으로 잘못 귀속했다. 따라서 **"정보검색은 Sonnet이 Haiku보다 낮은 유일 항목"이라는
서술은 근거 없음** — 실제 함의는 정반대로 *"저렴한 서브에이전트가 비싼 것에 밀리지 않는다"*(87.0 vs 85.4의 1.6%p는
k=3~8 표본이라 노이즈 구간 — "Haiku가 Sonnet보다 낫다"까지는 과다 해석). 공식 함의는
**"강한 오케스트레이터 + 저렴한 서브에이전트"**이고 이는 **U1을 강하게 지지하며 U3(웹서칭=opus)는 지지하지 않는다.**
→ C13-B 설계 변경의 직접 근거(§12.2). *교훈: 벤치 인용은 축(오케스트레이터 vs 서브에이전트)을 반드시 명시할 것.*

**11.7-보강**: WebSearch는 *"A session can make at most 200 WebSearch calls, counted across the main conversation
and every subagent it spawns"* (공식) — **메인+전 서브에이전트 공유 예산**이라 리서치 fan-out 설계 시 고려 필요.

**11.8 GPT 교차리뷰 커맨드 실측**(전부 wire 캡처/라이브): `effort=ultra` → wire는 `{"effort":"max"}` +
developer 메시지가 `Proactive multi-agent delegation is active`로 교체 + **`spawn_agent` 8회**(max는 0회).
추론 깊이는 max와 동일하고 차이는 **서브에이전트 자율 스폰** — **사용자가 이것을 목적으로 확정**
(2026-07-27 "sol이 ultra로 자기 subagent들까지 호출해서 최고로 탐색하는 걸 원한다") → ultra 채택,
"max로 정정" 권고는 철회. `service_tier=priority` wire 전송 확인(`fast`도 유효, **대소문자 구분**).
**값 오타는 침묵 무시**(CLI가 필드째 드롭; `--strict-config`는 **키만** 검증) → 값 검증은 wire 캡처뿐.
**`--enable fast_mode` 금지**(미지 플래그명에 **rc=1 하드 실패** — removed 시 리뷰 전체 사망, fail-open
교리 위반; `-c features.*`는 통과). `model_verbosity=high` A/B: **low 9,669B → high 25,022B(2.6배)** —
sol 기본이 low라 "GPT 사용이 제한적"의 실제 원인은 effort가 아닌 **분량 축**이었다. `-o` 3개 실패 모드
(①실패 시 **직전 파일 잔존**=stale 오독 ②쓰기 실패가 exit 0 ③다중 메시지 중 마지막만) →
`rm -f`+rc 확인+`[ -s ]`+**stdout 병행 보존** 필수. `model_max_output_tokens` 계열은 미실재.

## §12. C13 설계 결정 (in-place 개정, 2026-07-27 — Phase R brainstorming+grill 확정)

**사용자 확정 U1~U9**(C13 goal §1의 §0 편입 — goal은 gitignored): U1 fable 세션의 ultracode Workflow 서브에이전트는
상황에 맞는 하위 모델("같은 Fable 호출 시 토큰이 녹는다") · U2 Phase R의 WebSearch 근거 조달 강화 ·
U3 웹서칭은 opus(→ **§12.2에서 사용자 재판단으로 대체**) · U4 코드 탐색 sonnet의 effort는 xhigh ·
U5 codex GPT는 `gpt-5.6-sol` 고정 · U6 ultra의 서브에이전트 자율 스폰은 **목적**(부작용 아님 — "max로 정정" 권고 철회) ·
U7 `service_tier=priority` 적용 · U8 버전-무관 alias 원칙 유지(sol 리터럴은 선언된 예외) · U9 MERGE_POLICY wait.
**U10(2026-07-27 추가)**: 선재 결함은 발견분 전부 정정(스코프 축소 아님).

### §12.1 검증자 기준선 = `max(세션 티어, 작업자 티어)` — **완화가 아니라 강화**

**문제**: 두 SSOT가 다른 기준을 쓰고 있었다 — `cross-family-review.md:51` "검증자 티어 ≥ **작업자** 티어"
vs `model-policy.md:19` "검증자 티어 ≥ **세션**". 코드(hook Rule B `:131`, Rule C2 `:89`)는 세션-기준.
C13-A가 서브에이전트를 하위 모델로 내리는 순간 이 둘이 실제로 충돌한다(U1 vs 하향 금지).

**판정 이력(정직 기록)**: Phase R 초기 조사는 "작업자-기준으로 완화 = 신규 정책 완화이므로 DOWNGRADE-DECLARED
필요"라고 판정했으나, 적대 검증(V3)이 **부분 반증**했다 — 작업자-기준이 **원형이자 다수**(cross-family §3 원문 +
plans 5곳 + goal 2곳)이고 세션-기준은 C11 파생 2곳뿐. `plans/2026-07-25-tri-model-policy.md:327` →
`hooks/surface-model-policy.sh:136`에서 "티어 ≥ 작업자"가 "세션 티어(작업자 기준선)"로 **의도적 개서**된 이력 확인.
정확한 명명은 "신규 정책 완화"가 아니라 **라이브 양립 문면의 약한 방향 재해결**.

**채택**: 기준선 = `max(세션, 작업자)`. 두 독법의 **합집합**이므로 어느 쪽보다도 엄격하다 —
아래 ①②를 **위반으로 정의**하게 된다(정의상 닫힘 — *강제*는 별개, 다음 단락 참조):
① haiku 실행자 구멍(작업자-기준 단독의 약점: 실행자를 haiku로 내리면 검증자 haiku가 침묵 통과)
② `model-policy.md:19`가 수용 잔여로 남긴 "sonnet 세션 + opus 실행자 → 검증자<실행자" 역전
③ U1과 양립(검증자는 U1 대상 밖 — `CONTEXT.md:85` "검증자는 대상 아님"이 명문).
→ **DOWNGRADE-DECLARED 불필요**(완화가 아님). 두 문서의 용어 불일치도 이 정의가 흡수.

**★"정의"와 "강제"를 구분할 것 (Gate R 2패스 정정)**: 위 ①②는 새 기준선이 **위반으로 *정의*하게 되는**
케이스이지, 하네스가 **자동 탐지·차단하게 되는** 케이스가 아니다. 초안은 이를 "닫힘"이라 썼는데 그 표현은
강제까지 함축하므로 **취소한다**. 실제 강제 범위는 바로 아래 "강제 범위" 단락이 유일한 진실이며,
①은 Workflow 경로에서만(스크립트 텍스트에 두 리터럴이 함께 있을 때) 탐지 가능하고, ②는 canonical 캐리어
사례에서 보듯 **탐지 불가한 형태로도 발생**한다(무지정 상속은 리터럴이 없어 미매치 — §12.1 말미 표).
→ L1(문서 규범)이 정의를 담당하고, L2는 부분 탐지, 나머지는 **정직 공개된 수용 잔여**. 이 3층 분담이
C11 이래의 일관 패턴이며 이번에도 예외가 아니다.

**강제 범위(정직 공개)**: Workflow 경로(Rule C2)만 탐지 가능 — hook이 스크립트 전문을 한 문자열로 읽으므로
실행자 model과 검증자 model을 **같은 텍스트에서 비교** 가능. **Agent 도구 경로(Rule B)는 구조적 불가** —
`hooks/surface-model-policy.sh:126-162`가 단일 호출 `tool_input`만 보고, 실행자 model을 기억할 세션 상태가 없다
(`_common.sh` `session_marker`는 dedup 전용). 신규 상태 파일 + 실행자-선행 순서 가정이 필요한데 그건
advisory hook의 복잡도 상한을 넘음 → **L1 몫으로 명기하는 수용 잔여**.

**★canonical 캐리어의 floor 적용 범위 (Gate R 2패스 확정, 2026-07-27)**:
`workflows/rpi-implement.js`는 stage1을 `model:'opus'`(:42)로 고정하고 stage2는 무지정(:57, 상속)이다.
세션별 tier 계산(fable=4·opus=3·sonnet=2·haiku=1, floor=`max(세션, 실행자=3)`):

| 세션 | stage1 | stage2(상속) | floor | 판정 |
|---|---|---|---|---|
| **fable(4)** ← 캐리어의 선언된 모드 (A) | opus(3) | **fable(4)** | 4 | **충족** ✓ |
| opus(3) | opus(3) | opus(3) | 3 | **충족** ✓ |
| sonnet(2) | opus(3) | sonnet(2) | 3 | **위반** ✗ |
| haiku(1) | opus(3) | haiku(1) | 3 | 위반 ✗(단 RPIC 자체가 비권장 §3) |

→ **캐리어의 선언 모드(A: fable+ultracode, `model-policy.md:27`)에서는 무지정 상속이 이미 floor를 충족한다.**
위반은 **캐리어를 선언 모드 밖(sonnet/haiku 세션)에서 쓸 때만** 발생하며, 그 원인은 stage1의 `opus` 하드코딩이
세션 티어를 *넘기* 때문이다 — 즉 `model-policy.md:19`가 이미 수용 잔여로 기록한 "실행자를 세션 위로 상향"
케이스의 인스턴스다.

**★Gate R 1패스의 오답 기록(정직)**: 최초 해소안은 "stage2에 model을 명시하되 **실행자 티어 이상**"이었다.
이는 **두 겹으로 틀렸다** — ①floor는 `max(세션, 작업자)`인데 **세션 축을 누락**해, fable 세션에서 stage2=opus(3)를
명시하면 `max(4,3)=4 > 3`으로 **오히려 새 위반을 만든다**(상속이 정답인 자리에 하향을 박는 셈).
②stage2에 `'opus'` 리터럴이 생기면 fable 세션에서 `RE_REV_MODEL_AFTER`가 매치해 **Rule C2가 canonical
파일을 위반으로 ALERT** — §12.3이 경고한 "하네스가 자기 자신을 고발" 회귀와 동형. **교훈: floor 규칙은
두 축(세션·작업자)을 항상 함께 계산할 것. 한 축만 보면 반대 방향 위반을 생산한다.**

**채택 해소**: 캐리어 코드는 **무지정 상속 유지**(모드 A에서 정답이고, 리터럴 부재가 Rule C2 자기고발도 회피).
대신 ①캐리어가 **선언 모드(A) 전용임을 문서·주석에 명시**하고 ②모드 밖(sonnet/haiku 세션) 사용 시 floor
위반이 발생함을 **수용 잔여로 정직 공개**한다.
**★탈출구 부재 (Gate R 3패스 정정)**: 초안은 "호출자가 stage2 상향을 명시"를 탈출구로 적었으나 **실물에 그
파라미터가 없다** — `workflows/rpi-implement.js`의 stage2 opts(:56-60)는 `{agentType,label,phase}` 하드코딩이고
args 스키마(:25-35)는 `title/promptVerbatim/files/successCriteria/heavy/effort?`만 받는다. 캐리어를 버리고
인라인 스크립트를 쓰는 건 "canonical이 1차 방어"(§10) 전제를 무너뜨리므로 탈출구로 부적격.

> **행 인용 갱신 (C14, 2026-07-28)**: 위 `:42`/`:57`/`:56-60`/`:25-35` 및 §12.4 의 `:126-162` 는 C13 이
> 캐리어·hook 앞부분에 코드를 삽입하면서 밀려난 값을 실측 재대조한 것이다(직전 기록은 `:38`/`:53`/
> `:52-56`/`:24-31`/`:105-114`). 이 절의 행 인용은 load-bearing(탈출구 부재 논증의 근거)이므로
> **캐리어·hook 편집 시 동반 갱신 대상**이다.
→ **현 상태의 정직한 서술 = "모드 밖 사용 시 탈출구 없음"**. Phase P가 옵셔널 `verifyModel` args 추가를
task로 판단하되, 채택 시 **fable 세션에서 리터럴이 Rule C2 자기고발을 유발**하므로(2패스 오답 ②와 동형)
"floor 미달일 때만 삽입"하는 조건부 로직이 필수다.
**⚠§12.6이 폐기 — 아래 단락은 C13 Phase R 시점의 판정이며 Closeout 정정으로 무효**(현행: 상속 검증자는
세션 티어로 평가되어 floor 미만이면 Rule C2 발화). 원문 보존:
**Rule C2 미탐 성질은 유지된다**(무지정=값 없음 → `RE_REV_MODEL_*` 구조적 미매치) — 이는 결함이 아니라
정상 경로다. 근거는 **`agents/review-strict.md:14` frontmatter `model: inherit`**(seal #45가 `verify-setup.sh:455`로
봉인) + §11.3 해소 우선순위상 opts.model 부재 → frontmatter → 부모 모델. ※§11.3의 *"미지정=상속은
agentType-less 한정"* 명제(반례 builtin Explore)를 근거로 쓰면 **안 된다** — stage2는 agentType 지정 호출이라
그 명제의 적용 대상이 아니고, 성립 근거는 오직 frontmatter `inherit`이다(Gate R 3패스 지적).
floor 위반이 되는 유일 조건인 *실행자 상향*은 같은 스크립트 텍스트에서 stage1 model 리터럴로 관측 가능
→ **Rule C2 확장 후보**(Phase P 판단).

**동반 갱신 필요 목록 (Gate R 전수 — Phase P가 task로 흡수할 것)**: `docs/ai-context/model-policy.md:19,22` ·
`docs/ai-context/cross-family-review.md:51` · `CONTEXT.md:85,89` · `skills/start-rpi-cycle/SKILL.md:122,139`
("검증자는 **항상** model 무지정" — floor 하에서 거짓) · `setup/verify-setup.sh:445` seal #45 주석
("review effort 키 부재 = 검증자 상속 물리 앵커" — inherit이 더 이상 floor를 보장하지 않음) ·
**본 spec §3 매트릭스 `:105`**("검증자 티어 ≥ 세션" — §12.1 supersede 포인터 필요, §10·§11.6-정정 선례 동형) ·
`workflows/rpi-implement.js`(위 해소) · `hooks/tests/run-all.sh` SMP 픽스처.
※ `plans/*`(2026-07-25:60,150,156,327 · 2026-07-18:27)는 **완료 사이클 이력이라 갱신 대상 아님**(genesis-record).

※ **C14 보강**: 위 목록은 C13 Gate R 시점의 전수 결과다. 그 전수가 놓친 실사용 인스턴스
  (`hooks/surface-model-policy.sh:159` Rule B 메시지 · `workflows/rpi-implement.js:6` meta detail 등)는
  **§13.6 material drift 표**가 전수 기록한다 — 동반 갱신 대상의 현행 SSOT 는 §13.6 이다.

### §12.2 웹 리서치 = explore-strict 도구 배선(신규 에이전트 **기각**) — U3 대체

**사용자 재판단(2026-07-27)**: 11.6-정정으로 U3의 벤치 근거가 소멸하자 사용자가 직접 재판단 —
*"메인세션은 결국 fable이나 opus가 할 거니까 sonnet+xhigh로 웹 리서치를 추가 호출하도록 도구 배선만 추가"*.
→ **U3(웹서칭 opus 전용 에이전트) 철회, 도구-배선 안 채택.**

**기각: 웹 리서치 전용 opus 에이전트 신설.** 사유 4:
1. **공식 벤치가 지지하지 않음**(11.6-정정) — "강한 오케스트레이터 + 저렴한 서브에이전트"가 실제 함의.
   메인이 fable/opus이므로 강한 오케스트레이터 조건은 이미 충족.
2. **갭의 정체가 티어가 아니라 도구**(§11.7이 이미 기록) — 신규 에이전트는 도구 갭에 대한 과잉 대응.
3. **등록 표면 15곳+**(C13 Phase R 실측): `skills/start-rpi-cycle/SKILL.md:16`이 "sub-agent 위임은 wrapper
   3종**만**"이라 신규 에이전트를 **금지**(미수정 시 skill 자기모순) · `common-agent-contract/SKILL.md:10,38`
   3종 열거 + `COMPLETE` 소유자 열거 · `install.sh` REQUIRED · `verify-setup.sh:17,22,29` 3-agent 루프
   (→ PASS +N → seal #36이 README "현재 81 PASS" 자동 FAIL) · `acceptance.sh:65` ship 필수 3 agent ·
   opencode 미러 다수. **도구 배선은 frontmatter 1줄.**
4. **보안 델타가 새 축은 아님**: explore-strict는 이미 `WebFetch`(임의 외부 URL) 보유 — WebSearch도
   동일한 "아웃바운드 텍스트" 축 안이며 새 위험 축을 열지 않는다.
   ※**정정(§12.6 D4)**: 초안의 "Anthropic 백엔드 질의라 exfil 채널로서 **WebFetch보다 약하다**"는 데이터 흐름·
   위협 주체 정의 없이 결론만 있는 **미입증 주장**이었다(검색 query의 제3자 제공자 경계·보존·접근 주체가
   WebFetch보다 좁다는 근거 부재). 채택 근거에서 **격하**한다 — 채택의 주축은 U3 철회 + 배선 최소성이며,
   이 항목은 "기존 축 안"까지만 주장한다.
   (단 `SECURITY.md:71,73` Rule-of-Two 서술은 동반 정정 대상 — "유일 reader" 서술 유지되나 도구 목록 갱신.)

**채택**: `agents/explore-strict.md` tools에 `WebSearch` 추가 + Phase R step C에 웹 근거 조달 경로 명문화.
판단-heavy 웹 조사의 탈출구는 **기존 매트릭스가 이미 제공**(상향은 항상 허용 → 호출 인자 `model:'opus'`).
C13-C(effort xhigh)와 합쳐 explore-strict = **sonnet + xhigh + WebSearch**.
**★문제 재정의 유지**(§11.7): 웹 근거 조달이 규약 밖 경로(builtin `claude-code-guide`=haiku 티어)로 새고
있었다 — 이번 배선이 그 경로를 규약 안으로 편입한다.

### §12.3 Rule C 결함 4종 — 실물 hook E2E 재현(C13 Phase R)

> **시점 라벨 (§12.6 D3)**: 이 절 전체는 **정정 전 코드(C13 Phase R 시점)의 재현 기록**이다 — goal 문서가
> gitignored라 근거를 리포에 영구화한 것. 아래 "현 동작" 열과 `EX_HAS_MODEL:70-73` 인용은 **현행 파일에 대한
> 서술이 아니며**, 해당 변수·행 번호는 per-spawn 파서 전환으로 이미 존재하지 않는다.

| 케이스 | 당시 동작(정정 전) | 분류 |
|---|---|---|
| 프롬프트 문자열에 `model:'opus'` + 무선언 `execute-strict` | 무발화 | **미탐**(§11.5 확정) |
| 리서치 fan-out이 주석/프롬프트에 `execute-strict` 언급만 | **ALERT** | **오탐(신규 발견)** |
| 순수 리서치 fan-out(토큰 무언급) | `:48` 게이트 조기 exit | **사각**(U1 표적) |
| 형제 스폰 마스킹(준수 execute-strict + 무선언 execute-strict) | **SILENT** | **미탐**(§10:281 원문 한계가 옳음) |

**§10:281 한계 서술은 옳다 — 마스킹은 실재(★재현 이력 정직 기록)**: "스크립트에 execute-strict 호출이
여럿이면 하나의 준수 호출이 나머지 무선언 호출을 가릴 수 있음"은 **실물 hook E2E로 재현 확정**
(fable transcript·신규 SID: 단일 무선언=ALERT / 준수+무선언=**SILENT**).
**원인은 `[^}]*` 스팬이 아니라 `EX_HAS_MODEL`이 스크립트 전역 boolean OR**(`hooks/surface-model-policy.sh:70-73`)
이라는 점 — 준수 객체 하나가 플래그를 켜면 나머지 객체는 **개별 평가되지 않는다**. 즉 per-call 파싱 부재가
근본 원인이고, 정규식을 아무리 정교하게 고쳐도 이 구조에선 마스킹이 남는다.
**★초안 오판 기록**: C13 Phase R 초기에 나는 이를 "§10의 과장, `}`가 자연 방화벽"이라 판정했는데 **틀렸다**.
원인은 내 재현 스크립트가 앞 객체를 `review-strict`로 둬서 `RE_EX_MODEL_AFTER`가 애초에 매치하지 않은 것
(=execute 두 개인 현실 케이스를 재현하지 못함)이다. **교훈: hook 로직을 복제한 근사 재현이 아니라 실물
바이너리/스크립트를 E2E로 때려야 한다**(cycle-40 "합성-cwd 마스킹" 교훈의 동형 재발).
별개 축의 실제 위험으로 **네스팅**(`{model:'sonnet', tasks:[{agentType:'execute-strict'}]}`)도 존재하며,
그 결과 역시 오탐이 아니라 **미탐**(경보 억제)이다.
※ `hooks/tests/run-all.sh`의 SMP 09~19에 **마스킹 케이스가 없어** 이 미탐이 회귀로 잡히지 않았다 →
RED 픽스처 추가가 Phase P task 후보.
`hooks/surface-model-policy.sh:36` 주석의 "주석의 execute-strict 는 오탐" 서술도 Rule C 경로에선 **방향 오류**
(주석에 model 리터럴이 함께 있으면 억제=미탐, model 없으면 발화=오탐 — 둘 다 가능).

**대안 정규식 주의(적대 검증이 포착)**: `.\{0,120\}` 형태(BRE 바운드)는 bash `[[ =~ ]]`(**POSIX ERE**)에서
`\{`가 **리터럴 중괄호**로 처리되어 canonical `rpi-implement.js`를 **위반으로 뒤집는다**(치명 회귀 — 하네스가
자기 자신을 고발). ERE에선 `.{0,120}`가 올바른 형태. → 정규식 변경 시 **canonical 무회귀 케이스 필수**.

### §12.4 선재 결함(C13 무관하게 이미 깨져 있음 — 사용자 U10으로 **발견분 전부 판정 기록**; 정정 또는 "갱신 대상 아님" 판정 중 하나로 종결)

1. **`setup/install.sh` REQUIRED에 hook 2개 누락**: `surface-model-policy.sh`·`worktree-teardown.sh`
   (grep 0건 실측). 신규 PC 설치 시 **정책 hook이 없어도 침묵 통과** — L2 강제층이 통째로 증발하는 경로.
2. **`docs/ai-context/scaffold-registry.md` seal #45 미등재**: 제목이 "#17~#44 … = 27"에서 멈추고 표도 #44까지.
3. **`skills/ccs-delegation/SKILL.md:5,24,52`가 `~/.ccs/config.json` 지시** — 실재는 `config.yaml`
   (Glob 실측). 고장난 비-Claude 호출 경로가 라이브 상주.
4. `docs/superpowers/specs/2026-07-13-harness-upgrade-2026-07-design.md:89-97` cross-family 프로토콜 중복
   기술 + 버전 리터럴(§10 중복 SSOT 소지 — durable spec은 genesis-record라 **본문 편집 대신 포인터 주석**).
5. `settings.example.json`에 `ANTHROPIC_*_MODEL` env 전무 → "버전 바인딩 SSOT=settings.json env"가
   이 머신 한정 참(신규 PC에선 폴백 리터럴이 실질 바인딩).
6. `docs/harness-upgrade-2026-07/01-structure-map.md:55` "Wrapper agent 3종 전원 `model: inherit`" —
   실물은 C11 이후 `agents/explore-strict.md:14` = `model: sonnet`. **단 이 디렉터리는 C0~C10 이니셔티브의
   완료 산출물(genesis-record)**이므로 본문 편집 대신 **판정만 기록**: 갱신 대상 아님(이력 보존).

### §12.5 CONTEXT.md 신규/갱신 용어

- **검증자 기준선 (verifier floor)**: 검증자 티어가 넘어야 하는 하한 = `max(세션 티어, 작업자 티어)`.
  두 선행 독법(세션-기준·작업자-기준)의 합집합이라 어느 쪽보다 엄격. Workflow 경로만 hook 탐지 가능.
  _Avoid_: "검증자 하향 금지"(무엇 대비 하향인지 불명 — 이 모호성이 C13 이전 문서 드리프트의 원인).

### §12.6 GPT 교차패밀리 적대 리뷰 트리아지 (C13 Closeout, 2026-07-27)

`docs/ai-context/cross-family-review.md` 규약대로 codex CLI(gpt-5.6-sol, ultra/priority, read-only)로 사이클당 1회
적대 리뷰를 수행. 대상 = `hooks/lib/workflow-spawns.js` · `hooks/surface-model-policy.sh` Workflow 분기 · spec §12.
제기 19건(A 10 · B 0 · C 5 · D 4). **메인 세션이 원문 실측 대조로 전건 재현 검증** — GPT는 발견자이지 판정자가 아니다.

**판정: REAL 17 · 부분수용 2 · 기각 0.** 이번 리뷰는 오독이 0건이었다(C11 사이클의 REAL 9/기각 15, C12의 REAL 25/기각 3과 대비).

**[A] 파서 정확성 — 10건 전부 REAL → 파서를 정규식 휴리스틱에서 렉서+프로퍼티 워크로 전면 전환**

근본 원인은 개별 정규식의 정밀도가 아니라 **어휘 문맥(lexical context) 부재**였다. `maskStrings()`가 `sliceCall()`
*이후에만* 돌아서, 스폰을 *찾는* 단계에서는 문자열·주석이 살아 있었다. 그래서 A1(문자열 안 `agent(`가 스폰으로 계수),
A3(주석의 `/* model:'opus' */`가 실제 선언을 위조 → **Rule C 침묵**), A5(중첩 템플릿의 `model:'opus'`가 동일 위조),
A6(중첩 객체·중복 키 오귀속)이 모두 같은 뿌리에서 나왔다. **A3/A5/A6은 C13-A가 제거하려던 마스킹 클래스의 재발**이다 —
`EX_HAS_MODEL` 전역 OR를 없앴는데, 파서 안에서 "가짜 선언이 진짜 무선언을 가린다"는 형태로 부활해 있었다.

| # | 결함 | 실측 재현(정정 전) | 정정 |
|---|---|---|---|
| A1 | 문자열·주석·`function agent(` 선언을 스폰으로 계수 | `execute-strict\topus` (기대 무출력) | 렉서 선행 마스킹 + `function\s+` 제외 |
| A2 | `\b`가 JS 식별자 경계가 아님 → `obj.agent()`·`my$agent()` 오탐 | 동상 | `(?<![\w$.])` lookbehind |
| A3 | 주석이 스폰 존재·종류·model을 **양방향 변조** | 주석 model이 선언으로 인정 | 주석 본문 마스킹 |
| A4 | 정규식 리터럴의 괄호가 호출 깊이를 깨뜨림 | `?\t-` (절단) | 렉서가 정규식 본문 인식 |
| A5 | 템플릿 `${}`·중첩 템플릿 미처리 | 절단·위조·동적값 그대로 출력 | 템플릿 스택 + `${}` → dynamic 표시 |
| A6 | opts 객체를 확정하지 않고 호출 전역 첫 매치 | 첫 인자·중첩 객체의 model 채택, 중복 키 first-wins | 깊이 0 첫 `{`=opts + 깊이 0 프로퍼티 워크 + **last-write-wins** |
| A7 | 접미사 키(`fallback_model`)·삼항 피연산자 오탐, 정적 계산 키 미탐 | `execute-strict\topus` (실제 두 키 모두 부재) | 프로퍼티 경계 기반 key 판정 + `['model']` 해소 |
| A8 | escape 미디코드 (`-`·`\x66`·`\'`) | `execute-strict` → bash tier 0 | 정적 escape 디코드 |
| A9 | raw 개행/탭 출력이 "스폰당 1행" 계약 파괴 | 한 스폰이 2행 → bash `read`가 필드 분해 | line continuation 디코드 + `clean()` 접기 |
| A10 | 닫히지 않는 후보 반복이 O(N²) — `try/catch`는 **정지 불능에 무력** | 코드 경로 N=20000 에서 ~14s | 후보 **시도** 상한 400 (성공 스폰 상한만으론 불충분 — 실측) |

**[B] Bash 판정 로직 — 제기 0건**(none found).

**[C] 정책 정합성 — 5건 전부 REAL**

- **C1/C3 (동일 뿌리, 최중대)**: 2패스가 `SP_MODEL="-"`(무지정=상속)를 **폐기**해, sonnet 세션 + opus 실행자 +
  상속 검증자(=sonnet 2 < floor 3)라는 **§12.1 표가 "위반 ✗"으로 명시한 바로 그 칸**을 탐지하지 못했다.
  더 나쁜 것은 C2 경고문이 "무지정(상속)이 기본"이라 안내한 점 — 그대로 따르면 **위반은 남고 경고만 사라진다**.
  → 상속을 세션 티어로 **평가**(폐기 아님)하고, 메시지를 "model 삭제로는 해소되지 않는다"로 정정.
- **C2**: `tier 0` 검증자를 비교 전에 `continue` — "기타=0"은 **tier 계약**이지 판정 면제가 아닌데 면제로 쓰였다.
  → 면제 제거.
- **C4**: 파서의 `?`가 "agentType 키 부재"와 "키는 있으나 동적"을 뭉뚱그려, Rule C3가 후자에도 **세션 상속을 단언**했다.
  → 파서 계약을 3-값으로 확장(`?`=부재 / `*`=동적)하고 C3는 `?`에만 적용.
- **C5**: C/C3/C2가 동시 성립해도 첫 규칙만 emit 후 `exit 0` — **per-call 파싱으로 없앤 마스킹을 규칙 우선순위로
  되살린 셈**이고, 이 손실 우선순위는 §12 어디에도 설계 결정으로 선언된 적이 없다.
  → 규칙별 독립 마커 유지 + 성립한 규칙 **전부** 한 additionalContext 로 합쳐 emit.

**[D] 문서-실물 불일치 — 2건 REAL·2건 부분수용**

- **D1/D2 (REAL)**: §12.1 말미의 "Rule C2 미탐 성질은 유지된다(무지정=값 없음 → `RE_REV_MODEL_*` 구조적 미매치) —
  이는 결함이 아니라 정상 경로다"는 **C13 이후 거짓**이다. 신규 파서는 무지정을 `-` sentinel로 **관측 가능하게**
  만들었으므로 "값 부재라 못 본다"는 전제가 소멸했고, 같은 절의 표가 위반으로 정의한 입력을 "정상 경로"로
  재분류한 것은 절 내부 판정 충돌이었다. → 위 C1 정정으로 **미탐 자체가 해소**되었고, 해당 문장은 아래 정정으로 폐기.
- **D3 (부분수용)**: §12.3의 표와 `EX_HAS_MODEL:70-73` 인용이 현재형·live-line이라 신규 구현의 서술로 읽으면 거짓.
  다만 그 절의 목적은 **변경 전 재현 이력의 영구 기록**(goal이 gitignored이므로)이다 → 본문 유지 + **시점 라벨 명시**로 해소.
- **D4 (부분수용)**: §12.2의 "WebSearch는 Anthropic 백엔드 질의라 exfil 채널로서 WebFetch보다 약하다"는
  데이터 흐름·위협 주체 정의 없이 결론만 있다는 지적은 옳다. 다만 **채택 근거의 주축이 아니다**(주축은 U3 철회 + 도구
  배선 최소성) → 근거 강도를 "미입증 주장"으로 **격하 표기**하고 채택 결론은 유지.

**★§12.1 정정 (D1/D2 반영)**: 위 "Rule C2 미탐 성질은 유지된다 … 정상 경로다" 단락은 **C13 Closeout 시점부로 폐기**한다.
현행: **무지정(상속) 검증자는 세션 티어로 평가되며, `max(세션, 작업자)` 미만이면 Rule C2가 발화한다.**
`agents/review-strict.md:14`의 `model: inherit`은 여전히 **세션 축을 공짜로 보장**하지만, 작업자 축(실행자 상향)은
보장하지 않는다 — 그 갭이 바로 이번에 코드로 닫힌 부분이다. `workflows/rpi-implement.js`의 모드-밖 사용
(sonnet/haiku 세션) 잔여는 성격이 바뀐다: **침묵 잔여 → 관측되는 잔여**(캐리어를 그 세션에서 쓰면 Rule C2가 발화해
사용자에게 표면화된다). 탈출구 부재라는 사실 자체는 유지(수용 잔여).

**★§12.3 시점 라벨 (D3 반영)**: §12.3의 표와 `EX_HAS_MODEL` 인용은 **C13 Phase R 시점(정정 전 코드)의 재현 기록**이다.
해당 변수·행 번호는 현행 `hooks/surface-model-policy.sh`에 더 이상 존재하지 않는다(per-spawn 파서로 대체).

**교훈 (non-obvious 후보 아님 — 시스템 원인이 이미 규약으로 닫힘)**:
① **정규식 파서에 "문자열 안은 무시" 로직을 나중에 덧붙이면 반드시 순서 결함이 남는다** — 마스킹은 *탐색 전에*
   전역으로 한 번 돌아야 하고, 탐색 후 조각에 적용하면 탐색 자체가 이미 오염된 뒤다.
② **정지성은 `try/catch`로 보장되지 않는다** — 예외가 아니라 반환하지 않는 루프이므로 fail-open이 작동하지 않는다.
   입력 크기 상한이 아니라 **작업량 상한**(시도 횟수)이 필요하다.
③ **advisory 경고문은 "이렇게 고치면 된다"를 말하는 순간 그 복구 경로가 실제로 해소하는지 검증 대상이 된다** —
   C3는 경고문이 위반을 남긴 채 경고만 지우도록 안내하고 있었다(문서가 아니라 **코드의 일부**로 취급할 것).

**정정 착륙 E2E 검산 (Closeout, 실물 hook 실행 — 합성 재현 금지 원칙 준수)**:

| 검산 | 입력 | 결과 |
|---|---|---|
| 자기고발 무회귀 | canonical `rpi-implement.js` × 4 세션 티어 | fable·opus **무발화** / sonnet·haiku **ALERT** — §12.1 표와 완전 일치 |
| C1/C3 | sonnet 세션 + opus 실행자 + **상속** 검증자(2 < floor 3) | **ALERT** (정정 전 SILENT) |
| C1 역방향 | fable 세션 + opus 실행자 + 상속 검증자(4 ≥ 3) | **무발화** (정상 경로 무회귀) |
| C2 | sonnet 세션 + opus 실행자 + `model:'gpt-custom'`(tier 0) | **ALERT** (정정 전 면제) |
| C4 | fable 세션 + `agentType: TYPE`(동적='*') | **무발화** (거짓 상속 단언 제거) |
| C5 | fable 세션 + C·C3·C2 동시 성립 스크립트 | 한 additionalContext 에 **3 규칙 전부** (정정 전 1건만) |
| 파서 계약 | `node hooks/lib/workflow-spawns.js < workflows/rpi-implement.js` | `execute-strict\topus` + `review-strict\t-` (2행, 무회귀) |

**항목 수 정합**: A 10 + C 5(C1/C3 동일 뿌리라 4행 표기) + D 4(D1/D2 동일 뿌리라 3행 표기) = **19**.
REAL 17 = 19 − 부분수용 2(D3·D4). 기각 0.

## §13. C14 착수 근거 — C13 잔여 실측 (2026-07-27~28, goal 파일 gitignored이므로 여기 영구화)

> C14 goal 원문 = `_goal/c14-residue-and-eval-goal.md`(비추적). 1차 출처 = `_goal/c13-evidence/`
> (적대 검증 9-에이전트 + GPT 교차리뷰 원문, 둘 다 비추적). 아래는 **goal 파일 없이도 Phase R이
> 재현 가능**하도록 실측만 옮긴 것 — §11 선례. C13 Closeout이 "COMPLETE"로 보고했으나 적대 검증
> 4 렌즈 중 3이 뒤집었고, goal 성공기준 3개가 미충족이었다.

### §13.1 ★방법론 실패 — "없을 것"이라 가정하고 확인하지 않았다 (근본원인)

C13 Closeout은 프롬프트의 "goal은 gitignored라 없을 수 있다"를 **확인 없이 사실로 승격**해 요구사항을
spec §11/§12로만 읽었다. 그러나 `_goal/c13-dispatch-governance-goal.md`(18,744 bytes)는 **디스크에
실재했다** — `ls _goal/` 한 번이면 확인됐다. 결과: goal §4 성공기준 6개 중 3개가 미검증 상태로
"COMPLETE" 보고됨. spec §11.2는 7 probe를 요약만 하고(*"①~⑤⑦ SILENT, ⑥만 ALERT"*) **어느 probe가
성공기준인지는 goal에만** 있었다.

**시스템 원인**(사람/AI 아님 — CLAUDE.md §4-3): 요구사항 SSOT가 비추적 파일에 있고, 그 파일의 **부재를
가정해도 되는 조건이 규약에 없었다**. → C14-H가 non-obvious 등록 + 재현 픽스처 규약으로 닫는다.

### §13.2 ★probe p1~p7 실행 정의 (C13 goal이 라벨만 남겨 재현 불가였던 것 — 여기 영구화)

```bash
cd ~/.claude
mkdir -p /tmp/probe
for M in fable-5 opus-5 sonnet-5 haiku-4-5; do
  printf '{"type":"assistant","message":{"model":"claude-%s","content":[]}}\n' "$M" > /tmp/probe/$M.jsonl
done
mkev(){ KIND="$1" VAL="$2" TP="$3" SID="$4" node -e '
  const ti={}; ti[process.env.KIND]=process.env.VAL;
  console.log(JSON.stringify({session_id:process.env.SID,transcript_path:process.env.TP,cwd:"",
    permission_mode:"bypassPermissions",effort:{level:"xhigh"},hook_event_name:"PreToolUse",
    tool_name:"Workflow",tool_input:ti,tool_use_id:"t"}));'; }
run(){ rm -f /tmp/model-policy-c*-"$3"* 2>/dev/null   # ★마커 선삭제 필수 — 규칙별 1세션 1회 dedup
       O=$(mkev script "$1" "$2" "$3" | bash hooks/surface-model-policy.sh 2>/dev/null)
       printf '%s' "$O" | grep -q additionalContext && echo ALERT || echo SILENT; }
```
| probe | 스폰 | 의미 |
|---|---|---|
| p1 | `agent('q',{label:'a'})` | 순수 fan-out(agentType 부재) |
| p2 | `agent('q',{agentType:'explore-strict',label:'a'})` | 탐색자 fan-out |
| p3 | `agent('q',{agentType:'general-purpose',label:'a'})` | 범용 fan-out |
| p4 | `agent('r',{agentType:'review-strict'})` + `agent('r2',{})` | 검증자+무선언 |
| p5 | 준수 execute-strict + 무선언 execute-strict | 마스킹 |
| p6 | 무선언 execute-strict 단독 | 대조군 |
| p7 | `const t='execute'+'-strict'` | 변수 조립 |

**2026-07-27 실측(머지된 master `a289a45`, fable transcript)**: p1 **ALERT** · p2 **SILENT** ·
p3 **SILENT** · p4 ALERT · p5 **ALERT** · p6 ALERT · p7 SILENT(기지 잔여 — 동적 조립).
**2026-07-28 C14 Phase R 재현: 동일**(7/7 일치).
→ C13이 닫은 것 = p1·p5(+p6 무회귀). **C13 goal §4.1이 요구한 p2·p3는 미충족.**

### §13.3 ★C14-D 판정 — p2/p3 요구는 **(a) Rule 확장으로 수용**한다

**해석 충돌의 정체**: C13은 "agentType 명시 = 세션 상속 아님 → 역류 없음"으로 해석해 p2/p3를 의도적
제외했다. 그러나 그 해석은 **한 축을 빠뜨렸다** — 상속 여부를 정하는 것은 *agentType의 명시 여부*가
아니라 **그 agentType이 model을 선언하는가**다(§11.3 해소 우선순위: `opts.model > frontmatter > inherit`).

실측 대조(2026-07-28):

| agentType | frontmatter `model:` | opts.model 부재 시 실제 스폰 모델 | 역류? |
|---|---|---|---|
| `explore-strict` | `sonnet` (`agents/explore-strict.md:14`) | sonnet | **없음** |
| `general-purpose` | **파일 자체 부재**(builtin) | **세션 상속** | **있음** |
| `execute-strict` | `inherit` | 세션 상속 | 있음(Rule C가 담당) |
| `review-strict` | `inherit` | 세션 상속 | floor 판정(Rule C2) |

→ **p2와 p3의 답은 다르다**(goal §2.2가 예견한 대로):
- **p3 = REAL 미탐, 수용**. `general-purpose`는 `agents/` 파일이 없어 model을 선언할 곳 자체가 없다 →
  fable 세션의 fan-out이 통째로 플래그십으로 역류한다. §11.1 비용 표에서 이 경로는 **상속분의 10.8%
  (n=36) 단독 3위**이고, C13 goal 본문이 *"agentType-less + general-purpose = 상속분의 60.6%"*라며
  표적에 **명시 포함**했다. Rule C3의 근거(§11.3 "agentType-less는 상속")는 **model 무선언 agentType에도
  똑같이 성립**하므로, C3를 "agentType 부재"가 아니라 **"model을 선언하지 않는 스폰"** 축으로 재정의하는
  것이 일관된다.
- **p2 = 발화 불요, 단 조건부**. `explore-strict`는 frontmatter `model: sonnet`이라 역류가 없다.
  **다만 §11.3의 ★fail-to-parent**(allowlist 검증 실패 시 경고 후 **부모 모델 상속**)가 CCS 프록시
  환경에서 실재 위험이다. 그러나 그것은 *런타임 allowlist 실패* 조건이고 hook은 정적 텍스트만 보므로
  **정적으로 판별 불가** → L1/수용 잔여로 유지하고 발화시키지 않는다(오탐 비용이 이득을 넘음:
  정책 준수 스폰마다 경고가 뜬다).

**채택 = Rule C3 재정의(신규 번호 없이 축 확장)**: fable 세션에서 `model` 무선언 스폰 중
**"model을 선언하는 frontmatter가 없는 agentType"** 을 대상으로 한다. 구현은 **allowlist가 아니라
denylist의 역**(= `agents/<type>.md`에 `^model:` 이 있으면 제외)이 아니라 — hook은 파일시스템 조회
없이 결정론적이어야 하므로 — **정적 목록**으로 한다:
제외 목록은 **두 개의 서로 다른 사유**로 구성된다(한 공식으로 유도되지 않는다 — Gate R 정정):
- **사유 ① model 선언 보유** → 역류 없음: `explore-strict`(frontmatter `model: sonnet`).
  이 축이 디스크에서 유도 가능한 유일한 부분집합이다: `agents/*.md` 중 `^model:`이 `inherit`이 아닌 것
  = `{explore-strict}` (2026-07-28 실측).
- **사유 ② 다른 규칙이 전담** → C3 대상 아님: `execute-strict`(Rule C)·`review-strict`(Rule C2).
  둘 다 frontmatter는 `inherit`이라 ①로는 유도되지 않으며, 규칙 분담이라는 **설계 결정**이다.
- **사유 ③ 상속 단언 불가**: `*`(동적 agentType — GPT [C]4 판정 유지).
- 대상(발화): `?`(키 부재 — 현행) **+ 그 외 모든 리터럴 agentType**(general-purpose·Explore·Plan·
  claude 등 builtin 전부)

**봉인**: ①축만 seal이 자동 대조한다 — `agents/*.md`에서 `^model:`이 `inherit`이 아닌 것이 hook의
제외 목록에 **포함되는가**(⊆ 방향; 등호 아님 — ②③은 코드 상수라 디스크에 대응물이 없다).
새 wrapper agent가 `model: <비-inherit>`로 추가되면 hook 제외 목록에 넣으라고 발화한다.
※ 기존 seal #45 conjunct ②가 이미 `agents/explore-strict.md`의 `^model:[[:space:]]*sonnet`을
검사하지만, 그것은 **그 파일의 값 고정**이지 *hook 제외 목록과의 대조*가 아니다 — 별개 축.
②③의 정합은 seal이 아니라 **run-all 픽스처**가 지킨다(리터럴 목록의 로직 회귀는 픽스처 몫 — §6 원칙).

### §13.4 ★C14-J 판정 — context_paths 4파일은 **(b) skill 정정**(신설 아님)

**선행 판정이 이미 존재한다**(C14 Phase R 발견): `docs/superpowers/plans/2026-06-13-cycle31-seal-regression-metatest.md:29`
> *"`ai-context/*`(deny-patterns·non-obvious·architecture·domain-glossary)는 이 하네스 repo에 **부재**
> (target 프로젝트용 템플릿). 하네스 거버넌스 SSOT = `CLAUDE.md` + `CONTEXT.md` + `verify-setup.sh` seal."*

즉 이 4파일의 부재는 **사고가 아니라 아키텍처**다 — `skills/init-ai-ready-project/templates/*.tpl`이
**대상 프로젝트에** 생성하는 산출물이지, 하네스 자신의 자산이 아니다. `git log --all` 전부 빈 출력
(리포 역사상 추적된 적 없음)이 이를 뒷받침한다. 따라서 **일괄 신설은 아키텍처 위반**(하네스가 자기
스캐폴드 산출물을 자기 안에 복제)이며, 정정 대상은 **그 사실을 모르는 skill 텍스트**다.

**★경계의 정확한 외연 (Gate R 정정)**: 이 판정은 **파일명**에 걸리지 *디렉터리*에 걸리지 않는다.
`docs/ai-context/`에는 이미 하네스 소유 추적 파일 5개(`model-policy`·`cross-family-review`·
`memory-policy`·`plugin-pins`·`scaffold-registry`)가 산다. 따라서 이 디렉터리에 하네스 자신의 문서를
두는 것 자체는 정상이며, "부재가 정상"인 것은 **위 5개 스캐폴드 파일명**에 한한다.
그중 `non-obvious.md`는 C14-H가 **하네스용으로 실재하게 만들므로 이 목록에서 빠진다**(§13.5) —
skill 정정의 대상은 **architecture·domain-glossary·deny-patterns·runbook 4개**다.

**범위는 goal §2.8보다 넓다**(C14 Phase R 전수 실측 — grep으로 형제 인스턴스 발견):

| skill | 부재 경로를 지시하는 행 |
|---|---|
| `start-rpi-cycle/SKILL.md` | `:30`(ADR SSOT 서술) · `:41-44`(Phase R C) · `:178-180`(Closeout C-1) |
| `closeout-pr-cycle/SKILL.md` | `:37`(runbook 참조) · `:101-104` |
| `improve-codebase-architecture/SKILL.md` | `:25-26`(전제조건) · `:38-40` · `:118` |
| `init-ai-ready-project/SKILL.md` | `:49-53` — **정정 대상 아님**(생성하는 쪽 = 템플릿 소스) |

**정정 원칙**: 이 skill들은 **하네스에서도, 대상 프로젝트에서도** 돈다. 그래서 경로를 통째로 지우면
대상 프로젝트에서 기능이 준다. → **"실재하는 것만 전달"이라는 조건부 지시**로 바꾼다(경로 목록은
보존하되 부재 시 건너뛴다는 것을 명문화). 이는 이미 일어나고 있는 런타임 동작(서브에이전트는 없는
경로를 조용히 skip)을 **선언으로 승격**하는 것이라 동작 변경이 아니라 **정직성 정정**이다.
`CLAUDE.md §5`는 여전히 `architecture.md`를 전제하므로 **동반 정정**한다.
**`§4`는 정정 불요** — C14-H가 `non-obvious.md`를 실재하게 만들므로 §4가 지시하는 경로가 참이 된다(§13.5).

### §13.5 ★C14-H 판정 — non-obvious는 **`docs/ai-context/non-obvious.md`에 신설**(goal §4.8 그대로)

**★초안 판정을 Gate R이 반증 — 기록으로 남긴다(정직)**: 초안은 "§13.4가 경계를 세웠으니 하네스
non-obvious를 `docs/ai-context/`에 두면 그 경계를 위반한다 → `docs/harness-non-obvious.md`에 신설"이라
판정했다. **틀렸다.** Gate R이 지적한 실물: `docs/ai-context/`에는 이미 **하네스 소유 추적 파일 5개**가
산다(`model-policy.md`·`cross-family-review.md`·`memory-policy.md`·`plugin-pins.md`·`scaffold-registry.md`).
즉 그 디렉터리는 "대상 프로젝트 전용"이 아니라 **하네스의 ai-context SSOT 디렉터리**이고, §13.4의
경계는 *디렉터리*가 아니라 **그 5개 파일명**에만 걸린다. 초안은 §13.4의 결론을 디렉터리 전체로
과잉 일반화해, 요구사항 SSOT(goal §4.8이 `docs/ai-context/non-obvious.md` 실재를 명시)와 어긋나는
경로를 만들 뻔했다. **교훈: 경계를 세운 직후 그 경계를 다른 축으로 확대 적용하지 말 것 — §13.1과
같은 "확인 없이 승격" 계열이다**(이번엔 파일 존재가 아니라 *판정 범위*를 승격했다).

**채택**: `docs/ai-context/non-obvious.md`에 신설한다(goal §4.8·§3 C14-H 문면 그대로).
동거는 모순이 아니다 — 같은 파일명이 두 문맥에서 다른 역할을 한다:
| 문맥 | 경로 | 생성자 |
|---|---|---|
| **하네스 자신** | `~/.claude/docs/ai-context/non-obvious.md` (추적, C14 신설) | 하네스 사이클 Closeout |
| 대상 프로젝트 | `<project>/docs/ai-context/non-obvious.md` | `init-ai-ready-project` 템플릿 |
→ `CLAUDE.md §4`는 경로를 바꿀 필요가 없다(이미 이 경로를 지시한다). §13.4의 skill 정정은
**나머지 4개 파일명**(architecture·domain-glossary·deny-patterns·runbook)에만 적용된다 —
non-obvious는 이번에 실재하게 되므로 그 목록에서 빠진다.

**GAP-012 규약(픽스처 동반)**: non-obvious 등록 항목은 **재현 픽스처 경로를 필수 필드로** 갖는다.
근거 = 이번 사이클 자체가 그 갭의 실증이다(§13.1 — 등록만 있고 재현자가 없으면 다음 사이클이 같은
가정을 반복한다). 첫 실적용 = §13.1의 방법론 실패.

### §13.6 material drift 6건 (C14 Phase R 전건 실물 재현 — 2026-07-28)

| # | 위치 | 실물 | 결함 |
|---|---|---|---|
| M1 | `setup/doctor.sh:353` | lib 파서 4종(`workflow-spawns` 누락) | 이 파일 부재 시 Rule C/C2/C3 **전체 침묵 fail-open**인데 doctor는 "PASS 4개" 초록불. `verify-setup.sh:99`는 5종 → 두 매니페스트 상호 드리프트 |
| M2 | `setup/verify-setup.sh:50` | hook 권한 루프 11개(`surface-model-policy` 부재), 주석도 `11 hook scripts` | L2 정책 hook 권한 소실이 verify-setup 단독 실행에서 미탐(doctor `:332`가 부분 커버) |
| M3 | `hooks/surface-model-policy.sh:159` | `검증자 티어 ≥ 세션 티어(작업자 기준선)가 원칙` | C12와 byte-identical. 인용처 `cross-family-review.md:51`은 이미 max() → **메시지와 SSOT 불일치**. §12.6 교훈③이 겨눈 클래스 |
| M4 | `workflows/rpi-implement.js:6` | `검증자 하향 금지` | 같은 파일 `:20-23`은 max()로 갱신 — **파일 내부 자기모순**. `CONTEXT.md:94`가 `_Avoid_`로 금지한 문구이고 **런타임 meta로 노출** |
| M5 | `README.md:28,66` + 전역 | `11개 hook`(배선 12) · explore-strict 도구에 WebSearch 부재 · `model-policy` 문자열 **0건** | README만 읽는 사용자는 모델 디스패치 거버넌스의 **존재 자체를 모른다** |
| M6 | `hooks/lib/workflow-spawns.js` `findOpts:174-188` | 삼항 opts는 첫 분기만 / 첫 인자에 깊이-0 `{`면 오식별 | 실측: `agent('p', h ? {…model:'opus'} : {…무선언})` → 1행(무선언 소실=SILENT); `agent(()=>{…},{opts})` → `?\t-`(오탐+미탐 양방향) |

**M7(신규, C14 Phase R)**: `setup/tests/failopen-surface.test.sh:19-21` `witness()` cksum 목록도
4종 하드코딩 — `workflow-spawns.js` 누락. 격리 breach가 이 파일에 대해서만 미탐. M1과 동일 클래스의
**3번째 인스턴스**이며, C14-A의 seal이 이것까지 커버해야 클래스가 닫힌다.

### §13.7 ★C14-C 판정 — M6은 **(a) 구현**(삼항) + **(b) 정직 공개**(오식별) 혼합

두 형태의 성격이 다르므로 한 덩어리로 택일하지 않는다:
- **삼항 opts = (a) 구현.** 조건부 모델 선택(`heavy ? {opus} : {무선언}`)은 **이 정책이 규율하는 바로
  그 패턴**이라 현실성이 높고, 미탐 방향이 **마스킹**(준수 리터럴이 무선언을 가림 — §12.6이 "제거
  대상"으로 명명한 클래스가 호출-내 축에서 생존)이다. `findOpts`가 첫 `{`에서 반환하는 대신 **깊이 0의
  모든 `{…}` 후보를 수집**해 각각을 스폰으로 방출하면 해소된다(보수적: 후보가 여럿이면 전부 평가 →
  안전 방향).
- **opts 오식별 = (b) 정직 공개 + 픽스처 봉인.** `agent(()=>{…}, {opts})` 형태를 정확히 판정하려면
  "마지막 인자" 의미론이 필요한데, 인자 경계(깊이 0 콤마) 분할은 파서를 한 단계 더 복잡하게 만들고
  `agent('p')` 1-인자·트레일링 콤마 등 경계 케이스를 새로 연다. **위 삼항 수정이 이 축의 실용 사례
  대부분을 흡수**하므로(후보 수집이 첫-인자 객체와 진짜 opts를 **둘 다** 방출 → 진짜 opts가 관측됨),
  잔여는 파서 헤더·spec·픽스처 3곳에 명시하고 현행 동작을 고정한다.
  → **DOWNGRADE-DECLARED 불요**: 삼항 수정으로 오식별 축도 실질 개선되며(둘 다 "깊이-0 첫 `{`만
  본다"는 같은 뿌리), 남는 잔여는 기능 열화가 아니라 **정적 분석의 알려진 상한**이다.

### §13.8 ★C14-A 판정 — seal은 **디스크=SSOT 대조**(하드코딩 목록 금지)

기존 **seal #24**(`verify-setup.sh:196-201`)가 정확한 템플릿이다 — `DISK_H`(glob) vs `DOC_H`(awk 추출)
→ `comm -23`. 이 관용구를 `hooks/lib/*.js` 축으로 확장한다:
- **신규 seal**: 디스크 `hooks/lib/*.js` ⊆ {`doctor.sh` 21b 목록 ∩ `verify-setup.sh` item-16 목록 ∩
  `install.sh` REQUIRED ∩ `failopen-surface.test.sh` witness}. 하드코딩 목록을 **디스크와 대조**하므로
  다음 lib 신설 때 자동 발화한다(M1·M7이 이 seal 부재의 실증).
- **agents 제외목록 축**(C14-D 재발 방지 — §13.3 ①이 요구하는 seal): `agents/*.md` 중 `^model:`이
  `inherit`이 아닌 agent 이름이 `hooks/surface-model-policy.sh`의 C3 제외 목록에 **포함**되는가(⊆).
  새 wrapper가 하위 모델을 선언하며 추가될 때 hook 갱신 누락을 발화한다. ②③(규칙 전담·동적)은
  코드 상수라 디스크 대응물이 없어 이 seal의 대상이 아니다 — 픽스처가 담당.
- **skill context_paths 축**(C14-J 재발 방지): skill의 `context_paths` 리터럴 경로 ⊆ 실재 파일
  — 단 §13.4가 "부재 시 skip"을 정식 동작으로 승격하므로, seal은 **경로 실재**가 아니라 **조건부
  지시 문구의 존재**를 봉인한다(부재 경로를 무조건 FAIL시키면 대상-프로젝트 겸용 skill이 깨진다).
- seal/드리프트 검사는 **bash 파일옵스만**(node 보간형 금지 — C14-G가 그 위반을 정정하는 사이클이라
  신규 도입은 자기모순).

### §13.9 C14-E — spec §12.4-3(ccs) 거짓 기록 정정

`skills/ccs-delegation`은 **심링크**(`git ls-tree HEAD` = 모드 `120000`, blob 내용 = 링크 포인터 한 줄)
→ `git ls-files skills/ccs-delegation/` 은 빈 출력. C13이 "config.json → config.yaml 정정 착륙"의 근거로
쓴 grep은 **심링크 대상(리포 밖 실파일)** 을 읽은 것이라 리포에는 그 정정이 존재하지 않는다.
**2026-07-28 재확인(읽기 전용)**: 링크 대상 실파일은 `config.json` 0건 / `config.yaml` 4건 —
**로컬 정정 자체는 유효**하나 배포 경로(`git clone`)로는 따라오지 않는다.
→ §12.4-3의 "정정됨" 서술은 **취소**하고 심링크 사실로 대체한다. `scaffold-registry.md:44`는 이미
`(로컬 정션, 비추적)`으로 정직 기술하고 있었다 — **하네스 문서는 알고 있었는데 spec/plan이 무시**했다.
**클래스 교훈**: 리포 내 경로처럼 보이는 심링크가 검증을 오도한다 → `git ls-files` 교차 확인이
grep 증거의 필수 동반자(§13.1과 같은 "확인 없이 가정" 계열, non-obvious 등록 후보).

### §13.10 C14-G — doctor #23 bash-보간형 node (실물 재현)

`setup/doctor.sh:361`은 bash로 보간한 **MSYS 경로**(`/c/Users/…`)를 Windows node의 `readFileSync`에
넘긴다. **2026-07-28 실측**: 그 형태 → `ENOENT`(`catch(e){}`가 삼킴 → 빈 값 → "미설정" WARN).
같은 파일을 **stdin으로 전달**하면 `PCT-present:true WINDOW-present:true`. 즉 **설정돼 있는데 오보**한다.
정정 = stdin/argv 전달(값 미출력 원칙 유지 — 키 존재/숫자 비교만; `settings.json`은 gitignored +
`ANTHROPIC_AUTH_TOKEN` 보유라 `git add` 금지·값 출력 금지).
**메모리 교훈의 기존 위반 인스턴스**("bash-보간형 node = MSYS 미독" — cycle-10 doctor #23 발견분).

### §13.11 C14-F — seal #45 seal-regression 커버리지 공백

뮤테이터 7종(+control) 중 **seal #45 대상이 0개**(`setup/tests/seal-regression.test.sh:100-106` 실측 —
explore 대상은 `mut_explore_write`=seal #41뿐). 따라서 "9/0 통과"가 #45의 발화를 증언하지 않는다.
→ `mut_explore_effort`(xhigh→medium)·`mut_explore_websearch`(WebSearch 제거) 추가.

### §13.12 C14-I 판정 — `verifyModel` args는 **미채택**

§12.1이 남긴 "모드 밖 사용 시 탈출구 부재" 잔여. **미채택 사유**: ①실사용 조건이 "캐리어를 선언 모드
(fable+ultracode) 밖에서 쓸 때"인데 그 자체가 비권장 경로(`model-policy.md` 모드 C/haiku 항) ②채택 시
fable 세션에서 리터럴이 **Rule C2 자기고발**을 유발하므로 "floor 미달일 때만 삽입"하는 조건부 로직이
필수인데, 그 조건 판정은 세션 티어를 알아야 하고 **스크립트는 세션 티어를 모른다**(hook만 안다) →
정적 캐리어에 동적 조건을 넣는 구조적 부정합 ③§12.6 정정으로 이 잔여는 이미 **침묵 → 관측되는 잔여**로
성격이 바뀌었다(모드 밖에서 쓰면 Rule C2가 발화해 사용자에게 표면화된다).
→ **스코프 축소가 아니라 설계 판정**(YAGNI + 구조적 부정합). 잔여는 §12.1 서술 그대로 유지.
