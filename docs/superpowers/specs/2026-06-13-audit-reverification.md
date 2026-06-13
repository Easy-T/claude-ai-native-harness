# Audit Re-verification — 적대적 갭 재검증 + 강화 시퀀스 (2026-06-13)

> **성격**: 2026-06-13 external-standards-audit의 갭을 *적대적으로* 재검증한 결과 + 강화 백로그. 코드/설정 변경 0(이 문서는 분석 기록).
> **방법**: 24개 감사 갭마다 회의론자 1명을 붙여 **harness를 변호(갭 반증)** 시키고, 반증 못 할 때만 CONFIRMED. 동시에 completeness critic 3종이 감사가 *놓친* 갭을 탐색. 28 에이전트 / 366 tool calls / RED 재현 포함.
> **출처**: workflow `wf_5c8f19bf-108`. 모든 판정은 file:line 실측 기반.

**Status:** completed (재검증 보고서 — plan 아님)

---

## 0. 핵심 결론

- **감사 24개 갭 중 16개 기각** (REFUTED 1 + BY_DESIGN 13 + non-deficiency 2). 감사가 외부표준에 곧이곧대로 채점하며 **단일-운영자 트레이드오프를 결함으로 과대평가**했다. SECURITY.md·CONTEXT.md·spec이 이미 명시 수락한 잔여를 "갭"으로 재포장한 경우가 다수.
- **8개 확정** (CONFIRMED/OVERSTATED-실결함). 대부분 문서-과대주장(secret-scan exfil, bypass 자세 분기) 또는 자가치유-은폐(doctor 마커).
- **결정적 반전**: completeness critic이 감사가 **전혀 못 본 진짜 코드 버그**를 RED 재현과 함께 발견. 이들은 by-design 항변 여지가 없는 "문자 그대로 깨지는" 결함 — 강화의 1순위.

> 교훈: 자기-감사(self-audit)는 *과대평가*(by-design을 결함으로)와 *과소평가*(실제 버그 누락) 양방향으로 틀린다. 적대적 반증 + 외부 critic이 둘 다 교정했다.

---

## 1. 기각된 감사 갭 (16건 — 강화 불요)

| Gap | 판정 | 사유 (file:line 근거 요약) |
|---|---|---|
| G1-a 미커버 bash 벡터 | BY_DESIGN | SECURITY.md:15,35가 시그니처 1차방어선 상한으로 명시 수락 |
| G1-b MCP 무게이트 | BY_DESIGN | 구성된 MCP 서버 전부 read/search/fetch(FS-write 부재); SECURITY.md:38-40 권한모델 강제 범위-밖 |
| G1-c 파서 크래시 침묵 | BY_DESIGN | CMD는 순수 regex 매칭이라 공격자-입력으로 throw 불가; node-missing은 selfcheck가 잡음 |
| G1-d ≤5라인 누적우회 | BY_DESIGN | 단일운영자=파일저자 본인 자기기만; RPI_SKIP 더쉬운 우회 존재 (단, **NEW-trivial-singleline은 별개 실결함** — 아래) |
| G2-a CI 부재 | BY_DESIGN | 개인 dotfiles repo는 배포대상/릴리스 아티팩트 없어 DORA CD 매핑 부적합 |
| G2-d 95% 허용 | BY_DESIGN | 휴리스틱 매처 FP 흡수용 spec 명시(§6.2/6.6); phantom는 별도 무관용 게이트 봉인 |
| **G3-a 인젝션×knob 우회** | **REFUTED** | 인젝션 명령문자열은 stdin JSON 데이터일 뿐, hook 프로세스 env의 knob에 도달 불가. **인라인 SECRET_SCAN_SKIP= 명령이 실제 차단됨을 실증** |
| G3-c 분할-Edit 시크릿 | BY_DESIGN | SECURITY.md:31 "난독화 시크릿 미탐지, 1차방어선일 뿐" 정확히 인정 (단, doc 명료화는 rank 8) |
| G4-b 미봉인 중복 | BY_DESIGN | PASS=63 정확, #8/#14/#24가 hook 카운트 삼각검증, drift seal은 안정앵커 인스턴스만 정책화 |
| G5-a non-obvious prose | BY_DESIGN | §4는 모델 의미판단 이벤트라 결정적 파일경로 트리거 부재; spec이 ND3 수락클래스로 선제 명시 |
| G5-c 단일 stale-active | non-deficiency | 보안경계 아닌 RPI 자기규율 nudge; 자기탐지 가능 → "무방비" 과장 (단, session-start ⚠ 확장은 선택적 개선) |
| G6-b verdict 로깅 불완전 | non-deficiency | 누락 5경로 전부 allow결과, 모든 BLOCK는 로깅; 로그 완전성이 설계 불변식 아님 |
| G6-c 로그 무소비 | non-deficiency | 집계코드 0건은 사실이나 BLOCK/ALERT는 실시간 stderr 노출; README가 온디맨드 수동 트레일로 규정 (단, doctor 집계 1블록은 선택적) |
| G7-a 하드코딩 경로 | BY_DESIGN | IS_WSL+디렉터리 실존 이중가드로 타 머신선 WARN degrade; fork시 sed 치환을 채택단계로 문서화 |
| G8-a 캐시비용 미측정 | BY_DESIGN | transcript-usage cache 합산은 컨텍스트 점유 목적상 정확; 20배는 soft-guard rationale, 측정 주장 없음 |
| G8-b §1 stderr | BY_DESIGN | spec이 "사용자-타이밍 관심사라 stderr 정당"으로 명시 기각, cycle-24 KEEP 재확인 |

---

## 2. 확정된 감사 갭 (8건 — 강화 대상)

| Gap | 판정 | 핵심 | 강화 rank |
|---|---|---|---|
| G2-b 정합 단방향·텍스트 | CONFIRMED | run-all.sh:659 grep -qF bare-id 부분매칭(hook 미결속, 01-no-marker 중복 실증), 역방향·TOTAL 단언 부재, README "1:1" 과대주장 | rank 4 |
| G3-b fail-open 미문서 | OVERSTATED-실 | require_node·파싱실패 fail-open이 SECURITY.md 잔여목록 미기재 (CONTEXT.md:20-22 자체표준 위반) | rank 6 |
| G3-d bypass 자세 분기 | OVERSTATED-실 | install.sh가 example(default)→settings 복사라 신규설치자=default인데 README:499 "채택=bypass 수용" 부정확 | rank 8 |
| G4-a seal 무회귀테스트 | OVERSTATED-실 | seal 깨고 FAIL 기대하는 자동테스트 부재 (현실 break는 self-surfacing이나 E2E 미증명) | rank 9 |
| G6-a 침묵 fail-open | OVERSTATED-실 | 파서-런타임 절반 실재(enforce-rpi-bash.sh:32 2>/dev/null\|\|true); node-missing 절반은 selfcheck가 이미 표면화 | rank 6 |
| G7-b plugin false-green | OVERSTATED-실 | superpowers=WARN, skill-creator/claude-md-management 무검증 → install/verify-all PASS인데 RPI 비작동 | rank 4/5 영역 |
| G7-c README/install 불일치 | OVERSTATED-실 | "4개 plugin"↔3 커맨드, "선택"↔"필수" 드리프트, 봉인 seal 부재 | rank 8 |
| G8-c 글로벌 CLAUDE.md 미커버 | OVERSTATED-실 | stable-claude-md.sh:11 글로벌 무조건 silent exit; README:36은 커버 함의 → 불일치 | rank 8 |

---

## 3. 완성도 critic이 찾은 신규 실결함 (감사 누락 — RED 재현)

> 이것이 재검증의 최대 수확. 아래 **코드 버그 6건은 by-design 항변 불가** — RED 케이스로 즉시 재현됨.

| ID | 심각도 | 결함 (RED 재현) |
|---|---|---|
| **NEW-redir-singlequote** | HIGH | `echo x > 'evil.py'` → 단일인용 타깃 미스트립으로 isCode 실패 → 코드파일 무-plan 작성. redirect-targets.js:28 따옴표 그룹이 `"?`만(단일인용 미처리), :30 raw push(스트립 없음) |
| **NEW-trivial-singleline** | HIGH | `import os; os.system("rm -rf /")` 한 줄 → NR=1 → trivial PASS. enforce-rpi-cycle.sh:58 물리 개행수만 셈(변경 규모 무관) |
| **NEW-redir-noclobber** | MED | `echo x >\| evil.py` → `>\|` 미탐지(타깃 클래스가 `\|` 제외) |
| **NEW-redir-interp-eval** | MED | `node -e 'fs.writeFileSync("x.js",code)'`/perl -e/ruby -e → 미파싱(python -c만 모델링). node는 보장 런타임이라 가장 쉬운 우회 |
| **NEW-redir-quoted-falseblock** | MED | 주석/메시지 속 `>`·`->`가 오차단(`git commit -m "rename foo > bar.py"` → BLOCK bar.py). **이번 세션에서 실제 재현**. 운영자가 반사적 RPI_SKIP → 게이트 무력화 |
| **NEW-planstatus-prose** | MED | plan head-20의 prose/예시 `Status: active`(코드펜스·인용 포함)가 cwd 전체 게이트 개방. _common.sh:89 단어경계·frontmatter 검증 부재 |
| NEW-install-required-skills | MED | install.sh REQUIRED는 skill 4개, verify-setup item 6은 7개 필수 → 부분 클론 install PASS인데 verify-all FAIL |
| NEW-doctor-marker-unconditional | MED | doctor.sh:176-186 audit 마커 무조건 오늘로 sed → §3 30일 staleness 게이트 상시 무력화(자가치유 은폐) |
| NEW-doctor-test-mutates-live | MED | doctor.test.sh가 라이브 CLAUDE.md/백업 변형 + Test 3 tautological |
| NEW-state-schema-unverified | MED | state.schema.json은 SSOT지만 소비자(검증기) 0 = dead spec; closeout이 schema 검증 안 함 |
| NEW-failopen-trustbase | MED | node PATH-shadow나 _common.sh 변조가 모든 가드 silent 무력화 — 신뢰베이스 미문서 |
| NEW-env-not-gitignored | MED | .env/*.env/.npmrc/*.pem/*.key 미-gitignore → 생성 시 커밋 가능(.credentials.json만 by-name) |
| NEW-egress-scope (doc) | HIGH→doc | `cat creds \| curl -d @-`는 리터럴 키 없어 secret-scan 통과; SECURITY.md:26-31이 exfil 완화로 과대 프레이밍 |
| NEW-inbound-secret-scope (doc) | LOW→doc | Read/WebFetch/MCP 인바운드 시크릿 무검사 비대칭 미문서 |
| NEW-encoding-bypass (doc) | MED→doc | base64/hex/var-split가 secret-scan 무력화 → typo가드이지 exfil control 아님(문구 명료화) |
| NEW-session-marker-collision | LOW | _common.sh:131 /tmp 고정 마커 → 멀티유저/병렬 충돌; verify-integration이 라이브 /tmp 오염 |
| NEW-closeout-harness-verify-trigger | LOW | closeout harness-verify가 "~/.claude 수정" 판정을 자가신고 의존 → silent-skip 구조 개방 |
| NEW-credentials-windows-acl | LOW | .credentials.json world-readable(rw-r--r--); doctor 경고는 POSIX 전용, Windows ACL 미검증 |
| NEW-skeleton-firstmatch | LOW | skeleton-scan.js:22 cur.replace 첫 일치만 → Edit 재구성 오계산 |

---

## 4. 강화 시퀀스 (impact×effort, 9 rank)

> 원칙(synthesis notes): **RED-testable 코드결함 먼저(rank 1-3)** → parity seal(4) → 자가치유 은폐(5) → fail-open 표면화(6) → state schema(7) → **순수 문서 정합은 §1 캐시상 세션 종료 직전(8)** → 메타테스트(9). rpiNeeded=true는 각각 독립 RPI 사이클. 28개 전수 seal RED-test 금지(brittle·과투자) — 대표 1변이로 E2E만 증명. 새 egress 가드 구현은 인플레 — 문서 문구 정정만 정당(SECURITY.md가 이미 단일운영자 신뢰모델 명시).

| rank | 제목 | gapIds | effort | rpi | 핵심 fix |
|---|---|---|---|:--:|---|
| 1 ✅ | redirect-targets.js 4벡터 봉인 **(cycle-25 b765a56 완료)** | singlequote·noclobber·interp-eval·quoted-falseblock | M | ✓ | 따옴표-인지 토크나이저 교체 + node/perl/ruby -e 리터럴. run-all 125/125, review-strict PASS |
| ~~2~~ | trivial 게이트 — **KEEP (by-design 경계, 2026-06-13 사용자 결정)** | trivial-singleline | — | — | 바이트 예산은 짧은 위험 one-liner 미해결 + 정당 편집에 friction; RPI는 보안경계 아닌 자기규율(SECURITY.md 단일운영자). 생략 |
| 3 ✅ | plan_status bold+펜스 엄격화 **(cycle-26 완료)** | planstatus-prose | L | ✓ | bold `**Status:**` 만 인정 + 코드펜스 스킵(awk 재작성). 27 plan 회귀 0, run-all 129/129 |
| 4 ✅ | run-all 정합 강화 + install/verify skill parity **(cycle-27 완료)** | G2-b·install-required-skills | M | ✓ | TOTAL==선언 카운트 + 비주석 실재(주석-온리 phantom 차단, 양형식 커버) — hook→fn 매핑 불요; install REQUIRED +3 skill, verify-setup seal #29. RED 시연: 구 정합 오탐통과 vs 신 검출 |
| 5 ✅ | doctor 마커 보존(자가치유 은폐 제거) **(cycle-29 완료)** | doctor-marker·doctor-test-mutates | M | ✓ | 마커 append-only-if-absent(무조건 sed 제거) → §3 게이트+§1 캐시 둘 다 복원. Bug2는 Bug1로 마커변형 소멸+git백업스킵→해소(별도 mktemp 격리 불요); doctor.test Test3=no-overwrite 불변식. 라이브 마커 비변형 실증 |
| 6 | fail-open 표면화 | G3-b·G6-a·failopen-trustbase | M | ✓ | rpi-bash.sh:32 종료코드 분기+hook_log FAILOPEN(orchestrator ERR-센티넬 이식), selfcheck .js 스모크, SECURITY.md 신뢰베이스 명시 |
| 7 ✅ | state.json↔schema 검증 **(cycle-28 완료)** | state-schema-unverified | L | ✓ | verify-setup #30 스키마-구동 검증(스키마 읽어 required/type/minimum/date 재귀) — dead-spec→live. RED 시연 3종 검출. (closeout 노트는 rank8) |
| 8 | 거버넌스 문서 정합 (캐시상 마지막) | G3-d·G7-c·G8-c·egress·inbound·encoding | L | ✗ | bypass 자세 분기 명시, plugin 카운트 reconcile, 글로벌 캐시 커버리지 정정, secret-scan=content-only/typo가드 명료화 |
| 9 | seal-regression 메타테스트 + harness-verify 기계트리거 | G4-a·closeout-harness-verify | M | ✓ | 임시 $HOME 대표변이로 FAIL→exit E2E 1개; git diff 기반 harness-verify 필수 판정 |

추가 선택(별도 평가): NEW-env-not-gitignored(.gitignore 방어 글롭 — low, 거의 무해), NEW-session-marker-collision, NEW-credentials-windows-acl, NEW-skeleton-firstmatch.

---

## 5. 다음 행동

rank 1부터 **각각 독립 RPI 사이클**(start-rpi-cycle)로 강화. TDD: cases.tsv에 RED 케이스 먼저 → 통과. rank 8(문서)만 §1 캐시 규약상 묶어서 세션 종료 직전. 본 문서 §3·§4가 각 사이클의 read-before.
