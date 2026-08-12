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
