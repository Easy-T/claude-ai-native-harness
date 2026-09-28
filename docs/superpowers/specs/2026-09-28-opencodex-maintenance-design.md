# opencodex 유지보수 자동화 — Design Spec

**작성:** 2026-09-28 · **사이클:** RPI 75 (경량 RPI — 사용자 결정) · **상태:** 채택
**산출물 위치:** `~/.opencodex/maintenance/` (하네스 repo 밖 — 이 spec/plan 만 하네스에 기록)
**선행:** CCS 퇴역 + opencodex 상시가동(같은 날 Phase A) — 메모리 `project_opencodex_service.md` · `project_ccs_routing.md`
**개정 이력:**
- r2(2026-09-28): D7 을 사용자 결정 "갱신만 켜기"로 개정. 초판의 동시 갱신 우려는 오류였으므로 정정했다.
- r3(2026-09-28): Gate R+P FAIL 반영. D4 사후 검증 5조건(veto·실행 버전) · D6 자기 자손 제외·fail-closed · D7 `ocx config set/get` 경로 · D9 시간 예산 · D10 종료 정책 · §6 UAC 서술 정정 · §7 config 원복.
- r4(2026-09-28): 라이브 검증·델타 재심(2회) 반영. D6 R3 에 `--model` 직접 신호 추가 — Git Bash 에서 실행한 claude-ocx 는 MSYS exec 스텁이 남지 않아 조상 신호가 없음을 라이브로 실측했다. D10 변경 호출 출력을 파일로 전환(EPIPE 방지). D9 에 health 5초 가산(D1·D9 예산 약 29분으로 정정). §6 UAC 서술 보정, §6 에 R3 미탐 조건(Claude 계열 이름 프록시 모델 + Git Bash) 명시.

## 1. 목적 (사용자 의도, 원문)

> "자동부팅시 opencodex가 띄워지고 업데이트도 체크하고 로그인 증명도 리프레쉬해서 항상 유지되도록"

사용자 결정(2026-09-28 AskUserQuestion):
- 유지보수 자동화 = **이번 작업 직후 경량 RPI**
- 업데이트 정책 = **안전할 때만 자동 적용**. codex / `ocx claude` 세션이 없을 때만 stable 을 자동 적용한다.
  세션이 실행 중이면 **연기 + 알림**. preview 채널은 쓰지 않는다.
- 인증 = **tokenGuardian 갱신만 켜기**. warmup 은 끈다.

## 2. 현황 (2026-09-28 실측)

| 항목 | 현재 동작 | 공백 |
|---|---|---|
| 기동 | Task Scheduler `opencodex-proxy`(로그온·잠금해제·원격·콘솔 연결 트리거) → wscript → cmd 재기동 루프 → bun. 크래시 시 약 15초 안에 재기동 | 태스크 자체가 종료되면(`schtasks /end`, 재기동 루프 이탈) 다음 로그온까지 복구 주체 없음 |
| opencodex 업데이트 | 프록시가 20시간마다 **확인만** 하고 `version.json` 캐시만 갱신(stable 정규식) | **적용은 수동**(`ocx system update run --yes`) |
| Codex CLI 업데이트 | `ocx system codex-cli-update check` 는 Windows 에서 `windows_inspection_deferred` | opencodex 가 대신 감시하지 않음 → `npm outdated -g` 필요 |
| 인증 | 필요할 때 갱신(on-demand). `tokenGuardian` 선제 갱신은 기본 OFF(소스 주석이 ToS 탐지 표면 증가를 경고) | 인증 이상이 생겨도 **알림 없음** — 쓸 때가 돼서야 발견 |

opencodex 소스 실측(2.69.0, `src/update/job.ts`):
- `ocx system update run` 은 **트랜잭션 경로**다. 워커가 서비스를 멈추고, npm 으로 설치하고, `ocx service repair` 로 재등록한 뒤 포트 응답과 15초 안정성까지 확인한다.
- 진행 상태는 `~/.opencodex/update-job.json` 에 남는다(`running|restarting|succeeded|failed`).
- 재시작이 소유권 veto 로 거부되면 잡은 `succeeded` 이면서 `restarted:false` 로 끝난다(`job.ts:1982`). 이때 새 버전은 디스크에만 있고, 실행 중인 프록시는 구버전이다.
- **사용 중인 세션을 보호하는 장치는 없다.** 세션 보호는 이 설계가 제공해야 한다.

## 3. 결정

**D1 — 단일 스케줄 태스크 `opencodex-maintenance`.**
- 트리거: 로그온 후 5분 지연 + 매일 00:00 기점 **3시간 간격 반복**. `StartWhenAvailable` 이라 절전 중 놓친 실행은 복귀 시 1회 따라잡는다.
- 주체: 현재 사용자 · `InteractiveToken` · `LeastPrivilege`. 관리자 권한과 저장 암호가 필요 없다.
- 설정: `MultipleInstances=IgnoreNew` · **실행 제한 45분**(D9 예산 약 29분 + 여유) · 배터리 조건 없음.
- 숨김 실행: `wscript.exe` 런처(.vbs, 창 스타일 0)가 `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File` 을 호출한다. opencodex 서비스와 같은 방식이다.
- 기각한 대안:
  - `powershell -WindowStyle Hidden` 직결 — 3시간마다 콘솔이 번쩍인다.
  - S4U — 세션 0 에서 돌아 토스트를 띄울 수 없다.
  - `conhost --headless` — 비문서화 동작이다.

**D2 — 단계 순서:** ① 프록시 건강 → ② opencodex 업데이트 → ③ Codex CLI 업데이트 → ④ 인증 건강 → ⑤ tokenGuardian 설정 드리프트 로그 → ⑥ 로그 정리.
- 앞 단계가 실패하거나 예외를 던져도 뒤 단계는 **독립적으로 계속**한다.
- 단, ②와 ④는 프록시가 살아 있어야 실행한다.
- 한 번 실행에서 업데이트는 **최대 1건**만 적용한다. ②가 적용을 시도했으면(`updated`/`failed`) ③은 다음 주기로 미룬다.

**D3 — 프록시 복구는 `ocx service start` 하나로 한정한다.**
- `ocx start` 는 금지다. 호출한 프로세스 수명에 묶여 서비스 보호 밖에 놓인다(Phase A 함정 1).
- `ocx service repair` 도 자동으로 실행하지 않는다. 정의를 재등록할 때 UAC 가 뜰 수 있고, 호출자 PATH 를 래퍼에 굽는다(함정 2).
- 복구 후에도 `/healthz` 가 60초 안에 응답하지 않으면 알림을 보낸다(3시간마다 재알림). 알림에는 수동 명령을 적는다: `ocx service status` 로 확인한 뒤, 깨끗한 터미널에서 `ocx service repair`.

**D4 — opencodex 업데이트는 opencodex 자체 트랜잭션 경로에 위임한다.**
- **확인:** `ocx system update check --channel latest --json` 결과가 다음 조건을 모두 만족할 때만 후보로 삼는다.
  - `updateAvailable && canUpdate`
  - latest 와 current 가 모두 `^\d+\.\d+\.\d+$` 형식 — preview 사용자는 채널을 자동 전환하지 않는다.
  - `[version]latest > [version]current` — 다운그레이드는 하지 않는다.
- **적용:** 세션 가드(D6)를 통과하면 `ocx system update run --channel latest --restart on --yes --json` 을 실행한다.
  - 응답의 `job.id` 로 `update-job.json` 을 **파일로 폴링**한다. 재시작 중에는 API 가 내려가 있기 때문이다. id 가 다른 잡은 무시하고, 최대 15분까지 기다린다.
- **사후 검증 — 다섯 가지를 모두 요구한다.** 기대 버전은 잡 파일의 `latestVersion` 을 우선한다.
  1. 잡이 `restarted == true` 로 끝났다. veto 경로를 잡는다.
  2. `/healthz` 가 200 을 반환한다.
  3. **`/healthz` JSON 의 `version` 이 기대 버전과 같다.** 실행 중인 프록시가 실제로 새 버전인지 확인한다.
  4. `ocx --version` 이 기대 버전과 같다. 디스크의 CLI 버전이다.
  5. `ocx status --json` 에서 `startup.protection == "service"` 이고 `startup.serviceRunning` 이다.
- 하나라도 어긋나면 알림을 보낸다. 자동 복구는 하지 않는다(D3 과 같은 이유).
- 금지: 프록시가 실행 중일 때 원시 `npm i -g @bitkyc08/opencodex`. bun.exe 잠금으로 EPERM 잔재가 남는다(Phase A 함정 4).

**D5 — Codex CLI 업데이트는 npm 으로 한다.**
- **확인:** `npm outdated -g @openai/codex --json` 결과로 판정한다. npm 은 outdated 가 있으면 종료 코드 1 을 반환하는데, 이것은 정상이다.
  - 후보 조건: `current` 가 있고, 둘 다 stable 형식이고, `latest > current`.
  - 설치되지 않은 패키지는 설치하지 않는다. `{"error":…}` 응답은 `npm-error` 로 건너뛴다.
- **적용:** 세션 가드(D6, npm 잠금 범위)를 통과하면 **정확한 버전으로** `npm install -g @openai/codex@<latest>` 를 실행한다(`@latest` 재해석 경합 방지). 사후에 `codex --version` 이 목표 버전과 같아야 한다.
- opencodex 쪽에 Codex CLI 버전 핀이나 호환성 제약은 없다(소스 실측).

**D6 — 세션 가드(세션 보호).** 판정은 프로세스 테이블·TCP 테이블·파일 수정 시각만 읽는다. 관리 토큰은 필요 없다. ("가드"는 이 세션 가드만 가리키고, 토큰 갱신 기능은 항상 `tokenGuardian` 으로 부른다.)

| 규칙 | 판정 | 적용 대상 |
|---|---|---|
| R1 Codex CLI 세션 | `node.exe` 명령줄에 `\node_modules\@openai\codex\bin\codex.js` 포함, 또는 `codex.exe` 실행 경로나 명령줄에 `\node_modules\@openai\codex\` 포함 | 프록시 재시작 · npm 설치 |
| R2 기타 Codex 호스트 | R1 밖의 `codex.exe` 중 관리형 데몬 보조 프로세스(`--managed-daemon`, `daemon pid-update-loop`)가 **아닌** 것. IDE 확장 app-server 등이 해당한다. 경로와 명령줄을 모두 읽을 수 없는 `codex.exe` 도 여기에 넣는다(**fail-closed**). | 프록시 재시작 |
| R3 프록시 경유 Claude | `claude.exe`(또는 claude-code `node.exe`)가 다음 중 하나에 해당: ⓐ 자기 명령줄의 `--model` 값(`--model v`·`--model=v`·따옴표 값; 빈 값은 부재로 봄)이 Claude 계열이 **아님**. Claude 계열은 `claude`·`opus`·`sonnet`·`haiku`·`fable`·`mythos` 포함, 또는 `default`/`best`. ⓑ 조상 가운데 `\@bitkyc08\opencodex\` 또는 `claude-ocx` 명령줄이 있음. 조상은 6단까지 보고, 부모가 자식보다 늦게 생성됐으면 PID 재사용으로 보고 중단한다. | 프록시 재시작 |
| R4 진행 중 요청 | `127.0.0.1` 또는 `::1` 의 10100 포트로 ESTABLISHED 연결이 있음. 단, 프록시 리스너 PID 와 **이 스크립트 및 그 자손**이 가진 연결은 제외한다. | 프록시 재시작 |
| R5 최근 트래픽 | `~/.opencodex/usage.jsonl` 의 마지막 수정이 10분 이내(파일 내용은 읽지 않고 수정 시각만 본다) | 프록시 재시작 |

- 관리형 데몬(`~/.codex/packages/app-server-daemon/...`)은 **R1·R2 에서 제외**한다.
  - 상주할 수 있어서, 포함하면 업데이트가 영구히 연기된다.
  - npm 패키지 밖에서 실행되므로 설치 잠금도 없다.
  - 데몬이 실제로 쓰이는 중이면 R4·R5 가 잡는다.
- 가드에 걸리면 **연기**한다.
  - 알림은 **같은 대상 버전당 1회**만 보낸다(state.json).
  - 연기된 업데이트는 다음 주기(최대 3시간 뒤)에 다시 시도한다.
- R3 의 claude-ocx 경로는 실행 위치에 따라 모양이 다르다(2026-09-28 라이브 실측).
  - 비-cygwin 부모(cmd·PowerShell)에서 실행: bash(MSYS exec 스텁, 명령줄에 `claude-ocx`) → sh(npm `claude` shim) → `claude.exe`. 프록시 모델이 Claude 계열 이름이 아니면 ⓐ 가 먼저 잡고, Claude 계열 이름(`OCX_MODEL=claude-sonnet-5` 등)이면 ⓑ 가 잡는다.
  - Git Bash 에서 실행: exec 스텁이 **사라져** sh 의 부모가 스냅샷에 없다. 조상 신호가 없으므로 **프록시 모델이 Claude 계열 이름이 아닐 때만** ⓐ 가 잡는다(claude-ocx 는 항상 `--model <OCX_MODEL>` 로 exec 한다). Claude 계열 이름이면 미탐이다(§6).
  - 픽스처는 ⓐ 단독(무-스텁 체인)·ⓑ 단독(스텁 체인 + `--model` 없음/Claude 계열, `ocx claude` + `--model opus`)을 각각 고정하고, 라이브에서 1회 확인한다.

**D7 — 인증: 갱신만 하는 선제 갱신 + 모니터링·알림.** (r2 — 사용자 결정 "갱신만 켜기")
- **선제 갱신:** opencodex 공식 설정 경로 `ocx config set` 으로 두 키를 설정한다.
  - 이 경로는 뮤텍스와 검증을 거친다(`config-command.ts`). 원시 JSON 병합 쓰기는 lost-update 위험 때문에 기각했다.
  - 설정 키: `tokenGuardian` = `{"enabled":true}`, `providers.google-antigravity.refreshPolicy` = `proactive`.
  - `codexWarmupEnabled` 는 켜지 않는다. 합성 모델 요청이라 ToS 표면이 큰 쪽이다.
  - 수정 전에 `config.json.bak-guardian-20260928` 로 백업하고, 수정 후 `ocx config validate` 로 확인한다.
  - tokenGuardian 은 sweep 마다 config 를 다시 읽으므로 재시작이 필요 없다. 첫 sweep 은 기동 후 약 6시간 뒤다.
- **근거**(소스 실측 `src/oauth/token-guardian.ts`):
  - tokenGuardian 은 **Codex 메인 로그인(`~/.codex/auth.json`)을 갱신하지 않는다.** 메인에는 선택적 warmup 만 하고, 추가 풀 계정은 파일 락 + 세대 CAS 로 갱신한다.
  - 게다가 `openai` 의 refreshPolicy 는 lazy-only 로 해석되므로 Codex 섹션 자체가 돌지 않는다.
  - 따라서 Codex CLI 와의 동시 갱신 경합은 설계상 없다. 초판의 "같은 auth.json 을 두 주체가 갱신" 우려는 오류였다.
  - 현재 실제로 갱신되는 대상은 google-antigravity 1개다.
- Codex 메인 로그인 유지는 Codex CLI 가 맡는다(사용 시 약 8일 주기로 갱신). 아래 모니터링이 이를 보완한다.
- **모니터링:** `ocx status`(텍스트)의 `OAuth health:` 블록을 파싱한다.
  - 블록 줄은 들여쓰기 3칸, 항목 줄은 5칸 이상이다. 계정 ID 는 마스킹돼 있고 토큰은 없다(`cli/index.ts:1885-1889`, `status-oauth.ts` 실측).
  - **로그에는 파싱된 블록 줄만 남긴다.** 로그인 목록 줄(마스킹 이메일)은 남기지 않는다.
- **알림 대상:** `reauthentication required` · `refresh conflict` · `stale credentials` · `metadata mismatch` · 분류 불가(`warning`/`unknown`).
  - 같은 증상은 12시간마다 1회 재알림하고, 증상이 바뀌면 즉시 알린다.
  - `rate/quota limited until …`(cooldown)은 일시 상태라 로그만 남긴다.
- **드리프트 감지:** 매 실행마다 `ocx config get` 으로 두 키를 조회한다(비밀값 마스킹 경로). 설정이 풀렸으면 WARN 로그를 남긴다. 자동 재설정은 하지 않는다.

**D8 — 알림:** WinRT 토스트를 쓴다(Windows PowerShell 5.1, PowerShell AUMID — 등록 불필요). 토스트가 실패하면 `msg.exe` 로 폴백한다. 모든 알림은 로그에도 남긴다.

**D9 — 로그·상태·시간 예산:**
- 로그: `logs/maintenance-yyyyMMdd.log`(UTF-8). `maintenance-*.log` 중 30일이 넘은 것만 삭제한다.
- 상태: `state.json` 에 알림 스로틀 기록만 둔다. tmp 파일에 쓴 뒤 교체한다.
- 외부 호출은 모두 **타임아웃**으로 감싼다. 읽기 전용 호출은 System.Diagnostics.Process + 비동기 파이프 read 를 쓰고, 변경 호출은 D10 의 파일 출력을 쓴다. 중복 실행은 명명 뮤텍스(`Local\opencodex-maintenance`)로 막는다.
- 호출별 타임아웃(초): service start 90 · service status 60 · update check 60 · update run 120 · 잡 폴링 900 · `--version` 30 · status 90 · status --json 60 · config get 30×2 · npm outdated 120 · npm install 300 · codex --version 30 · `/healthz` HTTP 5(호출마다 — 응답 대기·본문 읽기 각각 상한).
- 최악 합계 추정:
  - opencodex 업데이트를 시도하는 실행: 복구 약 3.5분 + 업데이트 약 20.5분 + 인증 1.5분 + 드리프트 1분 + healthz 가산 최악 약 2.25분(25회×5초 + HealthInfo 10초) ≈ **약 29분**.
  - Codex 업데이트를 시도하는 실행: 약 15분.
  - 두 경우 모두 D1 실행 제한 45분 안에 든다.

**D10 — 안전 불변식:**
- 관리자 권한 없음.
- `ocx start` 없음. `ocx service repair` 자동 실행 없음.
- **프로세스 종료:** 타임아웃 난 **읽기 전용 호출**만 자기 자식 트리를 `taskkill /T` 로 종료한다. 프록시는 Task Scheduler 소유라 이 트리 밖에 있다.
  - 변경 호출(service start · update run · npm install)은 설치가 깨지지 않도록 종료하지 않는다. 대기만 포기하고 기록한다.
  - 변경 호출의 출력은 파이프가 아니라 **자식이 소유하는 임시 파일**로 받는다(`Start-Process -RedirectStandardOutput/-RedirectStandardError`). 대기를 포기한 뒤 이 스크립트가 끝나도 자식이 닫힌 파이프에 쓰다 EPIPE 로 중단(=설치 반쪽)되지 않게 하기 위해서다. 타임아웃이면 파일을 남기고 경로를 로그에 적는다.
  - 이 밖의 어떤 프로세스도 종료하지 않는다.
- **읽기 허용 목록**(이 목록 밖의 `~/.opencodex`·`~/.codex` 파일은 읽지 않는다):
  - `update-job.json` 내용
  - `usage.jsonl` 수정 시각
  - 자체 `state.json`·로그
  - `/healthz` 응답
  - `ocx` CLI 출력: config 는 `ocx config get` 의 두 키만. status 는 파싱한 OAuth 블록만 로그에 남긴다.
- opencodex config 는 D7 의 두 키 외에는 수정하지 않는다. agents 와 `~/.codex` 설정도 수정하지 않는다.
- preview 채널 없음.
- `-DryRun` 지원: 적용·복구·알림·state 쓰기·로그 삭제를 하지 않고 판정만 로그에 남긴다.

## 4. 검증 전략

1. **단위 테스트** `tests/maintenance.tests.ps1`: 스크립트를 dot-source 한 뒤(메인 미실행) 순수 함수와 흐름을 검증한다. 외부 호출 함수는 테스트가 재정의한다.
   - 대상: 버전 형식·다운그레이드 · 업데이트 check JSON · npm outdated JSON(오류·미설치 포함) · OAuth health 분류 · 세션 가드 R1~R5(PID 재사용·자기 자손·fail-closed·claude-ocx 두 체인 모양·`--model` 양성/음성 포함) · 알림 스로틀 · 복구 흐름 · 업데이트 흐름(적용·연기·재알림 억제·사후 검증 5조건 각각의 부정 케이스) · 실제 프로세스로 타임아웃 트리 종료 · 변경 호출의 파일 출력과 미종료 · `-Mutating` → 미종료 매핑 · 단계 독립 · 1회 1업데이트 예산 · 뮤텍스(별도 프로세스가 보유) · 드리프트 감지.
   - **판별력 확인:** 핵심 분기를 의도적으로 망가뜨리는 변이 테스트에서 테스트가 실패해야 한다(변이 사멸).
2. **정적 검사:** PowerShell 파서 오류 0. 파일은 UTF-8 **BOM** 으로 저장한다. 5.1 은 BOM 없는 UTF-8 한글을 ANSI 로 오독한다.
3. **라이브 `-DryRun`:** 실행 시점의 프로세스 스냅샷과 가드 판정이 **일치**하는지 확인한다. 기대값을 미리 고정하지 않는다(세션 유무는 시점마다 다르다).
4. **태스크 문맥 실행:** 등록 → `Start-ScheduledTask` → 다음을 확인한다.
   - `LastTaskResult=0` 이고 로그가 생성된다.
   - **창 없음:** 태스크가 띄운 powershell 의 `MainWindowHandle=0`.
   - 토스트 경로는 `-TestNotify` 로 1회 확인한다.
   - claude-ocx 실경로의 R3 판정도 라이브로 1회 확인한다.
   - 변경 호출의 파일 출력 경로가 숨김 런처 아래에서 창을 띄우지 않는지 1회 확인한다.

## 5. 비범위

`codexWarmupEnabled`(합성 요청) · Rule C3/ocx-* 래퍼(별도 RPI) · statusline 5h/7d 재배선 · CCS 파일 삭제 · opencodex 서비스 정의 변경 · 드리프트 자동 재설정.

## 6. 잔여 위험 (수용)

- **VBScript 퇴역 로드맵:** opencodex 서비스도 같은 의존을 가지므로 함께 대응한다.
- **업데이트 중 UAC 창:** 업데이트 워커의 `service repair` 가 정의 재등록 경로로 가면 UAC 창이 뜰 수 있다. 이는 opencodex 자체 동작이다.
  - 거부하면 워커가 직접 기동으로 폴백한다. 이때 서비스 등록은 남아 있어서 `protection` 은 `service` 로 남는다(`autostart-health.ts:80`). 이 경로를 잡는 것은 **`serviceRunning=false`**(D4 ⑤)다. 폴백 기동이 성공하면 잡은 `restarted=true` 로 끝나므로 D4 ① 은 이 경로를 잡지 못한다.
- **유휴 상태로 열린 경유 세션의 오탐·미탐:** R3 는 명령줄 휴리스틱이다. 미탐이면 약 1분의 재시작 창이 생기는데, Claude/Codex 가 재시도로 흡수하는 범위다.
  - **미탐 조건(ⓐ·ⓑ 모두 실패):** Git Bash 에서 `OCX_MODEL` 을 Claude 계열 이름의 프록시 모델로 지정해 claude-ocx 를 띄운 세션. opencodex 는 이런 이름의 모델도 제공한다(`cursor/catalog.ts:143` 의 `claude-sonnet-5` 등). 요청이 진행 중이면 R4, 최근 10분 안에 트래픽이 있었으면 R5 가 잡으므로, 남는 것은 **유휴 상태로 열려 있는** 그런 세션뿐이다. 이 경우 약 1분의 재시작 창을 재시도로 흡수한다.
  - 오탐 방향(업데이트 연기일 뿐)도 있다. 예를 들어 Claude 계열 이름이 들어가지 않은 사용자 지정 모델 ID(클라우드 추론 프로필 ARN 등)로 띄운 네이티브 세션은 ⓐ 에 걸린다. 연기 알림은 버전당 1회다.
  - 권한 상승(관리자) 세션은 명령줄을 읽을 수 없어 R3 가 놓친다(fail-open). `codex.exe` 만 fail-closed 로 처리한다. `node.exe`/`claude.exe` 까지 fail-closed 로 하면 무관한 권한 상승 프로세스 때문에 업데이트가 영구 연기된다.
- **상주 Codex 호스트:** Codex 데스크톱 앱(`Codex.exe`, 이름 비교는 대소문자 무시)이나 IDE 확장이 상주하면 R2 가 계속 연기한다. 연기 알림은 버전당 1회만 가므로 사용자가 인지할 수 있다. 현재 이 머신에는 설치돼 있지 않다.
- **알림 억제:** 집중 모드에서는 토스트가 알림 센터에만 쌓인다. 로그는 항상 남는다.

## 7. 롤백

1. 태스크 제거: `powershell -File ~/.opencodex/maintenance/install-task.ps1 -Uninstall`(또는 `Unregister-ScheduledTask -TaskName opencodex-maintenance -Confirm:$false`).
2. **tokenGuardian 원복**, 둘 중 하나:
   - `ocx config unset tokenGuardian` + `ocx config unset providers.google-antigravity.refreshPolicy`
   - `~/.opencodex/config.json.bak-guardian-20260928` 복원(백업 이후 다른 설정 변경이 없을 때만)
3. `~/.opencodex/maintenance/` 삭제.

Codex(`~/.codex`) 설정과 opencodex 서비스 정의는 건드리지 않으므로, 그 밖의 원복 대상은 없다.
