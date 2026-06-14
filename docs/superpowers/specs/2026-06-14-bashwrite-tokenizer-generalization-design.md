# bash-write 토크나이저 일반화 — Design (2026-06-14)

> **subsystem**: non-bypassable rule surfacing / bash-write 게이트 (`hooks/lib/redirect-targets.js`, `hooks/_common.sh` plan_status). durable 선례 = `2026-06-04-non-bypassable-rule-surfacing-design.md`(rank1 redirect 4벡터·rank3 plan_status).
> **계기**: `2026-06-14-audit-reverification-2.md` §6 신규갭 — ★NEW-redir-fd-amp(MED, `echo x >& evil.py` 게이트 우회 E2E exit0 확정) + NEW-planstatus-tilde-fence(LOW, `~~~` 펜스 내 active 누출). §8 Goal초안#2.
> **성격**: durable design spec. RPI cycle 34. 사용자 autonomy 하에 best-practice 확정.

**Status:** completed

---

## 0. 문제 (CONFIRMED, file:line)

1. **NEW-redir-fd-amp (MED, ①강제·⑤수명)**: `hooks/lib/redirect-targets.js:38-43` 토크나이저 op-감지가 `>`/`>>`/`>|`만 처리. `>&`는 `&`를 분리자(:46)로 봐 타깃을 놓침 → `echo x >& evil.py`(no-plan)가 enforce-rpi-bash 우회(코드작성). rank1이 봉인한 `>|`의 형제 연산자인데 누락. (대조 `&> evil.py`는 이미 차단.)
2. **NEW-planstatus-tilde-fence (LOW, ⑤수명)**: `hooks/_common.sh:92` plan_status awk가 백틱 펜스(` ``` `)만 토글. `~~~`(tilde) 펜스 내 `**Status:** active`가 첫 매칭으로 누출 → cwd 게이트 오개방 가능. (라이브 plan은 전부 백틱이라 현재 무영향이나 잠재 우회.)

---

## 1. 결정

### 결정 (1) — `>&` 파일명 타깃 탐지 (fd-number 자동 제외)

`redirect-targets.js:38-43` op-감지에서 `>`/`>>` 뒤 `&`를 op 토큰에 흡수:
```
let j = i + 1;
if (cmd[j] === ">") j++;          // >>
if (cmd[j] === "|") j++;          // >| / >>|  (noclobber)
else if (cmd[j] === "&") j++;     // >& / >>&  (both-streams)
```
**fd-number 제외는 별도 로직 불필요** — `>&2`/`>&1`/`2>&1`은 타깃 토큰이 `2`/`1`이고 `isCode("2")`는 코드 확장자 부재로 false → 자연 통과. 파일명 타깃(`>& evil.py`)만 `isCode` 참 → 차단. (보수성: 파일명만 차단, fd-dup 무차단 = §8 #2 autonomy 충족.)

### 결정 (2) — plan_status awk 펜스 정규식 확장

`_common.sh:92`:
```
/^[[:space:]]*```/      →   /^[[:space:]]*(```|~~~)/
```
백틱 OR 틸드 펜스 둘 다 토글 → `~~~` 펜스 내용도 스킵. (혼합 펜스는 비정상 문서 = 범위 밖.)

---

## 2. 테스트 (TDD, 대표 케이스 — 전수 금지)

cases.tsv + run-all.sh 동시 추가(정합: case_id가 비주석 라인 실재 + TOTAL==declared). LIBREGEX = `_common.sh code_ext_regex`.

| case_id | hook | exp | 의미 | RED(현재) | GREEN(후) |
|---|---|---|---|---|---|
| 140-redir-fdamp-code | hooks-lib | `evil.py` | `echo x >& evil.py` 파서 타깃 | `""`(누락) | `evil.py` |
| 141-redir-fdamp-num-pass | hooks-lib | `` | `ls foo >&2` fd-dup | `""` | `""` (무회귀·오탐0) |
| 142-redir-2to1-pass | hooks-lib | `` | `ls 2>&1` 최빈 idiom | `""` | `""` (오탐0) |
| 143-fdamp-noplan | enforce-rpi-bash | `2` | `echo x >& evil.py` no-plan E2E | `0`(우회) | `2`(BLOCK) |
| 144-planstatus-tilde-fence-skip | hooks-lib | `completed` | `~~~` 펜스 내 active 스킵 | `active`(누출) | `completed` |
| 145-tilde-fence-noplan | enforce-rpi-cycle | `2` | `~~~`-펜스 active만 있는 plan→code write E2E | `0`(오개방) | `2`(BLOCK) |

- 140·143·144·145 = RED→GREEN(봉인 증명). 141·142 = 양방향 GREEN(오탐0 가드 — 최빈 fd redirect 무차단 회귀 방지).

### 무회귀
- 기존 redirect 122-132 + planstatus 136-139 전부 불변(특히 `>|` 123·화살표 124·quoted 125-126·`&>`).
- run-all 129→**135**(6 추가), verify-setup ≥65, verify-all ALL PASS.

## 3. 엣지 / 비목표
- `>&-`(close fd) → 타깃 `-`, isCode false → 무차단(파일 아님). OK.
- `>>&file`(append both) → op `>>&`, file 타깃 → 차단. OK.
- 혼합 펜스(``` 열고 ~~~ 닫기) = 비정상 문서, 범위 밖.
- 변수/동적 파일명(`>& $f`) = Non-Goal(SECURITY.md 기존 경계 유지).
- 전수 28벡터 seal 금지 — 대표 케이스만.

---

> spec delta = YES(신규 design). 다음: writing-plans → Gate P(토크나이저/awk 정확성 독립검증) → implement.
