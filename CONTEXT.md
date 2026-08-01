# CONTEXT.md — 하네스 도메인 용어집

> 이 저장소(전역 `~/.claude` 하네스)의 canonical 용어. 구현 세부사항 없음 — 용어집 전용.
> 형식: 용어 / 정의 / _Avoid_ (금지 별칭). grill-with-docs가 갱신.

## Terms

### active plan
`docs/superpowers/plans/*.md` 중 head-20 안에 `**Status:** active` 또는 `**Status:** in_progress`를 **명시적으로** 가진 plan. (cycle-23부터 — 이전의 "Status 줄 없음 + 미체크 박스" fallback은 active로 인정하지 않는다.)
_Avoid_: "진행 중 plan"(상태 라벨과 혼동), "열린 plan".

### stale-active plan
사이클이 실제로는 마감됐는데(state.json cycle.count 증가) Status 헤더가 active로 남았거나 아예 없는 plan. RPI 게이트를 영구 개방시키는 anomaly.
_Avoid_: "잔재 plan"(원인 불특정 어휘).

### explicit-Status 의미론
has_active_plan이 명시 Status 헤더만 신뢰하는 결정론(cycle-23 채택). 파일 touch·편집으로 게이트가 연장되지 않는다.
_Avoid_: "mtime 캡 방식"(검토 후 기각된 대안).

### fail-open
차단 hook이 자기 고장(node 부재, 파서 예외, 런타임 에러) 시 차단 대신 허용으로 빠지는 설계. 의도된 트레이드오프이나 **무표면**이면 결함 — 고장은 표면화돼야 한다. 런타임 표면화 실현(cycle-32, rank6/G6-a): `enforce-rpi-bash.sh`가 redirect-targets.js 크래시를 **종료코드로 감지**(크래시≠빈출력)해 `hook_log FAILOPEN`+stderr로 표면화(fail-open 유지, 차단 아님)하고, `session-start-audit.sh`가 차기 세션 시작에 `hooks/lib/*.js` 런타임 스모크(`</dev/null` 무해입력)로 손상 파서를 ALERT한다. `setup/tests/failopen-surface.test.sh`(verify-all STAGE 2c)가 격리 복제본 크래시 스텁으로 표면화를 E2E 증명. SECURITY.md:19가 신뢰베이스(node/_common.sh 무결성 전제)를 명시.
_Avoid_: "안전 실패"(fail-safe와 방향 반대).

### conservative block (보수차단)
쓰기 타깃을 추출할 수 없는 명령(`git apply`, `patch`)을 active plan 부재 시 명령 단위로 차단하는 정책. docs 패치 false-positive를 의식적으로 감수, RPI_SKIP이 탈출구.
_Avoid_: "전면 금지"(plan 있으면 통과한다).

### drift seal (봉인)
verify-setup.sh의 특정-인스턴스 체크로 거버넌스 사실의 재드리프트를 막는 장치(#17~#25·#27~#30 실재; #26은 미채택·번호 소각). generalized 프레임워크 아님 — 안정 앵커가 있는 인스턴스만. seal이 드리프트에 실제로 발화함은 `setup/tests/seal-regression.test.sh`(verify-all STAGE 2b)가 임시 $HOME 복제본에 대표 변이(schema #30·parity #23·count #20)를 주입해 non-zero exit+FAIL 메시지를 E2E로 증명(cycle-31, G4-a) — 자가-표면화의 메타 레벨.
_Avoid_: "범용 parity 검사".

### genesis record
durable spec 본문의 v1 시점 숫자·기술을 의도된 역사 기록으로 보존하는 모델(Model-1, cycle-21 확정). 현재값 SSOT는 README + seal.
_Avoid_: "stale spec"(드리프트로 오인).

### 자가-표면화 (self-surfacing)
필수 절차의 누락이 침묵하지 않고 구조적으로 드러나게 하는 장치(고유 필수 보고 필드, 상시 표시, 차단 메시지 안내). 물리 강제가 불가한 곳의 수락된 상한.
_Avoid_: "강제"(advisory 표면과 혼동 금지).

### worktree teardown (정션-안전 삭제)
SessionEnd hook `worktree-teardown.sh`가 종료 세션의 *링크된* 워크트리를 삭제하는 절차. 불변식=데이터손실 0: 삭제 대상은 `git rev-parse --absolute-git-dir`로 링크 워크트리(`/worktrees/` 세그먼트 + basename==NAME)임이 증명된 단 하나; reparse point(정션)는 `rm` 전 *링크-only 선제거*(PowerShell 비재귀 `[IO.Directory]::Delete($false)`)로 제거해 정션이 `rm`에 도달 못 하게 한다. `git worktree remove --force` 미사용(정션 추종 사고 1차 범인). matcher가 `clear`/`resume` 제외(세션 지속 보호). SessionStart/End hook cwd는 항상 CLI 실행디렉터리(메인루트)지 워크트리가 아니므로(cycle-40 정정, spec §10), 워크트리 절대경로가 실제 도달하는 **PreToolUse**(enforce-rpi-cycle/bash)가 `session_id`-키 마커(`~/.claude/worktrees-marker/<sid>`=WT_ROOT)를 기록하고 SessionEnd가 자기 SID 마커를 소비하는 **fallback**을 둔다(SessionStart는 launched-from-worktree 보조; cwd가 authoritative·마커는 GUARD2/3 통과 후에만 삭제·빈 SID는 마커 skip·다른 SID 마커가 같은 WT_ROOT면 정리 보류=C5 동시성 가드). 워크트리 *디렉터리*가 harness/외부에 의해 제거돼 SessionEnd가 식별 못 하는 잔여(git 등록 prunable + `worktree-*` 브랜치 누적)는 `session-start-audit`의 **self-healing sweep**(`git worktree prune` + live worktree 미점유 고아 `worktree-*` 브랜치만 `-D`)가 식별-무관하게 청소; 활성 워크트리/타세션 브랜치/비-컨벤션 브랜치 보호(C5 원리), `.claude/worktrees` 존재 프로젝트로 게이트(spec §11).
_Avoid_: "워크트리 정리"(`git worktree prune`와 혼동), "rm 워크트리"(가드 생략 함의), "마커=삭제권한"(마커는 fallback 식별자일 뿐, GUARD2/3가 authoritative).

### anti-slop floor
design.md §6 체크리스트가 검사하는 "나쁨의 부재" 기준선(18항목). 삭제 절대 금지 — 문구 정련·랩 증거 기반 스코프 예외만 허용.
_Avoid_: "anti-slop 완화"(floor 삭제 함의), "체크리스트 축소".

### craft ceiling
"좋음의 존재"를 검사하는 상한 기준(위계 점프 ≥3단계·signature move 존재·밀도 완급 등, design.md v2 신설). floor와 이원 축 — floor 통과가 ceiling 통과를 함의하지 않는다.
_Avoid_: "quality bar"(단일 축 오해).

### signature move
페이지당 정확히 1개 허용되는 기억에 남는 표현 순간(오프닝 안무·스크롤 전환·예상 밖 그리드 등). 0개 = ceiling 미달, 2개+ = 완급 붕괴.
_Avoid_: "wow factor"(수량 상한 없는 어휘).

### FRICTION 채록
design lab에서 현행 design.md가 침묵/부족/과광역/틀림/충돌인 지점을 규칙 단위(`F-L<n>-<seq>`)로 증거(스크린샷·코드 라인)와 함께 기록하는 절차. v2 신규 규칙의 유일한 원료 — 무증거 규칙 금지.
_Avoid_: "버그 리포트"(코드 결함과 혼동 — 대상은 문서의 결함).

### cold-agent fitness
문서**만** 받은 새 에이전트가 ≤N 이터레이션 내 floor+ceiling을 재현하는지로 **문서 품질**을 판정하는 수용 기준. FAIL은 사이트가 아니라 문서의 결함으로 회귀한다.
_Avoid_: "사이트 품질 테스트"(판정 대상 오인).

### design lab
`~/.claude/_design-lab/` — gitignored(`/_*/`) 실증 작업장. 실사이트 제작으로 미학 상한을 실증하고 FRICTION을 채록한다. 사이트는 증거, 문서가 제품 — 랩 산출물 자체는 배포물이 아니다.
_Avoid_: "데모 사이트"(산출물로 오인).

### 동시-세션 격리 (concurrent-session isolation)
병렬 Claude 세션이 공유하는 ambient 싱글톤(Playwright chrome 프로필·dev 포트·dev서버 프로세스)에 대한 규약: 동시 세션은 상대 프로세스를 kill하지 않고(상호 파괴 방지) 대기 또는 isolated/ephemeral 프로필+세션별 포트로 회피. 경로-스코프 kill(worktree-teardown STEP A: 자기 워크트리 경로 매칭만)이 안전 준거. SECURITY.md에 안전모델 명시.
_Avoid_: "프로세스 정리"(광역 kill 함의), "stale-process kill"(단일세션 시간축과 혼동 — 이쪽은 다중세션 공간축).

### deadline invariant (문서-먼저 불변식)
모델 가용 종료 등 하드 데드라인 하에서, 판단 산출물(문서)이 구현보다 먼저 머지되어야 한다는 이니셔티브 최상위 불변식(harness-upgrade-2026-07). 어느 시점에 세션이 끊겨도 그때까지 머지된 문서로 다른 모델이 재개 가능해야 하며, "문서 없이 구현만 남는 것"이 유일한 실패 모드다.
_Avoid_: "문서 우선"(우선순위 선호로 오독 — 이것은 머지 순서 강제), "마감 준수"(일정 관리로 오독).

### Best-Direction Mandate (최선-방향 강제)
"구현이 복잡하면 열화 대안을 '최적'이라며 선택"하는 관찰된 결함을 교정하는 하네스 장치(사용자 관찰 2026-07-13, goal §4가 canonical). 핵심 구분: *스코프 최소주의*(요청 밖 기능 금지 — Simplicity First, 유지)와 *아키텍처 품질*(채택한 설계는 알려진 최선이어야 하며 열화는 선언 없이 불가 — 신설)은 서로 다른 축이다. Simplicity First는 열화의 알리바이가 아니다.
_Avoid_: "단순화 금지"(스코프 최소주의까지 부정하는 오독), "최선 노력"(best-effort와 혼동 — 이것은 방향 선택 규율).

### silent downgrade (무선언 열화)
알려진 최선 설계 대신 더 쉬운 대안을 **선언 없이** 채택하는 행위. 탈출구는 `DOWNGRADE-DECLARED(사유)` 표면화 + 사용자 승인 — RPI_SKIP과 동형의 의식적 우회 패턴. 열화 자체가 아니라 *무선언*이 결함이다.
_Avoid_: "타협"(정당한 트레이드오프 선언까지 포함하는 중립어), "간소화"(스코프 축소와 혼동).

### 실행자 하향 위임 (executor downshift)
fable 세션이 실행자(execute-strict)·탐색자(explore-strict) 위임을 역할×모델 매트릭스의 하위 모델+effort로 디스패치하는 **정적·문서화** 정책(SSOT=docs/ai-context/model-policy.md). 검증자(review-strict)는 대상 아님 — [[검증자 기준선]](임무-분리 — C16)이 별도 규율. 오케스트레이터의 동적 모델 재량이 아니다.
_Avoid_: "동적 모델 선택"(기각된 재량 — self-pass 우회로), "모델 다운그레이드"(품질 열화 함의 — 이것은 역할 적합 배치).

### 역할×모델 매트릭스 (role-model matrix)
(세션 모델, ultracode 여부) 2키로 역할(오케스트레이션/구현/탐색/검증)별 모델·effort를 정하는 정적 표. 상향은 항상 허용, 하향은 검증자가 [[검증자 기준선]](임무별 floor — C16) 미만 금지·실행자는 표 자체가 선언. SSOT=docs/ai-context/model-policy.md.
_Avoid_: "모델 정책"(범위 불명 — ANTHROPIC_* 라우팅 env 설정과 혼동), "모델 라우팅"(CLIProxy 티어 매핑과 혼동).

### 검증자 기준선 (verifier floor)
검증자(review-strict)의 모델 티어가 넘어야 하는 하한 — **임무-분리**(검문의 임무별 floor)된다(C16, 2026-08-02 — C13 일괄 `max(세션,작업자)`의 의식적 supersede, spec §12.1→§15.1). **준수-확인 임무**(Workflow 경로 = canonical carrier stage2): floor = **작업자 티어**(실행자 부재 스크립트는 세션 티어 폴백 — 보수 유지). **판단-게이트**(판단-필요 게이트, Agent 도구 경로 = Gate R/P·senior·drift): floor = **`max(세션 티어, 작업자 티어)` 유지**(Rule B 불변). 근거: C15 per-layer 수율 실측 — stage2는 준수-확인 임무에서 내용 발견 0, Gate P가 유일한 내부 발견 층. 하한 불변식: 어떤 임무에서도 검증자 < 작업자 금지. **무지정(상속)은 면제가 아니라 "세션 티어로 평가"**다(C13 Closeout, 불변): 상속 검증자는 세션 티어로 셈해 floor와 비교한다.
_Avoid_: "검증자 하향 금지"(무엇 대비 하향인지 불명 — 이 모호성이 C13 이전 SSOT 드리프트의 원인), "검증자 상속"(inherit는 구현 수단이지 기준이 아님), "일괄 floor"(C16 이후 임무 축이 선행한다).

### 스캐폴드 산출물 경계 (scaffold-output boundary)
`docs/ai-context/{architecture,domain-glossary,deny-patterns,runbook}.md`는 `init-ai-ready-project`가 **대상 프로젝트에** 생성하는 산출물이지 하네스 자신의 자산이 아니다(cycle-31 판정, spec §13.4 — `git log --all` 전부 빈 출력로 확증). 경계는 **파일명**에 걸리지 *디렉터리*에 걸리지 않는다 — `docs/ai-context/`에는 하네스 소유 추적 파일(model-policy·cross-family-review·memory-policy·plugin-pins·scaffold-registry, +C14의 non-obvious)이 함께 산다. skill이 두 문맥(하네스·대상 프로젝트)에서 모두 도므로 부재 경로 지시는 **삭제가 아니라 조건부 선언**("실재하는 것만")으로 정정한다.
_Avoid_: "ai-context 파일 누락"(부재가 사고라는 함의 — 아키텍처 경계다), "ai-context는 프로젝트 전용"(디렉터리 전체로 과잉 일반화 — Gate R이 반증한 초안 오류).

### 모델-무선언 스폰 (model-undeclared spawn)
Workflow `agent()` 스폰 중 `opts.model`이 없고 **그 agentType의 frontmatter도 model을 선언하지 않는** 것 — **통상** 세션 모델을 상속하므로 fable 세션에서 역류한다(예외: [[builtin 자체 바인딩]] 2종 — Explore·claude-code-guide 는 비상속, spec §14.2). 판정 축은 *agentType의 명시 여부*가 아니라 **model 선언의 존재**다(spec §13.3): `explore-strict`는 agentType 명시이나 frontmatter `model: sonnet`이라 역류 없음 / `general-purpose`는 `agents/` 파일 자체가 없어 선언할 곳이 없으므로 역류. Rule C3의 대상 축. **[[동적-model 스폰]]은 무선언이 아니다**(C15 — 선언은 있고 값만 런타임 결정; 파서 기호 `*`).
_Avoid_: "agentType-less 스폰"(C13의 좁은 독법 — 키 부재만 포함해 builtin 리터럴을 놓친다), "미지정 스폰"(무엇이 미지정인지 불명), "동적 model = 무선언"(C15 이전 계약의 붕괴 — 오탐의 원인).

### 동적-model 스폰 (dynamic-model spawn)
Workflow `agent()` 스폰 중 `model` 키는 존재하나 값이 단일 문자열 리터럴이 아닌 것(`model: chooseModel()`, `model: M`, 삼항 등). 파서 계약 기호 `*`(C15 3값 확장 — 리터럴/`-`=키 부재/`*`=동적). 정적으로 값을 알 수 없으므로 Rule C/C2/C3 전부 **면제** — agentType `*` 면제(§13.3 ③ "단언 불가")와 동일 원리. 면제는 "안전 인증"이 아니라 "판정 불가의 정직 표기"다 — L1 규범은 여전히 적용된다.
_Avoid_: "무선언 취급"(C15 이전 안전-방향 붕괴 — Rule C3 오탐을 만든 독법), "미선언"(선언은 존재한다).

### builtin 자체 바인딩 (builtin self-binding)
`agents/*.md` frontmatter 없이 CC 바이너리가 자체적으로 모델을 정하는 builtin agentType의 성질 — C15 실측: `Explore`=opus 티어·`claude-code-guide`=haiku 티어(≠세션 상속). "파일 부재 → 세션 상속" 구조 추론을 반증한 클래스(spec §14.2). CC 버전-의존 경험 사실이라 정책 계층(제외목록)에 넣지 않는다 — 업그레이드로 조용히 뒤집히면 미탐이 되므로.
_Avoid_: "builtin 상속"(2종은 상속하지 않는다 — 과잉 일반화), "builtin frontmatter"(파일이 없다).

### 재현 픽스처 동반 (fixture-paired registration)
non-obvious 등록 항목이 **재현 픽스처 경로를 필수 필드로** 갖는 규약(GAP-012). 등록만 있고 재현자가 없으면 다음 사이클이 같은 가정을 반복한다 — C13이 "goal은 없을 것"을 확인 없이 승격한 실패(spec §13.1)가 그 실증. 픽스처는 "테스트 통과"가 아니라 **요구 충족**을 겨눈다.
_Avoid_: "교훈 기록"(재현자 없는 산문과 혼동), "회귀 테스트"(일반 테스트와 혼동 — 이것은 *실패 클래스*에 결속된 것).

### 층별 수율 (layer yield)
사이클의 검문 층(Gate R/P·stage2·senior·drift·교차패밀리)별로 "실발견(내용 결함) N건 vs 확인"을 기록하는 계량 축(C16 신설). Closeout 고유 필수 필드 `layer-yield:`가 캐리어, 축적 대장은 `docs/ai-context/review-yield.md`. 목적: floor·리뷰 배분 결정을 감이 아니라 축적 데이터로 재심. "확인"은 낭비가 아니라 성격 분류다 — 준수 강제(TDD RED 증거 등)의 억지 효과는 분리 측정 불가로 수용.
_Avoid_: "리뷰 ROI"(토큰 수치가 필수인 듯한 함의 — 필수는 발견 카운트뿐), "검증 효율"(검증 축소 정당화로 오독).

### 델타 재심 (delta re-review)
게이트/스테이지 FAIL 후 재실행 리뷰의 success_criteria를 "직전 FAIL이 지목한 항목 각각의 해소 + 그 정정이 새로 깨뜨린 것 없음"으로 한정하는 규약(C16). 전체 기준 재검은 첫 회만. 근거: C15 Gate P #2가 발견 3건 재검에 전체 재리뷰 83k 지출.
_Avoid_: "재검증 생략"(스코프 한정이지 생략이 아님), "증분 리뷰"(diff-증분과 혼동 — 이것은 FAIL-항목 스코프).

### 핸드오프 복원력 (handoff resilience)
임의 시점 중단 후 다른 모델·세션이 **머지된 문서만으로**(이 머신의 auto-memory 없이) 작업을 재개할 수 있는 성질. 산출 문서의 self-containment(필요 사실 인라인 재서술)가 성립 조건이며, cold-agent fitness가 검증 수단.
_Avoid_: "인수인계 문서"(문서 존재만으로 충족되는 듯한 함의 — 재개 *가능성*이 기준), "백업"(상태 보존과 혼동).
