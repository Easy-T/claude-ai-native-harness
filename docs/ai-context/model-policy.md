# model-policy.md — 역할×모델 매트릭스 (런타임 규범 SSOT)

> 설계 근거·실측·기각 대안: `docs/superpowers/specs/2026-07-25-model-policy-design.md` (durable spec).
> 이 문서는 세션이 소비하는 규범만 담는다. 정책 키 = **(세션 모델, ultracode 여부)**.
> **버전-무관 불변식 (2026-07-26)**: 정책·디스패치 계층(이 문서·skill·frontmatter·hook·seal·workflow)은
> bare alias(fable/opus/sonnet/haiku)와 와일드카드(`claude-opus-*`)만 사용 — 구체 버전 ID(claude-opus-5 등)
> 바인딩은 **settings.json env(`ANTHROPIC_DEFAULT_*_MODEL`) 단일 지점**. 모델 세대 교체(5.1→6…) 시 그
> 파일만 갱신하면 전 계층이 따라온다. spec·memory·실증-기록 절(cross-family-review §4 등)의 버전
> 표기는 실측 역사 기록(genesis-record)이라 예외.

## 1. 역할×모델×effort 매트릭스

| 역할 | agent | 모델 | effort | 비고 |
|---|---|---|---|---|
| 오케스트레이션·판단·종합·게이트 해석 | 메인 세션 | 세션 모델 | 세션 effort | 위임 금지 — 플래그십의 존재 이유 |
| 구현 heavy (코드/TDD/다파일) | execute-strict | **opus** (frontmatter 기본 — C17 Option 1. 명시는 선택 보강; 무지정도 안전 기본) | ultracode: **xhigh** / 그 외: 상속 | 사용자 확정: 구현은 opus + effort 품질-우선(2026-07-26 — 공식 effort 가이드: 에이전트 코딩=xhigh 권장 시작점) |
| 구현 light (기계적 편집·문서 생성) | execute-strict | **opus** (동일 — frontmatter 기본) | ultracode: **high** (실행 모델 기본 effort — *기본 분기*는 이 밑으로 불가) / 그 외: 상속 | sonnet 구현·effort 변경(max 포함 양방향)은 per-task 선언적 override만 — 명시=선언, 하향 선언은 plan의 DOWNGRADE-DECLARED 규율 |
| 탐색 (읽기 전용 발견·전수조사·**웹 근거 조달**) | explore-strict | **sonnet** (frontmatter 기본) | **xhigh** (frontmatter 기본 — C13) | `WebSearch`+`WebFetch` 보유(웹 근거는 이 경로로 — 규약 밖 builtin 사용 금지). model 상향은 호출 인자로 자유. WebSearch는 세션당 200회를 전 서브에이전트가 공유 |
| 검증 (게이트·드리프트·적대) | review-strict | **상속 — 기준선 미만 금지** (상향 명시는 허용) | **상속 — 하향 금지** | 기준선 = **임무-분리 v2**(C17, spec §16): **준수-확인**(Workflow·Rule C2) = **작업자 티어**(실행자-전무 폴백 = **opus 정책 상수**) / **판단-게이트**(Agent 경로·Rule B) = **`max(작업자 티어, opus)`** — 세션 축 제거(U4). 평가: 무지정=frontmatter opus·명시 inherit=세션 티어·미지-리터럴 비면제. frontmatter opus 가 보장하는 것은 **opus-상수 절반뿐**(작업자 절반은 L1 — §16.4-1). 하한: 검증자 < 작업자 금지 |
| 교차 검증 (고-스테이크 closeout) | GPT | cross-family-review.md 규약 그대로 | — | 슬롯 2회(C16 §15.5) quota — stage별 GPT 검증 기각 |

- **상향은 항상 허용**(사유 불요). **하향**: 검증자는 **기준선(임무-분리 v2 — 준수-확인=작업자 티어 / 판단-게이트=`max(작업자, opus)`, spec §16) 미만 금지**(유일 탈출구 = DOWNGRADE-DECLARED(사유)+사용자 승인) / 실행자·탐색자는 이 표 자체가 선언 — 표 밖 하향(예: 구현을 haiku로)은 DOWNGRADE-DECLARED(사유) 필요. hook(L2) Rule A는 `inherit`/`fable`/`claude-fable-*` 명시 표기를 감지 — 변수 조립 등 그 외 표기·builtin 에이전트는 L1/L3 몫(수용 잔여).
- **fable 서브에이전트 위임 기본 금지**(U4). 예외 = 밸브 V1(사용자 요청)/V2(판정충돌 tie-break ≤1회)/V3(goal 명시 실험) + `FABLE-ESCALATION(사유)` 선언 + 검증자 동반 상향(spec §16.5). hook 은 명시 fable/inherit 를 전·조건 세션에서 환기(Rule A/B/C/C2-leak — 밸브-정당 호출에도 발화, advisory 오탐 수용).
- GPT quota 주의: 일상 경량 Claude 작업에 luna 남발 금지 — 경량은 sonnet 우선.

## 2. 모드 분기

- **(A) fable + ultracode**: start-rpi-cycle Phase I (d) Workflow — stage1 `agentType:'execute-strict', model:'opus', effort:'xhigh'`(heavy) 또는 `effort:'high'`(light; plan task가 코드/TDD 포함이면 heavy, 순수 문서·기계 편집이면 light — 기본 분기는 실행 모델 기본 effort(high) 밑으로 내려가지 않음). per-task `effort` 필드로 선언적 override(프론티어급 난제=max). stage2 `agentType:'review-strict'` **`model:'opus'` 명시**(작업자 티어 — spec §15.1)·**effort 무지정**(상속). canonical 캐리어: `Workflow({scriptPath: "$HOME/.claude/workflows/rpi-implement.js" 절대경로, args: [...]})` — **도구는 `~` 미확장(실측)**, 절대경로 필수. worktree 격리는 canonical에서 미사용 — Workflow의 `isolation:'worktree'`는 에이전트별 독립 사본이라 stage2가 stage1 변경을 못 봄; 파일 공유 task는 스크립트가 자동 순차 실행.
- **(B) fable 비-ultracode** (max 이하 effort 포함): (a)/(b)/(c) 경로에서 execute-strict 위임은 **frontmatter opus 가 기본**(C17 Option 1) — `model:'opus'` 명시는 선택 보강(전환-창 세션 방어). per-call effort는 플랫폼상 불가(Agent 도구 인자에 effort 없음) — 상속 수용.
- **(C) 비-fable 세션 (opus 등)**: execute/review-strict 는 frontmatter opus 고정(전 세션 — sonnet 세션에선 상향이며 항상 허용). explore-strict sonnet 불변.
- haiku/custom(GPT) 세션에서의 RPIC 사이클은 비권장 — 검증자 상속이 GPT가 되어 교차패밀리 전제가 뒤집힌다.

## 3. 강제 계층 (상보적 커버 — reload/upgrade 내성)

- **L1** = 이 문서 + start-rpi-cycle/SKILL.md 규칙(핵심 규칙 요지 + SSOT 포인터 — 전문 중복 금지; spec §4).
- **L2** = `hooks/surface-model-policy.sh` (PreToolUse `Agent|Workflow` 매처, advisory·항상 exit 0): **Rule A v2**(execute-strict fable 누출 — 명시 `inherit`(fable 세션 한정)·명시 `fable`(전 세션); **무지정은 침묵**(frontmatter opus=안전 기본) — 슬러그 `rule-a-fable-leak`)·**Rule B v2**(2계 arm, spec §16.2: **floor arm** = 평가 티어 < opus → ALERT[리터럴=tier_of·명시 inherit=세션 티어·무지정=opus·미지-티어 리터럴 비면제], 전 세션·미지-티어 세션 포함 / **누출 arm** = 명시 `fable`은 전 세션·명시 `inherit`은 fable 세션 한정 — 슬러그 `rule-b-verifier-below-opus-floor`·`rule-b-fable-leak`; 구 "세션 대비 하향" arm 제거)·**Rule C**(Workflow execute-strict 의 **무선언은 침묵**, 명시 `inherit`(fable 세션)·fable-리터럴(전 세션)만 ALERT — 슬러그 `rule-c-workflow-fable-leak`)·**Rule C2**(Workflow 검증자가 floor 미만 — floor = 실행자 티어 평가[리터럴=tier_of·무선언=**opus**(frontmatter)·명시 inherit=세션·동적 `*`=세션·미지-리터럴=**opus**], **실행자-전무 폴백 = opus 정책 상수**; 명시 inherit 는 model 삭제(=frontmatter opus)로 해소되나 inherit 유지로는 해소되지 않음 + **누출 arm C2-leak**(검증자 fable-리터럴 전 세션·명시 inherit fable 세션 한정 — 슬러그 `rule-c2-fable-verifier`))·Rule C3(**model 을 선언하지 않는** 스폰의 세션 모델 상속 역류 — agentType 부재 또는 frontmatter 에 model 이 없는 builtin; 단 일부 builtin 은 CC 자체 바인딩으로 비상속(Explore=opus·claude-code-guide=haiku — spec §14.2 실측, 제외목록 불변·메시지 hedge 만), fable 세션 한정; explore-strict 는 frontmatter sonnet 보유라 제외, C13·C14). Workflow 경로는 `hooks/lib/workflow-spawns.js`가 스폰을 **개별 추출**(렉서 기반: 주석·문자열·템플릿·정규식 마스킹, opts 깊이-0 프로퍼티 워크). 출력 계약은 스폰당 `<agentType>\t<model>` — **두 축 모두 3값**(C15) — agentType: 리터럴/`?`(키 부재)/`*`(키 존재·동적) · model: 리터럴/`-`(키 부재)/`*`(키 존재·동적). 동적 선언(`model: f()`)은 "무선언"이 아니므로 Rule C/C2/C3 전부 면제된다 — 면제는 안전 인증이 아니라 판정 불가의 정직 표기(L1 규범은 여전히 적용). 동적 조립(`MODELS[i]`)은 `*` 로 보고되며, agentType `*` 는 상속을 단언할 수 없어 Rule C3 대상이 아니다. canonical `workflows/rpi-implement.js`가 1차 방어(spec §10·§12.6). 감지는 규칙별 1세션 1회 dedup — 같은 세션의 2번째 이후 위반은 침묵(환기 목적 트레이드오프). 한 호출에서 성립한 규칙은 **전부** 함께 환기(우선순위 손실 없음).
- **L3** = verify-setup seal(#45 conjunctive): 이 문서 존재+토큰, explore-strict frontmatter, execute/review `model: opus`(C17 Option 1 물리 기본값)+review effort 키 부재, settings.example `Agent|Workflow` 매처 배선, `workflows/rpi-implement.js`의 `model: 'opus'`+effort 분기 토큰, start-rpi-cycle 토큰 parity(skill 재생성 소실 표면화). 토큰 존재 감지이지 로직 무결성 검증 아님(spec §6) — 로직 회귀는 run-all 픽스처가 담당.
- skill/plugin 재생성·업그레이드 내성: 강제는 git-추적 층(hook 배선·frontmatter·seal)에 있고, skill 텍스트 소실은 L3 토큰 parity가 FAIL로 표면화. plugins/cache는 정책 캐리어 금지.
