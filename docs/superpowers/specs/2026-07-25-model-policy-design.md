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
| 검증 (게이트/드리프트/적대) | review-strict | **상속** (하향 금지 — 상향 명시는 허용) | **상속** (하향 금지) | ⚠**§12.1→§15.1이 supersede**(현행: 임무-분리 — 준수-확인=작업자 티어/판단-게이트=max(세션,작업자))(2026-07-27): 기준선은 세션 단독이 아니라 `max(세션, 작업자)`. 아래 원문은 C11 시점 기록. 검증자 티어 ≥ **세션**(오케스트레이터) 보장. 실행자를 세션 위로 상향한 경우(예: sonnet 세션+opus 실행)는 검증자<실행자 잔여 — 그때는 검증자도 동반 상향 권고(L1, hook 미검출 수용) |
| 교차 검증 (고-스테이크 closeout) | GPT (codex CLI/CCS) | 기존 규약 | — | cross-family-review.md 소비, 신설 금지 |

- **상향은 항상 허용**(사유 불요), **하향은 검증자에 한해 금지**(⚠**§12.1→§15.1이 supersede**(현행: 임무-분리 — 준수-확인=작업자 티어/판단-게이트=max(세션,작업자)): 기준선은 세션 단독이 아니라 `max(세션, 작업자)`)·실행자는 이 표 자체가 선언이다.
  표 밖 하향(예: 구현을 haiku로)은 DOWNGRADE-DECLARED 동형 선언 필요 — hook Rule A는 부재/fable만
  감지하므로 haiku 명시 등은 L2 미검출(수용 잔여, L1이 담당; "검증자 금지"와 hook 메시지의
  DOWNGRADE-DECLARED 언급은 모순 아님 — 금지의 유일 탈출구가 그 선언+사용자 승인이다).
- 모드 분기: **(A) fable+ultracode** → start-rpi-cycle Phase I (d) Workflow stage1
  `agentType:'execute-strict', model:'opus', effort:'xhigh'|'high'`(heavy|light — plan task가 코드
  변경/TDD 포함이면 heavy, 순수 문서·기계 편집이면 light; 원안 high|medium은 §0 품질-우선 상향으로
  2026-07-26 대체 — 비-ultracode 상속 대비 역전 결함), stage2 `agentType:'review-strict'`
  **model/effort 무지정**(상속) (⚠§15.1이 supersede — stage2 는 `model:'opus'` 명시). goal 원문의 "stage2 GPT 규약 분기" 대안은 **기각(grill 확정)**:
  GPT quota는 상한 규율(cross-family §2 — 당시 사이클당 1회, ⚠§15.5가 2-슬롯으로 supersede)인데
  stage2는 task마다 발화 — 양립 불가(기각 논리는 2-슬롯에서도 동일: N-task ≫ 2슬롯). GPT 검증은
  고정 슬롯 지점 유지(⚠§15.5: 슬롯 1=Gate P 직후·슬롯 2=Closeout — "closeout 1회"는 C12 시점 기록). **(B) fable 비-ultracode** → (a)/(b)/(c) 세 경로 공통 규칙이되, skill 문구는
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
   override, max 포함) / stage2 `agentType:'review-strict'` model·effort 무지정 (⚠§15.1이 supersede — stage2 는 `model:'opus'` 명시).
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
     → ALERT(1세션 1회, rule-c2) — Workflow 경로의 검증자 하향도 Rule B 동형 커버 (⚠§15.1이 supersede — floor 임무-분리).
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

> ⚠**§15.1이 supersede (C16, 2026-08-02)**: 이 절의 일괄 floor는 **임무-분리**로 대체됐다 —
> 준수-확인 임무(Workflow/Rule C2) = 작업자 티어(실행자 부재 시 세션 폴백) / 판단-필요 게이트
> (Agent/Rule B) = `max(세션, 작업자)` 유지. 아래 원문은 C13 시점 기록(genesis) — 논증 이력
> (양 독법 재해결·강제 범위·행 인용 규약)은 여전히 유효한 참조다.

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
`workflows/rpi-implement.js`는 stage1을 `model:'opus'`(:41)로 고정하고 stage2는 무지정(:56, 상속)이다.
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
파라미터가 없다** — `workflows/rpi-implement.js`의 stage2 opts(:55-60)는 `{agentType,label,phase}` 하드코딩이고
args 스키마(:24-34)는 `title/promptVerbatim/files/successCriteria/heavy/effort?`만 받는다. 캐리어를 버리고
인라인 스크립트를 쓰는 건 "canonical이 1차 방어"(§10) 전제를 무너뜨리므로 탈출구로 부적격.

> **행 인용 갱신 (C14, 2026-07-28)**: 위 `:42`/`:57`/`:56-60`/`:25-35` 및 §12.4 의 `:126-162` 는 C13 이
> 캐리어·hook 앞부분에 코드를 삽입하면서 밀려난 값을 실측 재대조한 것이다(직전 기록은 `:38`/`:53`/
> `:52-56`/`:24-31`/`:105-114`). 이 절의 행 인용은 load-bearing(탈출구 부재 논증의 근거)이므로
> **캐리어·hook 편집 시 동반 갱신 대상**이다.
> **C16 재실측 (2026-08-02)**: stage2 `model:'opus'` 명시(§15.1)로 캐리어 주석·본문이 재편돼 위 인용을
> `:41`/`:56`/`:55-60`/`:24-34` 로 갱신(직전 C14 값 `:42`/`:57`/`:56-60`/`:25-35`).
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
3. **`skills/ccs-delegation/SKILL.md`가 `~/.ccs/config.json` 지시** — 실재는 `config.yaml`.
   **★C14 정정(2026-07-28)**: C13 이 "정정 착륙"이라 기록한 것은 **거짓**이다 — `skills/ccs-delegation`
   은 심링크(`git ls-tree HEAD` 모드 **120000**, blob 내용 = 링크 포인터 한 줄)이고
   `git log --all -- skills/ccs-delegation/SKILL.md` 는 빈 출력(리포 역사상 추적된 적 없음)이다.
   C13 의 근거 grep 은 **심링크 대상(리포 밖 비-git 디렉터리)** 을 읽은 것이라 이 정정은 리포에
   존재할 수 없었다(plan 의 `git add …/SKILL.md` 도 `beyond a symbolic link` 로 구조적 실행 불가).
   현 상태(C14 읽기 전용 재확인): 링크 대상 실파일은 `config.json` 0건 / `config.yaml` 4건 —
   **로컬 정정은 유효하나 배포 경로(`install.sh` `git clone`)로는 따라오지 않는다.**
   → 판정: **리포 관점에서는 "갱신 대상 아님"**(비추적 로컬 정션 — `scaffold-registry.md` 가 이미
   `(로컬 정션, 비추적)` 으로 정직 기술). 하네스 문서는 알고 있었는데 spec/plan 이 그것을 무시하고
   리포 파일처럼 행번호까지 지정해 정정을 지시한 것이 설계 결함이었다.
   **클래스 교훈**: 리포 내 경로처럼 보이는 심링크가 검증을 오도한다 → grep 증거는 `git ls-files`
   교차 확인이 필수 동반자(§13.9 · non-obvious 등록 대상 — C14-H).
4. `docs/superpowers/specs/2026-07-13-harness-upgrade-2026-07-design.md:89-97` cross-family 프로토콜 중복
   기술 + 버전 리터럴(§10 중복 SSOT 소지 — durable spec은 genesis-record라 **본문 편집 대신 포인터 주석**).
5. `settings.example.json`에 `ANTHROPIC_*_MODEL` env 전무 → "버전 바인딩 SSOT=settings.json env"가
   이 머신 한정 참(신규 PC에선 폴백 리터럴이 실질 바인딩).
6. `docs/harness-upgrade-2026-07/01-structure-map.md:55` "Wrapper agent 3종 전원 `model: inherit`" —
   실물은 C11 이후 `agents/explore-strict.md:14` = `model: sonnet`. **단 이 디렉터리는 C0~C10 이니셔티브의
   완료 산출물(genesis-record)**이므로 본문 편집 대신 **판정만 기록**: 갱신 대상 아님(이력 보존).

### §12.5 CONTEXT.md 신규/갱신 용어

- **검증자 기준선 (verifier floor)**: 검증자 티어가 넘어야 하는 하한 = `max(세션 티어, 작업자 티어)` (⚠§15.1이 supersede — 임무-분리).
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
사용자에게 표면화된다). 탈출구 부재라는 사실 자체는 유지(수용 잔여) (⚠§15.1이 소멸 — stage2 `model:'opus'` 명시로 전 세션 floor 충족).

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

실측 대조(2026-07-28; **builtin 행은 C15가 2026-07-29 실측으로 교체** — §14.2, 종전 "구조 추론" 표기 해소):

| agentType | frontmatter `model:` | opts.model 부재 시 실제 스폰 모델 | 역류? |
|---|---|---|---|
| `explore-strict` | `sonnet` (`agents/explore-strict.md:14`) | sonnet | **없음** |
| `general-purpose` | **파일 자체 부재**(builtin) | **세션 상속** (p3 실측 + C15 probe 재확인: fable 세션 → `claude-fable-5[1m]`) | **있음** |
| `execute-strict` | `inherit` | 세션 상속 | 있음(Rule C가 담당) |
| `review-strict` | `inherit` | 세션 상속 | floor 판정(Rule C2) |
| `claude` (builtin) | 파일 부재 | **세션 상속** (C15 실측: fable 세션 → `claude-fable-5[1m]`) | 있음 |
| `Plan` (builtin) | 파일 부재 | **세션 상속** (C15 실측: 동일) | 있음 |
| `Explore` (builtin) | 파일 부재 | **★opus 티어 — 상속 아님** (C15 실측: fable 세션에서 `claude-opus-5[1m]`, Workflow+Agent 2경로 일치) | **없음**(오히려 하향) |
| `claude-code-guide` | 파일 부재(플러그인/빌트인) | **★haiku 티어 — 상속 아님** (C15 실측: `gpt-5.6-luna` = 이 머신 haiku 티어 라우팅) | 없음(하향) |

※ C15 실측 방법·신뢰성 근거·바인딩의 버전 의존성(수용 잔여)은 §14.2.

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

### §13.13 C14 교차패밀리(GPT) 적대 리뷰 — 트리아지 결과 (2026-07-28)

`docs/ai-context/cross-family-review.md` §2 규약대로 경로 A(codex CLI, `gpt-5.6-sol`·ultra·priority·
verbosity high·`--sandbox read-only`)로 **사이클당 1회** 실행. 대상 = 본 §13 전문 + C14 plan(94KB, stdin).
GPT 발견 ~20건을 **원문 실측 대조**로 트리아지(GPT는 발견자이지 판정자가 아님 — 규약 §2).

**REAL 6건 — 전부 이 사이클 안에서 정정 착륙**:

| # | 발견 | 실측 재현 | 정정 |
|---|---|---|---|
| R1 | seal #46 이 파일 **전문** grep 이라 자기 설명 주석이 매니페스트를 마스킹 — 실효 목록에서 지워도 GREEN | `grep -n workflow-spawns setup/verify-setup.sh` → `:99`(실효) + `:472`(주석) | `lib_missing_in` 을 **주석 제거 후** 검사로. 뮤테이터 `mut_verify_item16_drop` 신설(주석 남기고 실효만 삭제 → 발화 확인) |
| R2 | seal #47 도 동형 — hook 설명 주석의 `explore-strict` 가 실효 `case` arm 삭제를 가림 | `grep -n explore-strict hooks/surface-model-policy.sh` → `:79`(주석) + `:82`(실효) | 앵커를 **case arm 정규식**으로. 뮤테이터 `mut_c3_exclude_drop` 신설 |
| R3 | **그룹핑 괄호**로 감싼 삼항이 통째 소실 — 마스킹 클래스가 괄호 하나로 부활 | `agent('v', (c ? {…opus} : {…haiku}))` → `?\t-` | `findOptsCandidates` 가 **호출 괄호가 아닌 괄호는 투명 처리**(직전 유의 문자 휴리스틱). 픽스처 203 |
| R4 | 명시 `model:'inherit'` 가 C3 를 빠져나감 — §13.3 표는 `inherit`=세션 상속이라 규정하는데 hook 은 `-` 만 검사 | `{agentType:'general-purpose', model:'inherit'}` → C3 무발화 | 조건을 `'-' 또는 'inherit'` 로. 픽스처 36(E2E) |
| R5 | C14-J 가 `:118`(Phase 4 입력 목록)을 범위로 명시했으나 **미정정** — plan 이 지목한 인스턴스가 잔존 | `improve-codebase-architecture/SKILL.md:116-120` 무조건 목록 | 조건부 주 추가(seal #48 은 파일 단위로 이미 GREEN 이었으나, 지목 인스턴스 자체를 정정) |
| R6 | 오탐이 **순수 안전 방향이 아님** — 가짜 후보가 ①`MAX_SPAWNS` 상한을 소비해 뒤쪽 진짜 위반을 자르고 ②규칙별 dedup 마커를 먼저 소비해 같은 세션의 진짜 위반을 침묵시킴 | 첫-인자 객체 100회 + 진짜 review-strict 위반 → 200행 방출·`review-strict` **0행** | 파서 헤더 한계 공개에 **오탐↔미탐 연결**을 명시(종전 공개는 오탐 결과만 적어 절반이었다) |

**기각 / 수용-잔여 (판정 근거 기록 — 재논의 방지)**:

- "§13.3 이 자기모순(`inherit` 선언인데 상속)" → **용어 정밀화로 수용**: 축은 "선언 유무"가 아니라
  "**하위 모델을 확정 선언하는가**"다. R4 정정이 이 독법을 코드에 물화했다.
- "builtin `Explore`/`Plan`/`claude` 의 상속을 실측 안 함" → **정당한 지적, 잔여로 명시**: `general-purpose`
  만 실측(§13.2 p3)했고 나머지는 "`agents/*.md` 부재 → frontmatter 없음"이라는 **동일 구조**에서 추론했다.
  advisory 환기라 오탐 비용이 낮아 수용하되, 실측 확장은 후속 후보.
- "동적 `model:f()` 을 '무선언'이라 부르는 건 `*` 면제와 비대칭" → **REAL 이나 이번 스코프 밖**: 판정 축을
  3값(`리터럴`/`-`/`동적`)으로 확장하는 **출력 계약 변경**이라 다음 사이클 후보로 이월.
- "상호배타 분기를 동시 스폰으로 취급해 Rule C2 오탐 가능" → **REAL, 수용 잔여**: 정적 분석이 분기
  배타성을 알 수 없다. advisory 이므로 오탐이 차단을 만들지 않는다 — R6 공개에 포함.
- "doctor Test 6 이 stdin 동작을 시험하지 않음" → **부분 수용**: 정적 소스 앵커가 맞다(라이브
  `settings.json` 은 토큰 보유라 테스트가 읽지 않는 것이 제약이다). 다만 "재현 테스트"라는 명명이
  과했다 — 실제로는 **회귀 앵커**다. 비-vacuity 는 pre-fix 소스 대조로 확인했다(RED 재현).
- 카운트 지적 3건 → **문면 오류 인정**: ①Task 3 Step 3 의 `235/239` 는 Step 5b 픽스처를 함께 착륙시킨
  실행 순서를 plan 문면이 앞질러 적은 것(실측은 `235/239` 로 관측) ②"4-way 대조" 서술 옆 주석의
  "3곳 중 2곳"은 **4곳 중 2곳**이 옳다(정정 완료) ③§13.4 의 "위 5개 스캐폴드 파일명"은 열거가 4개뿐이라
  `runbook` 을 포함해 읽어야 한다.

**교훈 (재사용)**: 문자열-존재 seal 은 **자기 설명 주석이 검사 대상을 가린다** — 앵커는 실효 라인
(주석 제거 또는 구문 앵커)에 걸어야 하고, 그 비-vacuity 는 "주석은 남기고 실효만 삭제"하는 뮤테이터로만
증명된다. R1/R2 는 C14 가 *신설한* seal 에서 발견됐다 — 즉 seal 을 늘리는 사이클은 그 seal 자체의
마스킹을 같은 사이클에서 검사해야 한다.

## §14. C15 설계 결정 (in-place 개정, 2026-07-29 — Phase R 실측 + grill 확정)

> C15 goal 원문 = `_goal/c15-contract-and-fitness-goal.md`(비추적). §13.13 이 명시 이월한 2건
> (파서 동적-model 3값 축 · builtin 상속 실측)을 닫는 사이클. 아래는 goal 파일 없이도 재현
> 가능하도록 실측·판정을 영구화한 것 — §11/§13 선례.

### §14.1 ★C15-A 판정 — model 축 3값 확장: 동적 선언 기호 = `*` (agentType 축과 동형)

**결함 (2026-07-29 실측 재현)**: `agent('p',{agentType:'general-purpose', model:chooseModel()})` 과
`agent('p',{agentType:'general-purpose'})` 가 **둘 다 `general-purpose\t-`** 로 방출된다 — "선언 안 함"과
"동적으로 선언함"이 같은 기호로 붕괴. 그 결과 Rule C3 가 동적 model 을 "**model 을 선언하지 않는**
서브에이전트"라며 ALERT 한다 — 메시지 전제가 거짓(오탐). agentType 축은 같은 불확실성을 `*` 로 구분해
C3 에서 **면제**하면서(§13.3 사유 ③ "상속 단언 불가"), model 축은 "부재"로 단정 — 비대칭(GPT [C]4 의
이월 지적, §13.13).

**채택 — 기호는 `*`**: agentType 축과 동일 기호·동일 의미(키 존재·값 비-리터럴)라 계약 독해가 한 규칙으로
통일된다. `-`(키 부재)·리터럴과 충돌하지 않음. 구현 지점은 `workflow-spawns.js` 의 방출부 한 곳 —
`parseProps` 가 이미 `undefined`(키 부재)와 `null`(키 존재·동적, `readValue` 판정)을 구분해 오므로
`mo === undefined ? "-" : mo === null ? "*" : mo` 로 끝난다(파서 내부 로직 변경 없음 — 계약 방출만).

**규칙별 면제 매트릭스 (전 소비자 전수 판정 — 2026-07-29 explore 전수조사)**:

| 규칙 | 현행 (`-` 로 붕괴) | 3값 후 (`*`) | 근거 |
|---|---|---|---|
| Rule C (fable 실행자) | `-` → C_HIT (오탐: "model 지정 없이"가 거짓) | **면제** (`'*'` arm 신설) | 하향 미적용을 단언 불가 — agentType `*` 면제(§13.3 ③)와 동일 원리. advisory 오탐은 순수 안전이 아님(R6: dedup 마커 소비가 진짜 위반을 침묵시킴) |
| Rule C3 (무선언 상속) | `-` → C3_HIT (오탐) | **자동 면제** (조건이 `-`/`inherit` 만 매치 — 코드 무변경) | 동적 선언은 "무선언"이 아님 — C3 판정 축(§13.3 "model 선언의 존재") 그대로 |
| Rule C2 (검증자 floor) | `-` → 세션 티어로 평가 | **면제** (`'*'` arm 신설; 방치 시 `tier_of("*")=0` 으로 떨어져 "0 티어 평가"로 의미 변질 — explore 조사 지적) | floor 미달을 단언 불가. §12.6 "상속=세션 평가"는 *무지정*에 대한 규정이지 동적 선언에 대한 규정이 아님 |
| WORKER_TIER 산정 | `tier_of("-")=0` | `tier_of("*")=0` — **수치 불변** | 동적 실행자는 floor 를 올리지 못함(알 수 없음) — 현행과 동일한 보수 방향 |

**소비자 전수 (계약 변경 동반 갱신 — goal §5-3)**: ①`workflow-spawns.js` 방출부+헤더 계약 서술(:6·:24-25)
②`surface-model-policy.sh` Rule C/C2 case arm(C3 는 무변경) ③`run-all.sh` 계약 주석(:664)+픽스처 186
기대값 `-`→`*` ④`docs/ai-context/model-policy.md:35` L2 계약 서술 ⑤이 spec(§13.7 포인터는 역사 기록
유지, 본 §14.1 이 현행). **소비자 아님(실측 확정)**: README(기호 서술 없음)·seal #45~#48(기호 의미
비앵커 — 파일명 매니페스트·case arm 존재 앵커뿐)·opencode-harness(`git grep spawns` 0건 — `git ls-files`
교차 확인, 미러 파서 부재)·완결 plan 2건(genesis-record).

**잔여 (정직 공개)**: ①리터럴 `model:'*'`/`model:'-'` 는 동적/부재와 구분 불가 — agentType 축의 기존
잔여와 동형(기호 충돌 클래스; 실사용 모델명이 아니라 수용) ②변수 opts(`agent('p', OPTS)`)는 여전히
`?`/`-`(파서 헤더 기지 한계 — OPTS 안의 model 은 관측 불가) ③상호배타 삼항 분기의 동시-스폰 취급
(§13.13 수용 잔여) 불변.

### §14.2 ★C15-B — builtin agentType 상속 실측 (§13.3 표의 "구조 추론" 행 교체)

**방법 (2026-07-29, fable 세션 = claude-fable-5[1m], CC 2.1.x, CLIProxy 라우팅 환경)**:
각 agentType 을 **model 무선언**으로 스폰해(상속 기본값이 측정 대상) 시스템 프롬프트의 모델 문장을
**verbatim 인용**하게 함 — "자기지식으로 추측 금지, 문면 인용만" + 도구 사용 금지. 2경로 교차:
Workflow `agent()`(6종 병렬) + Agent 도구(`Explore` 재현). **방법 신뢰성 근거(대조군 2중)**:
①`explore-strict`(frontmatter `model: sonnet` = 디스크 ground truth) → "Sonnet 5 / claude-sonnet-5[1m]"
정확 일치 ②`general-purpose` → fable 상속 = §13.2 p3 선행 실측과 일치.

| agentType | 관측 모델 | 판정 |
|---|---|---|
| `claude` | claude-fable-5[1m] (=세션) | **세션 상속 — 실측 확정** (종전 추론과 일치) |
| `general-purpose` | claude-fable-5[1m] (=세션) | 세션 상속 — p3 재확인 |
| `Plan` | claude-fable-5[1m] (=세션) | **세션 상속 — 실측 확정** (종전 추론과 일치) |
| `Explore` | **claude-opus-5[1m] (≠세션)** | **★비-상속 — 추론이 틀렸다.** CC 가 자체 모델 바인딩 보유(Workflow·Agent 2경로 일치) |
| `claude-code-guide` | **gpt-5.6-luna (≠세션)** | **★비-상속** — haiku 티어 바인딩(이 머신 CLIProxy 라우팅에서 haiku→luna). agents/*.md 부재인데도 하위 티어로 돔 |
| `explore-strict` (대조군) | claude-sonnet-5[1m] | frontmatter sonnet — 방법 검증용 |

**교훈**: "`agents/*.md` 파일 부재 → frontmatter 없음 → 세션 상속"이라는 §13.3 의 구조 추론은
**builtin 2종(Explore·claude-code-guide)에서 틀렸다** — CC 바이너리가 파일시스템 밖에서 자체 바인딩을
가질 수 있다. 실측 없는 구조 추론을 정책 표에 올리면 안 되는 실증(§13.1 "확인 없이 승격" 계열).

**Rule C3 함의 — 제외목록은 불변, 메시지만 hedge (설계 판정)**: 실측상 `Explore`/`claude-code-guide`
스폰은 역류가 없으므로 C3 ALERT 의 "세션 모델을 상속" 전제가 이 CC 버전에선 거짓(오탐 클래스).
그러나 제외목록에 추가하지 **않는다** — 목록의 채택 사유(§13.3)는 정적·디스크-유도 사실(①frontmatter)
·규칙 분담(②)·논리 필연(③)인데, 이 바인딩은 **CC 버전-의존 경험 사실**이라 바이너리 업그레이드로
조용히 뒤집힐 수 있고, 그때 제외는 미탐이 된다(advisory 오탐 < 침묵 미탐). 대신 C3 메시지에
"일부 builtin 은 CC 자체 바인딩으로 하위 티어에 돌 수 있음(spec §14.2 실측)" hedge 1줄을 넣어 전제
과잉단정을 제거한다. **바인딩의 버전 의존성 = 수용 잔여**(재실측 트리거: CC 메이저 업그레이드).

### §14.3 ★C15-E 판정 — 재개(resume)는 **신설 마커 없이 기존 자산 + SessionStart 1줄 주입으로 채택**

**요구(사용자, C14 중단 2회 이월)**: 예기치 못한 중단 후 다음 세션이 작업을 이어받는 hook.

**판정 = 채택(경량) — 세 질문에 대한 근거**:
1. **어떤 이벤트가 재개 신호를 잡는가 → SessionStart, 실런타임 증거 확보**: ①이 세션 자체가
   superpowers 플러그인의 SessionStart 컨텍스트 블록("SessionStart hook additional context")을 수신 —
   SessionStart stdout→모델 컨텍스트 채널이 **이 머신·이 CC 버전에서 실제 작동함을 라이브 관측**
   (합성 stdin 아님 — cycle-40 교훈 충족). ②반면 `session-start-audit.sh` 의 기존 `[plan] active plan: N`
   줄은 **stderr** 라 사용자에게만 보이고 모델 컨텍스트에 없음(이 세션 컨텍스트에 그 줄 부재로 실측) —
   즉 "재개 신호가 이미 있는데 모델에 도달하지 않는 것"이 현행 갭의 정체다. ③SessionStart cwd =
   CLI 실행 디렉터리(cycle-40 확정) = plan 이 사는 프로젝트 루트 — 이 용도에는 정확히 맞는 필드.
2. **작업 상태의 표현 → 기존 자산으로 충분, 신설 없음**: active plan(Status 헤더) + 미체크 체크박스가
   이미 "중단된 작업"의 완전한 표현이다(RPI 게이트가 이미 이것에 의존). 별도 재개 마커는 이중 장부 —
   plan 과 어긋나는 순간 거짓 재개 신호가 된다. **기각**.
3. **위험한 재개의 배제 → 자동 재실행이 없으므로 구조적으로 배제**: 주입되는 것은 "active plan 이 있다,
   열어서 재개 여부를 판단하라"는 **권고 1줄**뿐이다. 파괴적 연산 재시도 여부는 plan 을 읽은 모델·사용자
   판단에 남는다(자동 재개 아님). fail-open: 기존 hook 의 advisory 불변식 그대로(실패 시 무출력·exit 0).

**구현(선택 요건이나 채택 — ~10줄)**: `session-start-audit.sh` 의 기존 active-plan 카운트 블록에서
active ≥1 이면 **stdout** 으로 `[resume]` 1줄(plan 파일명 + 미체크 박스 수 + "이전 세션 중단 작업일 수
있음 — plan 을 열어 재개 여부 판단") 방출. SessionStart 는 stdout 이 컨텍스트로 주입되는 문서화된
채널이고 위 ①이 라이브 실증. 픽스처: stdout 내용 단언(active plan 존재 시 `[resume]` 존재, 부재 시 부재).
※ stderr 줄은 사용자용으로 유지(이중 채널 — 목적이 다름).

### §14.4 C15-C — fable+ultracode 라이브 fitness 대차 (2026-07-29~08-01 실측, 최종)

관측 프로토콜: runlog 오프셋(2026-07.jsonl 6881줄 / 2026-08.jsonl 0줄) 이후의 `surface-model-policy`
레코드 전수 + **라이브 입력의 합성 재생**(동일 스크립트를 hook 에 직접 주입) 대조. 사이클은 자연
실행(fitness 를 위한 인위 위반 0 — goal §5-9 준수).

**규칙별 발화 대차 (라이브 도구 호출 한정 — 픽스처 실행분 제외)**:

| 규칙 | 라이브 발화 | 기대 | 판정 |
|---|---|---|---|
| Rule A | 0회 | 0회 — execute-strict 를 Agent 경로로 위임한 적 없음(구현 전량 canonical carrier 경유) | **일치** — 모드 (A) 준수의 자연 결과 |
| Rule B | 0회 | 0회 — review-strict 위임 3회 전부 model 무지정(상속) | 일치 |
| Rule C | 0회 | 0회 — canonical carrier stage1 = `model:'opus'` 리터럴 | 일치 |
| Rule C2 | 0회 | 0회 — carrier stage2 무지정(상속) = fable 세션 floor 충족(§12.1 표 1행) | 일치 |
| Rule C3 | 0회 | 0회 — C15-B probe(인라인 Workflow)의 6스폰은 `agentType: t`(동적)=`*` 면제(§13.3 ③) | 일치 — **면제 설계의 정상 작동이지 미탐 아님** |

**미탐/오탐 판정의 근거 (무발화 ≠ 무작동 증명)**: hook 은 ALERT 시에만 runlog 를 남기므로 라이브
무발화만으론 "돌았는데 침묵"과 "안 돌았음"이 구분 안 된다. 2중 대조: ①같은 세션에서 다른 PreToolUse
hook(enforce-rpi-cycle)이 실 sid 로 발화 기록 — 배선 자체는 라이브 작동 ②라이브 입력 2건(probe
스크립트·control)을 hook 에 **재생**: probe→SILENT 재현, 리터럴 `general-purpose` control→**ALERT**
— 판정 경로 생존 실증. 잔여: "그 순간 CC 가 hook 을 실제 호출했는가"는 컴플라이언트 호출이 무기록이라
직접 증거 없음(수용 잔여 — ALERT 외 verdict 도 기록하는 확장은 로그 bloat 대비 이득 없어 미채택).

**advisory 행동 변화 (goal §3-C-3, 정직 기록)**: 이 사이클에서 advisory 가 낼 ALERT 자체가 0(위반
없음)이라 "환기→행동 교정" 사례는 관측 기회가 없었다 — L2 의 이 축은 이번 사이클에서 **미검증**이며
"작동함"으로 기록하지 않는다. 관측된 것은 오탐 0(컴플라이언트 실행에 소음 없음)뿐.

**canonical carrier (goal §3-C-4)**: Phase I 구현 4 task 전부 `Workflow({scriptPath:
"C:/Users/12132/.claude/workflows/rpi-implement.js", args:[...]})` — **canonical 경유, 인라인 이탈 0**.
비-구현 Workflow 1건(C15-B probe)은 인라인이나 구현 아님(관측 프로브 — §10 의 canonical 의무는
Phase I 구현 스테이지 대상). 실측 부수 확인: 도구는 `scriptPath` 의 슬래시 방향 무관(C:/ 표기 작동).

**신규 결함 등록 (C15-C 기준 2항)**: 미탐·오탐 신규 발견 0건. 단 사이클 중 세션이 장기 정지 후
재개된 사례 1회(2026-07-29→08-01) — C15-E 의 [resume] 주입이 겨눈 바로 그 시나리오가 사이클 내에서
재현됐고, 재개는 사용자 프롬프트+active plan 로 수행됐다(신설 [resume] 줄은 다음 세션부터 작동).

### §14.5 C15 교차패밀리(GPT) 적대 리뷰 — 트리아지 (2026-08-01)

`cross-family-review.md` §2 규약 경로 A(`gpt-5.6-sol`·ultra·verbosity high·read-only·**fast 미사용** —
§1-2 철회 준수). 대상 = §14 전문 + 사이클 전체 diff(913935b..HEAD, 33KB stdin). 발견 15건을 **전건
원문 실측 재현**으로 트리아지(GPT는 발견자이지 판정자가 아님). 실측 주의: X2 재현은 파일에 리터럴
`d` 바이트가 실제로 들어가야 한다 — bash `printf`/따옴표 계층이 이스케이프를 먼저 삼키면
"재현 안 됨"으로 오판한다(2번 오쳤음 — od -c 로 바이트 확인 후 확정).

**REAL — 이 사이클 내 정정 (T5a 파서 5건 + T5b hook/문서 8건)**:

| # | 발견 | 실측 재현 (HEAD) | 정정 |
|---|---|---|---|
| X1 | shorthand `{model}` 이 `-`(키 부재)로 붕괴 + shorthand 중복 키가 LWW 위반(stale `opus` 유지) | `general-purpose\t-` / `execute-strict\topus` | `parseProps.flush` 에 콜론-없는 세그먼트의 `agentType`/`model` 식별자 인식(→동적 `*`). 픽스처 206·207 |
| X2 | 식별자 이스케이프 키(`model`)가 미인식 — 문자열 키만 디코드하고 bare 키는 raw | `general-purpose\t-` / dup 조합 `execute-strict\topus` | `readKey` bare-식별자에 `\uXXXX` 디코드. 픽스처 208 |
| X3 | 앞 프로퍼티의 템플릿 보간 닫는 `}` 가 mask 에 잔존 → parseProps 깊이 -1 → 이후 키 전멸 | `label:\`t-${x}\`` 선행 시 `?\t-` | `lex()` 의 fromTmpl 복귀 `}` 를 blank(여는 `${` 와 대칭). 픽스처 210 |
| X4 | `['model'+'X']` 를 `model` 로 오해소 — 리터럴이 bracket 전체를 소진하는지 미검증 → 날조 `opus` 행이 Rule C 침묵 | `execute-strict\topus` (실제 키는 modelX) | `readKey` bracket 분기에 전체-스팬 검증(잔여 토큰 있으면 null). 픽스처 209 |
| X6 | 그룹핑 괄호 리터럴 `model:('fable')` 이 `*` 로 과분류 → **Rule C/C2/C3 실위반이 ALERT→SILENT 회귀**(base 는 `-` 붕괴라 발화했음) | `execute-strict\t*` (base: `execute-strict\t-`) | `readValue` 그룹핑 괄호 unwrap(정적 확정 리터럴로 복원). 픽스처 211. **3값 확장이 만든 유일한 실회귀 클래스 — 과분류의 비용이 base 와 반대 방향** |
| X8 | C3 hedge 가 어느 픽스처에도 내용-앵커 없음(additionalContext 존재만 검사) — hedge 원복해도 전량 GREEN | 실측 확인(픽스처 grep 대상 없음) | `test_smp_hedge` 40 신설(메시지 본문 '자체 바인딩' 단언) — R1/R2 교훈("신설 표면은 같은 사이클에서 마스킹 검사") 의 픽스처판 |
| X9 | resume 픽스처가 `[resume]` 접두만 검사 — 파일명·카운트·exit 0·완전 무출력 미단언 | 실측 확인 | `test_ssa_resume` 강화(패턴/EMPTY/exit0) |
| X10 | 다중 active plan 시 첫 파일명 + **전체 합산** 카운트 — 지목 파일에 대해 거짓 수치 | a.md(1)+b.md(2) → "a.md (미체크 3)" | 첫 plan 단독 카운트 + `외 N개 활성 plan` 서픽스 |
| X11 | 서브디렉터리 cwd(`<repo>/src`)에서 plans 게이트 미통과 → [resume] 구조적 미발화 | 게이트 `[ -d "$CWD/docs/superpowers/plans" ]` 실물 | `resolve_project_root` 앵커(PLAN_ROOT) — cycle-42 가 enforce 훅에 이미 배선한 SSOT 재사용 |
| X12 | 체크박스 regex `^\- \[ \]` 가 들여쓰기·`*` 불릿 미집계 | 실측 확인 | `^[[:space:]]*[-*] \[ \]` 확장. 펜스 내 예시 과계수는 수용 잔여(advisory 수치) |
| X13 | source 미판별 — `/clear`·post-compact SessionStart 에도 "이전 세션 중단" 오주입 | 게이트 `ACT_N>=1` 단독 실물 | source 게이트: `startup` 또는 필드 부재(구 CC fail-open)만 방출. 픽스처 10(compact 억제) |
| X14 | model-policy.md 신규 문면 "두 축 모두 3값: 리터럴/`-`/`*`" — agentType 부재 기호는 `?` 인데 `-` 로 오기(**C15 자신의 T3 문면 오류**) | 실물 확인 | 축별 분리 서술(agentType `?` / model `-`) |
| X15 | C3 메시지·CONTEXT.md·model-policy.md 가 "세션 모델을 상속" **전칭 단정** 유지 — §14.2 가 반증한 전제를 hedge 괄호가 부정하는 자기모순 | 실물 확인 | 본문을 "통상 상속"으로 완화 + 예외 2종 명시(3문서 동기) |

**수용-잔여 / 부분 채택 (판정 근거 기록 — 재논의 방지)**:

- **X5 (혼합 삼항 `c ? {리터럴} : OPTS` 의 변수 분기 소실)** — 결함 실재(재현: `general-purpose\t*`
  1행만, OPTS 분기 무행). 단 **후보-존재 시 폴백-미발동은 C14 이전부터의 구조**(후보 수집기의 알려진
  상한)이고, 완전 해소는 인자-경계 의미론(§13.7 이 기각한 그 축)을 요구한다. base 대비 회귀 부분
  (그 1행이 `-`→`*` 로 바뀌어 C3 가 침묵)은 실재하나, 같은 입력에서 base 의 ALERT 는 **리터럴 분기를
  오판**한 우연 발화였다(동적 model 선언 분기를 "무선언"이라 했음 — C15 가 제거한 바로 그 오탐).
  → 파서 헤더 + 이 절에 정직 공개, 미구현. 탐지 우회 의도가 아닌 자연 코드에서 희귀 형태.
- **X7 (픽스처 37 이 Rule C `'*'` arm 자체를 앵커하지 않음)** — 지적 사실(arm 삭제해도 fallthrough
  `tier_of("*")=0≠4` 로 37 GREEN — 실측 확인). 단 37 이 봉인하는 것은 **행동**("동적 선언은 발화하지
  않는다")이고, 그 행동은 arm 을 위반 목록(`-|inherit|'*'`)에 넣는 회귀를 잡는다. arm 은 fallthrough
  의존을 명시로 바꾼 방어적 중복(의도 문서화)이며 제거해도 행동 불변 → 픽스처는 비-vacuous(행동 축),
  arm 은 belt-and-braces 로 유지. §14.1 의 "arm 신설" 서술은 "명시화"로 읽을 것.
- X6 의 "C2 `continue` 배치" 등 bash case 의미론 지적 — 확인 결과 문제 없음(첫 arm 매치 시 후속 arm
  미평가, `continue` 는 while 루프로 정확히 탈출). 기각.

**교훈 (재사용)**: ①**출력 계약에 값을 추가하면 "과분류의 방향"이 뒤집힌다** — 2값 시대의 `-` 붕괴는
안전 방향(무선언 취급→발화)이었지만, 같은 코드가 3값에서 `*` 로 흐르면 면제 방향이 된다(X6). 계약
확장 시 **기존 붕괴 경로 전수를 새 기호의 의미로 재감사**해야 한다 — 방출부 한 줄만 보면 안 된다.
②정적 파서의 "동적" 판정은 **"확정 불가"의 증명이 아니라 "우리 파서가 못 읽음"의 자백**이다 —
그룹핑 괄호·shorthand·식별자 이스케이프처럼 정적으로 확정 가능한 형태가 섞여 있다. 면제 기호를
소비하는 규칙은 이 차이를 전제로 설계할 것.

## §15. C16 설계 결정 (in-place 개정, 2026-08-02 — Phase R 실측 + 블라인드 A/B + grill 확정)

> C16 goal 원문 = `_goal/c16-review-economics-goal.md`(비추적). 아래는 goal 없이 재현 가능하도록
> 근거를 영구화한 것 — §11/§13/§14 선례. 주제 = 리뷰 경제성: per-layer 수율 계량 표준화 ·
> stage2 검증자 floor의 임무-분리(§12.1 supersede) · 내부 발견력 A/B · 교차패밀리 2-슬롯.

### §15.0 근거 — C15 per-layer 리뷰 수율 실측 (축적 1호 행; 세션 아티팩트 usage 합산)

| 검문 층 | 출력 토큰 | 실발견(내용 결함) | 성격 |
|---|---|---|---|
| Gate R (review-strict, fable) | 71k | 0 | 확인 |
| **Gate P #1 (fable)** | 84k | **3 (코드 전 차단)** | **발견** |
| Gate P #2 재심 (fable) | 83k | 0 | 확인 — 전체 재리뷰 낭비 |
| stage2 ×6 (fable, 상속) | 273k | 0 (프로세스 FAIL 1 = RED 증거 강제) | 준수 확인 |
| senior (fable) | 80k | 0 (Minor 3) | 확인 |
| drift (fable) | 47k | 0 | 확인 |
| GPT 교차 (말미 1회) | (외부) | **REAL 13** | **발견** |

내부 637k 중 87%가 확인·프로세스 강제. 4사이클 연속(C11=9·C12=25·C13=17·C15=13) 내부 전 통과 후
GPT REAL. 단 confound: stage2 임무는 "준수 확인"이었지 "발견"이 아님 — §15.2 A/B가 분리했다.
stage2의 억지 효과(TDD RED 증거 강제 등)는 분리 측정 불가로 수용 — 검증 *횟수* 축소는 스코프 밖(goal §1-5).

### §15.1 ★C16-D — 검증자 floor 임무-분리 (C13 §12.1 일괄 `max(세션,작업자)`의 의식적 supersede)

**결정**: floor를 검문의 **임무별로 분리**한다.
- **준수-확인 임무 (Workflow 경로 = canonical carrier stage2, Rule C2)**: floor = **작업자 티어**
  (실행자 부재/전량-동적 스크립트는 **세션 티어 폴백** — 보수 유지). 근거: §15.0 — stage2는 준수-확인
  임무에서 내용 발견 0(C15), 이 임무에 세션 최고가 티어를 지불할 데이터 근거가 없다. 기대 효과:
  리뷰 토큰 최대 슬라이스(stage2 43%)의 단가 절반 + 대기 단축.
- **판단-필요 게이트 (Agent 도구 경로 = Gate R/P·senior·drift, Rule B)**: floor = **`max(세션, 작업자)`
  유지 — Rule B 불변**. 근거: Gate P가 유일한 내부 발견 층(§15.0) — 여기의 티어는 건드리지 않는다.
- 하한 불변식(goal §5-12): 어떤 임무에서도 **검증자 < 작업자 금지** — 완화는 "세션 축 제거"까지다.

**구현 형태 (Rule C2 — 슬롯1 S1/S2 정정 반영)**: `WORKER_TIER` 초기값을 세션 티어 → **0**으로,
1패스의 실행자 티어 평가를 **3분기**로: 리터럴 → `tier_of` / `-`·`inherit` → **세션 티어**(정의적 —
상속=세션 평가는 검증자와 동일 규칙) / `*`(동적) → **세션 티어**(보수 상계 — 런타임 해소값을 배제할 수
없음). **미지-티어 리터럴(`tier_of`=0, 예: gpt-커스텀)도 세션 상계**(슬롯2 F4 정정 — 초안은 0 유지라
"미지 리터럴 단독 실행자" 스크립트가 실행자-부재로 오분류돼 세션 폴백이 이중 적용될 뻔; 0 상계는 판별-불가
실행자가 floor 를 끌어내리지 못하게 하는 동일 보수 원칙, 픽스처 48 앵커). 2패스 floor =
`WORKER_TIER>0 ? WORKER_TIER : WF_TIER`(실행자 전무 시 세션 폴백). 검증자 측의
무지정(상속)="세션 티어로 평가"는 **불변**(C13 Closeout 정정 유지).
※ **슬롯1 정정 이력(S1/S2)**: 초안은 1패스를 `tier_of` 단독으로 두어 상속(`tier_of=0`)·동적(0) 실행자가
floor 기여 0이었다 — 혼합 스크립트(상속 실행자+하위 리터럴 실행자)에서 floor가 실제 작업자 아래로 붕괴해
"검증자<작업자 금지" 하한 불변식을 위반(예: opus 세션·inherit 실행자(실제 3)·sonnet 실행자·sonnet 검증자
→ 초안 floor 2=침묵). 상속·동적을 세션 티어로 평가하면 관측-불가 실행자가 있는 한 floor≥세션이 유지되어
구 동작과 동일(보수)하고, 완화는 **전 실행자가 리터럴로 관측될 때만** 적용된다 — 완화의 전제(작업자
티어를 안다)와 정확히 일치.

**완화가 새로 침묵시키는 경로 전수 (C15 교훈 ① — 방향 반전 재감사, goal §5-3)**:

| 경로 (Workflow, Rule C2) | 구 판정 | 신 판정 | 정당성 판정 |
|---|---|---|---|
| fable 세션·opus 실행자·opus 검증자 | ALERT(자기고발) | **SILENT** | 정당 — 새 정책의 목표 케이스. §12.1 "2패스 오답 ②" 자기고발 클래스 소멸 |
| fable 세션·sonnet 실행자·sonnet 검증자 | ALERT | SILENT | 정당 — 검증자==작업자(임무 정합). 실행자 sonnet 자체는 L1 per-task 선언 규율 몫 |
| opus 세션·sonnet 실행자·sonnet 검증자 | ALERT | SILENT | 동상 |
| fable 세션·haiku 실행자·haiku 검증자 | ALERT | **SILENT** | **§12.1 ①(haiku 실행자 구멍)의 Workflow 준수-확인 경로 한정 재개방 — 정직 공개.** §5-12 하한은 충족(검증자==작업자). 실행자 haiku 자체가 L1 위반(표 밖 하향=DOWNGRADE-DECLARED 요구)이고 그 축은 C16 전에도 L2 미탐(Rule C는 부재/inherit/fable만 감지). 판단-게이트 경로(Rule B)는 max 유지라 ① 원 맥락 불변 |
| fable 세션·sonnet 실행자·**opus 검증자**(작업자<검증자<세션) | ALERT | **SILENT** | 정당 — 검증자>작업자(하한 초과 충족). 슬롯1 S3이 표 누락 지적 → 보강: "검증자≥작업자 & <세션" 대역 전체(fable·haiku실행자·sonnet/opus검증자, opus 세션 등가 조합 포함)가 이 행과 동류로 새로 침묵하며, 전부 하한 충족이라 정당 |
| 실행자 부재·검증자 하향(예: fable·sonnet 검증자 단독) | ALERT | **ALERT (불변)** | 세션 폴백이 세션 축 보존 — 작업자 미상 시 보수 유지 |
| 상속/동적 실행자 혼재·하위 검증자 | ALERT | **ALERT (불변)** | 슬롯1 S1/S2 정정 — 상속·동적 실행자를 세션 티어로 평가하므로 관측-불가 실행자 존재 시 floor≥세션 유지(완화는 전-리터럴 스크립트에만 적용) |
| sonnet 세션·opus 실행자·상속 검증자(=2) | ALERT | **ALERT (불변)** | floor=작업자 3, 상속=세션 2<3 — C13 GPT C1/C3 정정 보존 |
| 검증자 < 작업자 (전 조합) | ALERT | ALERT (불변) | §5-12 하한. ※MAX_SPAWNS 절단 뒤 실행자는 관측 밖(슬롯1 S4) — 상한 자체는 C15 이전부터의 수용 잔여이나, C16 완화로 "절단된 상위 실행자+관측된 하위 실행자" 조합의 침묵이 커지는 방향성을 정직 부기(파서 헤더 자인 — 자연 코드에서 200+ 스폰은 비현실적 규모라 수용) |

※ **임무 축의 정의적 한계 (슬롯2 F3 — 수용 잔여, 정직 부기)**: 임무-분리는 "Workflow 경로 = 준수-확인"을
**경로 정의로** 선언한다(§15.1 서두 — canonical carrier 가 Workflow 의 규정 사용처). ad-hoc Workflow
스크립트에 판단-게이트급 review-strict 를 실으면 hook 은 임무를 판별할 신호가 없어 작업자-floor 로
평가한다(fable 세션·sonnet 실행자·opus 검증자 = 신 SILENT / 구 ALERT — 위 표 S3 대역과 동일 산식).
구조 해소는 scriptPath 신뢰 목록 또는 mission 표식 계약을 요구 — L2 는 tool_input.script 텍스트만 받아
scriptPath 대조 불가(hook 입력 계약). 방어선: L1 규범(판단-게이트는 Agent 경로로 — start-rpi-cycle
Gate R/P/senior/drift 전부 Agent 경로 고정)+canonical carrier 가 Workflow 의 규정 사용처라는 §10 규약.
잔여 수용 조건 = 판단-게이트를 Workflow 로 감싸는 것 자체가 규약 위반(그 시점에 L1 이 잡을 계층 오류).

**픽스처 함의 (Phase R 실측 — 기존 기대값 반전 0)**: 폴백 설계에서 기존 C2 픽스처 전수(smp 14·15·16·
26·27·28·29) 재계산 결과 전부 기대값 유지 — 14(fable·실행자無·sonnet검증자)=폴백 4→ALERT / 26·27·28
(sonnet·opus실행자)=floor 3→ALERT / 29·15·16 SILENT. goal §3의 "기대값 반전" 예상과 달리 반전은 0이고,
행동 변화는 **신규 케이스**(fable·opus실행자·opus검증자 = SILENT가 새 정답; 구 코드는 ALERT)와
canonical carrier **4세션 각각의 E2E 픽스처**(fable/opus/sonnet/haiku 전부 무발화 — 구 carrier에선
sonnet/haiku가 ALERT; 슬롯1 S12 지적으로 2개→4개 확정)로 포착된다. 신규 RED 픽스처가 이 두 클래스를
앵커할 것. 기존 26의 주석(`max(2,3)=3`)은 supersede된 산식 표기라 작업자-floor 표기로 동반 갱신(S11).
※ 완화 후 티어(opus)에서의 준수-확인 품질 자체는 미실측(S36) — layer-yield 3사이클 축적이 그 재심
트리거다(§15.3의 존재 이유; 열화 관측 시 floor 원복이 역-supersede 경로).

**부수 효과 — canonical carrier "탈출구 부재" 잔여 소멸**: stage2에 `model:'opus'`(=stage1과 동일 티어)
명시가 새 정답이 되므로, §12.1 수용 잔여 "모드 밖(sonnet/haiku 세션) 사용 시 탈출구 없음"이 해소된다 —
opus 검증자(=작업자 티어)는 어느 세션에서도 새 floor 충족. 캐리어 적용 범위 주석의 "모드 (A) 전용 +
sonnet/haiku 세션 사용 금지" 경고는 완화 서술로 개정. §12.1의 행 인용(:42/:57/:56-60/:25-35)은 캐리어
편집으로 shift — C14 규약대로 동반 갱신.

**동반 갱신 전수 (Phase R explore 전수조사 + 슬롯1 S7~S11/S32/S33 보강)**: `workflows/rpi-implement.js`
(stage2 model 명시 + 헤더 주석 :3·:6·:15·:20-23 + meta detail)·`hooks/surface-model-policy.sh`(Rule C2
판정식 + 메시지 + 주석 :4·:59·:93-96·:132)·`docs/ai-context/model-policy.md`(:19 검증 행·:22·:35 L2)·
`docs/ai-context/cross-family-review.md` §3(:50)·`CONTEXT.md` 「검증자 기준선」(완료) **+ :85 「실행자
하향 위임」·:89 「역할×모델 매트릭스」의 구 floor 서술 2곳(S9)**·`skills/start-rpi-cycle/SKILL.md` (d)
경로 **+ :132 인라인 규약("stage2 무지정" — S8)**·`setup/verify-setup.sh` #45 주석 ③ **+ ⑨ conjunct의
stage1-앵커 정밀화(S5: `model: 'opus'` 무스코프 grep이 stage2 리터럴 추가로 vacuous해짐 → stage1 라인
문맥 앵커로 강화)**·`README.md`(:39·:56)·본 spec §12.1 supersede 포인터 + §3 매트릭스 포인터 **+ §3
:115·§10 :250(stage2 무지정 서술)·§10 :267(Rule C2 세션-기준 서술)·§12.5 :576(용어 정의)·§12.6 :642
("탈출구 부재 유지" — §15.1이 소멸시킴) 각각에 §15.1 supersede 포인터(S10/S32/S33)**·
`docs/ai-context/scaffold-registry.md` **:24(hook 행)·:48(carrier 행) 서술 + Drift Seals 헤딩·표에 #49
등재(S7)**·픽스처(위 신규 2클래스 + canonical 4세션 + cases.tsv + README 카운트) **+ seal-regression에
#49 변이 추가(S6 — §13.13 "seal 신설 사이클은 그 seal의 마스킹을 같은 사이클에서 검사" 규약)**.
※ Rule B(:163-174)는 **불변** — 판단-게이트 floor 유지의 무회귀 증거는 기존 smp 03/04 픽스처.

### §15.2 ★C16-C — 내부 발견력 블라인드 A/B (2026-08-02 실행·판정)

**설계**: C15 GPT 리뷰의 대상이었던 역사적 diff `913935b→e96675b`에 대해, GPT와 동일 적대 프롬프트
(`Temp/c15-review-prompt.txt` 원문 재사용 — refute-by-default·defects only·원문 인용 강제·카테고리
A~F) + 블라인드 제약(대상 열람은 `git show <pinned>:` 경유만·`_goal/`/`projects/`/e96675b 이후 커밋
금지)으로 **fable review-strict 1회** 실행. 발견을 §14.5 X1~X15(REAL 13)와 메인이 사후 대조.

**블라인드 준수 증거**: 에이전트가 실행한 git show 명령 전수 보고(핀 2커밋 한정·작업트리 Read 0회·
금지 경로 0회) + 입력의 spec §14 추출본은 e96675b 시점(§14.5 부재 — grep 'X1|재발견' 0건 확인).
**잔여 오염 가능성(정직 부기)**: 같은 리포·같은 모델 계열이라 완전 격리는 불가(n=1, 방향 신호이지
통계 증명 아님). 비용: 출력 ~118k 토큰·도구 31회(참고: C15 senior 80k과 동급).

**결과 — 재발견 7/13 + 수용잔여 1 + 신규 4** (판정 기준 ≥4/13 상회):

| GT | 내용 | 블라인드 재발견 |
|---|---|---|
| X1 | shorthand `{model}` `-` 붕괴 | **✓** (B-X1) |
| X2 | 식별자 이스케이프 키 미인식 | ✗ |
| X3 | 템플릿 닫는 `}` mask 잔존 | ✗ |
| X4 | computed bracket key 오해소 | ✗ |
| X6 | 그룹핑 괄호 `*` 과분류 ALERT→SILENT | **✓** (B-X2) |
| X8 | C3 hedge 픽스처 무앵커 | ✗ |
| X9 | resume 픽스처 접두-만 단언 | **✓** (B-X7) |
| X10 | 다중 plan 합산 카운트 오귀속 | **✓** (B-X9) |
| X11 | 서브디렉터리 cwd 미발화 | **✓** (B-X8 — resolve_project_root 미사용까지 지목) |
| X12 | 체크박스 regex 들여쓰기 미집계 | **✓** (B-X9) |
| X13 | source 게이트 부재(/clear·compact 오주입) | ✗ |
| X14 | model-policy 문면 오기(agentType `-`) | ✗ |
| X15 | "세션 상속" 전칭 단정 자기모순 | **✓** (B-X10/B-X11 — hook 주석층·model-policy 층) |
| (X7) | Rule C `'*'` arm 무앵커(수용잔여) | ✓ (B-X5/B-X6 — dead-code 판정까지 동일) |
| (X5) | 혼합 삼항 분기 소실(수용잔여) | ✗ |

**신규 발견 (GT 밖 — HEAD 재현 실측 후 판정)**:
1. **B-X3**: 빈 리터럴 `model: ''`이 `clean()`의 `|| "-"`로 "키 부재" 기호에 붕괴 — HEAD 재현
   (`execute-strict\t-` — 리터럴 탭 아님, 계약 표기). 방향은 안전(무선언 취급→발화)·희귀 형태 →
   **수용 잔여로 기록**(§14.1 잔여 목록에 ④로 추가된 것으로 읽을 것).
2. **B-X4**: MAX_SPAWNS 상한 소비 × `*` 면제 상호작용 — 면제 행 200개가 상한을 소비하면 201번째 진짜
   위반이 절단되어 완전 침묵(2값 시대엔 동적 행 자체가 ALERT였음). 헤더 자인의 3값 확장 미반영 →
   **수용 잔여로 기록** + 파서 헤더 자인 1줄 보강(C16-F 편승).
3. **B-X2 확장**: 정적 확정 가능한 비-단일-리터럴 값(`'fa'+'ble'` 연결·`undefined`·숫자)이 `*` 면제로
   흐름 — HEAD 재현(`execute-strict` + `*`). §14.5 교훈 ②가 이미 자인한 클래스의 추가 형태 → 수용
   잔여 목록에 형태 명시(연결·undefined). 그룹핑 괄호는 X6 정정으로 이미 해소 확인(`('fable')`→`fable`).
4. **B-X10 주석층**: X15 정정(메시지+3문서 hedge)이 **hook C3 주석 블록(:78-79)을 누락** — "builtin …
   동일하게 상속한다" 전칭 단정이 주석층에 잔존. HEAD 실물 확인 → **이번 사이클 정정**(X15 완결, 1줄).
5. B-X12(plan 미체크 상태 커밋)는 중간-커밋 시점 관측 — Closeout에서 해소되는 절차 서사로 **기각**.

**판정 — 내부 적대 패스 채택 (임계 ≥4/13 상회: 7/13)**: stage2=0 vs GPT=13의 차이에서 **임무
프레이밍이 유의미한 변수**다 — 같은 fable이 refute-by-default 임무로는 절반 이상을 찾았다.
※**주장 강도 한정(슬롯1 S34)**: 이 실험은 프레이밍 축만 통제한 것이 아니다(스테이지별 diff ↔ 사이클
전체 diff, per-task 검증 ↔ 일괄 리뷰 등 교란 변수 잔존) — "지배 변수"의 인과 식별이 아니라 "프레이밍
전환만으로 재발견이 0→7이 됐다"는 **충분성 방향 신호**(n=1)로 읽을 것. 단 GPT-전속 발견 6건
(X2·X3·X4·X8·X13·X14)은 내부 패스가 놓쳤으므로 교차패밀리 층은 **이 관측 범위에서** 내부 패스로
대체되지 않았다(보완 관계의 실측 1례 — §15.5 2-슬롯 유지 근거. "구조적 대체 불가"의 증명은 아님, S35).

**채택 형태**: 별도 패스 신설이 아니라 **senior review의 임무 전환** — closeout-pr-cycle Phase 4
senior review 프롬프트를 refute-by-default 적대 템플릿(C15 프롬프트 동형 카테고리: 계약 정합성·소비
로직·픽스처 vacuity·문서-실물 드리프트·무회귀)으로 교체. **기존 PASS/FAIL·Critical/Important 출력
계약과 downstream(merge Critical=0 조건)은 불변** — 적대 프레이밍은 발견 단계의 태도이고, 발견의
심각도 분류·판정 계약은 그대로다(적대 카테고리 발견은 Critical/Important/Minor로 분류해 기존 계약에
합류; Suggestions 절은 유지하되 적대 카테고리와 무관 — S29 정합). 티어=세션(상속 — 판단-필요
게이트라 §15.1 floor의 max 축), 사이클당 1회(기존 senior 슬롯 재사용 — 검증 **패스 수** 불변 = goal
§5-13 충족). ※비용 한정(S37): 불변인 것은 패스 수다 — 적대 임무의 토큰 소비는 확인 임무보다 클 수
있다(A/B 실측 118k vs C15 senior 80k, +47%). 근거: §15.0에서 senior(확인 임무)는 실발견 0 — 그
슬롯의 지출을 발견형 임무로 전환하는 것이 수율상 우월.

### §15.3 C16-A — per-layer 수율 계량 표준화 (`layer-yield`)

start-rpi-cycle Closeout Communication Protocol에 **고유 필수 필드 `layer-yield:`** 신설(harness-verify·
phase-skills 선례 동형 — 누락 = 구조적 불완전으로 자가-표면화). **최소 계약**(슬롯1 S17 정정 — 문법을
현실 케이스로 확장) = 검문 층별 1줄: `<층명>: <상태> · 실발견 <N>건 · <발견|확인>` — `<상태>` ∈
{PASS, FAIL→정정, `k PASS/m FAIL` 집계, SKIP(사유), 실행(비판정 층)}. 필수는 발견 카운트다(토큰 수치는
가용 시 부기; 측정이 무겁면 필드가 죽는다). **실발견 정의(S22 정직 한정)**: "산출물을 바꾼 발견 + 수용
잔여로 등재된 발견"(정정 여부와 무관하게 REAL 판정이면 계수 — 처분이 아니라 판정이 기준). 자기보고
지표라는 상한은 수용(발견마다 트리아지 기록이 대응물 — 이 필드는 계량이지 감사가 아님). **집계 단위
주의(S21)**: 층 행에 호출 수를 병기(`stage2 ×6`처럼) — 1호출과 6호출의 발견 0은 다른 증거 강도다.
축적 대장 = **`docs/ai-context/review-yield.md` 신설**(spec은 설계 결정, 대장은 사이클마다 자라는 관측
데이터 — 분리). **대장은 글로벌 하네스 단일 파일**(S20): 필드는 모든 사이클 필수이나 대장 append는
`~/.claude/docs/ai-context/review-yield.md` 고정 — 대상-프로젝트 사이클도 여기 축적(리뷰 배분 재심은
하네스 거버넌스 결정이므로). §15.0의 C15 행이 축적 1호, C16 자신이 2호. 소비처 = 3사이클 축적 후
floor·리뷰 배분 재심(§15.1 완화 후 티어의 품질 재심 트리거 겸용 — S36). seal = #19 동형(SKILL.md
Step C-1 구간 ↔ Communication Protocol 구간 양쪽 토큰 parity) + 대장 존재 conjunct — 토큰-존재 seal의
상한(내용 문법 미검증)은 #19와 동일하게 수용(S18; L3는 존재 표면화까지, 내용은 L1 몫). seal-regression
변이 동반(§13.13 규약 — S6). scaffold-registry Docs 표 + Drift Seals 표에 등재(S7). **C16 행 기록
시점(S19)**: Closeout 보고 작성 시점의 완결 층까지 기재하고, 대장 append는 **머지 전 마지막 커밋**에
포함(슬롯 2·drift 등 말미 층의 행은 그 시점 실측 — 이후 층이 없도록 append를 Closeout 최종 커밋으로).
**커밋 소유권(슬롯2 F1 정정)**: "최종 커밋"은 하네스 사이클 한정 해석 — C-0(closeout-pr-cycle)가 PR 을
만든 뒤에도 머지는 사용자 승인 대기(MERGE_POLICY wait)라 브랜치에 추가 커밋이 가능하고, append 는 그
마지막 브랜치 커밋에 실린다(머지 후 소급 불가). auto-merge 사이클이면 C-0 **이전**에 append 를 선행.
대상-프로젝트 사이클은 대장이 ~/.claude 저장소에 있어 대상 repo 트랜잭션에 태울 수 없다(cross-repo
staging 불가) — **별도 하네스-repo 커밋**으로 분리(SKILL.md sub-step 9 동기).

### §15.4 C16-B — 델타 재심 규약

Gate R/P·stage2의 FAIL→재실행 경로에서 재심 review-strict의 success_criteria를 **"직전 FAIL이 지목한
항목 각각의 해소 + 그 정정이 새로 깨뜨린 것 없음"으로 한정** — 전체 기준 재검은 첫 회만. **"새로 깨뜨린
것 없음"의 범위(S23 정밀화)**: 무한 부정 증명이 아니라 **정정이 편집한 파일/절에 한정한 원 기준 재적용**
이다(정정 diff가 재심의 스코프 경계 — 원 기준 전체를 전 파일에 재적용하는 것만 금지). 재심이 스코프 밖
결함을 우연히 봤다면 보고는 허용(스코프는 의무의 한계이지 발화 금지가 아님). 준수는 자가-표면화 축(재심
호출의 success_criteria 원문이 세션 기록에 남음 — S24의 "규약-준수 검증기 부재"는 phase-skills와 동급의
수락된 advisory 상한). 근거: §15.0 Gate P #2가 발견 3건 재검에 전체 재리뷰 83k 지출. 이번 사이클 실증:
Gate P 델타 재심 2회가 이 규약으로 실행됨(1회차 4항 → 2회차 2항, 재심당 ~40-66k — 전체 재리뷰 83k 대비
절감 실측). 착륙 지점 = SKILL.md Gate R/P FAIL 경로 + (d) 경로 서술(stage2 재실행 동일 원리 — 재심은
메인이 successCriteria를 델타로 좁혀 새 호출로 전달, canonical carrier 코드 무변경).

### §15.5 C16-E — 교차패밀리 리뷰 2-슬롯 (발견을 설계 층으로 앞당김)

`docs/ai-context/cross-family-review.md` 개정:
- **슬롯 1 (신설)**: Gate P 직후, **spec delta + plan** 대상 적대 리뷰 — 설계-층 비대칭·계약 구멍을
  코드 작성 전에(C15 X6 "계약 확장이 기존 안전-방향 분류를 뒤집는" 클래스가 표적). 발견이 사이클
  말미에 도착해 재작업 꼬리(C15 구현 물량의 25%가 GPT 정정)를 만드는 구조의 교정.
  **발견 처리 규약(S28)**: 슬롯 1 발견은 메인 트리아지(기존 규약) 후 REAL이면 **spec/plan 정정 →
  Gate P 델타 재심**(§15.4 규약으로 — 정정 항목 한정)을 Phase I 착수 전에 통과해야 한다. Gate P PASS는
  슬롯 1 REAL 정정에 의해 잠정화되는 것이 명문 규칙이다.
  **프롬프트 계약(S27)**: refute-by-default 공통 규율 + 검사 범주 최소 세트 = {floor/판정식 건전성,
  소비자 동반-갱신 완결성, plan 내부 정합(산술·RED/GREEN 실행 가능성), 신설 계량/규약의 우회 가능성,
  기존 문서와의 모순, 실험/근거의 과잉 주장} — C16 첫 실행의 프롬프트가 준거 템플릿(A~F 카테고리).
- **슬롯 2 (기존)**: Closeout, 코드 diff 대상 — X1~X4류 구현-층 결함은 코드가 있어야 잡힌다(슬롯 1로
  대체 불가; §15.2가 보완 관계의 실측 1례).
- **출력 파일 슬롯별 분리(S30)**: `$REVIEW_OUT`을 슬롯별 고유 경로(`…-slot1-…`/`…-slot2-…`)로 — 기존
  "호출 전 rm -f" 규율이 슬롯 2에서 슬롯 1 증거를 지우지 않게.
- **호출 수 정직(S31)**: "슬롯당 1회"는 본호출 기준 — probe 스모크(저비용)는 별도이며 세션 내 재사용
  가능(같은 사이클에서 슬롯 1 probe가 성공했으면 슬롯 2는 probe 생략 가능).
- C11 "stage별 GPT 기각"과의 관계 명시: 그 기각은 N회(스테이지 수 비례)였고 이건 **고정 2회** — 별개
  결정. 불가 시 슬롯별 SKIP+사유(fail-open 불변). C16 자신이 슬롯 1의 첫 실행(S25 보강: 문서 상단
  "1회 리뷰" 리드 문구도 "2-슬롯 리뷰"로 동기 — "사이클당 1회" 리터럴 외의 빈도 서술 사이트 포함.
  구 이니셔티브 spec `2026-07-13-…-design.md:96`의 "사이클당 1회"는 genesis-record — C10 시점 기록이라
  본문 불편집, cross-family-review.md 현행이 SSOT라는 기존 계층이 이미 해석을 고정).

### §15.6 C16-F — 하우스키핑 판정 (C15-D [P1]~[P4] 편입 승인분 + 잔여)

1. **plugin-pins 드리프트 = 정당 업데이트 판정** (C10 절차 ② 동형): 핀 1781304936/33 → 실측
   1583290756/37. 원인 = superpowers 6.1.1→**6.2.0**(installed_plugins lastUpdated 2026-07-25) +
   context7/skill-creator/playwright 캐시 버전 디렉터리 추가(디렉터리명 = 이 하네스 repo 커밋 sha —
   C10 명명 특성 재확인: ba53b2ab03ad 등). 콘텐츠 diff 리뷰(⚠C16 stage2+슬롯2 F8 정정 — 초기 "7종 문구
   정련"은 오기재): cmp 14/14 전수 = **13/14 변경**(byte-동일은 using-superpowers 1종) — 대형 리워크
   3건(subagent-driven-development 600줄=리뷰-라운드 게이트 신설·finishing-a-development-branch 256줄·
   test-driven-development 78줄) + 문구 정련 10건. 판정 근거 = **보안 표면 0**(위임 agent명/allowed-tools/
   권한/원격조작 명령 변경 없음) + 정상 릴리스 채널. skill-creator 8버전 디렉터리 byte-동일. → 핀 재실측 갱신.
   구버전 6.1.1 캐시 잔존은 cksum 계산에 포함(결정론 유지 — find|sort|cat 전량 해시).
2. **[P1] model-window.js opus-4-(7|8) regex = 유지(사유)**: 사실로서 정확(실제 1M 창 모델)·이 머신
   라우팅 이력상 재등장 가능·제거 이득 0 vs 소비자 4건(픽스처 78·60·189·190) + README 동반 비용.
   model-window는 "아는 모델의 창 목록"이지 "현행 라우팅 목록"이 아니다. settings.example은 opus-5로
   이미 무관(실측 — opus-4 리터럴 0건).
3. **[P2] `feedback_response_language.md` 삭제** (CLAUDE.md §7과 완전 중복) + MEMORY.md 인덱스 라인 제거.
4. **[P3]+[P4] CCS 메모리 통합**: 5파일(pending_fix·gemini_exclusion·token_family_revocation·
   routing_guide·fable5_enabled) → `project_ccs_routing.md` 1파일. 통합 시 낡은 값 정정([P4]): 핀
   7.2.62-5 현행·GPT 슬롯 sol/luna(5.5/5.4-mini 시대 서술은 이력으로 압축)·구 백업 파일명 정리.
   원본 5파일 삭제 + MEMORY.md 인덱스 5줄 → 1줄. autocompact 메모리는 스코프 밖(별개 주제·현행성 유지).
5. **cases.tsv ssa 08/09 col4** `gen_ssa_resume`→`test_ssa_resume`: col4는 비소비 정보 컬럼 실측
   (run-all :1260이 col1/col2만 소비 — 기능 무영향, 정보 정확성만).
6. **B-X10 주석층 정정 편승**(§15.2-4): hook C3 주석 블록 hedge 1줄 + 파서 헤더 MAX_SPAWNS×`*` 자인 1줄.

### §15.7 교차패밀리 슬롯 1 첫 실행 — 트리아지 (2026-08-02, S1~S37)

경로 A(`gpt-5.6-sol`·ultra·verbosity high·read-only·`-o` 슬롯별 파일). 대상 = §15 전문 + plan 전문
(설계 층 — 코드 diff 없음, 슬롯 1의 정의 그대로). 제기 37건. 전건 원문 실측 대조 트리아지:

**REAL — spec/plan 정정 편입 (Gate P 델타 재심으로 재검)**:
- **S1/S2 (최중대)**: 1패스 실행자 평가가 `tier_of` 단독이라 상속(`-`/`inherit`)·동적(`*`) 실행자의
  floor 기여가 0 — 혼합 스크립트(상속·동적 실행자 + 하위 리터럴 실행자)에서 floor가 실작업자 아래로
  붕괴해 하한 불변식 위반. → §15.1 구현 형태를 3분기(리터럴=tier_of / 상속·동적=세션 티어)로 정정.
  완화는 전-리터럴 스크립트에만 적용. **C15 교훈 ①의 재현**: 완화가 만든 새 붕괴 경로를 표가 놓쳤다.
- **S3**: "새로 침묵" 표가 작업자<검증자<세션 대역 누락 → 표에 행 추가(전부 하한 충족 = 정당 침묵).
- **S5**: seal #45의 `model: 'opus'` 무스코프 grep이 stage2 리터럴 추가로 stage1-앵커로서 vacuous →
  #45 ⑨를 stage1 문맥 앵커로 강화(동반 갱신 목록 편입).
- **S6**: seal #49 신설에 seal-regression 변이 미동반(§13.13 위반) → 변이 추가 task 편입.
- **S7**: scaffold-registry :24/:48 구 서술 + #49 미등재 → 동반 갱신 목록 편입.
- **S8**: SKILL.md :132 인라인 규약 "stage2 무지정" 잔존 → 동반 갱신 목록 편입.
- **S9**: CONTEXT.md :85/:89의 구 floor 서술 2곳 → 동반 갱신(§15.1 목록 편입, R에서 「검증자 기준선」만
  갱신했던 것의 보완).
- **S10/S32/S33**: spec §3 :115·§10 :250·:267·§12.5 :576·§12.6 :642에 supersede 포인터 부재 → 전부
  포인터 추가 대상 편입.
- **S11**: 픽스처 26 주석의 `max(2,3)` 구 산식 → 주석 갱신 편입.
- **S12**: canonical E2E가 2세션뿐(§15.1 문면은 4세션) → 픽스처 4개로 확정.
- **S13**: run-all은 pass-rate ≥95%면 exit 0 — RED 단계의 "FAIL 2건"은 종료코드가 아니라 요약 텍스트로
  판정해야 → plan RED 스텝의 Expected를 "요약 라인에 FAIL 표기 + 해당 케이스 got/want 출력"으로 정밀화.
- **S14**: T4 RED에서 #36 count-seal이 #49 FAIL과 연쇄(85/2)+ tail -3이 #49 메시지를 가림 → Expected를
  `PASS=85 FAIL=2`(#49+#36 연쇄)로 정정, 확인 명령을 `grep "layer-yield"`로.
- **S15**: 0행-기대 grep은 exit 1 — 검증 명령에 `|| true` 및 "출력 0행" 기준 명시.
- **S16**: 신규 cases.tsv col4는 `test_smp`가 아니라 인접 행 동형 `mk_wf_event` — plan 표기 정정.
- **S17/S20/S21/S19**: layer-yield 문법이 자기 대장을 거부·대장 위치 미정·집계 단위 미정·C16 행 기록
  시점 미정 → §15.3 계약 확장(상태 enum·글로벌 대장 고정·호출 수 병기·최종 커밋 시점).
- **S25 (부분)**: cross-family-review.md 상단 리드 "1회 리뷰" 미편집 → 편집 대상 편입. 구 이니셔티브
  spec :96은 genesis-record 판정으로 불편집(현행 SSOT 계층이 해석 고정).
- **S27/S28/S30/S31**: 슬롯 1 프롬프트 계약 부재·발견→Gate P 재심 전이 부재·출력 파일 공유·probe 계수
  → §15.5 보강(위 반영).
- **S29**: senior 적대 전환이 기존 PASS/FAIL·merge 계약과 충돌 소지 → §15.2에 "출력 계약 불변, 프레이밍
  만 교체" 명문화.
- **S34/S35/S36/S37**: A/B 결론의 과잉 주장(지배 변수·대체 불가·완화 티어 미실측·비용 0) → §15.2/§15.1
  문면을 한정 표현으로 정정 + layer-yield 축적이 완화-후 품질 재심 트리거임을 명시.

**수용 잔여 / 기각 (판정 근거)**:
- **S4 (MAX_SPAWNS×완화 상호작용)**: 실재하나 상한 자체가 C15 이전부터의 수용 잔여이고 자연 코드에서
  200+ 스폰은 비현실적 규모 — §15.1 표에 정직 부기 + 파서 헤더 자인으로 수용(구조 해소는 상한 제거를
  요구 — 정지성 보장과 상충).
- **S18 (seal #49 내용-무검증)**: 토큰-존재 seal의 알려진 상한(#19와 동일 클래스) — L3는 존재 표면화,
  내용은 L1 몫. 기존 설계 원칙 그대로 수용.
- **S22 (자기보고 지표)**: 정의를 "REAL 판정 기준"으로 정정(처분 무관)하되, 계량의 자기보고 성격 자체는
  이 필드의 수락된 상한(감사가 아니라 계량 — 트리아지 기록이 대응 감사물).
- **S23/S24 (델타 재심의 무한 부정·준수 검증 불가)**: 스코프를 "정정 diff 한정 원 기준 재적용"으로
  정밀화해 S23 해소; S24의 물리 강제 불가는 phase-skills와 동급의 advisory 상한 수용.
- **S26 (priority 철회문의 '사이클당 1회' 리터럴)**: 이력 인용 원문 보존 원칙 유지 — 단 판정을 "잔존이
  드리프트 아님"에서 "이력 문구(당시 상한 기준)"로 주석 명확화는 T6에서 필터 사유와 함께 보고.
  원문 편집은 하지 않음(재논의-방지 기록).

**메타 관측 (슬롯 1의 가치 실증 — 첫 실행 자체가 근거)**: 37건 중 REAL(정정 편입) 26건이 전부 **코드
작성 전** 도착 — S1/S2(하한 불변식 위반 코드가 그대로 착륙할 뻔한 클래스)를 설계 층에서 차단. C15의
"발견이 말미에 도착해 재작업 25%"와 대조되는 첫 데이터 포인트. GPT 방향 오류도 있었음(S13의 "RED가
게이트가 아님"은 맞지만 plan의 RED는 애초 텍스트 판정 — 정밀화로 수용). 비용: 본호출 1회(+timeout
재시도 1회 — 첫 호출이 10분 타임아웃으로 유실, `-o` 파일 경유 재실행. C15 교훈 ③ 재확인).

## §16. C17 설계 결정 (in-place 개정, 2026-08-02 — U4 공리 + 매트릭스 v2 + 리뷰 통합)

> C17 goal 원문 = `_goal/c17-fable-minimization-goal.md`(비추적 · rev2 — opus 2렌즈 적대 검증 반영).
> 아래는 goal 없이 재현 가능하도록 근거를 영구화한 것 — §11/§13/§14/§15 선례. 주제 = fable 최소화:
> 역할×모델 매트릭스 v2(검증자 floor **세션 축 전면 제거**) · 리뷰 통합(Gate R 조건부화·drift/senior
> 합본·light-배칭) · fable 예외 밸브.

### §16.0 U4 공리 (사용자 선언, 2026-08-02 — 이 절의 전제)

**U4: "opus 와 fable 의 성능은 오케스트레이션을 제외하면 거의 같다고 가정한다."** (verbatim 요지)

따름정리:
1. fable 의 상주 역할 = **메인 세션 오케스트레이션 단 하나**. 서브에이전트 위임(실행·검증·판단·탐색)은
   기본적으로 fable 을 쓰지 않는다(§16.5 밸브만 예외). 메인이 하는 트리아지·판정 종합은 오케스트레이션의
   일부(위임 아님)라 U4 적용 밖.
2. C13 판단-게이트 floor `max(세션, 작업자)` 의 근거("세션이 만든 산출물을 세션보다 약한 눈으로 검증
   금지")는 U4 아래에서 소멸 → 검증자 floor 의 **세션 축을 전면 제거**한다. §15.1 임무-분리의
   판단-게이트 절반을 재-supersede — 신 기준선: **판단-게이트 = `max(작업자 티어, opus)` / 준수-확인 =
   작업자 티어(불변)**. 하한 불변식(어떤 임무에서도 검증자 < 작업자 금지)은 유지.
   ※ **근거의 정직 표기**: "opus 로 충분"의 실측은 준수-확인 층뿐(C16 stage2 T3·T7 — 사실 오류 2건
   실차단). 판단-게이트에서의 opus 충분성 실측은 없다 — C16 senior/A/B 는 전부 fable 단일 티어라 티어와
   프레이밍이 교란(n=1, §15.2 S34/S35 자인). **판단-게이트 opus 전환의 근거는 U4 공리 단독**이며,
   layer-yield 축적(C17 행 = opus 게이트 첫 실측, 3호 = §15.3 소비 임계 충족)이 **사후 관측 신호**가
   된다. ※주장 강도 한정(슬롯1 F1 정정): layer-yield 는 자기보고 계량이라 검증자 열화의 **검증**이
   아니다 — 약한 검증자는 결함을 놓쳐 PASS 를 늘리는 방향이라 대장 단독으론 열화가 관측되지 않을 수
   있고, C17 은 티어·프레이밍·게이트 빈도·Closeout 구조를 동시 변경해 교란도 남는다. 독립 대조군은
   교차패밀리 GPT 층(§15.5 — opus 게이트가 놓친 것을 슬롯1/2 가 잡으면 그것이 열화 신호). 열화 관측 시
   floor 원복이 역-supersede 경로(§15.1 S36 동형).
3. **리뷰 통합·조건부화·배칭 허용** — C16 goal §5-13("검증 횟수 자체의 축소 금지")을 사용자 선언이
   supersede. ※ **권위의 정직 표기**: 이 결정의 권위는 U4+사용자 지시이지 수율 대장이 아니다 — 대장은
   2행(C15·C16)뿐이라 §15.3 소비 임계(3사이클) 미달. 대장 데이터는 보조 근거로만 인용하고, floor·배분의
   데이터 기반 전면 재심은 §15.3 대로 C17 행 축적 후(C18) 별도 수행. 델타 재심(§15.4)·하한 불변식 유지.

### §16.1 매트릭스 v2 + Option 1 (frontmatter opus) — 실측 ①② 기록

**신 기준선 (model-policy.md 로 증류 — §3/§15.1 의 해당 행 supersede)**:

| 역할 | 모델 | 비고 |
|---|---|---|
| 오케스트레이션(메인 세션) | fable(+ultracode) | fable 의 유일한 상주 역할 |
| 실행 (execute-strict) | **opus** (frontmatter 기본) | 불변 |
| 준수-확인 검증 (Workflow stage2 / Rule C2) | **작업자 티어** | §15.1 불변 (carrier stage2 opus 명시 유지) |
| 판단-게이트 검증 (Agent 경로: Gate·통합 Closeout 리뷰·델타 재심 / Rule B) | **`max(작업자, opus)`** | 세션 축 제거 — fable 세션에서도 opus |
| 탐색 (explore-strict) | sonnet | 불변 |
| 교차패밀리 | GPT sol 2슬롯 | 불변 (§15.5) |
| fable 서브에이전트 위임 | **기본 금지** | §16.5 밸브만 |

**구현 = Option 1 채택 (실측 ①② 성립 — 2026-08-02, 세션 아티팩트 `subagents/*.jsonl`
`message.model` 실측·자가보고 불인정)**: `agents/execute-strict.md`·`agents/review-strict.md`
frontmatter `model: inherit` → **`model: opus`**. **무지정 호출** 클래스의 상속-누출이 wrapper 에서
소멸(신 세션 기준 — 슬롯1 F3 한정: 명시 `inherit` 경로와 전환-창 세션은 §16.2/§16.4 의 별도 축).

- **실측 ① (Agent 경로 전환 E2E)**: frontmatter opus 상태에서 fresh 헤드리스 fable 세션
  (`claude -p --model claude-fable-5`, 세션 54e3fd31)의 무지정 위임 → execute-strict=claude-opus-5·
  review-strict=claude-opus-5. 명시 `model:'opus'` 호출도 opus(회귀 없음). **성립.**
- **실측 ② (Workflow 무선언 스폰)**: 동일 조건 fresh 세션(c4a86737)의 인라인 Workflow `agent()`
  무선언 스폰 → execute-strict=claude-opus-5·review-strict=claude-opus-5. **frontmatter 추종 확정** —
  Rule C 의 "무선언=세션 상속" 전제는 frontmatter inherit 에 의존했던 것(§16.2 재계산 근거). **성립.**
- **★신규 발견 — frontmatter 세션-내 캐싱**: 전환은 **이미 열린 세션에 미적용** — 같은 실측에서
  현행(전환 전 시작) 세션의 무지정 위임은 Agent·Workflow 양 경로 모두 fable 로 상속됐다(각 2건 실측).
  frontmatter 값은 **세션-스코프로 고정되어 관측**된다(정확한 로드/캐시 시점 — 시작-시 로드 vs 첫-사용
  캐시 — 은 미판별, 슬롯1 F4 한정; 관측 사실은 "열린 세션 내 불변·새 세션 반영"뿐). **함의**: ⓐ전환 커밋 이전에 시작된 세션은 커밋 후에도
  무지정=구 의미(상속) — 그 창에서는 명시 `model:'opus'` 가 유일한 보장(C17 세션 자신이 그 케이스,
  전 위임 명시 규약으로 커버). ⓑhook 이 "무지정=frontmatter opus"로 평가하는 것은 새 세션부터
  사실-정확 — 전환-창 세션의 이론적 오차는 advisory 수용 잔여로 부기.

**Option 2 (기각 — 사유 기록)**: inherit 유지 + 전 호출 지점 명시 의무화 + hook 무지정 ALERT.
실측 ①② 성립으로 불채택 — 물리 기본값(Option 1)이 규약 기억 의존을 제거(Best-Direction).

### §16.2 hook 재정의 — Rule A/B v2 + Rule C/C2 재계산 (arm 집합 정의)

구 "세션-대비 하향 감지" → **"opus-floor + fable-누출 감지"**. 정책 상수 **OPUS_FLOOR=3**.

**무지정 vs 명시 inherit 의 의미 분리 (Option 1 이 만든 새 축 — 자율 확정)**:
- **무지정**(Agent `model` 인자 부재 / Workflow `-`) = **frontmatter opus 추종**(실측 ②) → tier 3 평가.
- **명시 `inherit`** = frontmatter 우회 세션 상속(§11.3 해소 순서: opts.model 존재 시 그것이 우선 —
  C14 §13.3 "명시 inherit 도 세션 상속" 유지) → **세션 티어 평가**(C13 의미론은 이 축에만 존속).

- **Rule B v2 (Agent 경로 review-strict) — 2계 arm (슬롯1 A1/A4/A6 정정 반영)**:
  - **floor arm (전 세션 — 미지-티어 세션 포함)**: 평가 티어 < OPUS_FLOOR → ALERT. 평가 = 리터럴은
    tier_of · 명시 `inherit` 은 세션 티어(세션 티어 미상=0 이면 이 분기만 skip — 단언 불가) · 무지정은
    opus(frontmatter — Option 1) · **미지-티어 리터럴(tier_of=0)은 비면제**(≥opus 단언 불가 → ALERT —
    C2 F4/픽스처 28 과 규약 정렬, 구 `!= "0"` 면제 arm 제거). **리터럴 평가는 세션 티어가 불필요하므로
    미지-티어(claude-미지) 세션에서도 수행**(슬롯1 A1 — 구 `SESSION_TIER != 0` 전체-skip 가드 제거;
    transcript 부재/비-claude 세션은 세션 판별 자체가 실패해 기존 fail-open 그대로).
    예: opus 세션 명시 inherit=3 침묵 · sonnet 세션 명시 inherit=2 → ALERT(**새로 발화** — 구 코드는
    inherit 의 tier_of=0 이라 검사 자체를 skip) · sonnet 세션 명시 sonnet=2 → ALERT(**새로 발화** —
    구 하향식은 2<2 거짓) · haiku 세션 haiku/sonnet/inherit 동류 · 무지정은 전 세션 침묵(안전 기본).
  - **누출 arm (fable-리터럴 = 전 세션 / 명시 inherit = fable 세션 한정)**: U4 의 fable 위임 금지는
    세션 무관이므로 **명시 `fable`(tier 4 리터럴) 은 어느 세션에서도 ALERT**(슬롯1 A6 — 구 설계의
    "fable 세션 한정" 게이트는 opus/sonnet 세션의 fable 요청을 침묵시켰다). 명시 `inherit` 은 fable
    세션에서만 누출(=fable 상속)이라 그 세션 한정. 메시지는 밸브(V1/V2/V3+FABLE-ESCALATION) 예외를
    환기 — hook 은 선언을 관측할 수 없으므로 밸브-정당 호출에도 발화한다(advisory 환기, 오탐 수용).
  - **구 "세션 대비 하향" arm 제거** — 신 정책의 정상 패턴(fable 세션 opus 검증자)을 ALERT 하는 소음원
    (라이브 실증: 2026-08-02 C16 T7 델타 재심 opus 지정 시 `rule-b-verifier-downshift` ALERT).
    로그 슬러그 교체: `rule-b-verifier-downshift` → `rule-b-verifier-below-opus-floor`(floor arm)·
    `rule-b-fable-leak`(누출 arm). **메시지 내용 픽스처 1건 동반**(슬롯1 B2 — additionalContext 존재만
    보는 픽스처는 구 메시지 잔존을 못 잡는다; `max(작업자` 토큰 단언, test_smp_hedge 동형).
  - ※ Agent 경로의 "작업자" 축은 **관측 불가 유지**(per-call 입력 — §12.1 강제-범위 단락) — hook 은
    opus 상수 축만 검사하고, `max(작업자, opus)` 의 작업자 절반은 L1 규범 몫(수용 잔여, §16.4-1).
- **Rule A v2 (execute-strict)**: 무지정 arm 의 전제가 뒤집힘(무지정=frontmatter opus=안전) →
  **무지정 arm 침묵 전환**. 유지 arm = 명시 `inherit`(fable 세션 한정 — 비-fable 세션의 inherit 은
  fable 누출이 아니라 실행자 하향(L1 몫, 구 코드도 미탐 — 불변 잔여)) + **명시 `fable`(전 세션 —
  A6 동형 확장)**. 슬러그 교체: `rule-a-downshift-missing` → `rule-a-fable-leak`.
- **Rule C 재계산 (실측 ② 성립 + A6 확장)**: fable 세션 실행자 무선언(`-`)=frontmatter opus=하향
  적용됨 → **`-` arm 침묵 전환**(새로 침묵). 명시 `inherit` arm 은 fable 세션 한정 유지(세션 상속=
  fable). **원시 티어 4 리터럴 arm 은 전 세션으로 확장**(A6 — U4 금지는 세션 무관). `*` 면제 불변.
  슬러그·메시지 교체: `rule-c-workflow-downshift-missing` → `rule-c-workflow-fable-leak`(슬롯1 B1 —
  구 메시지 "model 지정 없이" 는 신 의미론에서 거짓: 무지정은 안전이고 위반은 inherit/fable 명시다).
- **Rule C2 재계산**: 1패스 WORKER_TIER 평가 3분기 재정의 — 리터럴=tier_of / `-` 무선언=**opus(3 —
  frontmatter, 구: 세션)** / 명시 `inherit`=세션 티어(불변) / `*` 동적=세션 티어 평가(불변 — 런타임
  해소값 배제 불가. ※"상계"가 아니라 휴리스틱: 동적이 세션 위 값으로 해소되면 미달 — 관측 불가
  수용 잔여, 구 코드 동일 클래스) / 미지-리터럴(tier_of=0)=**opus 평가(구: 세션 — fable 세션에서 세션
  평가는 floor 4 를 만들어 opus 검증자 ALERT = 신 정책 정상 패턴 고발이 되므로 opus 로 교체. 이 역시
  상계 아님: 미지 리터럴이 실제 fable 급이면 과소평가 — 판별-불가의 정직 한계, 표에 반전 행으로 기록.
  floor 를 0 으로 끌어내리지 못하게 하는 F4 원리는 유지)**. **실행자-전무 폴백 = opus 상수(구: 세션
  티어)** — "보수"의 기준 자체가 세션→opus(라이브 실증: 검증-전용 Workflow 에서 `관측='opus', 필요
  티어=4` ALERT 가 신 정책 정상 패턴을 고발). ※전량-동적 스크립트는 실행자-전무가 **아니다**(각 동적
  스폰이 세션 티어로 floor 에 기여 — 폴백 미적용, 혼동 금지). 검증자 측 평가도 동형 분기: `-`=opus
  (frontmatter)·명시 `inherit`=세션·`*`=면제·리터럴=tier_of. floor 비교식 불변(`SP_T < FLOOR_TIER →
  ALERT`). **누출 arm 신설(C2-leak, A6)**: 검증자 **fable-리터럴은 전 세션 ALERT** + 검증자 명시
  `inherit` 은 fable 세션 한정 ALERT — floor 만으로는 fable 검증자가 항상 충족-침묵이라 U4 금지가
  Workflow 검증자 축에서 무검이 된다(구 §16.4-4 예정 잔여의 코드 해소; 밸브 동반-상향 케이스(fable
  작업자+fable 검증자)에도 발화하는 오탐은 advisory 환기로 수용 — 메시지가 밸브 선언을 환기).
  슬러그: `rule-c2-fable-verifier`. 폴백 상수와 원시 관측값은 변수 분리 유지(SP_T_RAW — 픽스처 49
  클래스). ※Workflow 경로의 세션-미상(WF_TIER=0) 조기 exit 은 유지 — C2 의 inherit/동적/폴백 평가가
  세션 티어를 요구해 부분-평가의 복잡도가 advisory 상한 초과(수용 잔여 §16.4-5; Agent 경로 Rule B 와
  비대칭임을 정직 부기).
- **Rule C3 불변** (fable 세션 무선언-frontmatter builtin fan-out — execute/review-strict 는 제외
  목록이라 이 개정과 무관; explore-strict frontmatter sonnet 불변).

**픽스처 기대값 반전 전수 표 (양방향 — C15 교훈 ⑬·⑯, goal §5-3; 슬롯1 A4/A5 보강 후 확정판)**.
대상 = 기존 smp 01~49 전수 재계산 + 반전·신설마다 RED/GREEN:

| 경로·케이스 | 구 판정 | 신 판정 | 방향 | 정당성 |
|---|---|---|---|---|
| A: fable 세션·exec 무지정 (smp 01) | ALERT | **SILENT** | 새로 침묵 | 무지정=frontmatter opus(실측 ②) — 안전 기본 |
| A: fable 세션·exec 명시 inherit/fable | ALERT | ALERT | 불변 | 명시 상속/fable = 누출 |
| B: fable 세션·review 명시 sonnet (smp 03) | ALERT(하향) | **ALERT(floor)** | 사유 교체 | 2<3 floor 미달 — 메시지·슬러그 갱신, 발화 자체는 유지 |
| B: fable 세션·review 명시 opus | ALERT(구 하향 — T7 라이브) | **SILENT** | 새로 침묵 | 신 정책의 목표 케이스 — 소음원 제거 |
| B: fable 세션·review 명시 inherit | SILENT(tier_of=0 skip) | **ALERT(누출)** | 새로 발화 | 선언 없는 fable 소비 |
| B: fable 세션·review 무지정 (smp 04) | SILENT | SILENT | 불변 | 구: 검사 skip / 신: frontmatter opus=3 충족 — 사유 교체 |
| B: sonnet 세션·review 명시 inherit | SILENT(skip) | **ALERT(floor)** | 새로 발화 | 세션 평가 2<3 |
| B: sonnet 세션·review 무지정 | SILENT | SILENT | 불변 | frontmatter opus 평가=3 충족 |
| B: opus 세션·review 명시 sonnet | ALERT | ALERT | 불변 | 2<3 (구: 2<세션3) — 사유 교체 |
| B: sonnet 세션·review 명시 sonnet (A4) | SILENT(2<2 거짓) | **ALERT(floor)** | 새로 발화 | 2<3 — 구 하향식의 동일-티어 구멍 소멸 |
| B: haiku 세션·review 명시 haiku/sonnet/inherit (A4) | SILENT·ALERT 혼재 | **ALERT(floor)** | 새로 발화·통일 | 1·2<3 (구: haiku→haiku 는 1<1 거짓 침묵) |
| B: 비-fable 세션·review 명시 fable (A6) | SILENT(상향) | **ALERT(누출)** | 새로 발화 | U4 fable 금지는 세션 무관 — 구: 상향은 항상 허용이었음 |
| A: 비-fable 세션·exec 명시 fable (A6) | SILENT(비-fable skip) | **ALERT(누출)** | 새로 발화 | 동상 |
| B: 미지-티어 리터럴 review (전 세션) | SILENT(`!=0` skip) | **ALERT(floor)** | 새로 발화 | ≥opus 단언 불가 비면제 |
| B: 미지-티어 **세션**·review 명시 sonnet (A1) | SILENT(`SESSION_TIER=0` 전체 skip) | **ALERT(floor)** | 새로 발화 | 리터럴 평가는 세션 불요 — 구 가드가 세션-축 잔존이었음 |
| C: 비-fable 세션·wf exec 명시 fable (A6) | SILENT | **ALERT(누출)** | 새로 발화 | U4 세션 무관 |
| C2: fable 세션·미지 실행자 단독·rev opus (A2) | ALERT(세션 평가 floor 4) | **SILENT** | 새로 침묵 | 미지→opus 평가 — 미지가 실제 fable 급이면 과소평가(정직 한계, 판별-불가 수용) |
| C2: 검증자 fable-리터럴 (전 세션, A6) | SILENT(floor 충족) | **ALERT(C2-leak)** | 새로 발화 | U4 — floor 축과 독립인 누출 arm 신설 |
| C: fable 세션·wf exec 무선언 (smp 09/11) | ALERT | **SILENT** | 새로 침묵 | 무선언=frontmatter opus(실측 ②) |
| C: fable 세션·wf exec 명시 inherit/fable (smp 18/36) | ALERT | ALERT | 불변 | 명시 상속/fable |
| C2: fable 세션·exec sonnet·rev sonnet (smp 42) | SILENT(작업자 floor) | SILENT | 불변 | 검증자==작업자 |
| C2: fable 세션·실행자 전무·rev sonnet (smp 14) | ALERT(세션 폴백 4) | **ALERT(opus 폴백 3)** | 불변·산식 교체 | 2<3 — 발화 유지, 필요 티어 표기 4→3 |
| C2: fable 세션·실행자 전무·rev opus | ALERT(3<4) | **SILENT** | 새로 침묵 | 신 폴백 3 충족 — 검증-전용 Workflow 라이브 오발화의 해소 |
| C2: 혼합 상속 실행자·하위 검증자 (smp 27/43) | ALERT | ALERT± | 재계산 | 무선언 실행자=opus 평가로 floor 산식 변화 — 케이스별 재계산(§15.1 S1/S2 하한 원리 유지) |
| C2: 미지-리터럴 단독 실행자·rev sonnet (smp 48) | ALERT(세션 상계) | **ALERT(opus 상계)** | 불변·산식 교체 | 2<3 |
| C2: canonical carrier 4세션 (smp 44~47) | SILENT | SILENT | 불변 | stage1/stage2 리터럴 opus — floor 3 충족 |
| C3 전 케이스 (smp 23~25/31~34/39) | 불변 | 불변 | 불변 | 이 개정과 직교 |

※ 위 표의 "재계산" 행 포함 smp 01~49 전수를 plan 이 개별 확정(픽스처 주석의 구 산식 표기 동반 갱신
— §15.1 S11 선례). 반전 픽스처마다 RED(구 코드에 신 기대 적용 시 FAIL)/GREEN(신 코드 PASS) 실측.
※ **판별력 보존 원칙 (자율 확정)**: 검사 *주제*가 무선언 arm 이 아니라 **다른 성질**(per-spawn 마스킹
해소 smp 20/35 · 프롬프트-노이즈 오인 방지 smp 21 · 세션 판별 면역 smp 08/19)인 픽스처는, 무선언 arm
침묵 전환으로 단순 기대 반전하면 그 성질의 봉인이 증발한다(위반-트리거가 사라져 vacuous) — 이 클래스는
**위반 트리거를 명시 `inherit` 로 교체**해(신 정책에서도 ALERT 인 arm) 원 성질의 판별력을 보존하고,
무선언 arm 의 침묵 전환 자체는 반전 표의 전용 픽스처(smp 01/09 류)가 앵커한다. smp 27 은 검사
주제가 "상속 검증자의 floor 평가" 자체이므로 입력 유지 + 기대 반전(ALERT→SILENT — 무선언=frontmatter
opus 가 floor 충족)이 옳고, 구 "거짓 복구 경로" 서사는 신 의미론에서 소멸(주석 동반 갱신 — hook C2
메시지의 "model 을 지우는 것(상속)만으로는 해소되지 않습니다" 문장도 같은 서사라 **교체 대상**, 슬롯1
C4: 신 의미론에선 model 삭제=frontmatter opus 라 실제로 해소된다 — "명시 inherit 로는 해소되지 않음"
으로 교체). smp 16(실행자-전무·sonnet 세션·sonnet 검증자)은 폴백 opus 상수로 **새로 발화** — 검증-전용
Workflow 의 검증자도 opus floor 를 적용한다는 신 정책의 직접 귀결(§16.2 Rule C2 폴백). **smp 30(3규칙
동시-emit 무손실)도 트리거-교체 클래스**(슬롯1 C1/Gate P BLOCKER-1 공통): WF_MULTI 의 무선언
execute-strict 가 신 의미론에서 침묵해 3규칙 동시 성립이 깨진다 — 그 스폰을 명시 `inherit` 로 교체해
판별 주제(규칙 우선순위 무손실)를 보존. **smp 11 도 트리거-교체로 확정**(Gate P deviation 정정): 판별
주제가 "scriptPath 파일 읽기 경로"이므로 파일 내용을 명시 `inherit` 스폰으로 교체해 ALERT 유지 — 위
반전 표·앵커 서술의 "smp 09/11" 은 **smp 09 단독**으로 정정해 읽는다(무선언 침묵 전환의 scriptPath
변형은 인라인과 판정 로직 동일 — 별도 앵커 불요). **구 슬러그 잔존 픽스처명(smp 03 등)은 신 슬러그로
rename**(슬롯1 B2) + 신 메시지 내용 픽스처 1건(`max(작업자` 토큰 단언 — test_smp_hedge 동형) 동반.

### §16.3 리뷰 통합 (C17-B — §16.0-3 이 근거)

1. **Gate R 조건부화 — 판별자 = spec-delta (슬롯1 D1 보강)**: spec delta 없는 재진입 사이클(durable
   spec 무변경 — "delta 없음(no-op)" 경로)만 서브에이전트 Gate R 생략 + 메인 자기점검 체크리스트
   대체. **delta 사이클(신설 포함)은 Gate R 유지 — opus**(§16.1 매트릭스). ★self-pass 방어(D1 —
   "no-op 선언" 자체가 생략 주체의 자기증언이므로 선언만으론 순환): 생략 경로의 자기점검 1줄은
   **`git diff <직전 사이클 머지 커밋>..HEAD -- docs/superpowers/specs/` 의 0-diff 출력을 증거로
   동반**해야 한다(spec 디렉터리 무변경 = no-op 의 기계 판별 — 선언이 아니라 diff 가 판별자). diff 가
   비어 있지 않으면 no-op 선언은 무효 — Gate R 필수. 잔여: spec 에 반영했어야 할 delta 를 반영하지
   않은 채 no-op 를 선언하는 미반영-delta 는 diff 로 못 잡는다(그건 Gate R 이 있어도 spec 역류 누락
   클래스 — 기존 Gate R 의 성질과 동일한 상한, 수용). C15/C16/C17 전부 delta 사이클 — C17 자신도
   Gate R 실행.
2. **Closeout 통합 리뷰 (슬롯1 D2/D3/D4/D5/E3 보강)**: drift 검사(start-rpi-cycle Step C-1
   sub-step 1)와 senior review(closeout-pr-cycle Phase 4)를 **단일 opus 적대 리뷰 1회로 합본, 실행
   지점 = Phase 4(머지 전 — drift 발견도 머지 전 정정 가능해야 의미)**. senior 검사 범주 A~E + drift
   체크리스트(CONTEXT/plan 체크박스/자산 갱신 — **5 Whys 통과 non-obvious 누적 또는 명시 면제 기준
   포함(D4 — 구 sub-step 1 문면 승계, 합본에서 탈락 금지)**/silent-downgrade 실물 대조)를
   success_criteria 합본. **드리프트 체크리스트 항목의 미충족은 최소 Important 로 분류**하고, 통합
   리뷰 보고는 **drift 항목별 판정을 명시 절로 분리 출력**(E3 — Critical 강등으로 PASS 를 얻는 우회
   차단: 스탬프 조건은 "PASS"가 아니라 "drift 절 판정이 전항 명시됨"이다). context_paths 는 구 drift
   검사가 받던 실재 자산(CONTEXT.md·active plan·non-obvious.md)을 **합본 호출에 추가**(D3 — 입력
   없는 체크리스트는 vacuous). 출력 계약(Critical/Important/Minor·FAIL if any Critical) 불변.
   **Step C-1 sub-step 1 은 "Phase 4 통합 리뷰 결과 소비(포인터)"로 개정**, **sub-step 3
   `audit.last_drift_check` 스탬프 조건을 "통합 리뷰(drift 체크리스트 포함)가 실제 수행된 경우에만"
   으로 재바인딩**(cycle-17 D-F5 위장-방지 불변식 보존 — 조건의 지시 대상만 이동). **폴백 술어는
   "C-0 미충족"이 아니라 "Phase 4 통합 리뷰 미수행"**(D2 — C-0 은 충족했으나 local check FAIL·PR
   실패·PARTIAL·abandoned 로 Phase 4 에 못 간 사이클도 폴백 대상): Closeout 이 Step C-1 에 도달했을
   때 Phase 4 통합 리뷰가 수행되지 않았으면 **사유 불문 sub-step 1 단독 drift 검사 실행**(리뷰 0회
   사이클 방지 — 술어가 원인 열거가 아니라 결과 부재). **머지-전 최종 리비전 창(D5 — 정직 부기)**:
   통합 리뷰 후 브랜치에 추가되는 말미 커밋(CLAUDE.md §3·layer-yield append — §5-7 캐시 제약이 강제
   하는 순서)은 리뷰 미대상 창이다 — 수용 조건: 그 창의 허용 내용을 **선언적 기계 편집 2건으로 한정**
   (plan 최종 task 가 내용을 사전 명시 + verify-setup 재실행이 증인)하고 그 외 변경은 통합 리뷰 재실행
   대상. 두 SKILL+미러 동기.
3. **stage2 light-배칭 — carrier 무수정, plan-작성 규약**: 인접 light task(순수 문서·기계 편집)는
   **plan 단계에서 하나의 task 로 병합**(files 합집합·successCriteria conjunct·문서-편집 대체 규약
   명시). carrier 불변(seal #45 ⑦⑧⑨ 앵커·30000자 slice 자연 적용). 병합 상한: 합본 stage1 보고
   30k 초과 예상 시 분할 유지(slice 절단 = 후미 diff 소실 = false PASS 클래스). heavy(코드/TDD)는
   per-task 유지(RED/GREEN 증거 규약 보호). start-rpi-cycle (d) 절 문구 1곳.
4. **델타 재심(§15.4)·교차패밀리 2-슬롯(§15.5) 불변. layer-yield(§15.3)는 계약 유지 + 층 분류법만
   개정(슬롯1 E2)**: 통합 리뷰는 대장에 **`통합(senior+drift)` 1층 1행**으로 기록(senior·drift 2행
   분리 기재 금지 — 이중 계상; 층 목록의 "senior·drift" 는 "통합(senior+drift) — C-0 미충족/미수행
   폴백 시 drift 단독" 으로 개정). append 시점 규약(§15.3 "머지 전 마지막 커밋")과 통합 리뷰의 시간
   관계(E4): 통합 리뷰가 측정하는 층은 자신 이전의 층이고, 통합 리뷰 자신의 행은 리뷰 완료 직후
   기재 — auto-merge 사이클의 "C-0 이전 append 선행" 규약은 **통합 리뷰가 Phase 4 로 이동한 뒤에는
   "통합 리뷰 완료 직후·merge 명령 이전 append"** 로 재해석(§15.3 문면의 C-0 기준은 wait-merge 시대
   기록 — 재해석을 이 절이 명문화).

### §16.4 수용 잔여 (명문 — 검증 A-2 + 슬롯1 A2/A3/A5/D6/F2)

1. **Agent 경로 작업자-축 관측 불가**: per-call 입력이라 hook 이 작업자를 볼 수 없다 — 세션 축 제거
   후 "작업자를 opus 위로 상향한 사이클(V1/V3 fable 작업자)의 검증자 동반 상향"은 **L2 강제 불가,
   L1 규범 몫**(C13 §12.1 강제-범위 단락 선례 동형). §16.5 밸브가 fable 작업자를 합법화하므로 이 창은
   실경로 — 밸브 발동 규약에 검증자 동반 상향 의무 포함으로 방어. **frontmatter opus 가 보장하는 것은
   floor 의 opus-상수 절반뿐**(F2 — "판단-게이트 floor 전체를 공짜로 보장" 류의 서술 금지; 작업자
   절반은 항상 L1 몫).
2. **frontmatter 세션-내 캐싱 창**(§16.1): 전환 커밋 이전 시작 세션의 무지정=구 상속. advisory 오차
   수용(새 세션부터 소멸·경계 세션은 명시 규약).
3. **hook 무지정 평가의 frontmatter 의존**: Rule A/B/C/C2 의 "무지정=opus" 평가는 frontmatter 실물이
   opus 임에 의존 — frontmatter 회귀는 seal #5/#45(개정판)가 FAIL 로 표면화(L3 분담). seal 은 라인
   앵커 grep(토큰-존재 계열)이라 frontmatter 블록-스코프 판별은 아니다 — 본문에 같은 라인을 심는
   조작-내성은 seal 의 알려진 상한(#19 클래스, 위협 모델은 적대가 아니라 망각).
4. **미지-티어의 opus "평가"는 상계가 아니다**(A2/A3): Rule C2 의 미지-리터럴 실행자 opus 평가·동적
   실행자 세션 평가는 휴리스틱 — 미지/동적이 실제 fable 급으로 해소되면 floor 과소평가로 하한
   불변식이 L2 미탐이 된다(구 코드도 동적 축은 동일 클래스). 구조 해소는 런타임 관측을 요구해 텍스트
   휴리스틱 상한 초과 — L1(밸브 동반-상향 규약)이 방어선, 표에 정직 기록.
5. **Workflow 세션-미상(WF_TIER=0) 조기 exit**(A1 비대칭): Agent 경로 Rule B 는 리터럴-평가를 세션
   무관 수행하도록 개정되나 Workflow 경로는 유지 — C2 의 inherit/동적/폴백 평가가 세션 티어 필수라
   부분-평가 복잡도가 advisory 상한 초과. 비대칭 정직 부기.
6. **V3 밸브의 상한 부재**(D6): V2 와 달리 V3(goal 명시 실험)는 회수 상한이 없다 — goal 문서가
   비추적이라 선언의 감사물은 Closeout 보고의 FABLE-ESCALATION 목록 + layer-yield 부기뿐. 수용 근거:
   V3 의 정의 자체가 "goal 이 사전 지정"이라 사용자 승인이 선행하고(§16.0 U4 와 같은 권위 채널),
   Closeout 의 fable-0 실측(§16.0-1)이 미선언 소비를 표면화한다. 남용 관측 시 V2 동형 상한(사이클당
   ≤N) 도입이 예비 경로.

### §16.5 fable 예외 밸브 (C17-E — 명시 선언 없이는 위임 금지)

발동 조건 3종만. 각 발동 = 보고에 `FABLE-ESCALATION(<사유>)` 선언 + layer-yield 부기 + **검증자 동반
상향 의무**(fable 작업자 승인 시 그 산출물의 검증자도 fable — 하한 불변식의 L1 이행):
- **V1**: 사용자 명시 요청.
- **V2**: 판정 충돌 tie-break — opus 내부 게이트와 교차패밀리 GPT 가 같은 대상에 Critical 급으로
  상충할 때 1회 재심(사이클당 ≤1).
- **V3**: goal 이 명시한 실험/캘리브레이션(C17 에서는 §16.1 실측 ①② 가 사전 지정분 — 실측 중 fable
  스폰 4건은 지표 위반이 아니라 V3 카운트).

### §16.6 동반 갱신 전수 (L1 전파 — C16 T3 동형)

seal: **#5**(verify-setup :26-30 — `^model: inherit$` 루프 → `^model: opus$`, 카운트 불변 2 ok →
δ=0)·**#45 conjunct ③**(`^model:[[:space:]]*inherit` → `opus` + review effort 키 부재 유지) + 개정
seal 각각에 seal-regression 변이 동반(§13.13 — **기존 변이에 model 축 커버 0건이 실측**되어 신설이
곧 공백 해소다) + 기존 frontmatter 관련 변이 기대값 재계산.
문서 (슬롯1 B3/B4/B5/E1 로 전수 보강): model-policy.md 매트릭스(:19 검증 행·:22·§2·§3 L2 서술)·
CONTEXT.md 「검증자 기준선」(3차 supersede)·「실행자 하향 위임」·「역할×모델 매트릭스」·
cross-family-review.md §3(기준선 **첫 단락 + :67 내부 적대 패스 단락의 "티어=세션 상속(판단-게이트
floor)" — 둘 다**(E1); "동적 선택 불채택" 논거는 "정적 opus 상수"로 유지됨을 명시)·start-rpi-cycle
SKILL.md(Gate 디스패치 model 규약·(d) 경로·Gate R 조건부·Step C-1 재배선·**sub-step 9 층 분류법
"senior·drift"→"통합"**(E2))·closeout-pr-cycle SKILL.md(Phase 4 통합 리뷰 + **frontmatter description
·본문 요약의 "senior review" 서술**(B3))·README(:39·:56·:59 + **:69/:185/:234 의 2-리뷰 토폴로지
서술("이후 review-strict drift 검사"·"Phase 4 (Senior Review)")**(B3) + **:292/:530 cases 카운트
2곳**(Gate P B-2 — seal #20 이 양쪽 대조))·spec §3/§12.1/§15.1 supersede 포인터·scaffold-registry
(:24·:48·:83 + **:32 Closeout 요약 행**(B3))·**hook :180 Rule B 메시지의 §12.1 인용 잔존(C16 미갱신
— Rule B 재정의가 메시지 자체를 교체하며 자연 해소)**·**hooks/verify-loop-watch.sh :38 의
"closeout(review-strict drift + state.json 갱신)" 권고 문구**(B4 — "closeout(통합 리뷰 + state.json
갱신)" 으로)·CLAUDE.md §3(→ 세션 종료 직전 마지막 task — §1 캐시 제약).
**opencode 미러**: C17-A(모델 축) 몫은 **no-op**(미러에 agent frontmatter `model:` 키·
surface-model-policy 동형물 자체가 부재 — 2026-08-02 전수 grep 실측, 의도적 제외). C17-B(절차 축)
동기는 skill 2파일(start-rpi-cycle·closeout-pr-cycle) + **opencode-harness/AGENTS.md :25 의 §3
Closeout 서술**(B5 — CLAUDE.md §3 개정의 미러 동형; 세션 종료 직전 task 에 포함).

### §16.7 하우스키핑 (C17-C)

1. §12.1 의 C16 재실측 인용 중 `:56`("stage2 는 무지정") — 현행 실물(stage2 `model: 'opus'` 명시,
   :57)과 불일치 → 인용 주석 정밀화 1줄.
2. hook 2패스 구 "[C]2 REAL 기타 tier 0 비면제" 출처 주석 소실 — 행동 불변 확인 후 복원 1줄.
3. §15.2 의 PR#37 body "X1~X13" 라벨 오기(GT=X1~X15) 정오 1줄. → **정오 (C17)**: §15.2 표의 GT 는
   X1~X15 가 옳다(PR#37 body 의 "X1~X13" 은 오기).
4. review-yield.md C16 행 정정: `stage2 ×8` → `×9`(1차 7+재심 2), `5 PASS/3 FAIL` → `7 PASS/2 FAIL`
   (재심 2 PASS 포함 산술). **append-정정 행**으로(원행 편집 대신 정오 병기 — 축적 데이터 이력 보존).

### §16.8 교차패밀리 슬롯 1 + Gate P 트리아지 (2026-08-02~03 — A1~F4 + BLOCKER 2)

경로 A(`gpt-5.6-sol`·ultra·verbosity high·read-only·`-o` 슬롯별 파일). 대상 = §16 초판 + plan 초판.
GPT 제기 26건(A1~A6·B1~B5·C1~C7·D1~D6·E1~E4·F1~F4) + Gate P(opus) FAIL 2 BLOCKER. 전건 원문 실측
대조 트리아지 — **REAL 24 / 수용 잔여 전환 2(A2/A3 의 "상계" 주장 철회·D6 V3 상한) / 기각 0**:

- **A1(REAL)**: Rule B 의 `SESSION_TIER != 0` 전체-skip 이 미지-세션에서 리터럴 검증자 평가까지
  삼킴 — 리터럴 평가는 세션 불요 → floor arm 을 세션-무관으로 개정(§16.2). Workflow 조기 exit 은
  비대칭 수용(§16.4-5).
- **A2/A3(REAL→정직 전환)**: 미지/동적의 opus·세션 "상계"는 상계가 아님(실제 상위 해소 시 과소평가)
  → "평가(휴리스틱)"로 전면 개칭 + §16.4-4 수용 잔여 명문 + 반전 표에 A2 행 추가.
- **A4(REAL)**: 반전 표가 Rule B 의 동일-티어 구멍 소멸(sonnet+sonnet·haiku 조합) 누락 → 행 추가 +
  픽스처 신설.
- **A5(REAL)**: 작업자-측 `-`/미지 산식 교체를 판별하는 픽스처 부재(fable 세션 미지 실행자+opus
  검증자 = 구 ALERT/신 SILENT) → 반전 행 + 전용 픽스처.
- **A6(REAL — 최중대)**: fable-누출 arm 의 "fable 세션 한정" 게이트가 비-fable 세션의 fable 명시
  위임을 침묵시킴(U4 금지는 세션 무관) + Workflow 검증자 fable 은 floor 충족이라 전-무검 → Rule
  A/B/C 의 fable-리터럴 arm 전 세션 확장 + C2-leak arm 신설(§16.2). 밸브-정당 호출 오탐은 advisory
  환기로 수용.
- **B1(REAL)**: Rule C 발화 메시지·슬러그가 제거된 무선언 arm 서사("model 지정 없이") 잔존 →
  `rule-c-workflow-fable-leak` 로 교체. **B2(REAL)**: 신 슬러그·메시지 무픽스처 + smp 03 구 슬러그명
  잔존 → rename + 내용 픽스처(`max(작업자` 단언). **B3(REAL)**: README :69/:185/:234·
  scaffold-registry :32·closeout SKILL description 의 2-리뷰 토폴로지 서술 미열거 → §16.6 편입.
  **B4(REAL)**: verify-loop-watch.sh :38 구 drift 권고 → 편입. **B5(REAL)**: CLAUDE.md §3 개정의
  opencode AGENTS.md :25 미러 동형물 미열거 → 편입.
- **C1(REAL — Gate P BLOCKER-1 동일)**: smp 30 의 무선언 트리거가 신 의미론에서 죽어 3규칙 동시-emit
  판별 증발(277/277 불성립 실측) → 트리거-교체 클래스 편입. **C2(REAL)**: plan 의 방향 분류(4/5)와
  가드 계수(3/4) 오기 → 정정. **C3(REAL)**: T1(hook)→T2(frontmatter) 순서가 "hook 침묵 + frontmatter
  inherit" 커밋 창을 만듦 → **task 순서 교환**(frontmatter 선행 = 구 hook 소음-안전 창으로 대체).
  **C4(REAL)**: C2 메시지 "model 을 지우면 해소되지 않음"이 신 의미론에서 거짓 → "명시 inherit 로는
  해소 불가"로 교체. **C5(REAL)**: M15/M16 단언 부분문자열이 seal #5 만 증명(#45 미증) → 변이당 #5·
  #45 각 1 단언(4 assert). **C6(REAL)**: seal grep 이 frontmatter 블록-스코프가 아님 → #5 를 awk
  frontmatter-스코프로 강화 + #45 는 토큰-존재 상한 수용(§16.4-3 부기). **C7(REAL)**: 무지정/명시
  inherit 의미 분리 후 구 픽스처명("inherit-ok" 류)이 오독 유발 → 04/15/29 등 rename.
- **D1(REAL)**: Gate R 생략 술어가 자기증언 → spec-디렉터리 git-diff 0 출력을 기계 판별자로(§16.3-1).
  **D2(REAL)**: C-0 폴백 술어가 원인-열거라 "C-0 충족 후 Phase 4 미도달" 누락 → 술어를 "Phase 4
  미수행"으로(§16.3-2). **D3(REAL)**: 합본 리뷰 context_paths 에 drift 입력(CONTEXT·plan·non-obvious)
  부재 → 추가. **D4(REAL)**: 5 Whys/명시 면제 기준 탈락 → 승계 명문. **D5(REAL)**: 통합 리뷰 후
  말미 커밋 창 미검 → 허용 내용을 선언적 기계 편집으로 한정(§16.3-2). **D6(수용 잔여)**: V3 무상한
  → §16.4-6(사용자-권위 채널 + fable-0 실측이 표면화, 남용 시 상한 예비).
- **E1(REAL)**: cross-family §3 :67 "티어=세션 상속" 자기모순 예정 → 편집 대상 편입. **E2(REAL)**:
  layer-yield 층 분류법의 senior·drift 2층이 합본과 충돌 → "통합(senior+drift)" 1층 개정(§16.3-4).
  **E3(REAL)**: Critical-만-FAIL 이 drift 항목 강등-PASS 우회 허용 → 최소 Important + drift 절 분리
  출력 + 스탬프 조건을 "전항 명시"로. **E4(REAL)**: auto-merge append 시점 규약과 Phase 4 이동 충돌
  → 재해석 명문(§16.3-4).
- **F1(REAL)**: "layer-yield 가 사후 검증"은 과잉(자기보고 계량 — 약한 검증자는 PASS 증가 방향) →
  "사후 관측 신호 + GPT 층이 독립 대조군"으로 정정(§16.0-2). **F2(REAL)**: "frontmatter 가 floor 를
  공짜로 보장"은 opus-상수 절반만 참 → §16.4-1 부기 + 전파 문구 수정. **F3(REAL)**: "구조적 소멸"
  과잉 → "무지정 클래스 한정(신 세션 기준)"으로(§16.1). **F4(REAL)**: "세션 시작 시점 로드" 단정 →
  "세션-스코프 고정 관측(로드 시점 미판별)"로(§16.1).
- **Gate P BLOCKER-2(REAL)**: README cases 카운트 2곳(:292 "N case"·:530 "N 케이스") 중 :530 만
  치환 계획 — seal #20 이 양쪽 대조라 FAIL → §16.6 에 2곳 명시.
- **Gate P deviation(REAL)**: smp 11 의 반전/트리거-교체 이중 분류 → 트리거-교체로 확정(§16.2 말미).

**메타 관측**: 슬롯 1 2회차도 전건이 **코드 작성 전** 도착 — A6(U4 금지의 세션-축 구멍)·C1(fixture
회귀)·D2(리뷰-0 사이클 잔여 경로) 클래스를 설계 층에서 차단. Gate P(opus) 첫 실측이 산술 BLOCKER 2건
을 샌드박스 재현으로 잡음(§16.0-2 의 "opus 게이트 첫 실측" 데이터 포인트 — 발견 2건 REAL).
