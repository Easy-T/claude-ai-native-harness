# GAP — 비-Claude 세션에서 모델-정책 5규칙 전면 침묵 (C21 최우선)

> **발견 경위**: C21 Orca 모드 재설계 조사가 부수적으로 적발. 메인이 실제 transcript 로 독립 재현 확정
> (2026-08-13). 브리지(`bin/claude-ocx`)를 C20 에서 **git 추적 자산으로 승격**시켰으므로, 이 공백은
> 앞으로 넓어지는 방향이다 — 그래서 관측이 아니라 **정정 대상**이다.

## 무엇이 깨졌나

`hooks/surface-model-policy.sh` 는 세션 모델을 transcript 의 assistant 라인에서 뽑는데,
그 정규식이 **`claude-` 접두만** 매치한다:

```bash
# :30-35  session_model_of()
match($0, /"model":[[:space:]]*"claude-[a-z0-9.-]+"/)
```

못 뽑으면 값이 비고, 두 진입점이 **전체 조기 종료**한다:

| 위치 | 코드 | 죽는 범위 |
|---|---|---|
| `:169` | `[ -n "$SESSION_MODEL" ] \|\| exit 0` | Agent 경로 **전체** — Rule A · Rule B |
| `:54` | `[ -n "$WF_SESSION_MODEL" ] \|\| exit 0` | Workflow 경로 **전체** — Rule C · C2 · C3 |

즉 비-Claude 세션에서는 **5규칙이 모두 침묵**한다. 티어 판정이 불가능한 축(`inherit`)뿐 아니라
**리터럴 선언조차 검사되지 않는다** — `review-strict, model:"haiku"` 같이 세션 티어와 무관하게
판정 가능한 위반도 통과한다.

## 실측 (메인 독립 재현, 2026-08-13)

실제 transcript 2개에 `session_model_of` 를 그대로 적용:

```
GPT  세션 (projects/C--Users-12132-orca-workspaces-orca-lab-impl-parse/3a8731e6-….jsonl)
  → []                ← 빈 값 → :169/:54 에서 exit 0
CLA  세션 (projects/C--Users-12132--claude/….jsonl)
  → [claude-opus-5]   ← 정상
```

그 GPT transcript 의 assistant 라인 model 값 분포:

```
$ grep -o '"model":"[^"]*"' 3a8731e6-….jsonl | sort | uniq -c
     22 "model":"gpt-5.6-sol"
```

## 가설적 위험이 아니다 — 이미 실행됐다

Orca 워크스페이스 세션 중 GPT 모델 라인을 보유한 transcript (실측):

```
 2  …orca-lab-impl-parse/036e8282-….jsonl
22  …orca-lab-impl-parse/3a8731e6-….jsonl
 4  …orca-lab-impl-parse/6af8730e-….jsonl
 1  …orca-lab-impl-parse/f50aaaf2-….jsonl
11  …orca-lab-lab-gpt3/13eb0a8a-….jsonl
```

다섯 세션이 이미 그 상태로 돌았다. 그 동안 모델-정책 L2 는 **전혀 관측하지 않았다**.

## 왜 놓쳤나 — C20 §19.3 의 사각과 다른 축

C20 이 판정한 「프로세스-경계 정책 공백」은 **"CLI `--model` 스폰은 `Agent|Workflow` 매처의 관측
범위 밖"** 이었다(§19.3). 그건 **매처 축**의 사각이다.

이 GAP 은 다른 축이다 — 매처는 통과해 훅이 **실행되는데**, 세션 모델 판별이 실패해서 규칙이
발화하지 못한다. 즉:

| 축 | 사각 | C20 판정 |
|---|---|---|
| 매처 축 | 워커 기동 argv (`claude --model X`) | §19.3 에서 식별 → L3 오라클로 대체 |
| **세션 판별 축** | **비-Claude 세션 전체** | **미식별** ← 본 GAP |

C20 이 브리지를 자산화하면서 비-Claude 세션을 *정규 경로로 승격*시켰는데, L2 가 그 경로를
관측하지 못한다는 점은 검토되지 않았다. **자산 승격과 검사 표면 확장이 동기화되지 않은 클래스**다.

## C21 처분 (제안 — 판단은 사이클 진입 시)

**F1 — 정규식을 패밀리-중립으로.** `"model":"…"` 를 그대로 뽑고, 티어 판정은 `tier_of` 에 맡긴다.
`tier_of` 는 이미 미지 모델에 `0`(미지 티어)을 반환하므로 하류 계약은 그대로다.

**F2 — 조기 종료를 축별로 분리.** 세션 티어가 *필요한* arm(`inherit` 평가, Rule A 의 fable 세션
분기)만 skip 하고, **리터럴 축은 계속 검사**한다. 현행은 하나가 불가능하면 전부를 포기한다 —
C15 X6("계약에 값 추가 시 과분류 방향이 반전")과 동형의 설계 결함이다.

**F3 — seal 동반.** GPT transcript 픽스처로 RED→GREEN. 모집단 실재(위 5세션)라 vacuous 아님.

**주의 — 이 GAP 은 "미지 티어 = 면제"의 재발이 아니다.** 미지 티어를 면제로 *계수*하는 것은
3값 계약의 정상 동작이다. 여기서 깨진 것은 **계수조차 하지 않고 조용히 전량 skip** 한다는 점이다.
"면제는 안전 증명이 아니라 판정-불가의 정직한 표기"(§19.3)라는 규범이 이 경로에서만 미적용이다.

## 상한 (정직 부기)

- 본 기록의 재현은 **transcript 를 입력으로 한 함수 단위 실측**이다. 훅 전체를 실 stdin shape 로
  E2E 재현하지는 않았다 — 합성 stdin 시도는 `trap 'exit 0' ERR EXIT`(fail-open 불변식)와
  「1세션 1회」 마커에 흡수돼 CONTROL 조차 침묵했다. **E2E 재현은 C21 의 RED 단계 과제**이며,
  그때 실 shape 를 써야 한다(non-obvious #1 "합성-cwd 테스트 마스킹"의 동형 교훈).
- 훅 로그에 `surface-model-policy` ALERT 는 1,593 건 존재하나, 그 각각이 어느 세션 패밀리에서
  났는지는 로그에 없다. "GPT 세션에서 0건"은 **직접 확인되지 않았다** — 위 함수 단위 실측과
  코드 경로로부터의 연역이다.
