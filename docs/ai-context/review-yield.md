# review-yield.md — per-layer 리뷰 수율 축적 대장 (C16 spec §15.3)

> 사이클마다 Closeout `layer-yield:` 필드와 같은 행을 append. 소비처: 3사이클 축적 후 floor·리뷰 배분 재심.
> 실발견 = REAL 판정된 내용 결함(정정/수용잔여 처분 무관 — 판정이 기준). 토큰 수치는 가용 시 부기(필수는 발견 카운트).

## C15 (cycle 66, 2026-08-01 — 축적 1호, spec §15.0 실측)

- Gate R: PASS · 실발견 0건 · 확인 (71k)
- Gate P #1: FAIL→정정 · 실발견 3건 · 발견 (84k — 코드 전 차단)
- Gate P #2 재심: PASS · 실발견 0건 · 확인 (83k — 전체 재리뷰 낭비, C16-B의 근거)
- stage2 ×6: 5 PASS/1 FAIL · 실발견 0건 · 준수 확인 (273k — FAIL 1 = TDD RED 증거 강제)
- senior: PASS · 실발견 0건 · 확인 (80k, Minor 3)
- drift: PASS · 실발견 0건 · 확인 (47k)
- 교차패밀리(GPT, 말미): 실행 · 실발견 13건 · 발견 (REAL 13/15)
