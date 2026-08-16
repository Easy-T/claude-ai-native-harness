# C21 슬롯 2 (GPT gpt-5.6-sol, ultra) 트리아지 — 메인 판정

> 판정 주권은 메인. 아래 REAL 판정은 **전부 메인이 직접 재현**한 것이다(GPT 주장 인용이 아니라 자체 실행 결과).
> 리뷰 원문: `_goal/c21-slot2-gpt.md` (30,721B) · 제기 23건 · 판정 = **REJECT**

## 결론 요약

**슬롯 2 가 코어 결함을 잡았다. C21 의 판별식은 미완성이다.**

후보 A 를 기각한 근거(툴콜 `input.model` 오채택 → `tier_of`=1 → N4 위반)가 **후보 E 에서도 살아 있다**.
60자 룩백은 JSON 스코프의 대용이 될 수 없으며, 방향이 입력 길이에 따라 뒤집힌다.

## REAL — 메인 재현 완료 (판별식 축)

| # | 등급 | 내용 | 메인 실측 |
|---|---|---|---|
| 1 | BLOCKER | `input` 이 **닫힌 뒤**의 진짜 `message.model` 도 60자 룩백이 거부 → EMPTY | 픽스처 77 입력 → `EMPTY` (기대 `gpt-5.6-sol`) |
| 2 | BLOCKER | 60/61 경계에서 판정이 **반전** — 패딩 1자 차이로 `input.model` 채택 | 패딩 44 → `gpt-5.6-sol` · 패딩 45 → `haiku` |
| 3 | MAJOR | `input` 외 중첩(`metadata.model`)은 그대로 선점 — "구조 앵커" 아님 | `metadata.model` → `haiku` (기대 `gpt-5.6-sol`) |
| 4 | BLOCKER | awk `m` 이 라인마다 초기화되지 않음 → **직전 assistant 모델이 stale 하게 잔존** | 2라인 입력 → `claude-fable-5` (기대 `gpt-5.6-sol`) |

**#2 의 정책 영향이 가장 크다**: `tier_of("haiku")`=1 이라 `SESSION_TIER != 0` 가드를 통과해 **상속 축이 오발화**한다 = N4 직접 위반. 이는 후보 A 기각 사유와 동일한 실패이며, 후보 E 는 그 창을 좁혔을 뿐 닫지 못했다.

**#4 는 fail-open 보다 위험**: 주석은 "전부 input 소속이면 빈 값 → fail-open" 이라 적었으나, 다중-assistant transcript(정상 상태)에서는 EMPTY 가 아니라 **과거 모델**로 정책이 발화한다.

## REAL — 메인 재현 완료 (seal #52 축)

| # | 등급 | 내용 | 메인 실측 |
|---|---|---|---|
| 12 | BLOCKER | Mutator 23 **정의행 자체**가 `TOTAL` 을 공급 → vacuous 가드 무력 | 정의행만 스캔 → `TOTAL=1 VIOLATION=0` |
| 13 | BLOCKER | escaped quote(`\"`)에서 소스를 잘라 **실제 보간을 놓침** | `node -e "…\"…\"…$PPV…"` → `VIOLATION=0` (기대 1) |
| 15 | MAJOR | 실행되지 않는 **문자열/주석도 VIOLATION** → 거짓 FAIL | `printf '%s\n' 'node -e "$TMP"'` → `VIOLATION=1` |
| 18 | MAJOR | `witness()` 에 `hooks/tests/run-all.sh` 부재인데 Mutator 23 이 그 파일을 수정 | witness 목록 실독 — 미등재 확인 |

seal #52 는 **양방향으로 부정확**하다(우회 가능 + 거짓 양성). "인라인 인터프리터 17건 위반 0" 이라는 GREEN 은 그 17 이 실제 호출 수가 아니므로 의미가 약하다.

## REAL — 픽스처 판별력 축 (가장 뼈아픈 지적)

**#20 (BLOCKER)**: 픽스처 77 이 **현 구현의 오답을 GREEN 으로 봉인**한다.

77 의 기대값은 `SILENT` 인데, SILENT 에 이르는 경로가 둘이다:
- 정상: `SESSION_MODEL=gpt-5.6-sol` → `tier_of`=0 → 상속 축 skip → SILENT
- 오답: `SESSION_MODEL=""` → `:169` fail-open → SILENT ← **현 구현은 이쪽**

내가 쓴 주석이 이를 자백하고 있다: *"앵커 생존 시 pick 빈 값 → :169 fail-open → SILENT"*.
즉 나는 EMPTY 를 **정상 동작으로 문서화**했다. 77 이 검출하는 것은 "첫 haiku 를 고르지 않았다" 뿐이고,
"올바른 GPT 를 골랐다" 는 검증하지 않는다.

**#21·#22 (MAJOR)**: 6건 중 구 코드를 실제로 죽이는 것은 73·74·75 뿐(76·77·78 은 구 코드에서도 GREEN).
게다가 73~75 는 리터럴 축이라 `SESSION_MODEL` 이 *비어 있지만 않으면* 통과한다 — 정확한 GPT 추출을 봉인하지 않는다.
GPT 가 제시한 반례 mutant(항상 `claude-opus-5` 반환 등)가 6건 전부를 통과한다.

## 미판정 (재현 미실시 — 정직 부기)

- #5 `tail -c 1000000` 이 대형 레코드 좌측 절단 (MAJOR, 주장은 구체적이고 기전상 타당)
- #6 미완성 JSON 라인 채택 (MAJOR)
- #7 escaped key(`foo\"model`)로 가짜 토큰 (MAJOR — 단 유효 JSON 이 그런 키를 쓸 개연성은 별도 판단)
- #8 공백/유니코드 이스케이프 (MINOR)
- #9 조밀 매치에서 이차 시간 (MAJOR — 5000 매치 6.29초 주장)
- #14 seal 의 멀티라인·`$1`·backtick·CLI 변형 미탐 (MAJOR)
- #16 awk 종료 상태 미확인 (MINOR)
- #19 Mutator 가 행동 수준 실패를 재현하지 않음 (MINOR)
- #23 `test_smp` 오라클이 arm slug 를 확인하지 않음 (MINOR)

## 기각 / 비-결함

- #10 오프셋 산술·종료성 — GPT 스스로 "반박 실패" 선언. 내 구현이 옳다.
- #11 literal `TOTAL=0 → OK` 경로 — GPT 스스로 반박됨(현 코드에 그 경로 없음). **단 #12 가 그 가드를 의미상 무력화**.
- #7 의 "일반 문자열 값 속 `\"model\"`" — GPT 실측으로 **안전** 확인(다만 "우연히 안전"이라는 지적은 타당).

## 처분 판단 (사용자 결정 필요)

이 결함들은 **plan Task 1 의 산출물 자체가 미완**임을 뜻한다. 사이클 내 정정은 판별식 재설계(정규식 → 구조 파싱)를
요구하는데, 이는 §20.2 가 지연 근거(후보 D = 276ms vs 134ms, 2.1배)로 **기각한 방향**이다. 즉 정정하려면
설계 판정(N2)을 다시 여는 것이며, 이는 goal 의 정지점 ②("N1~N4 를 뒤집는 증거")에 해당한다.

→ **사용자 판단 대기.** 자동 진행 금지.
