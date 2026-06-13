# cycle-25: redirect-targets.js 파서 4벡터 봉인 (강화 rank 1) Implementation Plan

> **For agentic workers:** 경량 사이클 — 메인이 executing-plans 절차로 직접 수행. TDD: RED 실측 → GREEN. enforce-rpi-bash의 코드-쓰기 게이트 파서 정확성 결함을 봉인.

**Status:** completed
**RPI-Cycle:** 25
**Started:** 2026-06-13

**Goal:** 재검증 워크플로(wf_5c8f19bf-108)가 RED로 재현한 redirect-targets.js의 4개 검증된 결함을 TDD로 봉인. 산출물 = cases.tsv RED 케이스 선추가 → 통과, redirect-targets.js 수정, README 카운트 정합, SECURITY.md Non-Goal 정밀화. **성공 기준(관찰가능): run-all 100% (114+신규), verify-setup PASS FAIL=0, 기존 케이스 0 회귀.**

**Subsystem spec:** redirect-targets.js 전용 durable spec 부재 — intent는 파일 헤더(:1-12) + SECURITY.md Non-Goal(:34-36). **spec delta = YES(소규모)**: 따옴표-인지 토크나이저 + 인터프리터-eval 커버리지. 반영처 = 파일 헤더 갱신(Task 3) + SECURITY.md:35 Non-Goal 좁힘(Task 4). 신규 도메인 용어 없음(CONTEXT.md no-op).

**근거(R, 점수 아님):** docs/superpowers/specs/2026-06-13-audit-reverification.md §3(신규 실결함)·§4(rank 1). 4벡터 모두 by-design 항변 불가 — 파서가 잡으려는 의도(`>`/`tee`/redirect) 내의 정확성 버그.

---

## 4개 결함 (재검증 RED 재현)

| 벡터 | 현상 | 유형 |
|---|---|---|
| (a) 단일인용 타깃 | `echo x > 'evil.py'` → 미탐지(따옴표 그룹 `"?`만, raw push) | under-block |
| (b) noclobber `>\|` | `echo x >\| evil.py` → 미탐지(타깃 클래스가 `\|` 제외) | under-block |
| (c) 인터프리터 eval | `node -e 'fs.writeFileSync("x.js",..)'`/perl -e/ruby -e → 미파싱(python -c만 모델링) | under-block(비대칭) |
| (d) 따옴표/화살표 오탐 | `git commit -m "a > b.py"`·`step1 -> output.js` → 오차단 → 반사적 RPI_SKIP → 게이트 무력화 | over-block |

설계: case-1(리다이렉션/tee)을 **따옴표-인지 토크나이저**로 교체해 (a)(b)(d) 동시 해결, case-4b(인터프리터 eval 리터럴)로 (c) 해결. case-2/3/5/6/0(sed/cp/dd/install/rsync/patch)은 불변(회귀 위험 회피, 96-117 테스트 보존). 변수/동적 파일명은 Non-Goal 유지(python -c 와 대칭).

---

### Task 1: RED 케이스 선추가 (cases.tsv + run-all.sh) — 실패 실측

**Files:** `hooks/tests/cases.tsv`, `hooks/tests/run-all.sh`

- [x] **Step 1 (RED 카탈로그):** cases.tsv에 11개 행 추가 (열: hook \t id \t expected \t gen-label).
  - `hooks-lib`: `122-redir-singlequote`(output), `123-redir-noclobber`(output), `124-redir-arrow-pass`(output), `125-redir-quoted-msg-pass`(output), `126-redir-quoted-target`(output), `127-node-eval-code`(output), `128-perl-eval-code`(output), `129-ruby-eval-code`(output)
  - `enforce-rpi-bash`: `130-singlequote-noplan`(2), `131-arrow-pass-noplan`(0), `132-node-eval-noplan`(2)
- [x] **Step 2 (RED test_lib):** run-all.sh lib 섹션(라인 ~524 뒤)에 추가:
  - `test_lib "122-redir-singlequote" "evil.py" "$(CMD="echo x > 'evil.py'" CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"`
  - `test_lib "123-redir-noclobber"   "evil.py" "$(CMD='echo x >| evil.py' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"`
  - `test_lib "124-redir-arrow-pass"  ""        "$(CMD='step1 -> output.js' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"`
  - `test_lib "125-redir-quoted-msg-pass" ""    "$(CMD='git commit -m "rename a > b.py"' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"`
  - `test_lib "126-redir-quoted-target" "out.py" "$(CMD='cat > "out.py"' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"` (따옴표 타깃 회귀가드)
  - `test_lib "127-node-eval-code" "gen.js" "$(CMD=$'node -e \'fs.writeFileSync("gen.js", x)\'' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"`
  - `test_lib "128-perl-eval-code" "y.pl"  "$(CMD=$'perl -e \'open(F,">","y.pl")\'' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"`
  - `test_lib "129-ruby-eval-code" "z.rb"  "$(CMD=$'ruby -e \'File.write("z.rb", x)\'' CODE_EXT_REGEX="$LIBREGEX" node "$LIB/redirect-targets.js")"`
- [x] **Step 3 (RED test_erb):** run-all.sh erb 섹션(라인 ~329 뒤)에 추가:
  - `test_erb "130-singlequote-noplan" 2 "$(mk_bash_event "echo x > 'evil.py'" "$NP")"`
  - `test_erb "131-arrow-pass-noplan"  0 "$(mk_bash_event 'echo done -> next.js' "$NP")"`
  - `test_erb "132-node-eval-noplan"   2 "$(mk_bash_event $'node -e \'fs.writeFileSync("g.js",1)\'' "$NP")"`
- [x] **Step 4 (RED 실측):** `bash ~/.claude/hooks/hooks/tests/run-all.sh` 실행 → 122/123/127/128/129/133/135 **FAIL**(미탐지), 124/125/134는 현재도 통과일 수 있음(파서가 오차단하면 FAIL). **RED 출력을 기록**.

### Task 2: 토크나이저로 case-1 교체 (a/b/d) — GREEN

**Files:** `hooks/lib/redirect-targets.js:27-30`

- [x] **Step 1 (GREEN 구현):** 라인 27-30(reRedir 정규식 + while 루프)을 따옴표-인지 토크나이저로 교체:
  - 문자 단위 스캔, 따옴표 상태(`'`/`"`) 추적.
  - 리다이렉션 연산자 `>`/`>>`/`>|`는 **따옴표 밖 + 직전 문자가 `-`/`=` 아님**일 때만 인식(`->`/`=>` 배제).
  - 연산자 뒤 타깃 토큰 읽기(따옴표 타깃이면 언쿼트). `tee [-a] FILE`도 따옴표-인지로 동일 처리(case 33 보존).
  - 셸 메타문자(`<|;&()`)는 토큰 경계. 따옴표 내부 `>`는 무시(오탐 방지).
- [x] **Step 2 (부분 GREEN 실측):** run-all → 122/123/124/125/126 통과 + 기존 75/76/77/33/30-36 회귀 0 확인.

### Task 3: case-4b 인터프리터 eval 추가 (c) + 헤더 갱신 — GREEN

**Files:** `hooks/lib/redirect-targets.js:45-53`(뒤에 4b 추가), `:1-12`(헤더)

- [x] **Step 1 (GREEN 구현):** case 4(python -c) 뒤에 4b 추가 — 리터럴 파일명만(보수적, 변수/동적=Non-Goal):
  - node: `\bnode\s+(?:-e|--eval)\b` 있으면 `(?:fs\.)?(writeFileSync|appendFileSync|createWriteStream)\(\s*["']([^"']+)["']` 매칭.
  - perl: `\bperl\s+-e\b` 있으면 `open(...,">"|">>",​"FILE")` 및 `open(...,">FILE")` 리터럴.
  - ruby: `\bruby\s+-e\b` 있으면 `File.(write|open)\(\s*["']([^"']+)["']`.
- [x] **Step 2:** 헤더 주석(:5-12 탐지 경로 목록)에 "1) 리다이렉션/tee = 따옴표-인지 토크나이저", "4b) node/perl/ruby -e 리터럴 쓰기" 반영.
- [x] **Step 3 (GREEN 실측):** run-all → 127/128/129/135 통과.

### Task 4: README 카운트 정합 + SECURITY.md Non-Goal 정밀화

**Files:** `README.md`(cases 카운트), `SECURITY.md:35`

- [x] **Step 1:** README의 cases.tsv 카운트 "114"를 신규 총수(114+11=**125**)로 갱신 — verify-setup seal #20 정합(README:274·510 등 cases.tsv 언급 줄 전부). E2E "8개"는 불변(신규 erb는 E2E.A-H가 아닌 단위 test_erb).
- [x] **Step 2:** SECURITY.md:35 "인터프리터 내부 쓰기" → "**변수/동적 파일명**을 쓰는 인터프리터 내부 쓰기(리터럴 파일명은 python/node/perl/ruby `-e` 탐지)"로 좁힘. (spec delta 반영)

### Task 5: 전체 GREEN + verify-setup

- [x] **Step 1:** `bash ~/.claude/hooks/hooks/tests/run-all.sh` → **125/125 passed, 정합 OK, pass rate 100%**.
- [x] **Step 2:** `bash ~/.claude/setup/verify-setup.sh` → **PASS FAIL=0** (특히 #20 cases 카운트 정합 green).
- [x] **Step 3:** `bash ~/.claude/setup/verify-integration.sh` → 8/8 (E2E.A-H 불변 — enforce-rpi-bash 동작 보존 확인).

---

## Closeout 체크
- plan Status → completed
- state.json cycle.count 24→25, last_completed_at/last_drift_check = 2026-06-13
- harness-verify: verify-setup PASS 보고 (하네스 수정 사이클)
- 재검증 doc §4 rank 1 완료 표시 → 다음: rank 2(trivial byte-budget)
