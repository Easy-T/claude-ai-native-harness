# non-obvious.md — 하네스 자신의 AI 실패 등록부

> 이 파일은 **글로벌 하네스(`~/.claude`) 작업 중 발생한 AI 실패**를 누적한다.
> 대상 프로젝트의 `docs/ai-context/non-obvious.md`(init-ai-ready-project 템플릿 산출물)와 **경로만
> 같고 문맥이 다르다** — 이쪽은 하네스 사이클의 Closeout 이 기록한다(spec §13.5).
> 등록 절차는 `CLAUDE.md §4`(5 Whys · 시스템 원인만 · SMART action item).

## ★규약: 재현 픽스처 동반 (GAP-012)

등록 항목은 **재현 픽스처 경로를 필수 필드로** 갖는다. 픽스처 없는 등록은 불완전하다.

- **왜**: 등록만 있고 재현자가 없으면 다음 사이클이 같은 가정을 반복한다. C13 이 그 실증 —
  "goal 은 없을 것"이라는 추론을 확인 없이 사실로 승격해 요구 3개를 놓쳤고, 그 실패를 잡아낼
  자동 재현자가 없었다(spec §13.1).
- **픽스처는 "테스트 통과"가 아니라 "요구 충족"을 겨눈다**: 내가 만든 픽스처는 내가 해석한 범위만
  검사하므로, 픽스처가 GREEN 인 것과 요구가 충족된 것은 다른 명제다(C13 은 run-all 235/235 인 채로
  요구 3개가 미착륙이었다).
- 형식: 각 항목에 `**재현 픽스처:**` 줄을 두고 **실행 가능한 경로 또는 명령**을 적는다.
  자동화가 불가한 절차적 실패는 `절차: <체크 지점>` 으로 적되, **그 체크가 어느 파일의 어느 단계에
  배치됐는지**를 반드시 명시한다(선언만 남기지 않는다).

---

## 1. gitignored 파일의 **부재를 확인 없이 가정**하면 요구를 통째로 놓친다

- **관측 (2026-07-27, C13 Closeout)**: 프롬프트의 "goal 은 gitignored 라 없을 수 있다"를 확인 없이
  사실로 승격하고 요구사항을 durable spec 으로만 읽었다. `_goal/c13-dispatch-governance-goal.md`
  (18,744 bytes)는 **디스크에 실재했다**. 결과: goal §4 성공기준 6개 중 3개가 미검증 상태로
  "COMPLETE" 보고 → 적대 검증 4 렌즈 중 3이 그 보고를 뒤집었다.
- **5 Whys (시스템 원인까지)**:
  1. 왜 요구 3개를 놓쳤나? → 요구사항 SSOT(goal §4)를 읽지 않았다.
  2. 왜 읽지 않았나? → 파일이 없다고 판단했다.
  3. 왜 없다고 판단했나? → "gitignored" 라는 프롬프트 문구를 "부재" 로 해석했다.
  4. 왜 그 해석을 검증하지 않았나? → 검증 비용이 `ls` 한 번인데도 **확인 단계가 절차에 없었다**.
  5. 왜 절차에 없었나? → **비추적 요구사항 문서를 읽는 규약 자체가 없었다** — durable spec 이
     요구를 전부 옮겼다고 암묵 가정했으나, spec §11.2 는 probe 를 요약만 하고 *어느 probe 가
     성공기준인지*는 goal 에만 있었다. ← **시스템 원인**(사람/AI 아님).
- **SMART action item**: Closeout 에서 **goal 파일의 성공기준 절을 직접 열어 항목별로 대조**하고
  그 증거를 보고에 포함한다. 파일 부재를 주장하려면 `ls` 출력을 근거로 제시한다.
- **재현 픽스처**: `절차: start-rpi-cycle Closeout Step C-1` — Closeout 보고에 goal §4 항목별 대조
  증거가 없으면 불완전. 자동 재현자는 불가(요구사항 문서 경로가 사이클마다 다름)이므로
  **절차 체크로 고정**하고, 그 체크가 실제로 수행됐는지는 보고의 대조 표가 증언한다.
  ※ 이 잔여(자동화 불가)를 명시하는 것 자체가 규약의 일부다 — 침묵 잔여 금지.

## 2. 리포 내 경로처럼 보이는 **심링크**가 grep 증거를 오도한다

- **관측 (2026-07-27, C13)**: `grep -c 'config.json' skills/ccs-delegation/SKILL.md` = 0 을 근거로
  "정정 착륙" 을 보고했다. 그러나 `skills/ccs-delegation` 은 심링크(`git ls-tree HEAD` 모드
  **120000**)라 그 grep 은 **워킹 디렉터리 파일시스템**(리포 밖 비-git 디렉터리)을 읽은 것이었다.
  `git log --all -- skills/ccs-delegation/SKILL.md` 는 빈 출력 — 리포 역사상 추적된 적이 없다.
  결과: 배포 경로(`install.sh` `git clone`)에는 정정이 따라오지 않는데 "착륙" 으로 기록됐다.
- **5 Whys**:
  1. 왜 거짓 보고가 났나? → grep 결과를 리포 내용으로 해석했다.
  2. 왜 그렇게 해석했나? → 경로가 리포 안(`skills/…`)처럼 보였다.
  3. 왜 심링크임을 몰랐나? → `ls -ld`/`git ls-files` 교차 확인을 하지 않았다.
  4. 왜 안 했나? → grep 이 파일시스템을 읽는다는 사실과 "리포 내용" 이 다르다는 구분이
     **검증 절차에 없었다**.
  5. 왜 없었나? → **"워킹트리 grep = 리포 내용" 이라는 암묵 등식**이 규약에 명시적으로 부정된 적이
     없었다. ← **시스템 원인**.
- **SMART action item**: 리포 착륙을 주장하는 grep 증거는 **`git ls-files` 또는 `git ls-tree` 교차
  확인을 동반**한다. 특히 `skills/` 하위처럼 심링크가 섞인 디렉터리는 필수.
- **재현 픽스처**: `bash -c 'cd ~/.claude && git ls-tree HEAD skills/ | grep ccs'` →
  `120000 blob …` (모드 120000 = 심링크)가 나오면 그 경로의 파일 grep 은 리포 증거가 아니다.
  대조군: `git ls-files skills/ccs-delegation/` → **빈 출력**(추적 파일 0개).

## 3. bash 가 만든 경로를 네이티브 인터프리터에 **소스 보간**하면 조용히 다른 위치를 가리킨다

- **관측 (2026-08-11, C20 Task 6)**: 오라클 판별력 실증(RED)을 위해
  `mkdir -p /tmp/mp-bad && python -c "... io.open('/tmp/mp-bad/bad.json','w') ..."` 를 실행했다.
  bash 는 MSYS 경로 공간에 디렉터리를 만들었고 **네이티브 python 은 같은 문자열을 `C:	mp\...` 로
  해석**해 `FileNotFoundError` 로 죽었다. 그런데 다음 줄의 오라클이 **빈 디렉터리**를 스캔해
  `TOTAL=0 LITERAL=0 DYNAMIC=0 VIOLATION=0` + `exit=0` 을 냈다 —
  **검사가 실패했는데 출력은 "위반 없음 통과"** 였다(plan 의 기대값 `VIOLATION=1` 이 포착).
- **판별자는 디렉터리 선택이 아니라 경로 전달 방식이다** (실측):
  `mktemp -d` 를 써도 소스 보간하면 깨진다. `$HOME/.claude/` 하위도 `/c/Users/...` 로 보간되면 동일.
  ```
  T=$(mktemp -d)                          # /tmp/tmp.7KIQD1czqn
  python -c "...isdir('$T')"    → False   abspath=C:	mp	mp.7KIQD1czqn   # 소스 보간
  python -c "...sys.argv[1]" "$T" → True                                    # argv 전달
  ```
- **5 Whys**:
  1. 왜 RED 실증이 거짓 통과로 보였나? → "대상 0"과 "위반 0"이 **같은 exit code(0)** 라 형태적으로
     구분되지 않았다.
  2. 왜 픽스처가 생성되지 않았나? → 경로 문자열을 bash 가 만들고 **네이티브 python 에 소스 보간**했다.
  3. 왜 그 형태가 plan 에 들어갔나? → 이 기전의 선행 기록(spec §13.10 C14-G · `setup/doctor.sh:361` ·
     다수 plan 의 "node 금지 — MSYS 미독" 보일러플레이트)을 **참조하지 않았다**. 규약은 존재했으나
     읽히지 않았다.
  4. 왜 존재하는 규약이 읽히지 않았나? → 그 규약이 사는 위치가 전부 **비강제 표면**이다 — 코드 주석
     1줄·spec 산문 1개 절·개별 plan 보일러플레이트. 셋 다 새 plan 을 쓸 때 자동으로 눈에 들어오는
     자리가 아니며, **Phase R 이 로드하는 이 파일에는 없었다**.
  5. 왜 비강제 표면에만 있었나? → **실측된 환경 제약을 강제 표면으로 승격시키는 경로가 하네스에
     없다.** C14-G 는 제약을 발견하고 그 자리에서 고쳤지만(doctor.sh 주석), 발견을 *다음 사이클이
     반드시 마주치는 자리*로 옮기는 단계가 절차에 없다 — C14-G 가 **코드 버그 수정**으로 처리돼
     §4 등록 경로를 타지 않았기 때문이다. ← **시스템 원인**.
  - *반대 심문*: "승격 경로가 있었어도 실패했을 것"은 성립하지 않는다 — 이 파일은
    `start-rpi-cycle` Phase R 의 `explore-strict` context_paths 에 **실제로 포함**되며
    (SKILL.md:53·:59 하네스 실재 SSOT 명시) plan 작성 전에 읽힌다.
- **SMART action item**:
  1. **경로 전달 규약** — bash 가 만든 경로를 네이티브 인터프리터(python/node)에 **소스 보간하지 말고
     argv/stdin 으로 전달**한다. 측정 = `setup/tests/`·`hooks/tests/` 의 `python -c`/`node -e` 인라인
     소스에 리터럴 `/tmp/` 또는 셸 변수 보간 경로가 있으면 FAIL 하는 seal 1건 추가 + **RED→GREEN 증명**.
     기한 = **C21 초입**.
  2. **오라클 "대상 0" 처분 의무** — 계수기형 오라클은 검사 대상 0 에도 exit 0 을 내므로 호출자가
     `TOTAL=0` 을 반드시 처분한다. 착륙 완료(C20, `setup/lib/modepack-oracle.sh` 헤더).
     측정 = `grep -c '반드시 처분' setup/lib/modepack-oracle.sh` = **1**, 주석 제거 시 **0**(음성 대조군).
- **재현 픽스처**:
  ① *기전* — 판별자가 전달 방식임을 보인다:
  ```bash
  bash -c 'T=$(mktemp -d); python -c "import os;print(\"interp:\",os.path.isdir(\"$T\"))"; python -c "import os,sys;print(\"argv  :\",os.path.isdir(sys.argv[1]))" "$T"; rm -rf "$T"'
  ```
  → MSYS 에서 `interp: False` / `argv  : True`. 경로 공간이 일치하는 환경에서는 둘 다 `True`.

  ② *증상* — 조용한 거짓-GREEN:
  ```bash
  bash -c 'source ~/.claude/setup/lib/modepack-oracle.sh; D=$(mktemp -d); modepack_oracle_scan "$D"; echo "exit=$?"; rm -rf "$D"'
  ```
  → `TOTAL=0 LITERAL=0 DYNAMIC=0 VIOLATION=0` + `exit=0` — 검사 대상 부재가 "위반 없음"과 동형.
- **관계**: spec §13.10(C14-G)과 **동일 기전**이며 이 등록은 그것의 **일반화·승격**이다(중복 아님).
  C14-G 는 `doctor.sh` 단일 사이트의 코드 수정이었고, 이 항목은 그 제약을 Phase R 이 읽는 자리로 옮긴다.

---

## 4. Edit 도구는 **혼합-개행** 파일의 개행을 한쪽으로 통일해 편집 범위 밖을 파괴한다

- **관측 (2026-08-10 C19 최초 · 2026-08-16 C21 재발)**: C19 Gate R 정정 세션에서 Edit 이 혼합-개행
  spec 파일의 LF 꼬리를 CRLF 로 재작성해 §17 전체가 diff 오염됐다
  (`plans/2026-08-09-c19-review-economics.md:48`). C21 Phase R 에서 **동일 사고가 재발** —
  `docs/superpowers/specs/2026-07-25-model-policy-design.md`(당시 CRLF **1823** + LF **723**, 총 2546 —
  `git show 89624bf:<파일>` 실측)에 **4줄 Edit** 을 넣었더니 **723 deletions** 이 나왔다.
  `git checkout --` 후 `perl -0777 -i -pe` 바이트 편집으로 전환(그래서 이 사고는 커밋에 남지 않았다 —
  git 이력으로는 재현 불가하며, **723 이라는 수치의 방향 함의만 커밋된 파일 상태로 독립 산출된다**).
  ※ 편집 시점을 `89624bf` 로 잡는 것은 추정이 아니라 **LF 지문 일치**다 — 인접 커밋의 LF 는
  `43acd9a`=572 · `89624bf`=**723** · `ff6e967`=726 이라 723 과 일치하는 스냅샷이 하나뿐이다.
- **★방향 = 소수 개행이 다수 개행으로 흡수된다(다수결).** 4개 데이터가 전부 이 가설과 정합한다:

  | 케이스 | 구성 | 결과 | 판정 |
  |---|---|---|---|
  | C21 spec (실파일) | CRLF **1823** / LF **723** | **723줄 변경** = LF 가 CRLF 로 | 다수(CRLF) 승 |
  | C20-B (합성) | CRLF 1 / LF 4 | 전량 LF | 다수(LF) 승 |
  | C20-C (합성) | CRLF 3 / LF 0 | CRLF 보존 | 혼합 아님 — 대조군 |
  | C20-A (합성) | CRLF 2 / LF 2 | 전량 LF | 동수 — 판별 불가 |

  **판별 산술**: C21 케이스에서 변경 줄 수(723)가 **LF 줄 수와 정확히 일치**한다. CRLF→LF 였다면
  변경 줄 = CRLF 줄 수 = **1823** 이어야 한다. 따라서 이 사고의 방향은 **LF → CRLF** 다.
  순수 CRLF(C20-C)는 보존되므로 "Edit 은 항상 LF 로 쓴다"도 "항상 CRLF 로 쓴다"도 아니고,
  **"혼합이면 한쪽으로 통일하며 그 방향은 다수 쪽"** 이 현 데이터가 지지하는 서술이다.
  **C19 원 기록(`plans/2026-08-09-c19-review-economics.md:48`)의 "LF 꼬리를 CRLF 재작성"은 옳았다** —
  C20 Phase R 이 합성 케이스만 보고 "C19 는 방향이 반대"라고 판정한 것(`_goal/c20-i1-repro-measured.md:21-23`)이
  오히려 오판이었고, 이 등록이 실파일 산술로 그것을 정정한다. 실패 *클래스*(편집 범위 밖 개행의
  전-파일 통일)는 세 기록이 모두 동일하다.
  ※ **상한**: 다수결 가설을 반증하는 케이스는 아직 없으나 C20-A(동수)가 판별 불가이므로
  "소수가 이기는 구성"은 미탐색이다. 실무 처방은 방향과 무관하다 — **혼합이면 Edit 을 쓰지 않는다.**
- **모집단 (2026-08-16 실측)**: 추적 `*.md` 중 혼합 파일 **2건** —
  `docs/superpowers/specs/2026-07-25-model-policy-design.md`(CRLF 1823/2597) ·
  `docs/ai-context/c21-orca-mode-design.md`(CRLF 728/754). 둘 다 사이클이 반복 편집하는 파일이다.
- **재발 (2026-10-05 · 대상-프로젝트 second_brain_project RPI86 — #6 진단 중)**: Why-3/4 의
  `grep -c $'\r'` 위음성이 그대로 재발했다(정답 CR 178 → 0 보고 · Python 텍스트모드 read 도 `0`).
  Action 1(기한 C22 Phase P — 정본 계수기 배치)이 **미착륙**이라는 실증: `skills/`·`workflows/`·`setup/`·`hooks/`
  에서 `perl -ne` 0건(2026-10-05 grep). 상세·후속 action = #6.
- **5 Whys (시스템 원인까지)**:
  1. 왜 4줄 편집이 723줄을 지웠나? → Edit 이 파일 전체 개행을 **다수 쪽(CRLF)으로 통일**해,
     편집 시점 **LF-only 줄 723개 전량**이 반대 개행으로 재작성됐다(723 = 그 시점 LF 줄 수 — 산술 일치).
  2. 왜 그 도구를 골랐나? → 파일이 혼합-개행임을 **모르는 상태**로 편집을 시작했다.
  3. 왜 몰랐나? → 확인을 시도했고 `grep -c $'\r'` 를 썼는데 **이 파일에서 0 을 반환**했다
     (실측: 정답 1823). 확인을 *했는데* 오답을 받아 "순수 LF" 로 판단했다.
  4. 왜 오답 계수기를 썼나? → 개행 계수의 **정본 명령이 어디에도 없다**. 각 사이클이 즉석에서
     `grep`/`file`/`cat -A` 중 하나를 고르고, 그중 `grep -c $'\r'` 는 MSYS 에서 조용히 틀린다.
  5. 왜 정본이 없나? → **파일의 개행 상태가 편집 도구 선택을 좌우하는데, 그것을 조회하는 단계가
     어느 skill·plan 템플릿에도 배치돼 있지 않다.** 도구 선택이 파일 속성에 의존한다는 사실 자체가
     절차에 표현돼 있지 않아, 확인은 개인 재량이 되고 재량은 오답 명령을 고를 수 있다.
     ← **시스템 원인**(사람/AI 아님 — C21 은 규율을 *알고도* 계수기 때문에 재발했다).
  - *반대 심문*: "규율이 있었으니 사람이 안 지킨 것"은 성립하지 않는다. C21 Phase R 은 규율을
    적용하려 **확인을 실행했고**, 그 확인이 틀린 값을 줬다. 절차가 명령을 지정했다면 막혔다.
- **SMART action item**:
  1. **개행 계수의 정본 고정** — 혼합-개행 파일을 편집하는 plan task 는 Files 블록에 개행 실측을
     `perl -ne '$n++ if /\r/; END{print "$n\n"}' <파일>` 출력으로 인용한다(`grep -c $'\r'` 금지).
     측정 = 그런 task 의 Files 블록에 `perl -ne` 계수 인용이 존재. **기한 = C22 Phase P**.
  2. **혼합 파일에서 Edit 금지** — 편집 전 CR 계수가 `0 < CR < 총줄수` 면 `perl -0777 -i -pe` 를 쓴다.
     순수 CRLF·순수 LF 는 Edit 허용(대조군 C 가 보존을 실증). 측정 = 편집 후 CR 계수 불변 +
     `git diff --numstat` 의 deletions 가 의도한 교체분과 일치. **기한 = 즉시 적용**(C21 이 이미 이행 —
     C21 의 spec 파일 커밋 **4건**(`89624bf`·`ff6e967`·`9eb409e`·`9b84de6`) 전부 CR **1823** 불변 실측).
- **재현 픽스처**:
  실파일 사고와 **같은 구성**(CRLF 다수 + LF 소수)에서, 개행 통일이 동반되면 편집 범위 밖이 번지는 것을 보인다:
  ```bash
  D=$(mktemp -d)
  # 실파일과 동형: CRLF 다수(4) + LF 소수(2). 실사고에서는 소수(LF 723)가 다수(CRLF 1823)로 흡수됐다.
  printf 'alpha\r\nbravo\r\ncharlie\r\ndelta\r\necho\nfoxtrot\n' > "$D/orig.txt"
  cp "$D/orig.txt" "$D/uni.txt"; cp "$D/orig.txt" "$D/byte.txt"
  perl -i -pe 's/^charlie(\r?)$/charlie-EDITED$1/; s/\n$/\r\n/ unless /\r\n$/' "$D/uni.txt"  # 1줄 편집 + 다수(CRLF)로 통일
  perl -0777 -i -pe 's/charlie/charlie-EDITED/'                                "$D/byte.txt" # 바이트 편집(개행 보존)
  crlf() { perl -ne '$n++ if /\r/; END{print $n+0}' "$1"; }
  chg()  { diff "$D/orig.txt" "$1" | grep -c '^<'; }
  printf 'BEFORE     CRLF=%s / 총 6\n' "$(crlf "$D/orig.txt")"
  printf '개행통일   CRLF=%s  changed=%s   ← 1줄 편집 의도가 번진다\n' "$(crlf "$D/uni.txt")"  "$(chg "$D/uni.txt")"
  printf '바이트편집 CRLF=%s  changed=%s   ← 의도한 1줄만\n'          "$(crlf "$D/byte.txt")" "$(chg "$D/byte.txt")"
  rm -rf "$D"
  ```
  → 실행 확인(2026-08-16): `BEFORE CRLF=4` · `개행통일 CRLF=6 changed=3` · `바이트편집 CRLF=4 changed=1`.
  **소수 개행 2줄이 다수(CRLF)로 흡수돼, 1줄 편집이 3줄 diff 가 된다** — 실파일 723 과 같은 기전이다.
  **자동화 상한(정직 부기)**: Edit 은 모델 도구라 셸이 호출할 수 없다 — 위 픽스처는 Edit 자체가 아니라
  **기전**(혼합 파일에 개행 통일이 동반되면 무관 줄이 diff 에 잡힘)을 재현한다. 구성은 실파일과 동형
  (CRLF 다수+LF 소수)이지만 **통일 방향은 픽스처의 `s/…/` 가 하드코딩한 것이지 Edit 을 관측한 값이 아니다**
  — 즉 픽스처는 기전의 증거이지 방향 가설의 증거가 아니다. Edit 의 실제 동작 근거는
  ⓐ `_goal/c20-i1-repro-measured.md` 3케이스 매트릭스(세션이 Edit 을 직접 호출해 측정 — 합성 파일) ·
  ⓑ C21 실파일 사고의 산술(723 = 편집 시점 LF 줄 수, `git show 89624bf:<파일>` 로 재검 가능)이다.
  계수기 오답도 함께 확인할 것: `grep -c $'\r' docs/superpowers/specs/2026-07-25-model-policy-design.md`
  → **0**(오답) vs `perl -ne '$n++ if /\r/; END{print "$n\n"}'` → **1823**(정답).
- **관계**: [[3]](#3-bash-가-만든-경로를-네이티브-인터프리터에-소스-보간하면-조용히-다른-위치를-가리킨다)과
  **동류**다 — 둘 다 "확인을 했는데 확인 도구가 MSYS 에서 조용히 틀린 값을 준다". #3 은 경로 축,
  이 항목은 개행 축이며 근본 원인도 같은 형태(실측 환경 제약이 강제 표면에 없음)다.
  spec **§19.7-7**(C20 이 "실측 방향으로 기재하고 원 기록을 정정 부기할 것"으로 예약한 항목 — 본 등록이 이행) ·
  `plans/2026-08-09-c19-review-economics.md:48`(C19 최초 관측 · 방향 서술의 실제 출처 — **옳았음이 확인됨**) ·
  `docs/ai-context/review-yield.md:63`(§4 1단계 사용자 승인 2026-08-10 · 방향 서술은 이 줄에 없음) ·
  `_goal/c20-i1-repro-measured.md:21-23`(C20 의 "C19 방향이 반대" 판정 — 본 등록이 실파일 산술로 정정).

---

## 5. 검증 명령 자체가 **되돌릴 수 없는 외부 부작용**을 낸다 — 관측은 정확한데 측정 행위가 파괴적이다

- **관측 (2026-08-17, C22 Closeout 정정 미니-사이클)**: `bin/orca-rpi.sh` 의 금지-인자 가드를
  **위치-인식**으로 정정한 뒤, "정당한 *값 토큰*은 이제 통과한다"를 증명하려고
  `bash bin/orca-rpi.sh run --objective new-child` 를 실행했다. 이 명령은 파싱을 통과한 뒤
  **그대로 라이브 Orca CLI 에 도달**해 실제 Run 을 생성했다 — `run_4e4776c1b041`
  (objective 문자열이 그대로 `"new-child"`). rc=0 도 파싱 판정도 **전부 정확했다** — 틀린 것이 없는데
  손해가 났다.
- **★ 사고 명령은 "정정이 방금 위험 쪽으로 옮긴 바로 그 명령"이었다.** 정정 전 코드는 전역 스캐너였고
  `new-child` 를 **값 토큰까지** 매칭했다(`git show 5acc8f0 -- bin/orca-rpi.sh` 의 삭제된
  `assert_no_forbidden_args`: `for a in "$@"` … `new-child|new-top-level) die …`). 즉 정정 전에는
  이 명령이 rc≠0 으로 거부돼 `$ORCA` 에 **도달조차 못 했다**. 정정이 이 입력을 거부→통과로 이동시켰고,
  증거 수집은 하필 그 이동을 증명하려는 명령이었다.
  → **일반화**: 가드의 과분류를 정정하면 일부 입력이 "부작용 경계 미도달"에서 "도달"로 넘어간다.
  그 이동분은 정의상 **첫 실행이 곧 첫 부작용**이다.
- **되돌릴 수 없다 (실측)**: `orchestration --help` 서브커맨드 28종 전수에 `run-delete`·`task-delete`·
  `run-archive`·`run-close` **부재**(`docs/ai-context/c22-orca-probe-measured.md:78-85`). 유일한 후보
  `orchestration reset` 은 `Usage: … reset (--all | --tasks | --messages)`(같은 파일 `:88`) — **Run 단위 셀렉터가 없어**
  내가 만든 것만 지울 수 없고, C22 goal 안전제약 6이 계열 발행을 금지한다. `run-list` 에 영구 잔존.
- **near-miss**: 「영구 DB 레코드 생성은 **사용자 승인 없이 진행하지 않는다**」는 규범이 이미 존재했다
  (`docs/ai-context/c22-orca-probe-measured.md:91`, 실제로 승인을 받아 프로브 Run 을 만들었다 `:112`).
  그러나 그 규범은 **프로브 보고서 산문에만** 있었고 goal 안전제약·plan 어디로도 승격되지 않았다 —
  Why-5 를 약화시키는 게 아니라 **강화**하는 두 번째 실례다.
- **5 Whys (시스템 원인까지)**:
  1. 왜 되돌릴 수 없는 라이브 레코드가 생겼나? → 인자-파싱만 검증하려던 명령이 파싱 통과 후
     **부작용 단계까지 실행**됐다.
  2. 왜 부작용 단계까지 갔나? → 이 캐리어에는 **인자 검증만 하고 멈추는 모드가 없다** — 파싱과 부작용
     발행이 한 프로세스에 직렬로 붙어 있어, 파싱을 검증하려면 부작용 경계까지 실행하는 것 외에 방법이
     없다. 그래서 유일한 차단 수단이 호출자의 `$ORCA` stub 치환뿐이었고, 그것이 주입되지 않았다.
  3. 왜 stub 이 주입되지 않았나? → **plan 의 확립된 증거-명령 형식이 "맨 명령"이다** —
     `docs/superpowers/plans/2026-08-17-c22-orca-carrier-landing.md:211-215`(ⓑ 증거 3건 전부 주입 지점
     없는 맨 명령) · `:222-227`(Step 5 는 **라이브 `$HOME/.claude/.orca-rpi` 에 직접 쓰고** Expected 가
     `rc=0`). 위임받은 쪽은 그 형식을 그대로 따랐다.
  4. 왜 증거 형식이 주입을 요구하지 않았나? → plan:64 verbatim 「**모든 유효성 검사는 `$ORCA` 호출 전에
     끝난다** — 실제 Orca 실행 여부와 무관하게 ⓑⓒ 를 테스트할 수 있어야 한다」. 이는 ⓑⓒ(거부)에 대해
     **참**이지만, 여집합인 「검증을 통과하는 명령은 *반드시* `$ORCA` 를 호출한다」가 **문서 어디에도
     없다**. 비대칭 미인지가 세션 기억이 아니라 **커밋된 문서에 화석으로** 남아 있다.
     게다가 이번 정정은 바로 그 여집합에 명령 하나를 새로 밀어 넣는 변경이었다(위 ★).
  5. 왜 그 비대칭이 절차에 없었나? → **되돌릴 수 없는 외부 부작용을 가진 CLI 를 검증 대상으로 삼을 때
     "부작용 차단 주입 지점을 명시하라"는 규약이 하네스에 없다.** 캐리어는 최초 착륙 시점부터
     주입 지점을 *제공*했다(`git show e3c3f7c:bin/orca-rpi.sh` `:10 ORCA="${ORCA_CLI_COMMAND:-…}"`)
     — 그런데 plan 의 증거 항목이 그것을 *요구*하지 않았다. **제공과 요구 사이가 비어 있다.**
     ← **시스템 원인**(사람/AI 아님).
  - *반대 심문 1* — "위임받은 에이전트가 부주의했다" → **기각**. ⓐ지시 위반이 아니다(plan 의 기존 증거
    형식을 준수했다) ⓑ어길 규칙이 없었다(goal 안전제약 1–7 전수에 Run *생성* 금지 항목 없음 — 6번은
    `reset` **발행** 금지이지 생성 금지가 아니다) ⓒ문서가 반대 방향으로 유도했다(plan:64).
    시스템이 안전 신호를 잘못 준 상황에서 "부주의"는 원인이 아니라 결과다.
  - *반대 심문 2* — "안전제약 6이 이미 금지했다" → **불성립**. 위 실측대로 `reset` 은 대상이 다르다.
- **SMART action item**:
  1. **부작용-차단 주입 명시** — plan 의 증거/검증 코드블록에 **`bin/orca-rpi.sh` 호출**(및 이후
     `docs/ai-context/` 에 등재되는 부작용-CLI 래퍼 목록)이 있으면, 같은 블록에 `ORCA_CLI_COMMAND=`
     또는 `--dry-run` 이 **반드시 동반**된다. 위임 프롬프트는 plan 의 증거 블록을 **verbatim 인용**하는
     것으로 간접 강제한다(프롬프트 자체는 측정 대상에서 제외 — **비지속 아티팩트**라 사후 검증 불가).
     측정 = `setup/tests/seal-regression.test.sh` 에 seal 1건 추가 + **RED→GREEN 증명**(#3 action 1 형식).
     기한 = **C23 Phase P**.
  2. **통과-케이스 비대칭 점검** — 증거 블록의 `Expected` 줄에 **`rc=0`** 이 있으면 통과 케이스로
     판정하고, 그 블록에 주입 지점이 없으면 FAIL. 측정 = 위 seal 이 `rc=0` 토큰을 탐지자로 사용.
     기한 = **C23 Phase P**.
  3. **캐리어에 검증-전용 경로** (Why-2 의 설계-층 대응 — 처방이 "호출자가 매번 조심하라" 한쪽으로만
     가지 않게) — `ORCA_RPI_DRYRUN=1` 이면 `$ORCA` 호출 직전에 명령줄만 출력하고 rc=0 종료.
     측정 = `ORCA_RPI_DRYRUN=1 … run --objective X` 실행 후 stub 로그 **0줄** + stdout 에 명령줄 1줄.
     기한 = **C23 Phase P**(또는 그 사이클 보고에 명시적 defer).
- **재현 픽스처**: 거부/통과 케이스의 **부작용 비대칭**을 보인다(이것이 사고의 기전):
  ```bash
  D=$(mktemp -d)
  printf '#!/usr/bin/env bash\nprintf "SIDE-EFFECT: %%s\\n" "$*" >> "$STUB_LOG"\necho "{\\"id\\":\\"req\\",\\"ok\\":true,\\"result\\":{\\"run\\":{\\"id\\":\\"run_stub\\"}}}"\n' > "$D/orca-stub.exe"
  chmod +x "$D/orca-stub.exe"; export STUB_LOG="$D/side.log"; : > "$STUB_LOG"
  ORCA_CLI_COMMAND="$D/orca-stub.exe" ORCA_RPI_RUNDIR="$D/rd" bash ~/.claude/bin/orca-rpi.sh spawn --run r --task t --model opus >/dev/null 2>&1
  echo "거부케이스 rc=$? / 부작용 줄수=$(wc -l < "$STUB_LOG")"
  ORCA_CLI_COMMAND="$D/orca-stub.exe" ORCA_RPI_RUNDIR="$D/rd" bash ~/.claude/bin/orca-rpi.sh run --objective new-child >/dev/null 2>&1
  echo "통과케이스 rc=$? / 부작용 줄수=$(wc -l < "$STUB_LOG")"
  cat "$STUB_LOG"; rm -rf "$D"
  ```
  → 실행 확인(2026-08-17): `거부케이스 rc=1 / 부작용 줄수=0` · `통과케이스 rc=0 / 부작용 줄수=1` ·
  로그 verbatim `SIDE-EFFECT: orchestration run-create --objective new-child --json`.
  **그 1줄이 주입 없이는 정확히 라이브 Run 이다.**
- **관계 — 등록부 내 독립 클래스**(판별자 = *손상이 어디에 남는가*):
  #1(확인 생략)·#2(심링크 오도)·#3(경로 소스 보간)·#4(개행 계수기)는 전부 **인식론적 오류**이고 손상이
  *결론*(또는 작업트리)에 남아 **복구 가능**하다. 본건은 **관측이 전부 정확한데 측정 행위 자체가
  파괴적**이고 손상이 **외부 시스템의 영구 레코드**에 남아 **복구 불가**다 — 등록부에 이 클래스는 0건이었다.
  #1 과도 구별된다: 본건은 확인을 *생략*한 게 아니라 **수행했고, 그 수행이 손해였다**.
  인접(중복 아님): ⓐ`docs/ai-context/c22-orca-probe-measured.md:91`(규범이 비강제 산문에만 존재 —
  #3 Why-5 와 같은 *승격 공백* 형태) ⓑ C15 교훈 「계약에 값 추가 시 과분류 방향 반전(안전→면제) 전수
  재감사」— 본건은 그 교훈의 **부작용 축 변종**이며 C15 교훈은 이 파일에 미등록이라 중복이 아니다.
- **수용 잔여(정직 부기)**: ⓐ 정정 위임 프롬프트 원문은 비지속이라 Why-3 을 프롬프트 층에서 직접
  검증할 수 없다 — 그래서 근거 표면을 **plan 층 동형 사례**로 고정했다(위 `:211-215`·`:222-227`).
  ⓑ `reset --pairing-code`/`--environment`/`--retry-request` 의 스코프는 미측정(help 무설명) —
  "되돌림 수단 전무"는 `--all|--tasks|--messages` 기준으로만 확정. 안전제약 6이 계열 전체를 금지하므로
  결론은 불변. ⓒ 본건 fitness(재발 0)는 action item 1·2가 seal 로 착륙해야 자동 확보된다.

---

## 6. Windows 텍스트-모드 생성기가 **파생 Workflow 스크립트**에 CRLF 를 심어 거부된다 — 대용량 verbatim payload 를 캐리어에 싣는 공인 경로가 없다

- **관측 (2026-10-05 KST · 2026-10-04T17:53Z, 대상-프로젝트 second_brain_project RPI86 Phase I (d))**: plan 8 task 를
  verbatim 으로 싣기 위해 생성기 `gen_workflow.py` 가 캐리어 `workflows/rpi-implement.js` 를 텍스트 치환한 파생본을 만들어
  `Workflow({scriptPath})`(args 미사용)로 디스패치했다. 응답 「The permission handler returned updatedInput for Workflow that
  failed schema validation … "script" … script contains control characters that would be hidden in the approval dialog …
  The tool input from the model was valid」. 원인: 생성기 `:89` 가 `write_text(out, encoding="utf-8")`(newline 미지정) —
  Windows 텍스트 모드가 `\n`→`\r\n` 으로 바꿔 CR **178**개(원본 캐리어 CR 0). `newline="\n"` 로 고친 뒤 재디스패치 성공
  (17:53:37Z → 17:54:36Z, 약 59초). 진단 중 위음성 3회 — Python 텍스트모드 read `0 []`·`Counter()`, `grep -c $'\r'` `0`
  (정답 178) — `od -c`·`tr -cd '\r' | wc -c` 로 확정.
- **재발 (2026-10-07T12:10Z · 대상-프로젝트 second_brain_project RPI87 Phase I (d) W1 — 등록 초안 작성 2일 뒤, 같은 세션)**:
  새 생성기 `gen_wave.py`(plan task 4건 verbatim 합계 53,102자 → 파생 `rpi87_w1.js`)가 같은 `write_text(…, encoding="utf-8")`
  (newline 미지정)로 써 **동일 거부**. `newline="\n"` + 쓴 바이트 재독 CR 단언으로 고쳐 재생성(12:10:09Z 거부 → 12:11:25Z, 약 76초).
  진단은 즉시(바이트 재독 — 위음성 계수기 미사용). **실증**: 등록부 지식은 재발을 막지 못했다 — Action 1~3(기한 C26 Phase P)
  전부 미착륙(2026-10-08 확인: `skills/start-rpi-cycle/SKILL.md` 의 `newline=` 0건 · `workflows/` 에 `rpi-implement.js` 만[embed-args.py 부재]
  · `.gitattributes` 부재). 같은 세션의 W2·Closeout 미니-사이클 생성기는 `newline="\n"`+CR/Cc 단언을 사전 적용해 무재발 —
  개인 규율로만 막힌 상태. 재현 픽스처 = 아래 ①② 그대로(기전 동일).
- **5 Whys**:
  1. 왜 거부됐나? → 권한 처리기가 scriptPath 를 해석해 돌려준 `updatedInput.script` 에 CR(Cc)이 있었고 스키마 검증이 거부했다(모델 입력은 유효).
  2. 왜 CR 이 들어갔나? → 생성기가 `newline=` 없이 텍스트 모드로 썼다(Windows `os.linesep`=`\r\n`).
  3. 왜 스크립트를 생성했나? → TDD-verbatim(start-rpi-cycle SKILL.md:168-169)은 요약을 금지하는데, 캐리어 입력은 도구 호출의
     `args` 뿐이다(SKILL.md:161 `Workflow({scriptPath, args: [task 배열]})` · rpi-implement.js:10 args 계약·:24 검사).
     payload 는 8 task `promptVerbatim` 합계 98,364자(헤더·Global Constraints 반복 포함) — args 경로는 이를 모델 출력으로
     다시 내보내야 해 바이트 동일성을 보장할 수 없으므로, 생성기로 임베드했다(`gen_workflow.py:1` "no hand-copy" · `:84-88` `args`→`TASKS`).
  4. 왜 막지 못했나? → SKILL.md:161 은 인라인/파생 스크립트에 모델 규약만 요구하고 **바이트 규칙(LF·Cc 0)과 디스패치 전 검사**가
     없다(skills·workflows·docs 에서 `control char|newline=|write_text` 0건). 진단에서도 #4 정본 계수기가 어디에도 배치되지 않아
     (skills·workflows·setup·hooks 에서 `perl -ne` 0건) 위음성 계수기가 쓰였다.
  5. 왜 없나? → **대용량 verbatim payload 를 캐리어에 싣는 공인 경로가 없어 우회(파생 스크립트)가 강제되는데, 그 우회 경로에
     소비자(Workflow `script` 검증기)의 바이트 계약이 정의·검사돼 있지 않다.** ← **시스템 원인**(사람/AI 아님 — 같은 Windows·같은 생성기면 결정론 재현).
  - *반대 심문*: "args 로 넘겼으면 됐다" → args 경로는 시도되지 않아 한계는 미측정이다(정직 부기). 그러나 그 경로도
    98K자의 바이트 동일성을 기계적으로 보장하지 못하므로 Why-5 의 공백은 그대로다.
- **SMART action item**:
  1. **바이트 규칙 + 사전 검사** — start-rpi-cycle SKILL.md Phase I (d) canonical 캐리어 ※줄(현 :161) 직후에 "파생/생성 스크립트는
     `newline="\n"` 으로 쓰고, 디스패치 전 `perl -ne '$n++ if /\r/; END{print $n+0}' <script>` = 0 확인(`grep -c $'\r'`·Python 텍스트모드
     read 는 위음성이라 금지)" 추가. 측정 = 그 SKILL.md 에서 `newline="\n"` 과 `perl -ne '$n++ if /\r/` 각각 ≥1건. 기한 = **C26 Phase P**.
  2. **공인 임베더** — `workflows/embed-args.py <carrier> <args.json> <out>`: 캐리어의 **단일 sentinel**(예: `const TASKS = args`)만 치환
     (전역 `re.sub(r"\bargs\b")` 금지), `newline="\n"` 강제, 쓴 직후 바이트를 다시 읽어 CR=0·Cc(`\n` 제외)=0·bidi/zero-width
     (U+200B·U+200E-F·U+202A-E·U+2066-9)=0 확인, 위반 시 exit≠0. 측정 = `setup/tests/` seal 1건 + `newline=` 제거 뮤테이션 **RED→GREEN 증명**.
     기한 = **C26 Phase P**(연기 시 그 사이클 보고에 명시적 defer).
  3. **캐리어 바이트 seal** — `workflows/*.js` CR=0 seal + `.gitattributes` `workflows/*.js text eol=lf`. 근거: 시스템 gitconfig
     `autocrlf = true`(`C:/Program Files/Git/etc/gitconfig:12`)인데 하네스 repo 만 로컬 `false`, `.gitattributes` 부재, `setup/install.sh:7` 은
     수동 `git clone` 안내뿐 — 새 clone 은 캐리어를 CRLF 로 체크아웃해 **정식 경로도** 같은 거부를 맞을 수 있다(추론·미실측).
     측정 = CRLF 복사본 픽스처에서 seal RED. 기한 = **C26 Phase P**.
- **재현 픽스처**:
  ① 기전(쓰기 기본값 × 계수기 위음성):
  ```bash
  D=$(mktemp -d)
  python -c "import sys;from pathlib import Path;d=Path(sys.argv[1]);(d/'crlf.js').write_text('a\nb\n',encoding='utf-8');(d/'lf.js').write_text('a\nb\n',encoding='utf-8',newline='\n');print('py-textmode CR=',open(d/'crlf.js',encoding='utf-8').read().count('\r'))" "$D"
  od -c "$D/crlf.js" | head -1
  echo "grep=$(grep -c $'\r' "$D/crlf.js") perl=$(perl -ne '$n++ if /\r/; END{print $n+0}' "$D/crlf.js") perl-LF=$(perl -ne '$n++ if /\r/; END{print $n+0}' "$D/lf.js")"
  rm -rf "$D"
  ```
  ② 실 캐리어:
  ```bash
  python -c "import sys;from pathlib import Path;s=Path(sys.argv[1]).read_text(encoding='utf-8');o=Path(sys.argv[2]);o.write_text(s,encoding='utf-8');print('carrier CR=',Path(sys.argv[1]).read_bytes().count(b'\r'),'textmode CR=',o.read_bytes().count(b'\r'));o.write_text(s,encoding='utf-8',newline='\n');print('lf CR=',o.read_bytes().count(b'\r'));o.unlink()" ~/.claude/workflows/rpi-implement.js "$(mktemp -u).js"
  ```
  → 실행 확인(2026-10-05): ① `a \r \n b \r \n` · py-textmode CR=0 · grep=0 · perl=2 · perl-LF=0 / ② carrier CR=0 · textmode CR=79 · lf CR=0.
  ※ 워크트리-격리 세션에서는 가드가 `$(...)` 블록을 거부한다 — 리터럴 경로 단일 명령으로 나눠 실행.
  Workflow 거부 자체는 셸 재현 불가 → `절차: start-rpi-cycle SKILL.md Phase I (d) canonical 캐리어 ※줄(:161) 직후 — 디스패치 전 perl CR=0`
  — **현재 미배치**(Action 1 착륙 시 배치; 그 전까지 선언 상태 — 정직 부기).
- **관계**: #4 와 **인접**(같은 Windows 개행 축, 메커니즘 다름 — #4 = Edit 이 혼합 파일을 통일, 본건 = 생성기 쓰기 기본값 × 소비자 검증기).
  다만 진단에서 #4 Why-3/4(`grep -c $'\r'` 위음성)가 **재발**했다 — #4 Action 1(기한 C22 Phase P)이 미착륙이라는 실증(#4 관측 줄에 재발 부기).
  #3 과 동류(확인 도구가 Windows/MSYS 에서 조용히 틀린 값). 프로젝트 등록부 `second_brain_project/docs/ai-context/non-obvious.md`
  「2026-06-15: Windows cp949 콘솔 … UnicodeEncodeError」와 인접(같은 Windows Python 텍스트 I/O 기본값 계열, 인코딩 축).
  손상은 크게 드러나고 복구 가능(약 59초) — #5 의 비가역 클래스 아님. 관측은 대상-프로젝트 사이클이나 결함·Action 표면이 전부
  하네스라 이 등록부에 둔다(하네스 Phase R 이 읽는 자리 — #3 Why-4).
