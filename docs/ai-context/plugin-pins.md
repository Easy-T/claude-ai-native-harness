# 플러그인 공급망 핀 (plugin-pins)

> 외부 플러그인(마켓플레이스 `claude-plugins-official`)의 **승인 시점 상태를 고정**해 rug-pull(승인-후-변경)을 방어한다.
> 근거: 02 §4 — ToxicSkills 13.4%·rug-pull·approve-once; 공식 마켓플레이스 신뢰만으론 승인 후 변경을 못 잡는다. 개인 규모에서 서명 인프라 없이 도달 가능한 최선 = **콘텐츠 해시 스냅샷 + 드리프트 자동 표면화**.
> 소비처: `hooks/session-start-audit.sh`(D-SUPPLY-CHAIN 드리프트 검사)·`setup/verify-setup.sh` **seal #40**(핀 존재 봉인).

## 핀 (승인 시점 스냅샷)

| 플러그인 | version | gitCommitSha |
|---|---|---|
| superpowers | 6.1.1 | `6efe32c9e2dd002d0c394e861e0529675d1ab32e` |
| context7 | 11a39a35d5ca | `11a39a35d5ca7f47fc9d0fbd352cff64e462a8b0` |
| skill-creator | 11a39a35d5ca | `11a39a35d5ca7f47fc9d0fbd352cff64e462a8b0` |
| playwright | 11a39a35d5ca | `11a39a35d5ca7f47fc9d0fbd352cff64e462a8b0` |
| claude-md-management | 1.0.0 | `7bc347b89aaa7f1e02c03617b8d163243d86ecce` |

<!-- 기계검증: 아래 skill-cksum 은 session-start-audit 드리프트 검사와 verify-setup seal #40 이 소비. 캐시 SKILL.md 전체 결정론 해시(`find plugins/cache/claude-plugins-official -name SKILL.md | sort | xargs cat | cksum`). -->
skill-cksum: 1099091361
skill-count: 46

## 드리프트 시 절차 (approve-once → review-on-change)

session-start-audit가 `[supply-chain] ⚠ ... cksum A→B` ALERT를 내면:

1. **diff 리뷰**: 무엇이 바뀌었는지 확인 — `git -C ~/.claude/plugins/cache/claude-plugins-official log`(git 캐시면) 또는 캐시 SKILL.md를 직전 상태와 비교. 특히 위임 대상 agent명·게이트 문구·권한 요구 변경을 본다.
2. **정당한 업데이트**(내가 `/plugin update` 했거나 알려진 릴리스): SKILL.md 변경이 안전하면 이 파일의 `skill-cksum`·`skill-count`·version/sha 표를 **재실측 값으로 갱신**(`find ... | sort | xargs cat | cksum`). 갱신은 세션 종료 직전(캐시 안정성).
3. **미승인 변경**(내가 안 했는데 바뀜 = rug-pull 의심): 해당 플러그인 **재설치/롤백**(pin sha로) 후 재검. 신뢰 못 하면 제거.

> ★핀 갱신은 *의식적 승인*이다 — ALERT를 무심코 끄려 cksum만 맞추지 말 것. review-on-change가 이 규약의 전부.
