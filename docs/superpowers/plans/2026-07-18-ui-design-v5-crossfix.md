# ui-design v5 — 교차패밀리 발견 정정 + 테스트 위생 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline — cold-agent 디스패치·Playwright 실측은 메인 세션 소관). Steps use checkbox (`- [ ]`) syntax.

**Status:** completed
**RPI-Cycle:** 60
**Started:** 2026-07-18
**Completed:** 2026-07-18

**Goal:** GPT-5.6 Sol 교차패밀리 리뷰가 적발한 design.md 결함 10건(X1~X10, spec §13)을 evidence 인용과 함께 정정하고, 테스트 위생 2건(H1·H2)을 마감하며, fitness L7(알림 인박스+삭제 모달, 제7 장르)로 재현성 불변식을 재실증한다.

**Architecture:** 재진입 사이클 — durable spec `docs/superpowers/specs/2026-07-12-ui-design-craft-upgrade-design.md` **§13**(v5 Delta)이 SSOT(수정 명세·심각도·근거 전수). design.md 편집=양 미러 동시(#43), H1/H2=seal-regression TDD, L7=spec §7 프로토콜(자족 격리·디자인 힌트 0).

**Tech Stack:** design.md 마크다운, bash(seal-regression), React+Vite+Tailwind(랩), Playwright MCP.

## Global Constraints
- §6 floor 18·§15 ceiling 9·기존 토큰명·§4 클래스명 불변 (X3 scrim=§1 기존 규정의 실체화=additive, X10=클래스 비접촉).
- 무증거 금지: 수정마다 `// evidence: F-XR-##` (FRICTION `## XR` 채록 선행).
- 검증 포그라운드: verify-setup FAIL 0·seal-regression 전수·run-all 전수·opencode 오라클.
- 동시세션: 다른 글로벌 세션이 capability 등재 병행 — 클로즈아웃 직전 origin/master 재확인.
- MERGE_POLICY: wait.

## Best-Direction Check
- X1~X10 수정 방향은 spec §13에 개별 확정(트리아지 2패스 통과) — 서머리-수치-제거·레시피-우선·additive 실체화 계급의 재사용. 채택안 == 최선안. **DOWNGRADE-DECLARED: 없음**.
- H1 = 숫자 제거(화석화 원천 차단, v4 R1(a) 동형) / H2 = witness 완결. L7 = §7 프로토콜 그대로.

---

### Task 1: FRICTION `## XR` 채록 (F-XR-01~10)
- [x] **Step 1**: `_design-lab/FRICTION.md`에 `## XR` 섹션 + F-XR-01~10 (spec §13 명세 그대로, 기각 4건 제외). 확인: `grep -c "^### F-XR" FRICTION.md` = 10.

### Task 2: design.md v5 정정 (X1~X10) + 미러
- [x] **Step 1**: §0 GS-3/GS-4 (X1) · GS-2/§2 소개문 'Pretendard' (X2)
- [x] **Step 2**: §1 `--color-scrim` 3곳 실체화 + §4 Modal `bg-scrim/40`·flex-1 페어 (X3·X4)
- [x] **Step 3**: §4 Input `text-body-lg md:text-body-md`+주석 (X5) · Primary 버튼 py-3 주석 (X6)
- [x] **Step 4**: §9 산식 명시 + 60ms 하한 우선순위 (X7·X8) · §2 measure 근거 재서술 (X9)
- [x] **Step 5**: §8 Mobile List Item button 시맨틱 (X10)
- [x] **Step 6**: 불변 확인 — floor 18·ceiling 9·evidence 발생 수 39(29+10). 미러 byte-copy `cmp` IDENTICAL. 커밋.

### Task 3: H1·H2 seal-regression 위생 (TDD)
- [x] **Step 1**: H1 — :4-5 화석 주석 숫자 제거, SSOT 위임 서술로.
- [x] **Step 2**: H2 — RED(`grep witness` 라인에 explore-strict.md·settings.example.json 부재 확인) → witness 추가 → GREEN(seal-regression 전수 PASS + live witness stable). 커밋.

### Task 4: fitness L7 — 알림 인박스 + 삭제 확인 모달 (제7 장르)
**Files:** Create `_design-lab/lab/src/pages/L7.jsx`(cold agent), Modify `App.jsx`(/l7 라우트 — 메인), Create `_design-lab/FITNESS-L7.md`.
- [x] **Step 1**: cold agent 디스패치 — design.md만 제공, 기능 명세만(알림 목록 ≥8행 읽음/안읽음·필터 탭·삭제 확인 모달·빈 상태·하단 버튼), "신규 CSS는 L7.jsx 안 <style> 자족·외부 CSS 접근 금지" 명시, 디자인 힌트 0.
- [x] **Step 2**: /l7 라우트 배선 + 렌더 스모크(콘솔 코드 에러 0).
- [x] **Step 3**: Playwright 실측(§4.4) — 오버플로우(1440/768/390×light/dark, root+내부)=0 · CLS<0.02 · reduced-motion 동등 · focus-visible · 다크 무결. **X-정정 재현 확인**: 모달 오버레이가 scrim 토큰(하드코딩 neutral-900/40 아님)·모달 버튼 페어 동일 너비·인터랙티브 행 button 시맨틱·비인터랙티브 요소 방향 신호 0.
- [x] **Step 4**: review-strict 채점 — floor 18(FAIL 0)·ceiling 9·자족 격리(index.css 상속 0)·§9 stagger 산술(간격×(N−1) ≤300ms).
- [x] **Step 5**: 판정 ≤2 iter — FAIL이면 문서 결함 역추적(F-XR-<seq> 추가 채록→회귀 수정→fresh iter2). FITNESS-L7.md 기록. 커밋(design.md 회귀 시 diff 포함).

### Task 5: 검증 + spec §13 결과 기입 + 클로즈아웃
- [x] **Step 1**: verify-setup·seal-regression·run-all·opencode 오라클 포그라운드 전수 PASS.
- [x] **Step 2**: spec §13 말미에 실행 결과 2-3줄(L7 판정·검증 수치·커밋 해시) append. plan tick + Status→completed.
- [x] **Step 3**: closeout-pr-cycle — PR 생성 후 **사용자 승인 대기**(MERGE_POLICY wait). state.json은 클로즈아웃 직전 origin/master 실측 후 bump. 메모리 append.

## Self-Review
- Spec coverage: §13 X1~X10=T2, H1/H2=T3, L7=T4, 검증·기입=T5. ✓
- 선행 실행 정합: T1~T3은 spec §13 확정 직후 이미 수행됨(체크 표기) — 이 plan은 잔여 T4~T5의 carrier + 완료분의 사후 기록. RPI 게이트는 spec(§13)+plan(본 파일) 존재로 충족. ✓
- Placeholder 0 · 경로/라벨 일관(F-XR·L7.jsx·FITNESS-L7). ✓
