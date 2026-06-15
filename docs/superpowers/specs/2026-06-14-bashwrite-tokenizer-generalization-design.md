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

### 결정 (3) — install/rsync 명령-위치 앵커 (cycle-37 delta, 2026-06-15)

**계기**: cycle-33~36 구현 중 `setup/install.sh` 경로를 참조하는 복합 검증 명령(`echo "... setup/install.sh ..." $(...)` 형태)이 라이브 게이트에 *실측 차단*됨. 원인: `redirect-targets.js:130`의 `\b(?:install|rsync)\b`가 **파일명/경로 내 'install' 부분일치**(`setup/install.sh`)를 coreutils `install` 명령으로 오탐 → 후행 코드타깃 추출 → no-plan시 과차단(over-block). cycle-23 install/rsync 탐지의 잔여.

> **Gate P 교정(2026-06-15, review-strict 실측)**: *단일* `bash -n setup/install.sh` 는 차단되지 **않는다** — `args.length>=2` 가드(line 132)가 1-토큰 `.sh` 매칭을 흡수하기 때문. 결함은 'install' 부분일치 **뒤에 ≥2 비옵션 토큰**이 와 가드를 통과하고 마지막 토큰이 코드-ext일 때만 발화. ∴ 충실한 재현자(faithful reproducer)는 `cat setup/install.sh hooks/foo.py`(OLD→`hooks/foo.py` 추출=차단; NEW→`""`). 표준-단어 변형 `echo install foo.py bar.py`(OLD→`bar.py`)도 동일 클래스이며 앵커가 함께 봉인. (실측: A=clean→`[]`, B=path-substr→`[hooks/foo.py]`, C=standalone→`[bar.py]`, D=real `install`→`[b.py]`.)

**결정**: install/rsync 탐지를 **명령-위치 앵커**로 제한 — `git apply`(line 21) `(^\s*|[;&|()]\s*)` 선례 동형. install/rsync는 *명령 시작*(라인 처음 또는 `;`/`&`/`|`/`(` 뒤)이고 *후행 공백+인자*를 가질 때만 매칭:
```
/\b(?:install|rsync)\b([^|;&]*)/g   →   /(?:^|[;&|()])\s*(?:install|rsync)\s+([^|;&]*)/g
```
→ `cat setup/install.sh hooks/foo.py`: 'install'이 `/` 뒤(명령경계 아님) → 미매칭(미차단). `echo install foo.py bar.py`: 'install'이 `echo `(공백) 뒤 → 미매칭. `install -m 755 a b.py`: 라인시작 → 매칭(불변). `foo && install x y.sh`: `&&` 뒤 → 매칭(불변). 보수성: 파일명/경로 substring·비명령-단어 무차단, 진짜 명령만 탐지. (NEW 실측: B/C→`[]`, D/E/F→`b.py`/`b.py`/`y.sh`.)

**비목표(YAGNI)**: cp/mv는 미터치 — `\bcp\b`/`\bmv\b`는 파일명 substring 매칭이 드물고(보통 standalone word) 그 타깃은 비코드라 자연 통과, 기존 테스트(97/98/113) 보유. 관측된 결함은 install/rsync만.

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
