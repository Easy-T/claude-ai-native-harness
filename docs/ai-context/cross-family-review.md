# 교차패밀리 적대 리뷰 규약 (cross-family-review)

> 고-스테이크 판정의 자기채점 편향(agreement bias)을 **비-Claude 패밀리(GPT) 1회 리뷰**로 중화한다. GAP-006(D2·D10 L5 보조) 착륙 산출물(C10, 2026-07-18).
> **핵심 프레임: 탐지(capability probe) 기반** — "GPT가 있다"가 아니라 "**탐지하고, 있으면 쓰라**". 이 repo를 받은 PC에 GPT 경로가 없어도 하네스는 멈추지 않는다(SKIP+사유 기록 = advisory fail-open 교리).
> 소비처: `closeout-pr-cycle` Phase 4(senior review 뒤 분기)·`start-rpi-cycle` 적대 리뷰 옵션. 실증 근거는 §4.

## 1. 탐지 (capability probe) — 순서 고정

교차 리뷰가 걸린 사이클의 Verify 단계에서:

1. **경로 A — Codex CLI (우선; CCS 불필요·이식성 높음)**: `command -v codex` 존재 **+** `codex login status`가 로그인 표시 → 가용. 스모크 1회(저비용): `echo probe | codex exec --sandbox read-only --skip-git-repo-check "Reply: OK"`.
2. **경로 B — CCS/CLIProxy 라우팅 (폴백; CCS 있는 PC만)**: A 불가 시 `claude --model "${ANTHROPIC_CUSTOM_MODEL_OPTION:-gpt-5.6-sol}" -p "Reply: OK" --output-format json` 1회 → **`modelUsage`에 `gpt-*` 키 존재 = 가용**. 모델명은 custom 슬롯 env가 SSOT(버전-무관 — GPT 세대 교체 시 settings.json env만 갱신; 폴백 리터럴은 env 부재 머신용). ★판별은 modelUsage만 — 응답 텍스트의 자가보고("나는 GPT다")는 불인정.
3. **둘 다 불가 → SKIP + 사유 1줄** 기록("이 머신 GPT 경로 부재(codex CLI 미설치/미로그인·CCS 라우팅 없음)") — 기존 자가-표면화 관행.

**★설치·로그인·인증·업데이트 시도 절대 금지** — 탐지는 read-only 확인만. 근거: ChatGPT OAuth 공유 시 reuse-detection 토큰 패밀리 전체 revoke 사고 이력·블라인드 `--update`/`--latest` 금지(바이너리 삭제 위험). codex-plugin-cc류의 자동 설치 제안(`/codex:setup`)도 이 금지에 걸린다.

## 2. 실행 프로토콜 (가용 시 — 두 경로 공통)

- **stdin 파이프 필수**(인자로 대형 문서 전달 금지 — E2BIG 실사고). **경로 A 리뷰 본호출 = canonical 커맨드**:

  ```bash
  cat <대상문서> | codex exec \
    -m gpt-5.6-sol \
    -c model_reasoning_effort=ultra \
    -c service_tier="priority" \
    -c model_verbosity=high \
    --sandbox read-only --skip-git-repo-check \
    -o "$REVIEW_OUT" \
    "<refute-by-default 프롬프트>"
  ```
  경로 B는 `cat <대상문서> | claude --model <gpt-모델> -p "<프롬프트>"` (제어 지점 없음 — 세션 effort 상속).

- **플래그별 근거 (전부 2026-07-27 라이브 실측 — 조합 완주 확인, 14,854 토큰)**:
  · `-m gpt-5.6-sol` — **사용자 확정(2026-07-27): codex GPT는 앞으로도 최상위 sol 고정**(codex 토큰 여유). 이 고정이 아래 `ultra`/`max` 계열의 모델별 비호환 리스크를 소멸시키는 전제다. **sol 이외 슬롯으로 바꾸려면 이 절 전체 재검증 필수**(luna=ultra 침묵 강등·5.5/5.4=max/ultra 400).
  · `model_reasoning_effort=ultra` — 카탈로그 최상위(sol/terra 전용). 실측 기전: wire는 `reasoning.effort="max"` + developer 메시지가 `<multi_agent_mode>Proactive multi-agent delegation is active…`로 교체 = **max + 자동 위임 스위치**. 서버 enum(`…xhigh,max`)엔 없는 클라이언트 티어라 `-m` 고정이 전제.
  · `service_tier="priority"` — codex TUI `/fast`의 비대화형 등가물(카탈로그 `{"id":"priority","name":"Fast","description":"1.5x speed, increased usage"}`). wire에 `"service_tier":"priority"` 실제 전송 확인. **속도·quota 축이지 품질 축이 아님**(정직 표기).
  · `model_verbosity=high` — sol 기본이 `low`라 산출이 절반 이하로 잘리고 있었다. A/B 실측: 동일 프롬프트·effort·stdin에서 low 9,669B → high 25,022B(**2.6배**). 리뷰 분량의 실질 레버.
  · `-o "$REVIEW_OUT"` — 최종 메시지를 파일에 verbatim 기록(C12의 tail 절단 사고 재발 방지). **소비 전 3중 단언 필수**(아래 항목).
- **★`-o` 소비 규율 (실측된 3개 실패 모드)**: ①API 실패 시 파일 미생성인데 **직전 파일이 그대로 남아** 이전 사이클 리뷰를 새 리뷰로 오독 ②쓰기 실패가 stderr 1줄 + **exit 0**(침묵 손실) ③리뷰어가 발견을 여러 메시지로 쪼개면 **마지막 메시지만** 기록. → 호출 전 `rm -f "$REVIEW_OUT"`, 호출 후 `[ -s "$REVIEW_OUT" ]` 단언, **stdout도 함께 보존**(다중 메시지 대비 — stdout이 상위 진실).
- **★`-c` 키 오타는 침묵 무시된다**(실측): `--strict-config` 없이는 미지 키가 경고 없이 no-op. 이 커맨드를 수정할 때는 반드시 `--strict-config` + 존재하지 않는 `--output-schema` 경로로 **API 호출 0회 오라클 검증**을 먼저 하라(무효 키 → `unknown configuration field` / 유효 키 → schema 읽기 실패까지 도달).
- §1 탐지 스모크는 **기본 설정 유지**(저비용 — 가용 확인만. 위 플래그는 본호출 전용).
- 경로 A는 반드시 **`--sandbox read-only`**(리뷰어에게 쓰기 권한 불필요 — 최소 권한, Rule-of-Two reader 원칙 동형) + 신뢰 디렉터리 밖은 `--skip-git-repo-check`.
- **프롬프트 형태**: refute-by-default(칭찬 금지·결함만) · 검사 범주 명시 · **원문 인용 강제**("§번호+정확한 인용 없으면 무효") · 범주에 결함 없으면 "none found" 명시 요구 · 신규 기능/스타일 제안 금지.
- **★메인 세션 트리아지 필수**: 타 패밀리 발견은 그대로 편입 금지 — 발견마다 원문 실측 대조 후 REAL/기각 판정(첫 실행 14건 중 4건이 스코프 오독). 편입 기준은 Claude 발견과 동일(인용+실측). **GPT는 추가 발견자이지 판정자가 아니다.**
- **빈도 상한: 사이클당 1회**(quota 소비 — 다만 2026-07-27 사용자 확정으로 codex 토큰 여유가 전제되어 sol+ultra+priority 조합을 상한 내에서 최대로 쓴다. Claude 일상 위임에 luna를 남발하지 않는 규칙은 유지 — 그건 별개 슬롯 얘기).
- **호출 지점 = 고-스테이크만**: closeout senior review·루브릭 재채점·적대 리뷰. 일상 검증(verify-setup·run-all)은 모델 무관 bash라 대상 아님.
- **컨텍스트 무공유가 원칙**: 리뷰 대상 문서만 stdin으로 전달 — 세션 컨텍스트·작업 이력 이관 금지(fresh-context 독립성이 이 규약의 존재 이유; §3 참조).

## 3. 검증자 모델 정책 + codex-plugin-cc 판정

- **검증자(review-strict)의 기준선은 `max(세션 티어, 작업자 티어)`이며, `model: inherit` 유지가 그중 세션 축을 공짜로 보장한다**(frontmatter 실물 명시 `inherit`; C13 정밀화 — 종전 "≥ 작업자 티어" 단독 표현은 실행자를 세션 위로 상향한 경우만 커버해 세션 축이 빠졌고, model-policy.md의 "≥ 세션" 표현은 그 반대였다. 두 독법의 합집합이 기준선이다 — spec §12.1). 실행자를 세션 티어 위로 상향했다면 **검증자도 그 티어 이상**이어야 한다. 실행자·탐색자 기본값은 `docs/ai-context/model-policy.md` 매트릭스가 별도 규정. **기준선 미만 하향은 사유 선언 필수**(DOWNGRADE-DECLARED 동형). 오케스트레이터의 동적 모델 선택은 채택하지 않는다 — 가장 신뢰하지 않는 계층(모델 판단)에 검증자 선택 재량을 주면 self-pass 우회로가 열린다.
- **codex-plugin-cc(openai) 기각 — 검증 용도 (2026-07-18 판정, 재논의 방지)**:
  ① 컨텍스트 공유(`/codex:transfer`·`--resume`)가 **반-목표** — 검증자가 산출물의 프레이밍·가정을 물려받아 fresh-context 독립성 오염(가치 실증 §4도 무공유 방식이었다).
  ② 자율 발동(codex-rescue 서브에이전트)이 **거버넌스 위반 표면** — "사이클당 1회·명시 호출" 상한을 재량으로 되돌림 + 구현 위임용이라 쓰기 권한 전제(reader 원칙 충돌).
  ③ **표면 증가** — 밑에서 같은 codex CLI 호출이므로 의존성이 CLI 1개 → CLI+플러그인+전용 마켓플레이스 3개로 늘고(C7 공급망 cksum 핀 대상 확장·일단위 고회전 업데이트), 서브에이전트 홉 1개만큼 토큰 이중 소비. `/codex:setup` 자동 설치는 §1 금지 충돌.
  ④ 스레드 이어가기는 raw CLI 동등(`codex exec resume --last` 실측) — 플러그인 전유물 아님.
  **재검토 트리거**: 향후 "Codex에 구현을 위임하고 스레드로 이어받는" 용도의 GAP이 생기면 그 용도로는 정당 후보 — 그때 재평가(검증 용도 기각은 유지).

## 4. 실증 근거 (2026-07-18, 원 검증 머신 실측 — goal 문서는 gitignored라 여기 영구화)

- **경로 A**: `codex` 0.144.1 npm 전역 + `codex login status`="Logged in using ChatGPT". `codex exec --sandbox read-only --skip-git-repo-check` stdin 파이프 정상 응답. 첫 시도가 신뢰 디렉터리 밖 거부 → `--skip-git-repo-check`로 해소(실측).
- **경로 B**: `claude --model gpt-5.6-sol -p` 헤드리스가 CLIProxy Plus(핀 7.2.62-5) 경유 GPT 응답, `modelUsage`에 `gpt-*` 확인. 과거 실패 모드 2종 소멸: E2BIG(→stdin)·CLIProxy 400 "reasoning"(→현 핀).
- **가치 실증**: design.md v4에 대한 GPT-5.6 Sol 1회 리뷰(경로 B)가 Claude 검증 패스 4회(v2 Distill·v3 Gate R/P·v4 Fable 재감사)가 전부 놓친 **진짜 결함 10건** 적발 + 오독 4건 트리아지 기각 — 자기채점 편향 중화 목적 달성 실증.
- C0(2026-07-13) 시점 "ccs 3프로필 전패 → 교차패밀리 불가" 인식은 이 실증으로 **소멸** — 당시 실패는 프로필 부재/구 핀 400/대화형 인증이었고, 현 규약은 그 3개를 전부 우회한다(codex CLI 직접·현 핀·비대화형).
