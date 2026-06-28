# Design — 글로벌 하네스 트랙: cwd-drift 앵커 + worktree/동시세션 fitness 배선

> Spec for the global-Claude harness track (`~/.claude` repo, separate from second_brain_project).
> 출처: 프로젝트 세션 `/goal` "Goal B — 글로벌 하네스 트랙" (non-obvious.md §4 메타-root: 프로젝트 RPI 사이클이
> 구조적으로 owner 못 되는 글로벌 하네스 결함 3건을 별도 ~/.claude 트랙에 dispatch).
> Created: 2026-06-28

## 문제 (3 항목, non-obvious.md 출처)

1. **① cwd-drift (:152, 재발3·★High Priority·blocked-on-global-track)** — `enforce-rpi-cycle.sh`·
   `_common.sh has_active_plan`이 plan/spec 디렉터리를 `$CWD/docs/superpowers/{plans,specs}`로 **cwd-상대
   단일레벨** 접합. 서브디렉터리 cwd(워크플로/서브에이전트가 `app/frontend`로 cd, 또는 메인세션 cd-잔류)에서
   루트의 active plan을 false-negative 차단. 우회가 글로벌 settings 부수변경을 유발(2차 표면).
   현 상태: `grep 'rev-parse --show-toplevel' _common.sh enforce-rpi-cycle.sh` = **0건**(미이행).

2. **② worktree-teardown (:211)** — closeout 'cd 메인루트' 지시가 cwd-키 SessionEnd teardown을 무력화하던
   문제. **현재 이미 해소됨**(cycle-40/41): `worktree-teardown.sh` GUARD1이 cwd OR `session_id`-키 마커
   fallback으로 동작(PreToolUse가 워크트리 절대경로 도달 시 마커 기록 → SessionEnd가 자기 SID 마커 소비).
   `worktree-teardown.test.sh`의 `Ta`(cd-out→마커 정리)·`Tb`(실신호 E2E)·`T1`(정션 node_modules 불변)이 실증.
   **잔여 갭**: `worktree-teardown.test.sh`가 `run-all.sh`/`verify-all.sh` 어디에도 **미배선(고아)** →
   fitness (3)(4)가 수용 게이트에서 실행되지 않음.

3. **③ 동시세션 격리 (:93)** — 병렬 Claude 세션이 단일 Playwright chrome 프로필·dev 포트(:8000/:5173)·
   프로세스를 공유 → 상호 차단·상호 kill 위험. Action: 동시 세션은 상대 프로세스 kill 금지(상호 파괴 방지).
   현재 `worktree-teardown.sh` STEP A는 이미 워크트리-경로 스코프 kill(타세션 무영향)이나, **격리 규약이
   ~/.claude 문서/가드로 미인코딩**.

## 비목표 (YAGNI)

- worktree-teardown.sh 훅 로직 재작성(이미 cwd-독립 — 무편집).
- 동시세션 kill을 차단하는 hook 가드(차단 대상 tool-콜 모호 + worktree-teardown 자기 kill·정당 kill 오살 위험 →
  문서 규약으로 한정).
- enforce-rpi-bash.sh 직접 편집(공유헬퍼 has_active_plan 경유 transitively 수정).
- 프로젝트 repo 접촉(읽기 연구만; 변경 0).

## 설계

### 항목 ① — cwd-drift 앵커 (핵심 구현)

**신규 `_common.sh::resolve_project_root <cwd>`** — 단일 앵커 SSOT:
```
1) git -C <cwd> rev-parse --show-toplevel  (워크트리 루트 = git 루트; plans 가 거기 위치)
2) (1) 실패 또는 git-루트에 plans 부재 시: cwd→상위로 docs/superpowers/plans 를 만날 때까지 탐색 (git top 까지 bound)
3) 둘 다 실패: 원래 cwd 반환 (회귀 0 — 기존 cwd-상대 동작 보존)
```
- Windows 경로: `normalize_path`로 백슬래시→슬래시 후 처리. git은 슬래시 출력.
- 상위탐색은 git top에서 멈춰 repo 밖($HOME 등)으로 안 나감(비-git이면 FS 루트까지, 미발견 시 cwd).

**`has_active_plan <cwd>`** — 첫 줄에서 `resolve_project_root` 호출해 root 산정 후 `$root/docs/superpowers/plans`
스캔. **계약 불변**(여전히 cwd 받음) → 4 호출자(enforce-rpi-cycle:95·enforce-rpi-bash:54·verify-loop-watch:28·
정의) 전부 무상처 + 서브디렉터리 cwd 수용 이득.

**`enforce-rpi-cycle.sh`** — `CWD` 해소 직후 `ROOT=$(resolve_project_root "$CWD")` 1회:
- spec-before-plan 게이트(L22): `$ROOT/docs/superpowers/specs`
- PLAN_DIR(L81): `$ROOT/docs/superpowers/plans`
- has_active_plan 호출(L95): `has_active_plan "$ROOT"` (idempotent)

**`enforce-rpi-bash.sh`** — 무편집(`has_active_plan "$CWD"`가 이제 robust).

**근거**: `rev-parse --show-toplevel` 리터럴은 SSOT인 `_common.sh::resolve_project_root` 한 곳에만 존재(DRY).
enforce-rpi-cycle은 `resolve_project_root` 호출로 그 앵커를 소비. fitness #31이 양쪽을 각각 단언(아래).

### 항목 ② — worktree-teardown.test.sh 배선

- 훅 무편집. `worktree-teardown.test.sh`(이미 `Ta`/`Tb`/`T1` 보유)를 **verify-all.sh STAGE 3b**로 배선.
- **플랫폼 가드**: 테스트는 powershell+정션(Windows 전용). STAGE 3b는 `command -v powershell` 시에만 실행,
  부재 시 skip-notice(비-Windows에서 false-RED 방지). Windows 운영본에서는 실측 실행.

### 항목 ③ — 동시세션 격리 규약

**SECURITY.md**에 "동시-세션 격리(concurrent-session isolation)" 절 추가(worktree-teardown 안전모델 인접):
- 동시 세션은 상대 세션의 chrome/uvicorn/vite/dev서버 프로세스 **kill 금지**(상호 파괴 위험).
- 잠금 충돌(Playwright 프로필·dev 포트) 시: 대기 또는 세션-고유 `--isolated`/ephemeral 프로필 + 세션별 포트.
- 안전 패턴 명시: worktree-teardown STEP A의 **경로-스코프 kill**(CommandLine이 *자기* 워크트리 경로 포함시만).
- CONTEXT.md 용어집에 "동시-세션 격리" 1항 추가(canonical 어휘).

### Fitness (verify-setup.sh #31~#34; §4 명세, fitness-first=현재 RED)

- **#31 (①, static)**: `_common.sh`에 `rev-parse --show-toplevel` ≥1 AND `enforce-rpi-cycle.sh`에
  `resolve_project_root` ≥1. 미이행 시 FAIL. (현재 0건 → 즉시 RED → 구현이 GREEN화.)
- **#32 (①, exec)**: 임시 git repo + 루트 `**Status:** active` plan. cwd=`$repo/app/frontend`에서
  (i) 코드파일 Edit → enforce-rpi-cycle **exit 0**, (ii) plan→completed flip → **exit 2**(과개방 방지),
  (iii) spec-dir 게이트: cwd=subdir서 루트 plans/에 plan Write + specs 부재 → **exit 2**, specs 추가 → **exit 0**.
  → plan-dir·spec-dir 양 게이트 서브디렉터리-cwd 회귀 가드.
- **#33 (②, static)**: `worktree-teardown.test.sh`가 verify-all.sh에 배선됨(grep) AND 핵심 단언 보유
  (`Ta` 마커 fallback stale 정리 + `T1` target(main) intact/junction NOT followed). 고아화·내용 회귀 봉인.
- **#34 (③, static)**: SECURITY.md에 동시-세션 격리 룰 실재(grep: 상대 프로세스 kill 금지 규약).

### verify-all.sh

- STAGE 3b 신설(STAGE 3 hook unit tests 직후): powershell-가드 `worktree-teardown.test.sh` 실행.

## 검증 (acceptance)

- `bash ~/.claude/setup/verify-all.sh` 전체 **ALL PASS** (STAGE 0~4 + 신규 3b, verify-setup #31~#34 포함).
- 구현 전 #31~#34 추가만 하면 RED(증명: fitness-first) → 구현 후 GREEN.
- ~/.claude repo 커밋(프로젝트 무접촉; `git -C ~/.claude status`로 프로젝트 경로 0 확인).

## Closeout 신호 (프로젝트 세션)

완료 시 프로젝트 세션에 전달: "글로벌트랙 완료 · 앵커 commit=<sha> · 검증=`grep -q 'rev-parse --show-toplevel'
_common.sh && grep -q resolve_project_root enforce-rpi-cycle.sh && bash setup/verify-all.sh`". 다음 프로젝트
closeout이 non-obvious.md ①cwd-drift/②worktree/③동시세션을 "fixed·앵커=~/.claude <sha>"로 갱신 +
blocked-on-global-track 해제 + 재발 카운터 동결.
