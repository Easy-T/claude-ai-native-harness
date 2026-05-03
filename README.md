# Claude AI-Native Harness

> 글로벌 `~/.claude/` 인프라 — Claude Code의 모든 세션에 **결정론적 사이클 강제**, **자동화된 프로젝트 부트스트랩**, **AI 실패 추적**을 적용합니다.

이 하네스를 설치하면 다음이 자동으로 작동합니다:

- "**기능 추가해줘**" → R(Research) → P(Plan) → I(Implement) → Closeout 사이클을 메인 세션이 강제로 따름
- "**새 프로젝트 셋업해줘**" → `/init-ai-ready <name>` 으로 12개 파일 + 5개 디렉터리가 결정론적으로 생성
- 코드 변경 전 active plan 부재 → hook이 차단 (≤5라인 trivial 변경은 자동 통과)
- 30일마다 글로벌 환경 self-audit, 컨텍스트 40% 도달 시 자동 `/compact` 알림

기반: Claude Code 2.1+, [superpowers](https://github.com/obra/superpowers), skill-creator

---

## 🎯 무엇을 얻는가

### 4개 진입점

| 진입점 | 발화 또는 명령 | 동작 |
|---|---|---|
| **`/init-ai-ready <name>`** | 슬래시 커맨드 | 빈 디렉터리에 AI-Ready 프로젝트 부트스트랩 (12 파일 + 디렉터리) |
| **start-rpi-cycle 자동 트리거** | "결제 모듈 추가해줘" / "버그 고쳐줘" / "리팩토링해줘" | RPI 사이클 강제 (R→P→I→Closeout) |
| **create-orchestrator-skill 자동 트리거** | "이거 자주 쓸 것 같아 skill로 만들어줘" | skill-creator + orchestrator 골격 자동 주입 |
| **doctor.sh** | `bash ~/.claude/setup/doctor.sh` | 19개 환경 진단·치료 (jq 자동 설치 등) |

### 5개 hook (활성)

| Hook | 모드 | 발동 시점 | 효과 |
|---|---|---|---|
| `enforce-orchestrator` | 차단 | Write/Edit on `*/skills/*/SKILL.md` | orchestrator 골격(Phase ≥3, Agent ≥1, Communication Protocol) 누락 시 차단 |
| `enforce-rpi-cycle` | 차단 | Write/Edit on 코드 파일 | active plan 없으면 차단. `*.md`, `*/.claude/*`, `*/docs/*`, `*/superpowers/*` 등은 화이트리스트 |
| `stable-claude-md` | 알림 | 루트 CLAUDE.md 수정 | "캐시 비용 ≈20배" 환기 (작업은 허용) |
| `auto-compact-watch` | 알림 | Read/Bash/Agent 후 | 컨텍스트 40% 초과 시 `/compact` 권장 (1세션 1회) |
| `session-start-audit` | 알림 | 세션 시작 | CLAUDE.md audit 마커 30일 초과 시 알림 |

크로스 플랫폼 path 정규화(Windows backslash → forward slash) 내장 — Linux/WSL/Windows 모두 동일하게 작동.

### 5개 orchestrator skill

| Skill | 트리거 키워드 | Phase 구조 |
|---|---|---|
| `init-ai-ready-project` | "새 프로젝트", "AI-ready", "프로젝트 초기화" | 0(Self-Audit) → 1(Discover) → 2(Generate) → 3(Verify) → 4(Closing) |
| `start-rpi-cycle` | "기능 추가", "이거 고쳐줘", "구현해줘", "리팩토링" | R(Research) → P(Plan) → I(Implement) → Closeout |
| `closeout-pr-cycle` | "PR 만들어줘", "merge 준비해줘", "작업 마무리해줘" | Preflight → 1(Local Gate) → 2(PR Gate) → 3(CI Gate) → 4(Senior Review) → 5(User Approval) → 6(Merge/Cleanup) |
| `create-orchestrator-skill` | "이거 skill로", "orchestrator", "<X> skill 만들어줘" | 1(Capture) → 2(skill-creator) → 3(Inject Skeleton) → 4(Verify) |
| `common-agent-contract` | (자동 주입) | wrapper agent 3종에 Input/Output 표준 주입 |

### 3개 wrapper sub-agent

| Sub-agent | 권한 | 역할 |
|---|---|---|
| `explore-strict` | 읽기 전용 (Read/Grep/Glob/WebFetch) | 코드베이스 탐색 + 발견 사항 요약 |
| `review-strict` | 읽기 전용 + read-only Bash | 명시 기준 PASS/FAIL 검증 |
| `execute-strict` | 쓰기 가능 (Read/Write/Edit/Bash) | scope 외 변경 거부, 명시 task만 수행 |

---

## ⚡ 빠른 설치 (4 단계)

### 사전 조건

| 항목 | 용도 |
|---|---|
| [Claude Code](https://claude.ai/code) 2.1+ | 런타임 — `claude` CLI 인증 (`claude /login` 또는 `ANTHROPIC_API_KEY` 환경변수) |
| Node.js v18+ | hook의 JSON 파싱 |
| bash, git | 인프라 운영 |
| 선택: gh CLI, jq | `doctor.sh`가 자동 설치 시도 |

**필수 플러그인** (하네스가 의존):

| 플러그인 | 출처 | 사용처 |
|---|---|---|
| `superpowers` | [obra/superpowers](https://github.com/obra/superpowers) (claude-plugins-official) | brainstorming / writing-plans / executing-plans / subagent-driven-development / finishing-a-development-branch — start-rpi-cycle skill이 메인 세션에서 호출 |
| `skill-creator` | claude-plugins-official | create-orchestrator-skill이 호출 |
| `claude-md-management` (선택) | claude-plugins-official | CLAUDE.md 점검 자동화 |

→ 미설치 시 RPI 사이클 일부가 작동하지 않습니다. 설치는 [STEP 4](#설치) 참조.

### 설치

```bash
# STEP 1. 기존 ~/.claude 백업 (있는 경우만)
[ -d ~/.claude ] && mv ~/.claude ~/.claude.pre-harness-$(date +%Y%m%d)

# STEP 2. 하네스 clone
git clone https://github.com/Easy-T/claude-ai-native-harness.git ~/.claude

# STEP 3. 설치 스크립트 실행 (chmod, settings.json 생성/병합, doctor 실행)
bash ~/.claude/setup/install.sh
```

```text
# STEP 4. Claude Code 세션 재시작 후, 채팅에서 의존 플러그인 설치:
/plugin install superpowers@claude-plugins-official
/plugin install skill-creator@claude-plugins-official
/plugin install claude-md-management@claude-plugins-official
```

(또는 `settings.json`의 `enabledPlugins` 키에 직접 추가하고 세션 재시작)

### 검증

```bash
bash ~/.claude/setup/verify-all.sh
```

기대 출력: `ALL PASS — system meets §6.6 acceptance gate.`

이 결과 + 4개 plugin 설치 완료면 **즉시 사용 가능**.

---

## 🚀 일상 사용 시나리오

### 시나리오 1 — 새 프로젝트 부트스트랩

```bash
mkdir -p ~/Documents/my-app && cd ~/Documents/my-app
```

Claude Code 채팅에서:
```
/init-ai-ready my-app
```

자동으로:
- Phase 0: doctor 환경 점검
- Phase 1: 디렉터리 충돌 + 스택 감지 (Next.js / Python / Rust 등)
- Phase 2: 12개 파일 결정론적 생성
  ```
  CLAUDE.md
  docs/ai-context/{architecture, runbook, deny-patterns, non-obvious, domain-glossary}.md
  .claude/{settings.json, state.json, hooks/pre-commit-deny.sh}
  .gitignore
  scripts/check.sh          ← 스택별 local quality gate
  .github/workflows/ci.yml  ← multi-stack GitHub Actions CI
  ```
- Phase 3: 무결성 검증
- Phase 4: "부트스트랩 완료" 안내

### 시나리오 2 — 기능 추가 (자동 RPI 사이클)

> ⚠️ **사전 조건**: `superpowers` 플러그인 설치 필수 (Phase R/P/I에서 호출).

채팅에 자연어로:
```
결제 모듈 추가해줘
```

start-rpi-cycle skill이 자동 발동:
1. **Phase R (Research)**: brainstorming + explore-strict — 요구사항·접근법·디자인 정리
2. **Phase P (Plan)**: writing-plans → `docs/superpowers/plans/YYYY-MM-DD-<topic>.md` 생성
3. **Phase I (Implement)**: subagent-driven-development 또는 executing-plans
4. **Phase Closeout**: (조건부) `closeout-pr-cycle` → Local Gate → PR → CI → senior review → 사용자 승인 → merge. 이후 review-strict drift 검사 + 자산 갱신 + state.json 업데이트

이 단계를 건너뛰고 바로 코드 쓰려고 하면 **enforce-rpi-cycle hook이 차단**:
```
[rpi] 차단: 활성 plan 없음 (docs/superpowers/plans/*.md).
  start-rpi-cycle을 사용해 R→P 단계를 먼저 완료하세요.
```

### 시나리오 3 — Trivial 변경 (≤5 라인)

```
typo 하나 고쳐줘 (s/recieve/receive/)
```

5라인 이하면 hook이 자동 통과 — RPI 사이클 강제 안 됨.

핫픽스 등 명시 우회:
```bash
RPI_SKIP="hotfix-prod-incident" claude
```

### 시나리오 4 — 커스텀 skill 생성

> ⚠️ **사전 조건**: `skill-creator` 플러그인 설치 필수.

```
docs를 자동으로 정리하는 skill 만들어줘
```

create-orchestrator-skill skill이 발동:
1. 의도 캡처 (목적, 트리거, 입출력)
2. skill-creator로 draft 생성
3. orchestrator 골격 자동 주입 (`orchestrator_skill: true`, Phase 마커, Agent 호출, Communication Protocol)
4. review-strict 검증 → 통과 시 파일 생성

이렇게 만든 skill도 enforce-orchestrator hook의 검증을 자동으로 통과.

### 시나리오 5 — PR Closeout (merge까지)

구현이 완료된 브랜치에서:
```
작업 마무리해줘
```
또는 `start-rpi-cycle` Phase Closeout에서 자동 발동 (remote + gh auth + non-main 브랜치 조건 충족 시).

`closeout-pr-cycle` skill이 발동:
1. **Phase 1 (Local Gate)**: `bash scripts/check.sh` 통과 확인 + uncommitted 없음 확인
2. **Phase 2 (PR Gate)**: push + `gh pr create` + PR body 검증
3. **Phase 3 (CI Gate)**: `gh pr checks --watch` — 실패 시 STOP
4. **Phase 4 (Senior Review)**: review-strict subagent — Critical/Important/Minor/Suggestions 분류
5. **Phase 5 (User Approval Gate)**: 사용자 명시 승인 없이는 **절대** Phase 6 진행 안 함
6. **Phase 6 (Merge/Cleanup)**: `gh pr merge --squash --delete-branch` + 로컬 정리

> AI는 merge를 결정하지 않는다. 사용자가 "1" 또는 명시 승인을 해야만 merge 실행.

---

### 시나리오 6 — 환경 점검 (이상하다 싶을 때)

```bash
bash ~/.claude/setup/doctor.sh
```

19개 이상 항목 자동 진단:
- Claude Code / node / bash / git 버전
- gh CLI 인증 상태
- 인터넷 연결 / 디스크 공간
- audit 마커 갱신 / `.installed` / git 관리 여부 등

문제 자동 치료(예: jq 미설치 시 winget/choco/scoop/brew/apt로 자동 설치 시도) + 결과 보고.

---

## 📁 프로젝트 구조

```
~/.claude/
├── agents/                              3 wrapper sub-agents
│   ├── explore-strict.md                  Read-only 탐색
│   ├── review-strict.md                   Read-only 검증
│   └── execute-strict.md                  Scoped 변경
│
├── commands/
│   └── init-ai-ready.md                 슬래시 커맨드 entry point
│
├── docs/superpowers/
│   ├── specs/2026-05-01-*-design.md     상세 설계 (3000+ 줄)
│   └── plans/2026-05-01-*.md            13단계 빌드 plan
│
├── hooks/
│   ├── _common.sh                        json_get / hook_log / normalize_path
│   ├── enforce-orchestrator.sh           orchestrator 골격 검증
│   ├── enforce-rpi-cycle.sh              RPI 사이클 강제
│   ├── stable-claude-md.sh               캐시 무효화 알림
│   ├── auto-compact-watch.sh             40% 임계 알림
│   ├── session-start-audit.sh            30일 audit 알림
│   └── tests/
│       ├── cases.tsv                     65 case 데이터 (현재 28 구현)
│       └── run-all.sh                    단위 테스트 러너
│
├── setup/
│   ├── doctor.sh                         환경 진단·치료
│   ├── install.sh                        하네스 설치 스크립트
│   ├── verify-setup.sh                   §6.3 39개 file/structure 체크
│   ├── verify-integration.sh             §6.5 5개 E2E 시나리오
│   ├── verify-all.sh                     4 stage acceptance gate
│   └── tests/doctor.test.sh
│
├── skills/
│   ├── common-agent-contract/SKILL.md    Input/Output 표준 (자동 주입)
│   ├── init-ai-ready-project/            부트스트랩 orchestrator
│   │   ├── SKILL.md
│   │   ├── templates/                    12 .tpl 파일
│   │   └── references/                   placeholder-spec, stack-presets
│   ├── start-rpi-cycle/SKILL.md          RPI 사이클 orchestrator
│   ├── closeout-pr-cycle/SKILL.md        PR Closeout orchestrator
│   └── create-orchestrator-skill/SKILL.md
│
│
│ (생성된 프로젝트 내)
│   scripts/check.sh                      스택별 local quality gate
│   .github/workflows/ci.yml             multi-stack GitHub Actions CI
│
├── CLAUDE.md                             6 메타 룰 + 4 사용자 원칙
├── settings.json                         (개인 설정, .gitignore됨)
├── settings.example.json                 템플릿
├── README.md                             이 문서
└── .gitignore
```

전체 size ≈ 250 KB (인프라). 운영 중에는 `projects/`, `cache/`, `plugins/cache/` 등이 누적되지만 모두 `.gitignore` 처리.

---

## 🔧 트러블슈팅

### Hook이 발동 안 함

1. **Claude Code 세션 재시작** — hooks는 세션 시작 시 settings.json에서 로드
2. settings.json 검증:
   ```bash
   node -e 'const c = JSON.parse(require("fs").readFileSync(process.env.HOME+"/.claude/settings.json","utf8")); console.log("hooks:", JSON.stringify(c.hooks).length, "bytes")'
   ```
   "0 bytes" 출력 시 settings.example.json 참조해서 hooks 키 추가
3. 실행 권한:
   ```bash
   ls -l ~/.claude/hooks/*.sh
   # 모두 -rwxr-xr-x 또는 755 여야 함
   chmod +x ~/.claude/hooks/*.sh
   ```

### "차단: 활성 plan 없음" — 단순 작업인데 막힘

- **≤5라인이면 자동 통과** — Edit으로 5줄 이하만 변경하면 hook이 trivial로 분류
- **문서 변경**: `*.md`, `*.txt`, `*/docs/*`, `*/.claude/*`, `*/.github/*`, `*/superpowers/*` 자동 화이트리스트
- **명시 우회 (1회성)**:
  ```bash
  export RPI_SKIP="hotfix-typo"
  ```

### settings.json 깨짐

doctor.sh가 git-managed면 자동 백업 안 만들지만, 수동 백업이 있을 수 있음:
```bash
ls ~/.claude/settings.json.backup-* 2>/dev/null
cp ~/.claude/settings.json.backup-YYYY-MM-DD ~/.claude/settings.json
```

또는 settings.example.json에서 재시작:
```bash
cp ~/.claude/settings.example.json ~/.claude/settings.json
# 그다음 env (ANTHROPIC_AUTH_TOKEN 등) 추가
```

### Hook 단위 테스트 실패

```bash
bash ~/.claude/hooks/tests/run-all.sh
```

Pass rate ≥ 95% 필요. 떨어지면:
- `hooks/.log/2026-MM.log` 확인 — 어느 hook의 어떤 verdict?
- Hook 본문 변경했나? (spec §4와 일치하는지 `diff`로 비교)

### 디스크 누적 (`.claude.backup-*` 다수)

doctor.sh가 git-managed 환경에선 백업 만들지 않지만, 과거 누적된 게 있으면:
```bash
# 최신 3개만 유지 (doctor가 자동으로 함)
ls -dt ~/.claude.backup-* | tail -n +4 | xargs -r rm -rf
```

### Cross-platform path 이슈

Windows에서 backslash path가 hook 화이트리스트를 못 통과하면:
- `_common.sh`에 `normalize_path` 함수가 있는지 확인
- 각 hook이 `FILE_PATH=$(normalize_path "$FILE_PATH")` 호출하는지 확인
- Path: 이미 적용됨 (commit `36a25fd`)

---

## 🎨 커스터마이징

### 글로벌 행동 규칙 변경

`~/.claude/CLAUDE.md` 편집:
- §1~§6 메타 룰 (캐시 안정성 / orchestrator / RPI / non-obvious / ADR / 도메인 용어)
- 사용자 원칙 4개 (Think Before Coding / Simplicity First / Surgical Changes / Goal-Driven Execution)

⚠️ 변경 시 prefix 캐시 무효화 → 다음 세션 1회 cache miss 비용 (≈20배). 한 번에 모아서 수정.

### Hook enforcement 조정

예: `enforce-rpi-cycle.sh`의 화이트리스트에 `*.yaml` 추가
```bash
case "$FILE_PATH" in
  *.md|*.txt|*.yaml|*.gitignore|...)
    exit 0 ;;
esac
```

변경 후 단위 테스트:
```bash
bash ~/.claude/hooks/tests/run-all.sh
```

### Trivial 임계 조정

`enforce-rpi-cycle.sh`의 5라인 임계:
```bash
(( TOTAL_LINES <= 5 )) && {
  hook_log "..." "trivial"; exit 0
}
```

10으로 올리려면 `5` → `10` 수정.

### 새 orchestrator skill 추가

```
"이거 자주 쓸 것 같아 skill로 만들어줘"
```
create-orchestrator-skill이 자동으로 골격 주입 + enforce-orchestrator hook 통과까지 검증.

---

## 📦 GitHub 배포 (네 fork 만들기)

### 1. 이 저장소를 너의 GitHub로

```bash
# 새 저장소 만든 뒤:
cd ~/.claude
git remote rename origin upstream  # 원본 보존
git remote add origin https://github.com/Easy-T/claude-ai-native-harness.git
git push -u origin master
```

### 2. 추적되지 않는 파일 점검

```bash
git status --short
# 정상 출력:
#  M plugins/installed_plugins.json   ← Claude Code 자동 관리
#  M plugins/known_marketplaces.json  ← Claude Code 자동 관리
```

`settings.json`, `hooks/.log/`, `projects/` 등 개인 데이터는 모두 `.gitignore` 처리됨.

### 3. README의 GitHub URL 교체

이 README의 `Easy-T` 부분을 너의 username으로 바꿔서 다시 commit:
```bash
sed -i.bak 's|Easy-T|YOUR_GITHUB_USERNAME|g' README.md
rm README.md.bak
git add README.md
git commit -m "docs: update GitHub URL in README"
git push
```

### 4. 다른 PC에서 설치 흐름 검증

위의 [⚡ 빠른 설치](#-빠른-설치-3-단계) 절차를 따라 새 환경에서 한 번 돌려보고 작동하면 끝.

---

## 📚 자세한 설계 / 빌드 과정

- 설계 명세: [`docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md`](docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md) (3,000+ 줄)
- 13단계 빌드 plan: [`docs/superpowers/plans/2026-05-01-ai-native-orchestration.md`](docs/superpowers/plans/2026-05-01-ai-native-orchestration.md)
- Hook 단위 테스트 65 case 명세: spec §6.2

---

## 🙏 Attribution

- **AI-Ready Codebase** (Fast Campus, 실별개발자, 2026.04) — 본 디자인의 핵심 사상
- **Claude Code** (Anthropic) — 하네스 런타임
- **superpowers** ([obra/superpowers](https://github.com/obra/superpowers)) — brainstorming / writing-plans / executing-plans / subagent-driven-development / finishing-a-development-branch
- **skill-creator** — 커스텀 skill 생성

---

## 📜 License

MIT (또는 너가 원하는 라이선스로 변경)

문제·제안: [Issues](https://github.com/Easy-T/claude-ai-native-harness/issues)
