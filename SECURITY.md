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
- **한계**: 시그니처 기반 → 미지의 키 포맷·난독화된 시크릿·PII는 탐지 못 함. 1차 방어선일 뿐 완전하지 않다.

## `enforce-rpi-bash` 보수차단 / 잔여 (cycle-23)
- **보수차단**: `git apply`/`patch`는 쓰기 타깃이 패치 *내용*에 있어 명령행 추출 불가 → active plan 부재 시 명령 단위로 차단(read-only 변형 `--check`/`--stat`/`--numstat`/`--summary`는 통과). docs 전용 패치 오탐은 `RPI_SKIP`으로 우회.
- **여전히 미탐지**: 변수 파일명(`python -c` f-string 등), `./patch` 같은 상대경로 실행, 인터프리터 내부 쓰기. 시그니처 기반 1차 방어선의 의식된 상한.
- **검증 커버리지 수락 잔여 (cycle-23)**: ① verify-setup #23은 hook command *basename*만 비교 — matcher 정규식 drift 미감지(안정 앵커 확보 시 재평가) ② `state.schema.json`은 검증자 없는 참조 문서 ③ verify-all에서 doctor(변이)가 선행해 `.installed`·audit-marker를 측정 전 자가치유 — 치료-후-검증 순서로 의도 수락.

## 범위 밖 (의도적으로 하지 않는 것)
- 네트워크 egress 필터링, PII 스캐닝, SAST, 런타임 콘텐츠 모더레이션, 권한 모델 강제(bypassPermissions 유지).
- 단일 운영자 데스크톱 도구에는 과하다고 판단해 제외. 멀티유저/규제 환경으로 가면 재검토 필요.
