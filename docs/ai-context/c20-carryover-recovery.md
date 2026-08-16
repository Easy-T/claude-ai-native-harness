# C20 이월 항목 복원 기록 (C21 인계)

> **작성 계기**: C20 Closeout 감사가 **기록 소실**을 적발했다. `review-yield.md:73` 이
> `I2·I3·I4·M1~M6 = §19.7 수용 잔여 이월` 로 선언했으나, **수취 절(§19.7)에 그 9건이 하나도
> 등재되지 않았다**(실측: §19.7 절 내 `I2|I3|I4|M1..M6` 매치 **0건**).
> 이월은 *선언*됐지만 *수취*되지 않았다 — 「정정-전파 공백」(CONTEXT.md canonical)의 자기-재발이며,
> 대상이 리뷰 발견 자체라 방치하면 복원 불가로 굳는다.
>
> 그래서 **세션이 살아 있는 동안** 실물에서 재현 가능한 것을 즉시 복원해 여기 고정한다.

## 소실 실측

```
$ awk '/^### §19.7/,/^## /' docs/superpowers/specs/2026-07-25-model-policy-design.md \
    | grep -c "I2\|I3\|I4\|M1\|M2\|M3\|M4\|M5\|M6"
0
```

spec 전체의 `M1`/`M4`/`M5`/`M6` 히트(:845·:848·:849·:850)는 **C14 §13.6 material drift 표의
동명이인**이지 C20 리뷰 발견이 아니다. `_goal/c20-*.md` 12파일에도 정의 없음.

## 복원 결과

| # | 원 레이블 | 복원 | 상태 |
|---|---|---|---|
| I2 | "워커 키 오타 침묵-skip" | **재현 성공** (아래 ①) | 복원됨 |
| I3 | "오라클 stderr `2>/dev/null` 폐기" | **재현 성공** (아래 ②) | 복원됨 |
| I4 | 레이블뿐 | 실패 | **복원 불가** |
| M1~M6 | 레이블뿐 | 실패 | **복원 불가** |

M5("`.cmd` 가 REQUIRED 목록에 없음")·M6("`.gitattributes` 부재 · install.sh 가 `bin/` chmod 안 함")은
Closeout 당시 메인 컨텍스트에 남아 있던 서술이나, **durable 근거가 없으므로 복원분으로 취급하지 않는다**
— C21 이 재감사로 독립 재발견해야 유효하다(자기증언을 실측으로 승격시키지 않는다는 §19 규율).

---

### ① I2 — ownership 키 오타가 위반을 침묵시킨다

**기전**: 오라클이 `ownership` 값을 `review-only` 리터럴로만 판정하므로, 한 글자 다른
`review_only` 는 review-only 워커로 인식되지 않고 floor 검사가 통째로 건너뛰어진다.
**오타 = 검사 면제**이며, 그 면제가 계수되지도 않는다(3값 계약의 `*` 는 model 축 전용).

**재현** (2026-08-13 실측):

```bash
T="$TEMP/mpi2"; mkdir -p "$T"
cat > "$T/typo.json" <<'EOF'
{ "modeName":"typo-test",
  "workers":[ {"role":"verifier","ownership":"review_only","command":"claude --model haiku"} ] }
EOF
bash -c 'source ~/.claude/setup/lib/modepack-oracle.sh; modepack_oracle_scan "$1"; echo "exit=$?"' _ "$T"
```

```
TOTAL=1 LITERAL=1 DYNAMIC=0 VIOLATION=0
exit=0                                    ← 침묵 통과
```

대조군(`review_only` → `review-only` 한 글자 수정):

```
TOTAL=1 LITERAL=1 DYNAMIC=0 VIOLATION=1
  typo.json: workers[0] (role=verifier) review-only 인데 haiku(tier 1) < floor 3
exit=1
```

**왜 위험한가**: seal #51 은 `VIOLATION>0` 일 때만 FAIL 한다. 오타 모드팩은
`TOTAL>0 ∧ VIOLATION=0` 이라 **vacuous-방지 arm 도 통과**한다 — 검사 대상은 존재하는데
검사는 실효 0인 상태가 GREEN 으로 보고된다.

**C21 처분 후보**: 알려진 키/값 집합 밖의 `ownership` 값을 만나면 **미지 값으로 계수**하고
(3값 계약의 `*` 와 동형) seal 이 그 카운트를 처분하게 한다. "모르는 값 = 안전"이 아니라
"모르는 값 = 판정 불가, 표면화"가 이 하네스의 규범이다.

> **C21 판정 (2026-08-16)**: **수용 잔여**(차기 이월 — C22 후보). 재현은 유효하다(재실행:
> `TOTAL=1 LITERAL=1 DYNAMIC=0 VIOLATION=0` + `exit=0`). 정정하지 않은 사유 = 위 처분안이
> `setup/lib/modepack-oracle.sh` 카운터 신설 + seal #51 처분 arm 확장 + seal-regression 변이를
> 동반하는 **독립 task 규모**이며, C21 의 주축은 Agent 리터럴 축 복원이고 이번 사이클 seal 예산
> 1건은 기한 있는 항목(non-obvious #3 SMART ①, 기한 "C21 초입" → seal #52 로 착륙)이 선점했다.
> **재판정 조건** = `modes/*.json` 파일 수 > 1 이 되거나 `ownership` 값 집합이 확장될 때
> (현재 파일 **1개** · 값 **1종** `review-only` — 실측). **기한** = C22.
> **현 위험 노출 = 0** (라이브 모드팩에 오타 없음).

---

### ② I3 — 오라클 stderr 폐기로 위반 상세가 사라진다

**실물** (`setup/verify-setup.sh:621`):

```bash
MP_OUT=$(modepack_oracle_scan "$HOME/.claude/modes" 2>/dev/null); MP_RC=$?
```

**기전**: 오라클은 위반 상세를 stderr 로 낸다(위 ① 대조군의
`typo.json: workers[0] (role=verifier) review-only 인데 haiku(tier 1) < floor 3`).
`2>/dev/null` 이 그것을 버리므로, seal 이 FAIL 해도 사용자는
`모드팩 오라클: 정책 위반 검출 — review-only 워커가 floor max(작업자,opus) 미만`(:629)이라는
**일반 문구만** 본다 — 어느 파일 어느 워커가 어느 티어로 위반했는지 알 수 없다.

**왜 위험한가**: 진단 정보 손실은 FAIL 을 재현 불가로 만든다. C20 자신이 seal-regression
control FAIL 을 A/B 로 귀책 실증할 수 있었던 것은 상세가 남아 있었기 때문이다.

**C21 처분 후보**: stderr 를 변수로 포획해 FAIL 메시지에 동반 출력. `2>/dev/null` 은
"오라클 부재 시 소음 억제" 목적으로 보이나, 그 목적은 `[ -f "$MP_ORACLE" ]` 가드가 이미 담당한다.

> **C21 판정 (2026-08-16)**: **정정 완료**. `setup/verify-setup.sh` 의 오라클 호출을 stderr 포획형
> (`MP_ERR=$(mktemp)` → `MP_DETAIL`)으로 교체하고 FAIL 문구 끝에 ` — 상세: ${MP_DETAIL:-없음}` 을
> 덧붙였다. 상세 유실 실측(정정 전): 오라클 stderr 에만
> `typo.json: workers[0] (role=verifier) review-only 인데 haiku(tier 1) < floor 3` 이 나오고
> verify-setup 사용자는 일반 문구만 봤다. 원 목적(오라클 부재 시 소음 억제)은 `[ -f "$MP_ORACLE" ]`
> 가드가 담당하므로 회귀 없음 — 정정 후 `verify-setup: PASS=90 FAIL=0` 실측.

---

## 재발 방지 (C21 규약 후보)

**이월 선언과 수취 등재의 비대칭이 근원이다.** ledger 는 "이월했다"고 쓸 수 있지만, 수취 절이
그것을 받았는지는 아무도 검사하지 않는다. 선언만으로 항목이 살아남는다고 가정한 것이 실패다.

- **규약**: layer-yield 행이 `→ §N.M 이월` 을 선언하면, 그 절에 **항목별 1행**이 실재해야 한다.
- **기계 검사**: ledger 의 이월 선언에서 레이블을 추출해 지목된 절에서 grep — 하나라도 없으면 FAIL.
  (seal #49 가 이미 layer-yield 필드 *존재*를 봉인하므로, 그 옆에 *내용 정합* arm 을 붙이는 형태)
- 이 검사가 있었다면 C20 Closeout 에서 9건 소실이 즉시 걸렸다.

> **C21 판정 (2026-08-16)**: **차기 이월**(C22 후보). 사유 = 이번 사이클 seal 예산 1건은
> non-obvious #3 SMART ①(기한 "C21 초입")이 선점해 **seal #52 로 착륙**했고, 이 검사는 ledger
> 이월 선언의 레이블 추출 규칙(어떤 문면을 "이월 선언"으로 볼 것인가)을 새로 정의해야 하는
> 별도 계약 설계다. **재판정 조건** = C22 Phase R 에서 그 추출 규칙이 결정될 때.

## 부수 발견 — `.gitignore` 베어 `.bak` 사각

```
$ git check-ignore -v settings.json.bak         → 출력 없음, rc=1   (무시 안 됨)
$ git check-ignore -v settings.json.bak-test    → .gitignore:25:settings.json.bak-*, rc=0
```

`.gitignore:25` 가 하이픈 접미사를 요구해 **베어 `settings.json.bak` 을 못 잡는다**.
`settings.json` 자체는 `.gitignore:46` 으로 무시되는 개인 설정이므로, 그 백업이 추적 후보로
노출되는 것은 설계 의도와 반대다. 내용 스캔은 완료(크리덴셜 키 0건 — 매칭 2건은
`enforce-secret-scan.sh` 훅 경로 문자열)이나, **다음 백업이 무해하다는 보장은 없다**.

C21 하우스키핑: `.gitignore` 에 `settings.json.bak` 추가(또는 :25 를 `settings.json.bak*` 로 확장).

> **C21 판정 (2026-08-16)**: **정정 완료**. `.gitignore:25` 를 `settings.json.bak-*` →
> `settings.json.bak*` 로 확장. 실측 `git check-ignore -v settings.json.bak` rc **1 → 0**
> (매치 `.gitignore:25:settings.json.bak*`) · 레거시 `settings.json.bak-test` rc 0 유지(무회귀).
> 정정 시점에 워킹트리에 `?? settings.json.bak` 이 실재했으며 정정 후 추적 후보에서 사라졌다.
