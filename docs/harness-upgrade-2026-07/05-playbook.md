# 05 — Opus 운영 플레이북 (harness-upgrade-2026-07 이니셔티브)

> 대상 독자: **이 문서 세트만 가진 임의 모델·임의 세션**(Opus 상정). 전제 = 이 git repo(`~/.claude`) + Claude Code + 이 디렉터리의 문서 6종. **이 머신의 auto-memory(프로젝트 메모리)를 참조하지 않는다** — 필요한 사실은 전부 여기 인라인되어 있고, 메모리와 이 문서가 충돌하면 **문서+실물 코드가 우선**이다.
> 목적: 04-gap-backlog의 항목을 하네스 규약대로 안전하게 구현하고, 03-rubric을 갱신하며, 핸드오프 불변식(어느 시점에 끊겨도 재개 가능)을 유지한다.

## 0. 30초 오리엔테이션

- 이 repo는 **글로벌 Claude Code 하네스이자 자기 자신이 RPIC 사이클로 진화하는 프로젝트**다. master가 기본 브랜치, PR로 머지한다.
- 거버넌스 교리: **강제는 hook(결정론), 프롬프트는 권고**(SECURITY.md). 규칙을 추가할 땐 prose가 아니라 hook/seal/테스트로.
- 이니셔티브 목표: 04의 갭들을 사이클당 1~3개 구현해 03의 목표 레벨에 도달. **첫 착수 = GAP-001**(Best-Direction Mandate, C1 고정).
- 이 이니셔티브의 merge 정책: **auto**(사용자 위임, `_goal/harness-upgrade-2026-07-goal.md` 상단 선언) — 검증 ALL PASS 전제로 PR 머지까지 자동. 그 외 이니셔티브·작업에는 적용하지 않는다(기본은 사용자 승인 대기).

## 1. 사이클 운영 규약 (RPIC — 하네스가 물리 강제한다)

**차단 hook이 있어서 순서를 건너뛸 수 없다**: 코드 파일 쓰기(Write/Edit + bash 리다이렉트·tee·sed -i·cp/mv 등)는 head-20에 `**Status:** active`를 가진 plan이 `docs/superpowers/plans/`에 없으면 **차단**된다(enforce-rpi-cycle·enforce-rpi-bash). plan보다 먼저 durable spec이 있어야 한다(spec-before-plan 게이트). 우회는 `RPI_SKIP=<사유>` env뿐이며 사용이 표면화된다. ≤5줄 trivial 변경과 .md 문서는 게이트 비대상.

절차 (start-rpi-cycle skill이 canonical — `skills/start-rpi-cycle/SKILL.md` 필독):

1. **Phase R**: 이 이니셔티브의 durable spec은 이미 존재 — `docs/superpowers/specs/2026-07-13-harness-upgrade-2026-07-design.md`. 재진입 사이클은 spec을 **읽고**, 새 설계 결정이 생겼으면 in-place 개정(개정일 명기), 없으면 "delta 없음" 명시. Gate R = review-strict로 spec↔CONTEXT.md 용어 정합 검증.
2. **Phase P**: `docs/superpowers/plans/YYYY-MM-DD-harness-upgrade-c<N>-<topic>.md` 작성. 헤더 필수: `**Status:** active` / `**RPI-Cycle:** <state.json count+1>` / `**Started:** YYYY-MM-DD`. Gate P = review-strict로 spec↔plan 정합.
3. **Phase I**: plan task 순서대로 TDD(RED 재현→GREEN). 04의 각 GAP에 "테스트 계획(RED)"이 있다.
4. **Closeout**: 아래 §3 검증 → PR → 머지 → plan `**Status:** completed` → `state.json` cycle.count +1·last_completed_at 갱신 → 04 상태·03 재채점·README 상태 갱신(같은 PR에 — 갱신 계약) → 사이클 보고(한국어).

**워크트리**: 메인 디렉터리가 다른 브랜치 작업 중일 수 있다 — `EnterWorktree`(네이티브 도구)로 격리 후 origin/master 기준 작업이 안전 기본값. 이 하네스는 SessionEnd에 워크트리를 자동 정리(worktree-teardown)하며, 정리 실패 잔여는 session-start-audit의 sweep이 청소한다 — 수동 `git worktree remove --force`는 금지(정션 추종 사고 이력).

## 2. GAP 항목 착수 절차 (공통 체크리스트)

1. 04에서 해당 GAP 블록 전체 + 03의 해당 차원(앵커·현행 증거) + 01의 참조 섹션을 읽는다.
2. spec delta 판단(§1-1) → plan 작성(§1-2). plan에는 GAP의 "수용 기준"을 그대로 성공 기준으로 옮긴다.
3. **Best-Direction Check**(GAP-001 착륙 전에도 이 이니셔티브 안에서는 수행): 04의 "Best-direction 근거"에 적힌 최선안과 다른 접근을 택하려면 plan에 `DOWNGRADE-DECLARED(사유)`를 명시하고 사이클 보고에 포함 — 무선언 열화 금지.
4. RED 먼저: GAP의 "테스트 계획(RED)"대로 실패를 먼저 재현. **기억·문서 속 재현 명령이 현 코드에서 여전히 RED인지 실측 후 진행**(가드 리팩터링이 테스트를 vacuous하게 만든 전례가 있다 — 아래 §5 함정 7).
5. 구현 → GREEN → §3 검증 전건 → Closeout.

## 3. 검증 커맨드 전문 (Closeout 필수 — 전부 exit 0이어야 머지)

```bash
bash setup/verify-setup.sh        # 구조·seal 검사. 2026-07-13 기준선 PASS=70 FAIL=0
bash hooks/tests/run-all.sh       # hook 동작 156 케이스(cases.tsv 양방향 정합+95% 플로어)
bash setup/verify-all.sh          # 통합: doctor→verify-setup→seal-regression→failopen→run-all→teardown(E2E)→verify-integration. "ALL PASS" 출력 확인
```

- **기준선이 움직였다면**(체크를 추가/제거한 사이클): README.md의 해당 카운트 선언도 같은 커밋에서 갱신 — seal #20(run-all 케이스 수)·#21(E2E 수)이 README와 실측의 parity를 강제하므로 어긋나면 verify-setup이 FAIL한다. verify-setup 총 수(70)는 현재 **무봉인**(GAP-009가 seal 신설 예정) — 그래도 README:283 숫자를 손으로 동기하라.
- drift 검사: closeout에서 review-strict subagent에 "CONTEXT.md·architecture 문서 갱신 여부, plan 체크박스 완결, 미신고 열화 없음"을 PASS/FAIL로 검증시킨다(start-rpi-cycle Step C-1의 success_criteria 참조).
- PR: `gh pr create` → 검증 로그를 PR 본문에 → auto-merge(이 이니셔티브 한정) → `git checkout master && git pull`.

## 4. 03 재채점 절차

사이클이 터치한 차원만: 앵커 대비 새 증거(커맨드 출력·file:line) 수집 → 03의 해당 차원 "현행" 갱신+사유 1줄 append → 종합표 갱신 → 04 상태 갱신 → README 상태 테이블 갱신. **앵커 수정 금지**(비교 무효화 — 결함 발견 시 새 버전 append+[retired]).

## 5. 하네스 고유 함정 (인라인 — 전부 실사고 유래)

1. **CLAUDE.md(글로벌·프로젝트 루트) 수정은 세션 종료 직전에만** — 시스템 프롬프트 prefix에 로드되어 세션 중 수정 = 캐시 무효화(비용 ~20배). GAP-001의 헌법 수정이 여기 해당: diff를 먼저 사이클 보고에 제시하고 마지막 커밋으로.
2. **SKILL.md 편집은 enforce-orchestrator가 게이트** — `*/skills/*/SKILL.md` 쓰기는 orchestrator 골격(Phase ≥3 · `Agent(` 호출 ≥1 · `Communication Protocol` 섹션) 누락 시 차단. 골격을 유지한 채 편집하라(HTML 주석 속 Agent()는 불인정).
3. **seal 연쇄**: README의 hook 표·skill 표·카운트 문장은 seal(#17~#34)이 본문과 parity 검사한다. hook/skill/케이스를 추가하면 README·settings.example.json(#23)·cases.tsv(#20)·doctor REQUIRED_HOOKS(#24)·install.sh REQUIRED(#29)를 **같은 커밋에서** 동기해야 verify-setup이 통과한다.
4. **opencode 미러**: `opencode-harness/`는 회사 반입용 미러 하네스. `hooks/lib/*.js` 파서를 수정하면 `opencode-harness/plugin/lib/`의 대응 파일도 동기하고 `node opencode-harness/_oracle/diff-parsers.mjs`(차등 오라클: canonical과 byte-일치 검증)를 실행하라. hook 셸 스크립트 자체(비-lib)는 미러가 별도 구현이라 로직 등가만 유지.
5. **모델ID `[1m]` suffix**: settings.json의 모델명에 붙은 `[1m]`은 1M 컨텍스트 창 인식용 워크어라운드(wire 전송 전 strip됨). Claude Code 업데이트가 이를 정규화·제거할 수 있으니(v2.1.173 선례) 업그레이드 후 `/context`로 창이 1M인지 재검증. 200K로 붕괴하면 auto-compact가 조기 발화해 무인 루프가 죽는다.
6. **`ccs` 교차모델 CLI**: gpt 프로필로 교차패밀리 리뷰 가능하나, **비대화형 `-p` 모드에서 파일 컨텍스트 전달이 불안정** — 파일 내용을 프롬프트 문자열에 인라인해 전달하라. 실패 시 사유 기록 후 동일-패밀리 리뷰로 fallback(기록 필수).
7. **vacuous RED 함정**: 과거 사이클에서, 기억된 "차단되는 명령"으로 RED를 유도했더니 가드 리팩터링 탓에 이미 차단되지 않는 상태였다(테스트가 헛돌음). RED는 반드시 현 코드에서 실측 재현 후 TDD를 시작한다.
8. **테스트 격리**: run-all·seal-regression·failopen-surface는 임시 $HOME 복제본 패턴을 쓴다(실 하네스 무변이). 새 테스트도 같은 패턴 — 실 `~/.claude`를 변이하는 테스트 금지(단 run-all의 worktrees-marker는 고유 SID로 안전하게 실경로 사용 중 — 전례로만 허용).
9. **hook은 fail-open + 표면화**: hook 자기 고장은 차단이 아니라 허용+FAILOPEN 로그가 교리(작업 중단 방지). 새 hook도 동일 — 로깅 실패가 판정을 막으면 안 된다(`|| true`). 반대로 **무로깅** fail-open은 결함(enforce-orchestrator ERR-센티넬이 유일 잔존 — GAP-010이 해소 예정).
10. **동시-세션**: 병렬 Claude 세션이 흔하다. 다른 세션의 dev 서버·브라우저 프로세스를 kill하지 말고, 세션 상태는 `session_id`-키 파일로 격리(기존 패턴: `~/.claude/worktrees-marker/<sid>`).
11. **Fable 5→Opus 컨텍스트**: 이 문서 세트는 Fable 5(1M 창)가 작성했다. Opus 세션이 200K~1M 어느 창이든, 01·02는 필요 섹션만 발췌해 읽어도 착수 가능하게 구조화되어 있다 — 전체 프리로드보다 GAP별 참조 섹션(04 각 항목의 "증거" 필드)만 읽는 것이 컨텍스트 경제에 맞다.

## 6. 롤백 규약

- 머지 전: 워크트리 브랜치 폐기(`ExitWorktree` remove 또는 브랜치 삭제)로 흔적 0.
- 머지 후 회귀 발견: `git revert <merge-commit> -m 1`로 PR 단위 되돌림 → 04 해당 GAP을 PENDING으로 복귀+사유 append → 03 재채점 원복. 부분 revert(파일 단위)는 seal 연쇄(§5-3)를 깨기 쉬우니 PR 단위가 기본.
- CLAUDE.md 수정 롤백은 그 자체가 또 캐시 무효화 — 세션 경계에서만.

## 7. 이니셔티브 종료 (C-final 체크리스트)

1. 03 최종 재채점 — before/after 표(C0 채점 대비).
2. 04 전 항목 상태 확정(DONE/DEFERRED/REJECTED + 사유).
3. **cold-agent fitness**: 새 subagent에 이 플레이북 + 04의 미착수 항목 1개만 주고 "착수 계획(plan 초안+RED 재현 커맨드)"을 요구 — 막히는 지점이 있으면 그것은 에이전트가 아니라 **문서의 결함**: 문서를 고치고 재시도.
4. 사용자 최종 보고(한국어): 완료/미완 목록 + 루브릭 델타 + 다음 착수 항목 지정과 이유.

## 부록 A — 자주 쓰는 경로

| 무엇 | 어디 |
|---|---|
| durable spec (이 이니셔티브) | `docs/superpowers/specs/2026-07-13-harness-upgrade-2026-07-design.md` |
| goal 문서 (요구 canonical) | `_goal/harness-upgrade-2026-07-goal.md` (gitignored — 부재 시 spec §1이 요약 보존) |
| 사이클 plan 위치 | `docs/superpowers/plans/` (Status 헤더 규율 — seal #27) |
| 용어집 | `CONTEXT.md` (deadline invariant·Best-Direction Mandate·silent downgrade·핸드오프 복원력 등재) |
| hook 본문·공용 함수 | `hooks/*.sh`, `hooks/_common.sh`, 파서 `hooks/lib/*.js` |
| 검증 | `setup/verify-setup.sh`·`setup/verify-all.sh`·`hooks/tests/run-all.sh`(+`cases.tsv`) |
| 상태 카운터 | `state.json` (cycle.count — plan 헤더 RPI-Cycle과 동기) |
| 미러 | `opencode-harness/` (+`_oracle/`) |
