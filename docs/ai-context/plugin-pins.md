# 플러그인 공급망 핀 (plugin-pins)

> 외부 플러그인(마켓플레이스 `claude-plugins-official`)의 **승인 시점 상태를 고정**해 rug-pull(승인-후-변경)을 방어한다.
> 근거: 02 §4 — ToxicSkills 13.4%·rug-pull·approve-once; 공식 마켓플레이스 신뢰만으론 승인 후 변경을 못 잡는다. 개인 규모에서 서명 인프라 없이 도달 가능한 최선 = **콘텐츠 해시 스냅샷 + 드리프트 자동 표면화**.
> 소비처: `hooks/session-start-audit.sh`(D-SUPPLY-CHAIN 드리프트 검사)·`setup/verify-setup.sh` **seal #40**(핀 존재 봉인).

## 핀 (승인 시점 스냅샷)

| 플러그인 | version | gitCommitSha |
|---|---|---|
| superpowers | 6.4.1 | `5bf4e78011075bcfc0dc295f0724994cd123ee71` |
| context7 | 2a8ad9f74633 | `2a8ad9f74633d10e3d9bb0660a03bfc6e50584b1` |
| skill-creator | 2a8ad9f74633 | `2a8ad9f74633d10e3d9bb0660a03bfc6e50584b1` |
| playwright | 2a8ad9f74633 | `2a8ad9f74633d10e3d9bb0660a03bfc6e50584b1` |
| claude-md-management | 1.0.0 | `7bc347b89aaa7f1e02c03617b8d163243d86ecce` |

<!-- 기계검증: 아래 skill-cksum 은 session-start-audit 드리프트 검사와 verify-setup seal #40 이 소비. 캐시 SKILL.md 전체 결정론 해시(`find plugins/cache/claude-plugins-official -name SKILL.md | sort | xargs cat | cksum`). -->
skill-cksum: 413615869
skill-count: 34

<!-- 핀 갱신 이력: 2026-10-03 (C25 Closeout) — 절차 ② 정당 업데이트 판정(메인 실측): context7/skill-creator/playwright
  fa59bc903774→2a8ad9f74633(installed_plugins.json lastUpdated 09-30T11:36Z, 구 dir 에 `.orphaned_at` = 정상 마켓플레이스
  교체). `diff -rq` 3/3: 콘텐츠 차이 0(캐시 장부 파일 `.in_use`·`.orphaned_at` 만), skill-creator SKILL.md `cmp` 동일.
  cksum 252811375→413615869·count 33→34 는 byte-동일 사본 1개가 전량 해시에 추가된 결과뿐 — rug-pull 아님.
  2a8ad9f… 도 하네스 repo 에 없는 객체(`git cat-file -t` 실패). 예고: 고아 dir(`.orphaned_at`) 이 정리되면 count 가
  다시 줄어 드리프트가 한 번 더 뜬다 — 그때도 콘텐츠 diff 로 판정. -->
<!-- 핀 갱신 이력: 2026-09-29 (C25 T6) — 절차 ② 정당 업데이트 판정(explore-strict opus 보안 표면 diff 리뷰, LEGIT-UPDATE):
  superpowers 6.2.0→6.3.0→6.4.1(installed_plugins.json lastUpdated 09-25T15:38 · 6.3.0 캐시 orphaned_at 동시각 = 정상
  마켓플레이스 교체) + context7/skill-creator/playwright fa59bc903774 교체(lastUpdated 09-28). 판정 근거: hooks.json·
  run-hook.cmd 동일, session-start 는 Muse 분기만 추가(자기 SKILL.md 만 읽음), 신규 스크립트(task-start/task-done·
  sdd-workspace 등)는 자기 작업공간 쓰기만 — 네트워크·자격증명 접근·우회 플래그·프롬프트 인젝션 0, 외부 전송
  (`gh issue create`)은 승인 게이트 뒤. 행동 변화(보안 무관): executing-plans 가 task 사이 확인 없이 연속 실행
  (파괴적·보안·merge/push·계획 붕괴에서만 정지) — 하네스 Phase I (b) 경로에 영향, 사이클 보고에 표면화.
  한계: 6.2.0 캐시는 이미 삭제돼 6.2.0→6.3.0 구간은 릴리스 노트로만 재구성. context7·playwright 는 SKILL.md 없음,
  skill-creator 캐시 3개 dir byte-동일. ★명명 특성 재관찰: fa59bc9…·5bf4e78… 는 이 하네스 repo 에 **없는 객체**
  (`git cat-file -t` 실패) — 캐시 버전명의 원천이 혼재한다(하네스 커밋명 dir 과 비-하네스 sha dir 공존: context7·
  playwright·skill-creator 캐시에 `1ec99123d23a`(= 하네스 커밋 `1ec9912`)·`ad30d62cd52a`·`fa59bc903774`(활성) 3개 dir)
  — 07-17 관찰("캐시 버전명 = 로컬 하네스 커밋 sha")은 항상 성립하는 규칙이 아니다; cksum 이 유일한 실검증이라는
  결론은 불변. -->
<!-- 핀 갱신 이력: 2026-08-02 (C16-F-1) — 절차 ② 정당 업데이트 판정: superpowers 6.1.1→6.2.0(lastUpdated
  07-25) + context7/skill-creator/playwright 캐시 버전 디렉터리 추가(디렉터리명=하네스 repo sha — C10 명명
  특성 재확인). 콘텐츠 diff 실측(cmp 14/14 전수, C16 stage2 정정): 13/14 변경(byte-동일은 using-superpowers만)
  — 대형 리워크 3건(subagent-driven-development 600줄=리뷰-라운드 게이트 신설 "R≤3 resume/R≥4 fresh"·
  finishing-a-development-branch 256줄=push/PR 절차 서술·test-driven-development 78줄), 나머지 10건 문구 정련.
  판정 근거: 보안 표면 0(위임 agent명/allowed-tools/권한/원격조작 명령 변경 없음 — push 문구는 예시 주석),
  정상 릴리스 채널(installed_plugins.json lastUpdated 07-25) → rug-pull 아님. skill-creator 8버전 dir
  byte-동일. 구버전 6.1.1 캐시 잔존은 cksum 전량 해시에 포함(결정론). -->
<!-- 핀 갱신 이력: 2026-07-17 (Fable 재감사 C-1) — 절차 ② 정당 업데이트 판정: 마켓플레이스 정상 갱신(installed_plugins.json lastUpdated 07-17 06:44, context7/skill-creator/playwright 11a39a35d5ca→9acf649a292f 캐시 버전 교체 = SKILL.md 46→33). 콘텐츠 diff 리뷰: superpowers 6.1.0↔6.1.1 14/14 byte-동일·skill-creator 신구 diff 0 — 위임 agent명/게이트/권한 변경 없음, rug-pull 아님. 직전 핀(1099091361·46, C7 2026-07-14)은 그 시점 정확. -->
<!-- ★명명 특성 실측(2026-07-17): 캐시 "version" 디렉터리명/gitCommitSha(9acf649a292f·11a39a35d5ca·d372b2c·85e0ba8)는 anthropics/claude-plugins-official의 sha가 아니라 정확히 **이 하네스 repo(~/.claude)의 커밋 sha**다(git rev-parse 일치: master·cfinal·ui-design v2·PR#12). CC 플러그인 클라이언트가 버전명을 로컬 git 컨텍스트에서 취하는 것으로 보임 — 따라서 version/sha 표는 참고치일 뿐 공급망 검증력이 없고, **콘텐츠 cksum이 유일한 실검증**이다(이 파일의 설계와 정합; 항구적 가정 금지, 다음 갱신 시 재관찰). -->

## 드리프트 시 절차 (approve-once → review-on-change)

session-start-audit가 `[supply-chain] ⚠ ... cksum A→B` ALERT를 내면:

1. **diff 리뷰**: 무엇이 바뀌었는지 확인 — `git -C ~/.claude/plugins/cache/claude-plugins-official log`(git 캐시면) 또는 캐시 SKILL.md를 직전 상태와 비교. 특히 위임 대상 agent명·게이트 문구·권한 요구 변경을 본다.
2. **정당한 업데이트**(내가 `/plugin update` 했거나 알려진 릴리스): SKILL.md 변경이 안전하면 이 파일의 `skill-cksum`·`skill-count`·version/sha 표를 **재실측 값으로 갱신**(`find ... | sort | xargs cat | cksum`). 갱신은 세션 종료 직전(캐시 안정성).
3. **미승인 변경**(내가 안 했는데 바뀜 = rug-pull 의심): 해당 플러그인 **재설치/롤백**(pin sha로) 후 재검. 신뢰 못 하면 제거.

> ★핀 갱신은 *의식적 승인*이다 — ALERT를 무심코 끄려 cksum만 맞추지 말 것. review-on-change가 이 규약의 전부.
