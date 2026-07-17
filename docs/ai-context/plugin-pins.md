# 플러그인 공급망 핀 (plugin-pins)

> 외부 플러그인(마켓플레이스 `claude-plugins-official`)의 **승인 시점 상태를 고정**해 rug-pull(승인-후-변경)을 방어한다.
> 근거: 02 §4 — ToxicSkills 13.4%·rug-pull·approve-once; 공식 마켓플레이스 신뢰만으론 승인 후 변경을 못 잡는다. 개인 규모에서 서명 인프라 없이 도달 가능한 최선 = **콘텐츠 해시 스냅샷 + 드리프트 자동 표면화**.
> 소비처: `hooks/session-start-audit.sh`(D-SUPPLY-CHAIN 드리프트 검사)·`setup/verify-setup.sh` **seal #40**(핀 존재 봉인).

## 핀 (승인 시점 스냅샷)

| 플러그인 | version | gitCommitSha |
|---|---|---|
| superpowers | 6.1.1 | `6efe32c9e2dd002d0c394e861e0529675d1ab32e` |
| context7 | 9acf649a292f | `9acf649a292f22db8139fe5d72d9661ceae6f5e1` |
| skill-creator | 9acf649a292f | `9acf649a292f22db8139fe5d72d9661ceae6f5e1` |
| playwright | 9acf649a292f | `9acf649a292f22db8139fe5d72d9661ceae6f5e1` |
| claude-md-management | 1.0.0 | `7bc347b89aaa7f1e02c03617b8d163243d86ecce` |

<!-- 기계검증: 아래 skill-cksum 은 session-start-audit 드리프트 검사와 verify-setup seal #40 이 소비. 캐시 SKILL.md 전체 결정론 해시(`find plugins/cache/claude-plugins-official -name SKILL.md | sort | xargs cat | cksum`). -->
skill-cksum: 1781304936
skill-count: 33

<!-- 핀 갱신 이력: 2026-07-17 (Fable 재감사 C-1) — 절차 ② 정당 업데이트 판정: 마켓플레이스 정상 갱신(installed_plugins.json lastUpdated 07-17 06:44, context7/skill-creator/playwright 11a39a35d5ca→9acf649a292f 캐시 버전 교체 = SKILL.md 46→33). 콘텐츠 diff 리뷰: superpowers 6.1.0↔6.1.1 14/14 byte-동일·skill-creator 신구 diff 0 — 위임 agent명/게이트/권한 변경 없음, rug-pull 아님. 직전 핀(1099091361·46, C7 2026-07-14)은 그 시점 정확. -->
<!-- ★명명 특성 실측(2026-07-17): 캐시 "version" 디렉터리명/gitCommitSha(9acf649a292f·11a39a35d5ca·d372b2c·85e0ba8)는 anthropics/claude-plugins-official의 sha가 아니라 정확히 **이 하네스 repo(~/.claude)의 커밋 sha**다(git rev-parse 일치: master·cfinal·ui-design v2·PR#12). CC 플러그인 클라이언트가 버전명을 로컬 git 컨텍스트에서 취하는 것으로 보임 — 따라서 version/sha 표는 참고치일 뿐 공급망 검증력이 없고, **콘텐츠 cksum이 유일한 실검증**이다(이 파일의 설계와 정합; 항구적 가정 금지, 다음 갱신 시 재관찰). -->

## 드리프트 시 절차 (approve-once → review-on-change)

session-start-audit가 `[supply-chain] ⚠ ... cksum A→B` ALERT를 내면:

1. **diff 리뷰**: 무엇이 바뀌었는지 확인 — `git -C ~/.claude/plugins/cache/claude-plugins-official log`(git 캐시면) 또는 캐시 SKILL.md를 직전 상태와 비교. 특히 위임 대상 agent명·게이트 문구·권한 요구 변경을 본다.
2. **정당한 업데이트**(내가 `/plugin update` 했거나 알려진 릴리스): SKILL.md 변경이 안전하면 이 파일의 `skill-cksum`·`skill-count`·version/sha 표를 **재실측 값으로 갱신**(`find ... | sort | xargs cat | cksum`). 갱신은 세션 종료 직전(캐시 안정성).
3. **미승인 변경**(내가 안 했는데 바뀜 = rug-pull 의심): 해당 플러그인 **재설치/롤백**(pin sha로) 후 재검. 신뢰 못 하면 제거.

> ★핀 갱신은 *의식적 승인*이다 — ALERT를 무심코 끄려 cksum만 맞추지 말 것. review-on-change가 이 규약의 전부.
