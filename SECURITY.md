# Security Model — Claude AI-Native Harness

> 이 하네스의 위협 모델과 보안 자세. 2026-05-29 self-audit(Patch C) 기준.

## 신뢰 모델 (Trust Model)
- **단일 운영자(single trusted operator)** 가정. 멀티테넌트/공유 환경이 아님.
- 거버넌스는 tool 경계의 결정론적 hook으로 강제 (enforce-rpi-cycle / enforce-rpi-bash /
  enforce-orchestrator / enforce-secret-scan). 프롬프트(CLAUDE.md)는 권고일 뿐 — 강제력 없음.

## 의도된 트레이드오프 (의식적 선택)
- `permissions.defaultMode = "bypassPermissions"` + `skipDangerousModePermissionPrompt = true`:
  권한 프롬프트를 끔 → **모든 안전장치가 커스텀 hook에 집중됨.** 편의를 위한 의도적 선택이며,
  fetch한 web 콘텐츠·읽은 파일·MCP 결과에 섞인 프롬프트 인젝션이 Bash로 흘러갈 표면이 생긴다.
  - 완화: `enforce-secret-scan`(시크릿 유출 차단) + `enforce-rpi-bash`(셸 코드작성 게이트).
  - 잔여 위험(미완화): 임의 Bash 실행 자체는 막지 않음 — 신뢰 운영자 가정에 기댄다.
    더 강한 자세가 필요하면 `defaultMode`를 `default`/`acceptEdits`로 바꾸고 allowlist 운영할 것.
  - **배포 자세 분기**: 위 bypassPermissions 자세는 이 *운영본*(live `settings.json`)의 선택이다.
    배포 템플릿 `settings.example.json`은 `defaultMode: default`(프롬프트 ON)로 출하되고 install.sh가 이를 복사하므로 **신규 설치자는 default 자세로 시작**한다 — bypass는 의식적 전환.
  - **fail-open 신뢰베이스**: `require_node`(node 부재)·파서 런타임 실패 시 차단 hook은 통과(fail-open)한다 — `hooks/_common.sh` 무결성 + PATH상 `node` 존재가 전제. 침해 시 모든 경계가 침묵 무력화 — 단 (a) `enforce-rpi-bash` 파서 크래시는 FAILOPEN 로깅+stderr로 실시간 표면화하고, (b) 세션-시작 selfcheck는 node-missing·구문 오류에 더해 `hooks/lib/*.js` 런타임 스모크로 *손상 파서*까지 차기 세션에 표면화한다(cycle-32 rank6; `bash -n`이 못 잡는 런타임 고장 포착).

## audit 마커 (§3 staleness 게이트)
- `~/.claude/CLAUDE.md`의 `<!-- audit: YYYY-MM-DD -->`는 마지막 *실제* 점검 시점. session-start-audit이 30일 초과 시 알림(읽기 전용).
- **갱신은 human/audit 전용** (cycle-29): doctor.sh는 부재 시 부트스트랩만 하고 기존 마커는 *보존*한다 — doctor 실행이 신선도를 위조하면 게이트가 영구 무력화되고 CLAUDE.md 수정이 §1 캐시를 무효화하기 때문. 31일째 게이트가 발화하면 운영자가 실제 점검 후 마커를 수동 갱신하는 것이 정상 흐름.

## 자격증명 (Credentials)
- `~/.claude/.credentials.json` 는 Claude Code가 관리하는 OAuth 토큰 저장소(평문).
  - git-ignore 처리되어 커밋되지 않음.
  - POSIX: `chmod 600`(소유자 전용) 적용. Windows(NTFS): chmod는 사실상 no-op → ACL/EFS로 별도 보호 권장.
  - `doctor.sh`가 권한이 느슨하면(POSIX) 경고한다.
- 모델 트래픽은 로컬 CCS 프록시(`127.0.0.1:8317`) 경유. 이 프록시는 신뢰·가용성 단일 의존성이며
  하네스 범위 밖에서 관리된다(키는 `ccs-internal-managed` placeholder, 실제 키는 프록시가 보유).

## `enforce-secret-scan` 가드
- Write/Edit/NotebookEdit 콘텐츠와 Bash 명령에서 고-특이도 시크릿 패턴
  (Anthropic / AWS / GitHub / GitLab / Slack / Google 키, PEM private-key 블록)을 탐지하면 차단(exit 2).
- placeholder(`XXXX`/`REDACTED`/`EXAMPLE`/`your-key`/`DUMMY`/`FAKE`…)는 통과. 값은 절대 로그하지 않음(종류만 기록).
- 우회: `export SECRET_SCAN_SKIP="<이유>"`.
- **한계 (typo/accident 가드 — exfil control 아님)**: 시그니처 기반 → 미지 키 포맷·PII 미탐지.
  - **인코딩/분할 우회**: `base64`·hex·변수 분할 기입(`P1=sk-..; P2=..; echo $P1$P2`)은 전부 무력화 → 사실상 *우발적 평문 유출* 가드이지 적대적 exfil 차단이 아니다.
  - **콘텐츠 전용**: 파일을 *읽어* 네트워크로 내보내는 명령(`cat ~/.claude/.credentials.json | curl -d @-`)은 리터럴 키가 명령문에 없어 통과 — egress 필터링은 의도적 범위 밖(단일운영자 가정).
  - **인바운드 미검사**: `Read`/`WebFetch`/MCP로 *들어오는* 시크릿은 검사 안 함(PreToolUse 출력측 전용). 비대칭은 신뢰 운영자 가정에 기댄 수락 잔여.

## `enforce-rpi-bash` 보수차단 / 잔여 (cycle-23)
- **보수차단**: `git apply`/`patch`는 쓰기 타깃이 패치 *내용*에 있어 명령행 추출 불가 → active plan 부재 시 명령 단위로 차단(read-only 변형 `--check`/`--stat`/`--numstat`/`--summary`는 통과). docs 전용 패치 오탐은 `RPI_SKIP`으로 우회.
- **여전히 미탐지**: **변수/동적 파일명**(`python -c` f-string·변수 등), `./patch` 같은 상대경로 실행, 변수 파일명을 쓰는 인터프리터 내부 쓰기. (리터럴 파일명은 `python`/`node`/`perl`/`ruby` `-e`/`-c` 탐지 — cycle-25.) 시그니처 기반 1차 방어선의 의식된 상한.
- **검증 커버리지 수락 잔여 (cycle-23 → cycle-24 재평가)**: ① ~~verify-setup #23 basename-only~~ — **cycle-24 이행**: isHarness 한정 (phase|matcher|basename) 트리플 parity로 승격(matcher drift 감지 + 커스텀 hook 오탐 제거) ② `state.schema.json`은 검증자 없는 참조 문서(KEEP — 소비자 1·필드 2에 검증자 과잉) ③ verify-all에서 doctor(변이)가 선행해 `.installed`·audit-marker를 측정 전 자가치유 — 치료-후-검증 순서로 의도 수락(KEEP — doctor 설계 자체).

## `worktree-teardown` 안전 모델 (SessionEnd 데이터-삭제 hook)
- 하네스의 **유일한 데이터-삭제 hook**. 종료 세션의 워크트리(`<repo>/.claude/worktrees/<name>`)만 결정적으로 정리 — 단일 운영자 가정에 정합(자기 throwaway 워크트리 대상).
- **데이터손실 0 다중방어** (참조: 대상 repo `docs/ai-context/non-obvious.md` "2026-06-17 node_modules 정션" 데이터손실 사고):
  - **삭제 대상 1개 한정**: cwd가 `*/.claude/worktrees/<name>` 마커 안 + `git rev-parse --absolute-git-dir`가 `/worktrees/` 세그먼트 포함 + basename==NAME (= *링크된* 워크트리)일 때만. 메인 체크아웃·비-worktree 서브디렉터리는 `.../.git`로 해소 → **거부**. `/`·`$HOME`·빈·`.`/`..` 거부.
  - **정션 추종 차단**: `rm` 전 reparse point(정션/심링크)를 PowerShell 비재귀 `[IO.Directory]::Delete($false)`로 **링크-only 선제거** 후 **잔존 0 확인될 때만** `rm`. powershell 부재·잔존 시 `rm` 생략(잔존+ALERT) → 정션이 `rm`에 도달 불가.
  - **POSIX `rm -rf`만** · **`git worktree remove --force` 절대 미사용**(정션 추종 1차 범인).
  - **cd-out 정리(fallback) — 마커는 삭제권한 아님**: 세션이 워크트리 밖으로 cd해도(RPI closeout가 메인루트 이동) 정리되도록 SessionStart가 `session_id`-키 마커(`~/.claude/worktrees-marker/<sid>`=WT_ROOT)를 기록하고 SessionEnd가 *자기 SID* 마커만 소비. 소비 경로도 위 가드(linked-worktree `--absolute-git-dir` 증명 등)를 **동일 통과해야만** `rm`(마커 맹신 금지 — 스테일/위조 경로는 비-worktree로 해소→no-op). 빈/`unknown` SID는 마커 write·consume 모두 skip(동시 세션의 'unknown' 마커 공유 → 타 세션 *활성* 워크트리 오정리 방지).
  - **세션-지속 보호**: matcher가 `clear`/`resume`/`bypass_permissions_disabled` 제외(세션이 같은 cwd로 계속될 수 있어 활성 워크트리 삭제 위험) — `prompt_input_exit`/`logout`/`other`만. stdin에 `reason` 있으면 자가-게이트 추가.
- **실패 모드는 전부 "잔존"(악화 없음)**: crash 미발화·cwd 락·powershell 부재 → 삭제 안 함(오늘의 수동 상태와 동일). SessionEnd는 종료를 막을 수 없어 항상 exit 0·멱등.
- **검증**: `hooks/tests/worktree-teardown.test.sh`(격리 temp repo E2E)가 메인 target 무사·메인/비-worktree no-op·reason 게이트·멱등·dev서버 kill·**cd-out 마커 fallback 정리·빈 SID 마커 미사용**을 실측(13/13). SessionStart 마커 write/skip/prune 은 `hooks/tests/run-all.sh`(156-160). 설계기록: `docs/superpowers/specs/2026-06-21-worktree-teardown-sessionend-design.md`(§9 cd-out 개정, 2026-06-22).

## 동시-세션 격리 (concurrent-session isolation)
- 단일 운영자라도 **병렬 Claude 세션**은 ambient 싱글톤을 공유한다: Playwright MCP chrome user-data-dir,
  dev 포트(`:8000`/`:5173`), dev서버 프로세스(node/esbuild/vite/uvicorn/python). 대상 repo
  `docs/ai-context/non-obvious.md`("2026-06-16 Playwright 프로필 동시점유")가 상호 차단·상호 kill 위험을 기록.
- **규약(상호 파괴 방지)**: 동시 세션은 **상대 세션의 chrome/uvicorn/vite/dev서버 프로세스를 kill 금지**.
  잠금 충돌 시 (a) 대기, 또는 (b) 세션-고유 `--isolated`/ephemeral 프로필 + 세션별 포트로 회피.
- **안전 패턴 = 경로-스코프 kill**: `worktree-teardown.sh` STEP A는 프로세스 CommandLine이 *자기* 워크트리
  절대경로를 포함할 때만 kill(타세션·메인 무영향) — 광역 이름 매칭 kill 금지의 준거.
- 강제는 hook이 아닌 규약(차단 대상 tool-콜이 모호하고 정당 kill 오살 위험) — 단일 운영자 가정의 수락 상한.

## Rule-of-Two 세션 분리 + deny 최후방어선 (lethal trifecta 방어)
- **lethal trifecta**(02 §4): untrusted 입력(웹) + 시크릿/private 접근 + 쓰기/exfil 능력이 한 에이전트에 공존하면 프롬프트 인젝션이 탈취로 이어진다. "인젝션 조심" 프롬프트는 02 §4가 "영구 속성"으로 평가해 기각 — **구조 분리(도구 박탈)만 작동한다.**
- **Rule-of-Two (reader/doer 분리)**: untrusted-웹 읽기(외부 URL 페치·deep-research류)는 `explore-strict`(reader: `Read, Grep, Glob, WebFetch` — **쓰기도구 無**)에 위임 → 발견만 반환. **오케스트레이터가 검증한 뒤** privileged 행동은 `execute-strict`(writer: Write/Edit/Bash — untrusted 웹 페치 안 함)에 위임한다. untrusted-웹 능력과 쓰기 능력을 한 wrapper에 공존시키지 않는다. **강제**: `setup/verify-setup.sh` **seal #41**이 explore-strict의 쓰기도구 미부여를 봉인(누군가 Write 추가 시 FAIL).
- **deny 최후방어선**: `settings.json`(템플릿 `settings.example.json`) `permissions.deny`에 자격증명 read(`.credentials.json`·`.env`·SSH 키)·파괴 명령(`rm -rf ~|/`) 차단 규칙 — **`bypassPermissions` 하에서도 유효한 최후 층**(deny는 allow/bypass보다 우선한다; 아래 "범위 밖"의 권한-모델-미강제에 대한 *의식적 예외* = 최소 deny는 유지). **강제**: **seal #42**가 deny 규칙 존재를 봉인. 잔여(정직): 런타임 `bypassPermissions` 실차단 검증 = per-machine(라이브 `settings.json`은 gitignored); OS-레벨 sandbox(srt) = GAP-007 L5 별 사이클.
- 잔여(정직): 메인 오케스트레이터 세션은 전 도구 보유(구조상 불가피) — Rule-of-Two는 *위임 패턴* 권고, seal은 *wrapper*(explore-strict) 강제. 단일 운영자 가정의 수락 상한(동시-세션 격리 §과 동형).

## 범위 밖 (의도적으로 하지 않는 것)
- 네트워크 egress 필터링, PII 스캐닝, SAST, 런타임 콘텐츠 모더레이션, 권한 모델 *전면* 강제(bypassPermissions 유지 — **단 최소 deny 최후방어선은 의식적 예외**, Rule-of-Two § 참조).
- 단일 운영자 데스크톱 도구에는 과하다고 판단해 제외. 멀티유저/규제 환경으로 가면 재검토 필요.
