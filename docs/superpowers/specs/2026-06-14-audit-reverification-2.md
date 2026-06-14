# Audit Re-verification #2 — cycle 25-32 강화 적대적 무변이 재검증 (2026-06-14)

> **성격**: 2026-06-13 외부표준 8차원 감사 → 적대적 재검증 → cycle 25~32 강화가 (a)실제로 착지했고 (b)회귀 없으며 (c)새 갭을 만들지 않았는지를 *처음부터 적대적으로* 재검증한 결과. **분석 전용 — 코드/설정 변경 0.**
> **방법**: 무변이 기준선(라이브 read-only 게이트 3종) + 메타테스트 비공허 재확인 → 강화 8건+KEEP/defer 2건마다 회의론자가 격리 RED로 *반증 시도* → review-strict가 독립 RED로 검증 → completeness critic이 신규 갭 독립 탐색 → 8차원 재점수. 모든 변이는 임시 $HOME 복제본(`make_replica`)/scratch, 라이브 `~/.claude` 무변형(git status witness).
> **출처**: workflow `wf_849eb68b-7a0`(skeptic→verify 파이프라인) — 프록시 재시작으로 5건 deep verdict(rank3·6·9A·9B) 수확 후 나머지는 메인 세션이 결정론적 인라인 RED로 직접 완결(아래 각 항 출처 표기 `[baseline]/[meta]/[wf]/[inline]`). 직전 기준선 = `2026-06-13-audit-reverification.md`.

**Status:** completed (재검증 보고서 — plan 아님)

---

## 0. 핵심 결론

- **강화 8건 전부 LANDED, 회귀 0.** 각 rank의 fix가 라이브 file:line에 실재하고, 원래 RED가 격리 환경에서 기대대로 차단/정상 작동함을 실측. 무변이 불변식 충족(시작·게이트후·종료 git clean, HEAD `c64737d` 불변, 전 변이 mktemp 격리).
- **기준선 그대로**: run-all **129/129** · verify-setup **65/0** · verify-integration **8/0** · seal-regression **5/0**(비공허) · failopen-surface **5/0** · verify-all **ALL PASS**. 워크플로 25-agent 적대적 RED **후에도 run-all 129/129 불변** = 재검증 자체가 라이브를 변형/오염시키지 않음.
- **적대적 반증 실패 = LANDED**: rank3·6·9A·9B는 워크플로 회의론자가 다수 우회 벡터를 시도했으나 핵심 주장을 깨지 못함(rank6은 자가검증 함정 RPI_SKIP env 누출을 스스로 발견·수정 후에도 불변). 나머지 rank1·2·4·5·7·8은 메인 세션이 baseline/메타테스트/인라인 RED로 직접 확정.
- **신규 갭 3종 표면화(전부 저~중 영향, 회귀 아님)**: ★**NEW-redir-fd-amp**(`echo x >& evil.py`가 게이트 우회, MED — E2E exit 0 확정) / **NEW-planstatus-tilde-fence**(`~~~` 펜스 내 active 누출, LOW) / **rank8 doc staleness 2건**(LOW). §3 미강화 잔여 4종은 by-design 그대로 유지(회귀/신규 아님).
- **8차원 재점수**: 강화가 ⑥ **3→4**(rank6 fail-open 표면화)·④ **4→5**(rank9A seal 회귀봉인)을 올림. ③ **3 유지**(정직성↑이나 핵심 G3-a 미해소)·⑦ **3 유지**(cycle25-32 미터치). **새 min = ③ 보안·⑦ 재현성**, 특히 ⑦이 가장 RED-fixable한 다음 타깃(하드코딩 경로 `doctor.sh:13` 실재 확인).

---

## 1. 무변이 증명 (시작 / 게이트후 / 종료 git status)

| 시점 | HEAD | git status --porcelain | 비고 |
|---|---|---|---|
| 재검증 시작 | `c64737d` | clean (빈 출력) | cycle-32 rank6 마감 상태 |
| read-only 게이트 3종 직후 | `c64737d` | clean | run-all/verify-setup/verify-integration 워킹트리 무변형 |
| 메타테스트(2b/2c) 직후 | `c64737d` | clean | seal-regression/failopen-surface 자기격리(cksum witness) |
| full verify-all(doctor 포함) 직후 | `c64737d` | clean | **doctor가 audit 마커 보존(2026-06-12 불변) + 트리 무변형 — rank5 라이브 증명** |
| 적대적 workflow 25-agent + 인라인 RED 직후 | `c64737d` | spec .md 1건만 untracked | 전 변이 mktemp 복제본/scratch 격리, **run-all 129/129 재확인(회귀 0)** |
| 재검증 종료 | `c64737d` | 본 보고서 1파일만 신규(untracked) | 코드/설정 변경 0 |

라이브 `~/.claude`는 재검증 전 과정에서 변형 0. seal-regression/failopen-surface 메타테스트는 종료 시 cksum witness로 라이브 파일 byte-동일을 단언했고, 모든 RED 변이는 `mktemp -d`(`.git` 1.1GB 미복사)에서만 수행. 인라인 RED 중 일부가 라이브 `enforce-rpi-bash`에 차단된 것(아래 rank1)은 오히려 게이트의 라이브 작동을 입증했다.

---

## 2. (A) 무변이 기준선 — read-only 게이트 3종 [PASS]

clean tree(HEAD `c64737d`)에서 라이브 게이트 3종 실행. **success criteria 정확 일치, 회귀 0:**

| 게이트 | 실측 | 기대 | exit | 판정 |
|---|---|---|---|---|
| `hooks/tests/run-all.sh` | **129 / 129 passed** · cases.tsv↔run-all 정합 OK(129 declared==129 run, 비주석 실재) · pass rate 100% | 129/129 | 0 | ✅ |
| `setup/verify-setup.sh` | **PASS=65 FAIL=0** (#30 state↔schema 포함) | 65/0 | 0 | ✅ |
| `setup/verify-integration.sh` | **PASS=8 FAIL=0** (E2E.A–H) | 8/0 | 0 | ✅ |

- **git status 게이트 전/직후**: 둘 다 clean → 게이트가 워킹트리를 변형하지 않음.
- 8차원 감사(2026-06-13) baseline은 run-all **114/114** · verify-setup **63/0**. 현재 **129/129·65/0**는 cycle 25~32가 추가한 단위 케이스(+15: redirect 4벡터 122-132/plan_status 136-139/install-parity 등)와 seal(#29·#30)을 반영한 정상 증가 — 회귀 아님.

---

## 3. (B) 메타테스트 — seal-regression + fail-open-surface [PASS, 비공허 증명]

`verify-all.sh` STAGE 2b/2c GREEN + 격리 복제본 대표변이 주입 시 **non-zero exit + FAIL 메시지 발화**(공허 아님) 재확인.

### STAGE 2b — `seal-regression.test.sh`: **PASS=5 FAIL=0**
```
✓ control: unmutated replica → verify-setup exit 0, FAIL=0           ← 무변이 대조군 무발화
✓ mutant[state_schema]:    exit=1 + seal FAIL «state.json schema 위반»      ← #30 발화
✓ mutant[settings_parity]: exit=1 + seal FAIL «settings/example harness-hook drift» ← #23 발화
✓ mutant[readme_cases]:    exit=1 + seal FAIL «README cases drift»          ← #20 발화
✓ live ~/.claude untouched (witness cksum stable across run)
```
[wf] rank9A 회의론자가 **소스레벨 인과**로 비공허성 추가 증명: 3 needle(«…drift»/«…위반»)이 전부 `verify-setup.sh`의 fail 분기(:154/:192/:268)에서만 출력 → control 복제본은 rc=0+needle 0건 → needle은 mutation-specific(공허 아님). mutator 3종 실제 변형 확인(count 32→"32", matcher 1→0, 129→128 2사이트).

### STAGE 2c — `failopen-surface.test.sh`: **PASS=5 FAIL=0**
```
✓ ①control: healthy parser still BLOCKs code-write w/o plan (exit 2)   ← 정상차단 무손상
✓ ①crash:   파서 크래시 → fail-open 유지(exit 0) + FAILOPEN 로깅       ← enforce-rpi-bash:36-42
✓ ②control: healthy 복제본 → lib runtime ALERT 없음 (no false-fire)
✓ ②crash:   손상 skeleton-scan.js → selfcheck ALERT (stderr + log)     ← session-start:40-50
✓ live ~/.claude 파서+hook 비변형 (witness cksum 안정)
```

### full `verify-all.sh` (STAGE 1 doctor 포함): **ALL PASS**
```
STAGE 1 doctor: PASS=35 WARN=2 FAIL=0   STAGE 2 verify-setup: 65/0
STAGE 2b seal: 5/0                        STAGE 2c failopen: 5/0
STAGE 3 run-all: 129/129                  STAGE 4 integration: 8/0
ALL PASS — system meets §6.6 acceptance gate.
```
- **rank5 라이브 증명**: verify-all이 doctor를 STAGE 1 + 1b(doctor.test)로 다회 실행. audit 마커가 실행 전후 **`2026-06-12` 불변** + **git clean** → cycle-29 "append-only-if-absent"가 라이브에서 자가치유 은폐 없이 작동(NEW-doctor-marker-unconditional 해소 확정).

---

## 4. (C) 강화 8건 착지 판정표 — 적대적 RED 재현 [전부 LANDED]

| rank | 제목 | 판정 | RED 재현 증거 (file:line + 출처) |
|---|---|:--:|---|
| **1** | redirect-targets 4벡터 (cycle-25) | **LANDED** | [baseline] run-all 122-132 전부 PASS: singlequote(122/E2E130→`evil.py` BLOCK)·noclobber `>\|`(123→`evil.py`)·arrow(124/E2E131→빈,통과)·quoted-msg(125→빈)·quoted-target(126→`out.py`)·node-eval(127/E2E132→`gen.js` BLOCK)·perl(128→`y.pl`)·ruby(129→`z.rb`). [inline] 라이브 메타확증: 내 `node -e fs.writeFileSync("g.js")` 명령이 라이브 enforce-rpi-bash에 **실제 차단**됨=interp-eval 탐지 라이브 작동. redirect-targets.js:28-78 따옴표-인지 토크나이저 + :103-121 interp. **★신규갭 §6 NEW-redir-fd-amp.** |
| **3** | plan_status bold+펜스 (cycle-26) | **LANDED** | [baseline] run-all 136-138(plan_status prose/펜스/real)·139(enforce-rpi-cycle prose-noplan BLOCK) PASS. [wf] skeptic+verify LANDED: prose `Status: active`·백틱펜스 내 active 미인정, 진짜 bold `**Status:**`만 → `completed`/`active` 정확(_common.sh:88-102). E2E exit prose=2(BLOCK)/bold-active=0(PASS). **★신규갭 §6 tilde-fence.** |
| **4** | run-all 정합 + skill parity (cycle-27) | **LANDED** | [baseline] reconciliation "129 declared==129 run, 비주석 실재"(run-all.sh:678-697, TOTAL==선언+주석온리 phantom 차단). [meta] seal-regression mutant[settings_parity]·[readme_cases] exit=1+FAIL. verify-setup #29(install REQUIRED⊇7 tracked skill, :237-244) in 65/0. |
| **5** | doctor 마커 보존 (cycle-29) | **LANDED** | [meta] full verify-all: doctor 다회 실행에도 마커 `2026-06-12` 불변 + git clean(doctor.sh:176-188 append-only-if-absent). doctor.test Test3(no-overwrite 불변식, :19-23) in STAGE 1b. 라이브 자가치유 은폐 제거 증명. |
| **6** | fail-open 표면화 (cycle-32) | **LANDED** | [meta] failopen-surface 5/0(①crash→FAILOPEN log, ②crash→lib-smoke ALERT, control 무발화). [wf] skeptic LANDED: 종료코드 판별(크래시≠빈출력) 정확, healthy 무발화, 정상차단 무파괴 — 자가검증 함정(RPI_SKIP env 누출) 발견·수정 후에도 불변, bash -n 사각(valid-bash/valid-JS throw)을 ②smoke가 포착 입증. enforce-rpi-bash:36-42, session-start:40-50. |
| **7** | state↔schema 검증 (cycle-28) | **LANDED** | [meta] seal-regression mutant[state_schema] exit=1+FAIL(count 정수→문자열 type 위반 검출). verify-setup #30(스키마-구동 required/type/minimum/format:date 재귀, :246-268) in 65/0. |
| **8** | 거버넌스 문서 정합 (cycle-30) | **LANDED** (과대주장 0) | [inline] 4주장 코드 대조 일치: secret-scan 7패턴/typo가드/인바운드 미검사(enforce-secret-scan.sh:36-44, 22)·bypass 분기(example `default`↔live `bypassPermissions`, install.sh:126 example→복사)·마커 human-only(doctor.sh:176-188)·글로벌 캐시 제외(stable-claude-md.sh:11). **★경미 잔여 2건 §6(8-a/8-b).** |
| **9A** | seal-regression 메타테스트 (cycle-31) | **LANDED** | [meta] STAGE 2b 5/0(위 §3). [wf] LANDED: needle이 fail 분기에서만 출력됨을 소스레벨 인과로 증명(공허 아님), control 무발화, live cksum 불변. |

→ **8건 전부 fix 코드가 라이브에 실재 + 원래 RED가 기대대로 차단/정상.** REGRESSED/INCOMPLETE 0건.

---

## 5. (D) deferred 정당성 재확인 (회귀 아님 — 의도 유지)

| 항목 | 판정 | 근거 |
|---|:--:|---|
| **rank2** trivial-singleline KEEP | **유지 정당** | [inline] 1줄 위험 one-liner `import os; os.system("danger")`(NR=1, no-plan) → **exit 0 = trivial PASS** 직접 확인(enforce-rpi-cycle.sh:55-64 max(OLD,NEW) 라인 ≤5). [baseline] run-all 15-write-tiny·52-s7-3x3 PASS. KEEP 근거 문서 실재: SECURITY.md:6 단일운영자 신뢰모델 + `2026-06-13-audit-reverification.md` §1 G1-d·§4 rank2(2026-06-13 사용자 결정). **REGRESSED로 재포장 금지 — 의도된 by-design 경계 그대로.** |
| **rank9B** harness-verify 기계트리거 defer | **defer KEEP 정당** | [wf] LANDED: deferred fix 코드 라이브 부재=의도된 defer 그대로 실재. Stop 훅(verify-loop-watch.sh)은 advisory-only(emit_block 함수 자체 부재, decision:block 없음) → closeout git-diff를 기계 강제 불가(F12-class). 신규 Stop 매처가 생겼어도 advisory라 deferred 값 미상승 → INCOMPLETE 불성립. **★정직성 노트(§6)**: defer 서사의 "트리거 없음" 함의는 약간 과장(turn-end advisory는 이미 존재) — 문구 정밀화 후보(차단 아님). |

---

## 6. (E) 적대적 신규 갭 (completeness critic) — 전부 저~중 영향, 회귀 아님

| ID | 심각도 | 분류 | RED 재현 + file:line | 권고 |
|---|:--:|---|---|---|
| **NEW-redir-fd-amp** | **MED** | real-residual | [inline] `echo x >& evil.py`(no-plan) → enforce-rpi-bash **exit 0 = 미차단**(코드작성 우회). 대조 `&> evil2.py` → exit 2(정상 차단). redirect-targets.js:38-44가 `>`/`>>`/`>\|`만 op로 처리, `>&`의 `&`를 sep로 보고 타깃 누락. rank1이 봉인한 `>\|`의 형제 연산자인데 누락. **회귀 아님**(rank1 이전 regex도 미탐지)·적대적 헌트로 표면화. | 차기 사이클: 토크나이저에 `>&`(파일명 타깃) 추가. RED-testable. |
| **NEW-planstatus-tilde-fence** | LOW | real-residual | [wf] rank3 발견 + E2E 도달 확인: `~~~`(tilde) 펜스 내 `**Status:** active`가 `active`로 누출 → cwd 게이트 오개방 가능. _common.sh:92가 백틱 ```` ``` ````만 토글, `~~~` 미인지. **claim 범위(백틱) 밖 + 라이브 plan은 전부 백틱이라 무영향.** | awk 펜스 정규식 `^[[:space:]]*(```\|~~~)`로 확장. |
| **rank8-doc-staleness-a** | LOW | doc-staleness | [inline] SECURITY.md:19 fail-open 괄호("selfcheck가 node-missing/syntax만 차기 표면화")가 cycle-32 rank6의 session-start lib-runtime smoke를 미반영(CONTEXT.md:21은 반영) → 두 문서 간 과소진술. **과대주장 아님.** | §1 캐시상 세션종료 직전 1줄 정정. |
| **rank8-doc-staleness-b** | LOW | doc-residual | [inline] install.sh:150 STEP2 헤더가 claude-md-management를 "필수(미설치시 RPI 작동X)"로 묶음 ↔ README:87/122 "선택". rank8이 README는 고쳤으나 install.sh prose 잔존(G7-c 부분잔여). | install.sh STEP2 문구 분리. |
| **rank9B-defer-narrative** | LOW | doc-precision | [wf] defer 사유문구의 "어떤 트리거도 closeout 무관" 함의가 과장(verify-loop-watch turn-end advisory 존재). 단 '필수/차단 기계판정'은 여전히 미제공이라 defer 자체는 정당. | 문구 "blocking/REQUIRED 기계판정은 advisory-only 아키텍처상 불가"로 정밀화. |

### §3 미강화 NEW-* 잔여 4종 — 전부 still-residual (by-design, cycle25-32 미터치, 회귀/신규 아님)
- **NEW-env-not-gitignored**(LOW): `.gitignore`에 `.credentials.json`만, `.env/*.env/*.pem/*.key/.npmrc` 글롭 없음 → 생성 시 커밋 가능. 단일운영자 가정 수락 잔여.
- **NEW-session-marker-collision**(LOW): `_common.sh:142` `session_marker`가 `/tmp/%s-%s` 고정(session_id suffix) → 멀티유저/병렬 충돌 가능. 단일운영자 수락.
- **NEW-credentials-windows-acl**(LOW): `doctor.sh:327-328` Windows는 WARN만(ACL/EFS 권장), 강제 없음 — 문서화된 by-design.
- **NEW-skeleton-firstmatch**(LOW): `skeleton-scan.js:22` `cur.replace(oldS,newS)` 첫 일치만 → Edit 재구성 오계산 엣지. Edit 유일매칭 규약과 대체로 정렬되어 실효 영향 미미.

### 강화-도입 회귀 점검 (rank1 토크나이저/rank3 awk/rank4 정합/rank5 doctor)
- rank1 토크나이저: 신규 벡터 7종 격리 헌트 — `>>`/`&>`/`2>`/double-space/tab/escaped-quote 전부 정상 BLOCK, `$VAR`(Non-Goal) 정상 통과. `>&` 1건만 누락(위). **정당 케이스 오차단·크래시·ReDoS 0.**
- rank3 awk: 진짜 bold active 미스(under-block) 0(real-active=active 확인). tilde 1건만 over-open(위).
- rank4 정합: control 복제본 무발화(false-green 0), mutant 발화 — vacuous-pass 미발견.
- rank5 doctor: 라이브 마커 보존(위조 0) + 트리 무변형(meta). 새 우회 미발견.

---

## 7. (F) 8차원 재점수 (동일 5점 루브릭: 1부재/2prose/3부분강제·검증/4강제+검증+고장표면화/5+회귀봉인+외부표준충족)

| 차원 | old | new | 근거 (어느 강화가 점수를 움직였나) |
|---|:--:|:--:|---|
| ① 강제 아키텍처 | 4 | 4 | rank1이 bash-write 4벡터 봉인(커버↑)이나 MCP 무게이트(G1-b)+신규 `>&` 갭 → 5 미달. **커버 강화된 4.** |
| ② 검증 파이프라인 | 4 | 4 | rank4(정합 양방향)·rank7(schema live)·rank9A(seal meta-test)로 false-green 방지 실질 강화. 그러나 CI 부재(G2-a, DORA CD) → 5 미달. |
| ③ 보안 | 3 | **3** | rank8 정직성↑(secret-scan=typo가드 명시·egress 범위밖·bypass 분기·fail-open 신뢰베이스)·rank6 fail-open 표면화. **그러나 핵심 G3-a(우회-*사용* RPI_SKIP/SECRET_SCAN_SKIP 실시간 표면 + bypassPermissions 자세) 미해소** → min 유지. rank6은 *파서 크래시* 표면화이지 *우회 사용* 표면화가 아님. "정직하게 문서화된 3". |
| ④ 드리프트 방어 | 4 | **5** ⬆ | ★**rank9A가 G4-a(seal 무회귀테스트, 명시된 5-blocker)를 직접 봉인** — seal이 드리프트에 non-zero exit+FAIL로 비공허 발화함을 메타테스트(seal-regression.test.sh, verify-all STAGE 2b)로 E2E 증명. 11+ seal content-parity + **회귀봉인** + NIST Measure 매핑. (잔여 미봉인 중복은 cycle-19~21 in-place 정합/genesis-record로 대부분 해소, minor by-design.) |
| ⑤ 수명주기 | 4 | 4 | rank3가 plan 게이트 강화(prose/펜스 stale-active 오개방 봉인)이나 G5-a(non-obvious prose-only) 미해소 → 4 유지. |
| ⑥ 관측가능성 | 3 | **4** ⬆ | ★**rank6가 G6-a(침묵 fail-open)를 직접 봉인** — 크래시→FAILOPEN hook_log+stderr / lib-runtime smoke ALERT(고장 표면화=level-4 trait 충족). rank5가 doctor 자가치유 은폐 제거(staleness 게이트 관측화). G6-c(로그 무소비, 집계 부재) → 5 미달. |
| ⑦ 재현성 | 3 | **3** | **cycle25-32가 미터치** — G7-a(`doctor.sh:13` 하드코딩 `/mnt/c/Users/12132/.claude` 실재 재확인)·G7-b(plugin false-green superpowers WARN) 그대로. **가장 명확하고 RED-fixable한 다음 타깃.** |
| ⑧ 컨텍스트 경제 | 4 | 4 | 미터치 → 4 유지. |

**총평 (min 기준)**: 강화는 자신이 겨냥한 ⑥(관측)·④(드리프트)를 정확히 끌어올렸다(3→4, 4→5). ③(보안)은 *정직성*은 올랐으나 min을 결정하는 G3-a(실시간 우회 표면 + bypassPermissions)가 미해소라 3 유지. ⑦(재현성)은 cycle25-32의 보안/검증/관측 초점 밖이라 미터치 3 유지. **새 min = ③ 보안 + ⑦ 재현성**이며, ⑦이 가장 즉시 고칠 수 있는 결함(하드코딩 경로 1줄 + plugin 게이트 승격)을 안고 있어 다음 사이클 1순위 후보다.

---

## 8. CONFIRMED 결함별 차기 RPI goal 초안 (3라벨)

> 본 재검증은 분석 전용 — 아래는 *별도 RPI 사이클*로 분리할 초안. impact×effort 순.

### Goal 초안 #1 — 재현성 min 해소: 하드코딩 경로 + plugin false-green (⑦, 최우선)
- **goal:** `setup/doctor.sh:13`의 하드코딩 `WINDOWS_CLAUDE_HOME_CANDIDATE="/mnt/c/Users/12132/.claude"`를 `$HOME`/환경 유도 경로로 치환(타 사용자 WSL 이식). 플러그인 의존성(superpowers/skill-creator)을 verify-all의 명시 게이트 또는 doctor의 분명한 비-PASS 상태로 승격해 "ALL PASS"가 RPI 작동을 거짓 보증하지 않게(G7-b). 산출물 = doctor.sh + (선택)install.sh 코드 변경 + 신규/갱신 단위 케이스(이식 경로 RED→GREEN). **RPI 사이클 필수(코드).**
- **read-before:** 1. 본 보고서 §7 ⑦ + `2026-06-13-external-standards-audit.md` §D⑦/백로그#3 2. `setup/doctor.sh:13,105-119,251-259` 3. `setup/verify-setup.sh`(seal 패턴) 4. `hooks/_common.sh` normalize_path/resolve_cwd 규약 5. `README.md:81-122`(plugin 표).
- **autonomy:** 경로 치환은 기존 normalize_path 규약과 일관. plugin을 PASS 조건으로 넣을지 doctor WARN 강화로 둘지는 "신선-클론 거짓 green 안 됨"을 만족하는 선에서 best-practice(과한 게이트=init 마찰 주의). 카운트류는 #20/#21 seal과 충돌 없게.

### Goal 초안 #2 — bash-write 토크나이저 일반화: `>&` + `~~~` 펜스 (① + ⑤)
- **goal:** `hooks/lib/redirect-targets.js`의 따옴표-인지 토크나이저에 `>&`(파일명 타깃, fd-number 제외) 리다이렉션 탐지를 추가해 NEW-redir-fd-amp 우회를 봉인하고, `hooks/_common.sh:92` plan_status awk의 펜스 정규식을 `^[[:space:]]*(```\|~~~)`로 확장해 NEW-planstatus-tilde-fence 누출을 봉인한다. 산출물 = lib + _common 코드 변경 + cases.tsv RED 케이스(`>&`→코드타깃 BLOCK, `~~~` 펜스→active 미인정) → run-all GREEN. **RPI 사이클 필수(코드).**
- **read-before:** 1. 본 보고서 §6 NEW-redir-fd-amp/tilde-fence 2. `hooks/lib/redirect-targets.js:28-78`(토크나이저 op 분기 :38-44) 3. `hooks/_common.sh:88-102`(plan_status awk) 4. `hooks/tests/run-all.sh:512-548`(redirect/planstatus 단위 패턴) + `cases.tsv` 5. `2026-06-13-audit-reverification.md` §3(원래 redirect 4벡터 봉인 맥락).
- **autonomy:** 보수적 — `>&2`/`>&1`(fd-number 타깃)은 파일 작성 아니므로 차단 금지(파일명 타깃만). 오탐 최소화(quoted/arrow 기존 케이스 회귀 0 단언). tilde 확장이 기존 백틱 케이스 136-137 무회귀.

### Goal 초안 #3 — 보안 min: 우회-사용 실시간 표면화 (③, 백로그#1 잔존)
- **goal:** `RPI_SKIP`/`SECRET_SCAN_SKIP` 우회 *사용*을 세션 내 실시간으로 1줄 표면화(현재는 로그-only, G3-a). fail-open 크래시 표면화(rank6)와 달리 *우회 사용*은 아직 무표면. doctor에 당월 `.log` BLOCK/ALERT/SKIP 집계 read-only sub-check 추가(G6-c 로그 소비, S8 postmortem). 산출물 = hooks(emit) + doctor 코드 변경 + 단위 케이스. **RPI 사이클 필수.**
- **read-before:** 1. 본 보고서 §7 ③·⑥ + `2026-06-13-external-standards-audit.md` §D③/백로그#1 2. `hooks/enforce-rpi-cycle.sh:68-72`·`enforce-rpi-bash.sh:25-28`·`enforce-secret-scan.sh:28-31`(우회 분기) 3. `hooks/_common.sh`(emit_system_message/hook_log) 4. `SECURITY.md`(잔여 위험 절).
- **autonomy:** 우회를 차단으로 바꾸지 말 것 — 표면화만(의도된 트레이드오프). 로그 집계 read-only(secret 값 미표시 불변식). 새 seal은 안정 앵커 있을 때만.

### Goal 초안 #4 — 문서 staleness 정정 (8-a/8-b/9B, doc-only, §1 캐시상 묶음)
- **goal:** SECURITY.md:19 fail-open 괄호에 rank6 lib-runtime smoke 반영, install.sh:150 STEP2에서 claude-md-management 선택/필수 분리(README와 정합), rank9B defer 사유문구를 "blocking/REQUIRED 기계판정은 advisory-only 아키텍처상 불가"로 정밀화. **doc-only(RPI ✗), §1 캐시 규약상 세션 종료 직전 묶음 커밋.**
- **read-before:** 1. 본 보고서 §6 staleness 2건 + §5 rank9B 노트 2. `SECURITY.md:19` 3. `setup/install.sh:150-155` 4. `README.md:87,122` 5. `skills/start-rpi-cycle/SKILL.md`(harness-verify 절).
- **autonomy:** 순수 문서 — 카운트류는 #20/#21 seal과 충돌 없게. 과대주장 금지(rank6 실측 범위 내).

---

> **무변이 종료**: HEAD `c64737d` 불변. git status = 본 보고서 1파일만 untracked. 코드/설정 변경 0. 적대적 RED 후 run-all 129/129 재확인(회귀 0).
