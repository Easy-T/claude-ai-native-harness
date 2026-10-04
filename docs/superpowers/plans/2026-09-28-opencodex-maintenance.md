# opencodex 유지보수 자동화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** completed
**RPI-Cycle:** 75
**Started:** 2026-09-28

**Goal:** 숨김 스케줄 태스크 `opencodex-maintenance` 하나로 네 가지를 자동화하고, opencodex `tokenGuardian` 을 "갱신만"으로 켠다.
- 실행 시점: 3시간 주기 + 로그온 후 5분
- 자동화 대상: 프록시 복구 · 안전할 때만 stable 자동 업데이트(opencodex·Codex CLI) · 인증 점검/알림 · 로그 정리

**Architecture:**
- 구성: PowerShell 5.1 단일 스크립트(순수 판정 함수 + 외부 호출 경계 + 단계 오케스트레이션)를 VBS 런처가 창 없이 실행한다. dot-source 하면 메인은 실행되지 않는다.
- 업데이트 적용은 opencodex 자체 트랜잭션 잡(`ocx system update run`)과 npm 에 위임한다.
- 이 스크립트가 책임지는 것은 두 가지다: **언제 적용해도 안전한지**(세션 가드 R1~R5), **적용 후 정말 새 버전으로 복귀했는지**(사후 검증 5조건).

**Tech Stack:** Windows PowerShell 5.1 · WScript(VBS) · Task Scheduler XML · Node(opencodex `ocx.mjs`·npm `npm-cli.js` 직접 호출) · WinRT 토스트

**Spec:** `docs/superpowers/specs/2026-09-28-opencodex-maintenance-design.md` (r4 — D1~D10)

**Best-Direction Check:** 최선안 = 채택안 = 아래 7요소 조합. **DOWNGRADE-DECLARED: 없음.**
- 채택안 7요소:
  1. opencodex 자체 트랜잭션 업데이트 경로 재사용
  2. 세션 가드
  3. 사후 검증(실행 중 버전·veto 포함)
  4. opencodex 공식 config 경로(`ocx config set/get`)
  5. 스로틀 알림
  6. 단위 테스트 + 변이 테스트로 판정 로직 고정
  7. 숨김 실행
- 기각한 더 쉬운 대안:
  - (기각 1) 원시 `npm i -g @bitkyc08/opencodex` — 실행 중 bun 잠금으로 EPERM(Phase A 실측).
  - (기각 2) `codex.exe` 존재만으로 가드 — 상주 관리형 데몬 때문에 영구 연기.
  - ⓒ 테스트 없이 라이브 1회 확인 — 가드 분기 대부분이 현재 머신 상태로 재현되지 않는다.
  - ⓓ `-WindowStyle Hidden` 직결 — 콘솔이 번쩍인다.
  - ⓔ config.json 원시 병합 쓰기 — lost-update 위험. Gate R+P 지적으로 ⓔ 가 한때 plan 에 있었으나 구현에서 공식 경로로 대체했다.

## Global Constraints

- 설치 위치는 `C:\Users\12132\.opencodex\maintenance\` 로, 하네스 repo 밖이다. 하네스에는 이 plan 과 spec 만 기록한다.
- 관리자 권한이 필요 없는 작업만 한다.
  - `ocx start` 금지.
  - `ocx service repair` 자동 실행 금지.
  - 프로세스 종료는 타임아웃 난 읽기 전용 호출의 자기 자식 트리만 허용.
- **읽기 허용 목록**(spec D10):
  - `update-job.json` 내용
  - `usage.jsonl` 수정 시각
  - 자체 state·log
  - `/healthz`
  - `ocx` CLI 출력(config 는 `ocx config get` 두 키만)
  - 이 밖의 `~/.opencodex`·`~/.codex` 파일은 읽지 않는다. 특히 `auth.json`, `admin-api-token`, `runtime-port.json`, `claude-intercept/*`, `*.salt`, `~/.codex/*` 가 해당한다.
- stable 전용: 버전 정규식 `^\d+\.\d+\.\d+$`, 채널은 `latest` 고정, 다운그레이드 금지.
- `.ps1` 은 UTF-8 **BOM** 으로 저장한다. 모든 외부 호출에 타임아웃을 건다(spec D9 표). 한 번 실행에서 업데이트는 최대 1건.
- 태스크 이름은 `opencodex-maintenance`. 트리거는 로그온 +5분 지연 & 매일 00:00 기점 3시간 반복(`StartWhenAvailable`). 실행 제한 PT45M.

## Review Focus

1. **관리형 데몬만 떠 있는 유휴 상태.** 업데이트가 영구 연기되면 안 된다 → T5(a)·T6
2. **PID 재사용.** 평범한 `claude.exe` 가 R3 로 오탐되면 안 된다 → T5(e)
3. **업데이트 재시작 중 API 부재와 veto 경로.** 파일 폴링 + id 일치 + `restarted` + 실행 버전으로 대응한다 → T9
4. **같은 연기 알림 반복.** 버전당 1회만 보낸다 → T9·T11
5. **ANSI 색/CRLF 섞인 `ocx status` 출력.** 파서가 놓치면 안 된다 → T4

---

### Task 1: 단위 테스트 (RED)

**Files:** Create `C:\Users\12132\.opencodex\maintenance\tests\maintenance.tests.ps1`

**Interfaces (Task 2 가 구현 — 이름·시그니처 고정):**

순수 함수:
- `Test-StableVersion([string]) -> [bool]`
- `Test-VersionNewer([string]$Latest,[string]$Current) -> [bool]`
- `Get-OcxUpdateCandidate([string]$Json)`, `Get-NpmUpdateCandidate([string]$Json,[string]$Package)` → `{Available;Current;Latest;Reason}`
- `Get-OAuthHealth([string]) -> {State:'ok'|'alert'|'cooldown'|'absent'; Lines; Signature}`
- `Get-SessionGuard -Processes -Connections -ProxyPids -UsageLastWrite -Now -Scope 'proxy'|'codex-npm' -> {Busy;Reasons}`
  - 프로세스 필드: `ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine, CreationDate`
  - 연결 필드: `RemoteAddress, RemotePort, State, OwningProcess`
  - R1 의 "npm 경로"는 부분 문자열 `\node_modules\@openai\codex\` 로 판정한다. 명령줄이 `npm\\node_modules` 처럼 이중 백슬래시로 나오는 실측 대응이다.
- 알림 스로틀:
  - `Test-NotifyDue(State,Key,Signature,[timespan]Realert,Now)` — `Realert=Zero` 이면 같은 서명은 재알림하지 않는다.
  - `Set-NotifyMark`, `New-MaintenanceState`, `ConvertTo/From-MaintenanceStateJson`

단계 함수:
- `Invoke-ProxyRecovery -> healthy|recovered|failed|would-start`
- `Invoke-OcxUpdate([bool]$ProxyUp=$true) -> none|updated|deferred|failed|skipped`
- `Invoke-CodexUpdate -> 같은 enum`
- `Invoke-AuthCheck -> State`
- `Test-GuardianConfig -> ok|drift`
- `Invoke-LogPrune(Dir,Days,Now) -> [int]`
- `Invoke-Maintenance -> 종료코드`

외부 호출 경계(테스트가 재정의):
- `Invoke-Ocx/Invoke-Npm([string[]],[int],[switch]$Mutating)`, `Invoke-CodexCli`
- `Invoke-External(File,Args,TimeoutSec,[bool]KillOnTimeout)`
- `Test-ProxyHealth`, `Get-ProxyHealthInfo`, `Get-ProcessSnapshot`, `Get-ProxyConnections`, `Get-ProxyListenerPids`, `Get-UsageLastWrite`, `Read-UpdateJob`
- `Show-Toast`, `Wait-Seconds`

스크립트 상태: `$script:DryRun`, `$script:State`, `$script:LogDir`, `$script:StatePath`, `$script:MutexName`, `$script:Timeouts`

- [x] **Step 1: 테스트 작성.** T1~T17:
  - T1~T3 판정 함수. 다운그레이드·preview 현재 버전·미설치·npm 오류 포함.
  - T4 OAuth. ANSI·CRLF 포함.
  - T5 proxy 가드: a 유휴 · b R1 · c R2 · d/d2/d3 R3(`ocx claude` node 체인·bridge·bash 스텁→sh 체인) · d4 R3(Git Bash 실측 무-스텁 체인, `--model` 신호) · d5/d6 `--model=`·따옴표 값 · d7/d8 ⓑ 단독(claude-ocx 스텁 + `--model` 없음/Claude 계열, `ocx claude` + `--model opus`) · k `--model` 음성 10종(빈 값·default·best·Claude 별칭/ID·`claude` 토큰 단독 `claude-next`) · e PID 재사용 · f/g R4 · h R5 · i 자기 자손 · j fail-closed.
  - T6 npm 가드.
  - T7 스로틀. JSON 왕복 포함.
  - T8 복구.
  - T9 업데이트: 적용 · 연기 · 재알림 억제 · 없음 · 잡 실패 · 다른 id · 사후 검증 부정 5종(보호 해제 · 서비스 미실행 · healthz 실패 · veto · 실행 버전 구버전) · CLI 버전 불일치 · 프록시 다운 · DryRun.
  - T10 Codex 업데이트: 적용 · 연기 · 없음 · 버전 불일치.
  - T11 인증.
  - T12 로그 정리.
  - T13 실제 PING 프로세스로 타임아웃 → 트리 종료.
  - T13b 변경 호출: 실제 프로세스가 타임아웃 후에도 살아 있고, 출력이 자식 소유 파일로 끝까지 기록됨(EPIPE 방지).
  - T13c `Invoke-Ocx`·`Invoke-Npm` 의 `-Mutating` → KillOnTimeout=false 매핑(실제 함수 본문을 fake 경계로 호출).
  - T14 단계 독립.
  - T15 1회 1업데이트.
  - T16 별도 프로세스가 뮤텍스 보유.
  - T17 드리프트(`ocx config get` 사용).
- [x] **Step 2: RED 확인.** `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\maintenance.tests.ps1` → 스크립트 부재로 rc=1 이다. r3 추가분은 RED 8건(`PASS=117 FAIL=8`), r4 추가분은 RED 5건(`PASS=138 FAIL=5`: T5d4~d6·T13b 2건)으로 확인했다.

### Task 2: 유지보수 스크립트 (GREEN)

**Files:** Create `C:\Users\12132\.opencodex\maintenance\opencodex-maintenance.ps1` (UTF-8 BOM)

- [x] **Step 1: 구현.** Task 1 인터페이스 그대로 구현한다.
  - 외부 호출은 `node.exe` 로 `ocx.mjs`·`npm-cli.js`·`codex.js` 를 직접 실행한다(.cmd 인용 문제 회피).
  - 메인: 뮤텍스 → 복구 → opencodex 업데이트 → (1회 1업데이트 예산) Codex 업데이트 → 인증 → 드리프트 → 로그 정리 → state 저장 → 종료코드(실패 단계가 있으면 1).
  - 진입부: `if ($MyInvocation.InvocationName -ne '.') { exit (Invoke-Maintenance) }`
- [x] **Step 2: BOM + 파서 검사.** 3개 파일 모두 parse errors 0.
- [x] **Step 3: GREEN.** `RESULT PASS=150 FAIL=0`(r4, 델타 재심 2·3회차 정정 포함).
- [x] **Step 4: 변이 테스트(판별력).** 핵심 분기를 각각 무력화했을 때 테스트가 모두 실패해야 한다. 결과 **27/27 사멸**.
  - 1라운드(16): PID 재사용 · 데몬 제외 · 스로틀 · DryRun 적용 차단 · 다운그레이드 · 보호 · serviceRunning · healthz · R4 자기 · R5 · veto · 실행 버전 · 자기 자손 · 예산 · 뮤텍스명 · 트리 종료.
  - 2라운드(6, r4): R3 `--model` 분기 · Claude 계열 허용목록 · ocx/npm `-Mutating` 매핑 각 1 · 파일 출력 분기 · 빈 `--model` 처리. 빈 값 변이가 처음엔 생존해 테스트를 추가한 뒤 사멸.
  - 3라운드(3, 델타 재심 2회차 지적): ⓑ `claude-ocx` 조상 · ⓑ opencodex 조상 · `default/best` 별칭. 재심이 ⓐ 가 ⓑ 테스트를 가린다는 것을 변이로 재현해 지적했고, ⓑ 단독 픽스처를 추가해 사멸시켰다.
  - 4라운드(2, 델타 재심 3회차 비차단 관찰): `^best$` 별칭 단독 · 허용목록 `claude` 토큰 단독. 둘 다 처음엔 생존(음성 테스트 부재) → `best`·`claude-next` 음성 케이스 추가 후 사멸.

### Task 3: 런처·설치기·README + tokenGuardian + 라이브 검증

**Files:**
- Create `...\maintenance\run-hidden.vbs`
- Create `...\maintenance\install-task.ps1` (BOM, `-Uninstall`)
- Create `...\maintenance\README.md`
- Config: `ocx config set` 2키(원시 파일 쓰기 없음)

- [x] **Step 1: 런처·설치기 작성.** 설치기는 InteractiveToken · LeastPrivilege · IgnoreNew · PT45M · 트리거 2개.
- [x] **Step 1b: README 작성.** 동작 · 스케줄 · 가드 표 · 로그·상태 위치 · 수동 명령(DryRun/TestNotify/즉시 실행) · tokenGuardian 설정과 원복 · 제거 절차.
- [x] **Step 2: tokenGuardian 설정.**
  - 백업: `config.json.bak-guardian-20260928`.
  - 설정: `ocx config set tokenGuardian '{"enabled":true}'` · `ocx config set providers.google-antigravity.refreshPolicy proactive`.
  - 확인: `ocx config validate` = valid. 키 경로 diff 는 정확히 2개(`tokenGuardian.enabled`, `providers.google-antigravity.refreshPolicy`). `config.error=null`, `health.ok=true`.
- [x] **Step 3: 라이브 DryRun.** 내 셸에서 `-DryRun` 을 실행한다. 로그에서 다음을 확인한다: 복구 healthy · opencodex none(already_latest) · codex none · auth ok · guardian ok · 적용과 알림 없음. 이어서 **같은 시점의 가드 판정**(Codex CLI 세션 종료 후 — proxy/npm 모두 not busy)이 스냅샷과 일치하는지 확인한다.
- [x] **Step 4: 태스크 등록·실행.** 결과(2026-09-28 23:31): 트리거 = Logon(PT5M 지연) + Daily 00:00 반복 PT3H · Principal = 12132/Interactive/Limited. 실행 중 wscript·powershell 모두 `MainWindowHandle=0`. `LastTaskResult=0`. 로그 `run start (dry-run=False)` → 전 단계 정상 → `failed=[]`.
  - 등록: `install-task.ps1` 실행 → `Get-ScheduledTask` 로 트리거 2개와 Principal 을 확인한다.
  - 실행: `Start-ScheduledTask` 후, 실행 중에 **창 없음**(태스크가 띄운 powershell 의 `MainWindowHandle=0`)을 확인한다.
  - 완료 후: `LastTaskResult == 0` 이고, 당일 로그에 태스크 문맥 실행이 기록됐는지 확인한다.
- [x] **Step 5: 알림 경로.** 결과: 런처 경유 `-TestNotify` → exit 0, 로그 `toast ok`. 변경 호출의 파일 출력 경로도 숨김 런처 아래에서 창 없음(PING·conhost·powershell 모두 hwnd 0)을 확인했다. 런처로 `-TestNotify` 를 1회 실행한다(숨김 경로와 동일). 로그에 `toast ok` 가 있어야 한다. 실패했다면 msg 폴백이 기록돼야 한다.
- [x] **Step 6: R3 라이브.** 결과: 1차는 R4 만 발화하고 R3 는 **미탐**이었다. Git Bash 실행 시 MSYS exec 스텁이 사라지는 것을 실측했다(sh 의 부모가 스냅샷에 없음). r4 의 `--model` 신호를 추가한 뒤 재실행해 `R3 opencodex-routed Claude session (pid 27840, --model gpt-6-sol)` 을 확인했고, 종료 후 잔여 프로세스는 0이었다. 라이브 실행은 `MAX_THINKING_TOKENS=0` 으로 했다. opencodex 2.69.0 업스트림 버그 때문인데, thinking 을 켜면 `reasoning.summary='none'` 400 오류가 난다. 가드 판정과는 무관하다.
  - 실행: `bash ~/.claude/bin/claude-ocx -p` 를 짧은 프롬프트로 백그라운드 실행한다.
  - 판정: 실행 중 가드 판정에 R3 가 나타나는지 확인한다. 결과를 기록한다.
  - 정리: 완료 후 프로세스가 종료됐는지 확인한다.

### Task 4: Closeout

- [x] **Step 1: 델타 재심.** Gate R+P FAIL 항목(1·4·6·7·8·9, 수정 지시 8개)의 해소와 신규 파손 없음을 review-strict 로 확인한다. 범위는 편집한 파일과 절로 한정한다. — **완료: 3회**(1회 FAIL 테스트명 → 정정 · 2회 FAIL F1 예산 29분 전파/F2 ⓑ 판별력/F3 §6 미탐 방향 → 정정 · 3회 PASS, 비차단 관찰 6건 중 5건 반영[best·claude 토큰 음성 테스트 → 변이 27/27, 주석·spec 이력·healthz 산식]; ⓐ/ⓑ 기호 중복은 plan 기각안을 "(기각 N)" 으로 개칭해 해소).
- [x] **Step 2: Closeout 리뷰.** review-strict 로 다음을 확인한다: spec D1~D10 과 실물 대조 · 테스트 재실행 · 태스크 정의 재조회 · 읽기 허용 목록 준수 grep. — **1회 FAIL(기준 6 = plan 손상: JS `String.replace` 치환 문자열의 `$`+백틱 이 "매치 앞부분"으로 해석돼 134행 중복 삽입) → head/tail 무치환 재조립 → 델타 재심 1회 FAIL(README R4 주소 1종·임시 파일 위치) → 정정 → 델타 재심 2회 FAIL(README 읽기 목록에 로그 폴더 목록 누락) → 리뷰어 지정 문구로 정정, 코드 읽기 지점 전수(297·384-385·448·469·476·712행)와 메인이 대조해 확인.** 나머지 기준(D1~D10 실물·테스트 150/0·태스크 정의 LastTaskResult=0·읽기 허용 목록·kill 안전성) PASS.
- [x] **Step 3: 마감.** plan Status → completed. 메모리 `project_opencodex_service.md` 를 갱신한다.
