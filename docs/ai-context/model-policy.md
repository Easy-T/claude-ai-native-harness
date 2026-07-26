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
| 구현 heavy (코드/TDD/다파일) | execute-strict | **opus** (fable 세션 한정 호출 인자 명시 — 비-fable 세션은 §2 모드 C 상속) | ultracode: **xhigh** / 그 외: 상속 | 사용자 확정: 구현은 opus + effort 품질-우선(2026-07-26 — 공식 effort 가이드: 에이전트 코딩=xhigh 권장 시작점) |
| 구현 light (기계적 편집·문서 생성) | execute-strict | **opus** (동일) | ultracode: **high** (실행 모델 기본 effort — *기본 분기*는 이 밑으로 불가) / 그 외: 상속 | sonnet 구현·effort 변경(max 포함 양방향)은 per-task 선언적 override만 — 명시=선언, 하향 선언은 plan의 DOWNGRADE-DECLARED 규율 |
| 탐색 (읽기 전용 발견·전수조사) | explore-strict | **sonnet** (frontmatter 기본) | **medium** (frontmatter 기본) | model 상향은 호출 인자로 자유. 판단-heavy 탐색은 builtin Explore(상속 — CC의 Opus 상한 가능성 있음) 또는 메인 직접 |
| 검증 (게이트·드리프트·적대) | review-strict | **상속 — 하향 금지** (상향 명시는 허용) | **상속 — 하향 금지** | 검증자 티어 ≥ **세션** 보장 (cross-family-review.md §3). 실행자를 세션 위로 상향했다면 검증자도 동반 상향 권고 |
| 교차 검증 (고-스테이크 closeout) | GPT | cross-family-review.md 규약 그대로 | — | 사이클당 1회 quota — stage별 GPT 검증 기각 |

- **상향은 항상 허용**(사유 불요). **하향**: 검증자 금지(유일 탈출구 = DOWNGRADE-DECLARED(사유)+사용자 승인) / 실행자·탐색자는 이 표 자체가 선언 — 표 밖 하향(예: 구현을 haiku로)은 DOWNGRADE-DECLARED(사유) 필요. hook(L2) Rule A는 부재/`inherit`/`fable`/`claude-fable-*` 표기를 감지 — 변수 조립 등 그 외 표기·builtin 에이전트는 L1/L3 몫(수용 잔여).
- GPT quota 주의: 일상 경량 Claude 작업에 luna 남발 금지 — 경량은 sonnet 우선.

## 2. 모드 분기

- **(A) fable + ultracode**: start-rpi-cycle Phase I (d) Workflow — stage1 `agentType:'execute-strict', model:'opus', effort:'xhigh'`(heavy) 또는 `effort:'high'`(light; plan task가 코드/TDD 포함이면 heavy, 순수 문서·기계 편집이면 light — 기본 분기는 실행 모델 기본 effort(high) 밑으로 내려가지 않음). per-task `effort` 필드로 선언적 override(프론티어급 난제=max). stage2 `agentType:'review-strict'` **model/effort 무지정**(상속). canonical 캐리어: `Workflow({scriptPath: "$HOME/.claude/workflows/rpi-implement.js" 절대경로, args: [...]})` — **도구는 `~` 미확장(실측)**, 절대경로 필수. worktree 격리는 canonical에서 미사용 — Workflow의 `isolation:'worktree'`는 에이전트별 독립 사본이라 stage2가 stage1 변경을 못 봄; 파일 공유 task는 스크립트가 자동 순차 실행.
- **(B) fable 비-ultracode** (max 이하 effort 포함): (a)/(b)/(c) 경로에서 execute-strict 위임 시 `model:'opus'` 명시. per-call effort는 플랫폼상 불가(Agent 도구 인자에 effort 없음) — 상속 수용.
- **(C) 비-fable 세션 (opus 등)**: 현행 상속 유지. 단 explore-strict frontmatter 기본(sonnet+medium)과 검증자 하향 감지(hook Rule B)는 전 세션 공유 이득.
- haiku/custom(GPT) 세션에서의 RPIC 사이클은 비권장 — 검증자 상속이 GPT가 되어 교차패밀리 전제가 뒤집힌다.

## 3. 강제 계층 (상보적 커버 — reload/upgrade 내성)

- **L1** = 이 문서 + start-rpi-cycle/SKILL.md 규칙(핵심 규칙 요지 + SSOT 포인터 — 전문 중복 금지; spec §4).
- **L2** = `hooks/surface-model-policy.sh` (PreToolUse `Agent|Workflow` 매처, advisory·항상 exit 0): Rule A(fable 세션 실행자 하향 미적용 — 부재/inherit/fable)·Rule B(검증자 하향, 전 세션)·Rule C(Workflow 스크립트의 execute-strict 무model/fable 감지)·Rule C2(Workflow 스크립트의 review-strict 하향 model 감지 — C12). Workflow 경로는 텍스트-휴리스틱 커버(변수 조립 미검출·주석 오판 가능 — canonical `workflows/rpi-implement.js`가 1차 방어, spec §10). 감지는 규칙별 1세션 1회 dedup — 같은 세션의 2번째 이후 위반은 침묵(환기 목적 트레이드오프).
- **L3** = verify-setup seal(#45 conjunctive): 이 문서 존재+토큰, explore-strict frontmatter, execute/review `model: inherit` 유지+review effort 키 부재, settings.example `Agent|Workflow` 매처 배선, `workflows/rpi-implement.js`의 `model: 'opus'`+effort 분기 토큰, start-rpi-cycle 토큰 parity(skill 재생성 소실 표면화). 토큰 존재 감지이지 로직 무결성 검증 아님(spec §6) — 로직 회귀는 run-all 픽스처가 담당.
- skill/plugin 재생성·업그레이드 내성: 강제는 git-추적 층(hook 배선·frontmatter·seal)에 있고, skill 텍스트 소실은 L3 토큰 parity가 FAIL로 표면화. plugins/cache는 정책 캐리어 금지.
