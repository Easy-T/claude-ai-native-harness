# C21 (cycle 72) 재개 goal — 비-Claude 세션 정책 침묵 정정

> **이 파일을 읽었다면**: Phase R 은 완료·커밋됐다. Phase P(plan)부터 시작한다.
> post-compact 재개용이므로 `read-before` 를 먼저 전부 읽고 시작할 것.

---

## goal

`hooks/surface-model-policy.sh` 의 **세션 판별 축** 결함을 정정해 비-Claude 세션에서
**Agent 경로 리터럴 축**을 복원하고, 그 과정에서 실재가 확인된 C19 예약분(I1)과
C20 이월분을 함께 처분한다. 설계는 **spec §20 에 확정돼 있다** — plan 은 그것을 구현으로
번역하는 것이지 재설계가 아니다.

### 관찰가능 success criteria

| # | 항목 | PASS 조건 |
|---|---|---|
| S1 | 정규식 중립화 | `session_model_of()` 문자클래스 `claude-[a-z0-9.-]+` → `[A-Za-z0-9._-]+`. **RED→GREEN 증거 필수**: 정정 전 GPT transcript + `review-strict:haiku` → SILENT / 정정 후 → `rule-b-verifier-below-opus-floor` ALERT |
| S2 | 신규 픽스처 | `hooks/tests/cases.tsv` 에 비-Claude 세션 케이스 **≥4**(리터럴 haiku·리터럴 fable·execute fable·inherit SILENT). **실 shape 필수**(`run-all.sh:1042 mk_agent_event` 계열 · 합성 shape 금지 — cycle-40 교훈) |
| S3 | 무회귀 | `run-all` **291/291 + 신규분** · `verify-setup` **89/0 + 신규분** · `seal-regression` **26/0** |
| S4 | Workflow 불변 | `hooks/surface-model-policy.sh` `:42-158` diff **0**(N3 — Rule C/C2/C3 미개정) |
| S5 | GAP 원 기록 정정 부기 | `docs/ai-context/c21-gap-nonclaude-session-blindness.md` `:21-22`·`:81-83` 에 §20.2/§20.3 판정 반영. **삭제 아님 — 부기**(§19.7-7 선례 · §20.6-6) |
| S6 | I1 non-obvious 등록 | §4 5단계 전수(사용자 확인 완료분 — C19 승인) + review-strict 5 Whys + **재현 픽스처**. root cause = 시스템/프로세스 |
| S7 | C20 이월 처분 | I2(ownership 오타 침묵-skip) · I3(오라클 stderr `2>/dev/null`) · `.gitignore` 베어 `.bak` — 각각 정정 또는 수용 잔여 명문화 |
| S8 | seal 신설 | 신규 seal 1건 이상(번호는 **closeout 직전 origin/master 실측 발급** — §6) + seal-regression 변이 동반(§18.3 판별력 경화) |

---

## 이미 끝난 것 (재수행 금지)

- **Phase R 완료**: brainstorming(메인 직접) · grill(코드 탐색으로 대체) · spec §20 집필-위임(execute-strict opus, 재작성 0회)
- **Gate R**: FAIL(실발견 2) → 정정 4건 → **델타 재심 PASS 7/7**
- **커밋 5개** (`c0a0acf`..`f15ec33`), 브랜치 `cycle-72-nonclaude-policy-gap`, 작업트리 clean
- **CONTEXT.md** 신규 canonical 「세션 판별 축 / 세션 티어 축」 등록 완료

## 확정 설계 (spec §20 — 재논의 금지)

- **N1** 결함 = C17 A1 정정의 **미완결분**(티어 축은 열렸고 판별 축은 남았다). "신규 결함"·"C17 이 놓쳤다" 프레이밍 금지
- **N2** 수단 = **정규식 1개 중립화**. `:169` 조기종료 제거는 **기각**(판별 실패 ≠ 미지 티어 · 모집단 50중 12)
- **N3** 범위 = **Agent 리터럴 축만**. Workflow(`:54`·`:56`)는 §16.4-5 의식적 수용으로 존속
- **N4** 상속 축(`inherit`)은 **계속 skip** — 임의 티어 부여는 §16.4-4 "평가≠상계" 후퇴의 재발

## ★ 작업 중 반드시 지킬 것 — I1 (이 사이클에서 실재 재현됨)

`docs/superpowers/specs/2026-07-25-model-policy-design.md` 는 **CRLF 1823 + LF 572 혼합**이다.
- **Edit 도구는 이 파일을 전량 CRLF 로 정규화해 기존 절 723줄을 훼손한다**(실측)
- **`grep -c $'\r$'` 는 이 파일에서 0 을 반환한다** — 계수에 쓰지 말 것.
  정확한 계수: `perl -ne '$n++ if /\r/; END{print "$n\n"}' <file>`
- 혼합-개행 파일 편집은 **`perl -0777 -i -pe`** 바이트 편집 사용(`RPI_SKIP` 선언 동반)
- 편집 후 매번 CR 계수와 `git diff --numstat` 로 무결성 확인

---

## read-before (post-compact 필수 — 존재하는 것만)

1. `C:\Users\12132\.claude\docs\superpowers\specs\2026-07-25-model-policy-design.md`
   — **§20 전체(:2397-2549)** 가 이번 사이클 설계. 배경으로 §16.2(:1546-1552) · §16.4-4/-5(:1588-1594) · §19.1
2. `C:\Users\12132\.claude\CONTEXT.md` — 특히 「세션 판별 축 / 세션 티어 축」 · 「프로세스-경계 정책 공백」 · 「정정-전파 공백」
3. `C:\Users\12132\.claude\docs\ai-context\c21-gap-nonclaude-session-blindness.md`
   — **부분적으로 틀린 원 기록**(§20.2 가 `:169` 지목 기각 · §20.3 N3 가 `:54` 를 수용 판정). S5 대상
4. `C:\Users\12132\.claude\hooks\surface-model-policy.sh` — `:30-35`(정규식) · `:169` · `:171`·`:178`·`:198`·`:201`
5. `C:\Users\12132\.claude\docs\ai-context\non-obvious.md` — #1(합성 테스트 마스킹 — S2 픽스처 규율) · #3(MSYS 경로 · SMART① = 이 사이클 기한)
6. `C:\Users\12132\.claude\docs\ai-context\c20-carryover-recovery.md` — S7 의 I2/I3 재현 절차
7. `C:\Users\12132\.claude\docs\ai-context\review-yield.md` — C20 행(대장 형식 참조)
8. `C:\Users\12132\.claude\skills\start-rpi-cycle\SKILL.md` — Phase P 이후 절차
9. `C:\Users\12132\.claude\_goal\c21-skeleton-spec20.md` — 골격 계약(§20 이 무엇을 약속했는지)

## autonomy

goal 실행 중 선택 분기는 멈추지 말고 best-practice 로 판단해 진행(scope 내).
멈춤은 **진짜 사용자 결정이 필요할 때만** — 구체적으로:
- **PR 머지**(하네스 규약: AI 는 merge 를 결정하지 않는다 — 명시 승인 필수)
- spec §20 의 N1~N4 를 **뒤집어야 할** 근거가 나온 경우(설계 재판정은 사용자 사안)
- 외부 도구 **설치·로그인·인증·업데이트**(`cross-family-review.md:15` 절대 금지)
- **CCS 제거** 관련 일체(사용자 명시 보류)

그 외 — 픽스처 개수, seal 형태, 커밋 분할, task 순서, 이월분 처분 방식(정정 vs 수용
잔여), 리뷰 층 구성 — 은 전부 자율 판단한다.

## 진행 방식

1. **Phase P** — `writing-plans` skill 호출. plan 을 `docs/superpowers/plans/2026-08-16-c21-nonclaude-policy-gap.md`
   에 저장(헤더 `Status: active` · `RPI-Cycle: 72`). **Best-Direction Check 필수 필드**.
   S1~S8 을 task 로 분해하되 light-병합 규약 적용(§16.3-3).
2. **Gate P** — review-strict. FAIL 시 델타 재심(§15.4).
3. **Phase I** — ultracode ON 이므로 (d) Workflow 또는 (a) subagent-driven 중 판단.
   S1 은 heavy(TDD 필수) · S5/S7 은 light. **TDD-verbatim 규약**(plan 본문 verbatim 전달).
4. **Closeout** — closeout-pr-cycle(C-0) → 통합 리뷰 소비 → plan completed → state.json
   (`cycle.count` 72 · `last_completed_at` · `audit.last_drift_check`) → verify-setup →
   seal-regression **full 필수**(setup/ diff 발생 예정) → layer-yield 대장 append → PR.
5. **머지는 사용자 승인 후** — PR 생성까지 하고 정지.

## 정지점 (자동 속행 금지)

- `FABLE-TAKEOVER` **2산출물 연속** → 진행 중단하고 사용자 판단 대기(spec §17.1)
- S3 무회귀가 깨지고 원인이 설계 축이면(단순 픽스처 조정으로 안 되면) 보고 후 대기
