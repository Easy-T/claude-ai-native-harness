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
SessionEnd hook `worktree-teardown.sh`가 종료 세션의 *링크된* 워크트리를 삭제하는 절차. 불변식=데이터손실 0: 삭제 대상은 `git rev-parse --absolute-git-dir`로 링크 워크트리(`/worktrees/` 세그먼트 + basename==NAME)임이 증명된 단 하나; reparse point(정션)는 `rm` 전 *링크-only 선제거*(PowerShell 비재귀 `[IO.Directory]::Delete($false)`)로 제거해 정션이 `rm`에 도달 못 하게 한다. `git worktree remove --force` 미사용(정션 추종 사고 1차 범인). matcher가 `clear`/`resume` 제외(세션 지속 보호). 세션이 워크트리 밖으로 cd해도(closeout가 메인루트로 이동) 정리되도록 SessionStart가 `session_id`-키 마커(`~/.claude/worktrees-marker/<sid>`=WT_ROOT)를 기록하고 SessionEnd가 자기 SID 마커를 소비하는 **fallback**을 둔다(cwd가 authoritative·마커는 GUARD2/3 통과 후에만 삭제·빈 SID는 마커 skip).
_Avoid_: "워크트리 정리"(`git worktree prune`와 혼동), "rm 워크트리"(가드 생략 함의), "마커=삭제권한"(마커는 fallback 식별자일 뿐, GUARD2/3가 authoritative).
