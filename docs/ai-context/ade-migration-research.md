# ADE 마이그레이션 리서치 — Orca + opencodex

> **목적**: Antigravity(IDE) + CCS cliproxy(멀티모델) → **Orca ADE** + **opencodex** 전환을 위한
> 실측·조사 기록. 나중 세션에서 재조사 없이 참조 가능하게 유지.
> **작성**: 2026-08-08 (브랜치 `master`)
> **상태**: 리서치 진행 중 — 확신도 라벨 필수(§0 규약)

---

## §0. 확신도 규약

| 라벨 | 의미 |
|---|---|
| `[실측]` | 이 머신에서 직접 실행/읽어서 확인 |
| `[문서]` | 공식 문서·소스 파일에서 확인 (URL 명기) |
| `[미확인]` | 문서에 없음 — 라이브 프로브 필요 |
| `[추정]` | 근거는 있으나 미검증 — **의사결정 근거로 쓰지 말 것** |

`[추정]`을 근거로 파괴적 작업(설정 덮어쓰기·CCS 제거)을 하지 않는다.

---

## §1. 용어 — 세 물건의 구분 (혼동 금지)

셋은 이름이 비슷하나 **완전히 다른 소프트웨어**다. 이 절은 SSOT다.

| 이름 | 패키지 / 배포 | 정체 | 이번 전환에서 |
|---|---|---|---|
| **Orca** | `stablyai/orca` (MIT), `orca-windows-setup.exe` | **ADE** — GUI. 여러 에이전트 CLI를 git worktree 격리로 병렬 실행 | **Antigravity 대체** |
| **opencodex** | npm `@bitkyc08/opencodex`, 명령 `ocx` | **로컬 라우팅 프록시** — 40+ 프로바이더를 단일 로컬 엔드포인트로 중계 | **CCS cliproxy 대체** |
| ~~opencode~~ | npm `opencode-ai`, 명령 `opencode` | 별개의 **에이전트 하네스** (CLI). Orca가 지원하는 워커 중 하나일 뿐 | **무관** — 이미 설치됨, 이번 건과 별개 |
| ~~codex~~ | npm `@openai/codex`, 명령 `codex` | OpenAI 공식 **에이전트 CLI**. opencodex의 *클라이언트* | 유지 (프록시 경유 대상) |

> **왜 헷갈리나**: `opencodex` ≠ `opencode` + `codex`의 합성어가 아니다.
> opencodex는 프록시(서버 쪽), opencode는 에이전트(클라이언트 쪽)다.
> 별도로 `ymichael/open-codex`(하이픈)라는 무관한 Codex CLI 포크도 존재 — 이것도 아니다.

---

## §2. 현재 환경 실측 (2026-08-08)

`[실측]` `command -v` + `npm ls -g --depth=0`:

```
@anthropic-ai/claude-code@2.1.226
@google/gemini-cli@0.39.1
@kaitranntt/ccs@8.7.0            ← 교체 대상
@openai/codex@0.145.0
opencode-ai@1.17.11
```

| 명령 | 경로 | 상태 |
|---|---|---|
| `opencode` | `/c/Users/12132/AppData/Roaming/npm/opencode` | 1.17.11 `[실측]` |
| `codex` | `/c/Users/12132/AppData/Roaming/npm/codex` | 0.145.0 `[실측]` |
| `node` | `/c/Program Files/nodejs/node` | `[실측]` |
| `bun` | `/c/Users/12132/.bun/bin/bun` | `[실측]` |
| `git` | `/mingw64/bin/git` (MSYS) | `[실측]` |
| `orca` | — | **미설치** `[실측]` |
| `ocx` | — | **미설치** `[실측]` |

`~/.ccs/` 존재 `[실측]` — `config.yaml`, `cliproxy/`, `proxy/`, 다수 `*.settings.json`
(routed / opus-direct / sonnet-direct / haiku-direct / claude / codex / gemini) + 백업 다수.

---

## §3. Orca ADE

### 3.1 설치 `[문서]`

> ⚠️⚠️ **`releases/latest`를 쓰지 말 것** (2026-08-10 실측):
> `api.github.com/repos/stablyai/orca/releases/latest` 가 **QA 프리릴리스**
> (`qa-pr13411-exact-head-58e91cb0d8-windows-wsl`)를 반환한다.
> `/releases/latest/download/...` URL도 같은 릴리스를 가리키므로 **테스트 빌드를 받게 된다.**
> → **버전을 명시한 URL**을 쓰거나 winget을 쓸 것.
> 안정판 판별: `releases?per_page=30` → `prerelease==false && tag ~ /^v\d+\.\d+\.\d+$/`

| 플랫폼 | 방법 |
|---|---|
| **Windows (winget, 권장)** | `winget install --id StablyAI.Orca --exact` |
| **Windows (직접)** | `https://github.com/stablyai/orca/releases/download/v<버전>/orca-windows-setup.exe` |
| macOS | `brew install --cask stablyai/orca/orca` |
| Arch | `yay -S stably-orca-bin` |
| Linux | `.../releases/latest/download/orca-linux.AppImage` |

- Windows 패키지 매니저(winget/scoop/choco) 경로: **문서에 없음** `[미확인]`
- 코드 서명: Windows 빌드 서명됨 `[문서]`
- 필수 선행 조건(Node/Bun/Git 최소 버전): **명시 없음** `[미확인]` — git worktree가 핵심이므로 git은 사실상 필수
- 설치 경로 / AppData 상태 경로: **문서에 없음** `[미확인]` — 설치 후 실측 필요

출처: `https://github.com/stablyai/orca` README, `https://www.onorca.dev/download`

### 3.2 Orca CLI `[문서]`

CLI는 **Settings → Experimental → CLI**에서 등록해야 활성화 `[문서]`.

```bash
orca status --json
orca worktree list | ps | current | show | create | set | rm
#   create 옵션: --agent --prompt --setup --parent-worktree --no-parent
orca terminal create --worktree active --title "tests" --command "npm test" --json
orca terminal list | read | send | wait | split
orca terminal send --terminal <handle> --text "continue" --enter --json
orca skills install            # 또는 npx skills add <repo> --skill <name>
orca emulator ...              # iOS Simulator
```

- `orca dispatch` / `--inject`: **CLI 레퍼런스에 없음** `[미확인]`
  → 모드팩 문서에는 등장하므로, orchestration(실험 기능) 활성화 시에만 노출되는 것으로 `[추정]`

출처: `https://www.onorca.dev/docs/cli/overview`, `/docs/cli/reference`

### 3.3 설정 파일 위치 `[미확인]`

- 공식 사이트가 리포지토리 루트 `orca.yaml`을 언급하나 **스키마 미공개**
- 사용자 레벨 설정 경로 미명시
- 모드팩만은 경로 확정: `~/.orca/<modeName>/` `[문서]`

### 3.4 지원 에이전트 `[문서]`

Claude Code, Codex, OpenCode, Grok, Gemini, Cursor, GitHub Copilot, Amp, OpenClaude,
Antigravity, Pi, oh-my-pi, Hermes, Devin, Goose, Auggie, Charm, Cline, Codebuff,
Command Code, Continue, Droid, Kilocode, Kimi, Kiro, Mistral Vibe, Qwen Code, Rovo Dev 외.
"터미널에서 도는 임의의 CLI 에이전트"와 호환 주장 `[문서]`.

### 3.5 ★ 에이전트 실행 계약 — **전환의 핵심**

> **`workers[].command` = "Full shell command for `orca terminal create --command`"** `[문서]`
>
> 그리고: **"모델은 dispatch가 아니라 worker command를 통해 공급된다"** `[문서]`

즉 **Orca는 워커를 임의 셸 명령으로 띄운다**. 따라서 opencodex 라우팅을 물리는 방법은
Orca 내부 설정이 아니라 **command 문자열 자체**다. 이건 좋은 소식이다 —
Orca가 env를 어떻게 다루는지 몰라도 command에 다 넣을 수 있다.

문서화된 command 형태 `[문서]`:

```bash
# Codex
codex -m gpt-5.6 -c model_reasoning_effort="xhigh"

# Claude
claude --model sonnet

# Gemini / OpenCode — 정확한 플래그 문서에 없음 [미확인]
```

`[미확인]` — Orca가 스폰 프로세스에 env를 주입/오버라이드하는지 (ANTHROPIC_BASE_URL 등),
에이전트 자체 설정(`~/.claude/settings.json`, `~/.codex/config.toml`)을 읽는지 우회하는지.
**→ 라이브 프로브 필요.** 프록시 라우팅 성패가 여기 걸림.

---

## §4. Orca 모드팩 (orca.teaboard.link) — 오케스트레이션 레이어

`https://orca.teaboard.link` 는 **모드팩 생성기**(서드파티 스튜디오). Orca 본체와 별개 레이어.

### 4.1 설치 `[문서]`

```bash
curl -fsSL https://orca.teaboard.link/setup-mode-pack.sh | bash
```

설치 스크립트 실제 내용 확인함 `[문서]` — 쓰는 경로:

```
~/.agents/skills/orca-mode-pack/SKILL.md
~/.agents/skills/orca-mode-pack/references/REQUEST.template.md
~/.agents/skills/orca-mode-pack/references/mode-pack.schema.json
~/.orca/studio/generate-pack.sh
~/.orca/jinjing/studio/generate-pack.sh     # 복제본
~/.orca/templates/{REQUEST.template.md,mode-pack.schema.json}
~/.orca/MODE-PACK-INSTALLED.md
```

`set -euo pipefail`, curl 다운로드만, 기존 설정 파일 변조 없음 `[문서]`.
`ORCA_SITE` / `ORCA_INSTALL_DIR` / `ORCA_TOOLS_DIR` env로 경로 재지정 가능.

> ⚠️ `curl | bash` — 스크립트 내용은 위와 같이 검토 완료. `~/.agents/`와 `~/.orca/`에만 쓴다.
> 단 원격 스크립트는 언제든 바뀔 수 있으므로 **실행 시점에 다시 받아 읽고 실행**할 것.

엔진 스킬 (PC당 1회) `[문서]`:
```bash
npx skills add https://github.com/stablyai/orca --skill orchestration
npx skills add https://github.com/stablyai/orca --skill orca-cli
```
그리고 **Orca → Experimental → Orchestration ON** `[문서]`.

### 4.2 ★ mode-pack.schema.json (전문) `[문서]`

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://reallygood83.github.io/orca/mode-pack.schema.json",
  "title": "OrcaModePack",
  "type": "object",
  "required": ["modeName","displayName","coordination","coordinator","workers","worktreePolicy"],
  "properties": {
    "modeName":    { "type":"string", "pattern":"^[a-z0-9]+(?:-[a-z0-9]+)*$",
                     "description":"Install dir name under $HOME/.orca/" },
    "displayName": { "type":"string", "minLength":1 },
    "triggers":    { "type":"array", "items":{"type":"string"}, "default":["orchestrate"] },
    "coordination":{ "type":"string", "enum":["supervised","handoff"], "default":"supervised" },
    "coordinator": { "type":"object", "required":["agent"], "properties":{
        "agent":  { "type":"string",
                    "enum":["grok","claude","codex","gemini","hermes","opencode","custom"] },
        "command":{ "type":"string", "description":"Optional; empty = current session" } } },
    "workers": { "type":"array", "minItems":1, "items":{
        "type":"object", "required":["role","agent","command"], "properties":{
          "role":     { "type":"string",
                        "enum":["implement","review","test","research","docs","custom"] },
          "agent":    { "type":"string" },
          "model":    { "type":"string" },
          "effort":   { "type":"string" },
          "command":  { "type":"string",
                        "description":"Full shell command for orca terminal create --command" },
          "ownership":{ "type":"string", "enum":["edit","review-only"], "default":"edit" } } } },
    "worktreePolicy":{ "type":"string", "enum":["active","isolated","auto"], "default":"auto" },
    "maxConcurrent": { "type":"integer", "minimum":1, "maximum":6, "default":3 },
    "waitTimeoutMs": { "type":"integer", "minimum":60000, "default":900000 },
    "finalSections": { "type":"string" },
    "projectRules":  { "type":"string" }
  }
}
```

**요점**:
- `coordinator.agent` enum에 `"custom"` 있음 / `workers[].agent`는 **자유 문자열**(enum 없음)
- `workers[].model`·`effort`는 **사람이 읽는 메타데이터일 뿐** — 실행은 `command` 문자열이 결정 `[문서]`
- `maxConcurrent` 최대 6
- `coordinator.command` 비우면 = 현재 세션이 코디네이터

### 4.3 생성기 `generate-pack.sh` `[문서]`

```bash
~/.orca/studio/generate-pack.sh \
  --out "$HOME/.orca/<name>" \
  --worker-cmd 'codex -m gpt-5.6 -c model_reasoning_effort="xhigh"' \
  --review-cmd '<claude 명령>' \
  --worker-entry 'role=implement|agent=codex|cmd=<command>' \
  --coord --display --max --wt --triggers --finals --coordination --wait-ms --project-rules
```

생성 산출물 (`$OUT` 아래) `[문서]`:
```
PLAYBOOK.md  README.md  meta.json  REQUEST.filled.md  SKILL.md
install-quickref.md  prompts/quick-command.txt  prompts/coordinator-start.md
```

프로젝트 오버레이(선택): `<repo>/.orca/<modeName>.md`, `.orca/PLAYBOOK.md`, `AGENTS.md` `[문서]`

첫 implement 워커의 command가 canonical로 승격되어 `orca terminal create --command`,
`meta.json.workerCmd`, PLAYBOOK/SKILL/프롬프트 전반에 박힘 `[문서]`.

### 4.4 supervised 디스패치 루프 `[문서]`

1. 코디네이터가 `~/.orca/<modeName>/PLAYBOOK.md` 읽음
2. 리포 오버레이 `.orca/<modeName>.md` 읽음
3. `coordination == supervised` 확인
4. `task-create`로 태스크 생성
5. `dispatch --inject`로 워커 기동
6. `check --wait`로 완료 감시
7. `meta.json`의 **정확한 command**로 각 워커 스폰
8. `maxConcurrent` 준수
9. 전 워커 `worker_done` 대기
10. `finalSections` 구성으로 최종 보고

워커는 각자 별도 터미널·핸들. 태스크 스펙에 `[implement/codex]` 식 역할 프리픽스가 붙음 `[문서]`.
`ownership: review-only` 워커는 플레이북이 명시 위임하지 않는 한 편집 권한 없음 `[문서]`.
`handoff`는 이 injection-and-wait 라이프사이클 없음 → `orca-cli` 스킬 사용 `[문서]`.

---

## §5. opencodex (`ocx`)

### 5.1 개요 `[문서]`

로컬에서 도는 **라우팅 프록시**. Codex / Claude Code가 단일 로컬 엔드포인트를 통해
40+ 프로바이더 모델을 쓰게 한다. 스트리밍·툴콜·reasoning·이미지를 보존하며 프로토콜 변환.

어댑터: Anthropic Messages / Google Gemini / Azure / OpenAI Responses / OpenAI-compatible Chat Completions.
프로바이더: Anthropic, Google, xAI, Kimi, OpenRouter, Azure, DeepSeek, GLM, Groq, Ollama Cloud 등 40+.

포크 여부 미명시 — 독립 커뮤니티 프로젝트로 소개 `[문서]`.

### 5.2 설치 `[문서]`

```bash
npm install -g @bitkyc08/opencodex
```

Node 최소 버전 **미명시** `[미확인]`.

### 5.3 알려진 서브커맨드 `[문서]`

```bash
ocx init      # Codex 설정에 프로바이더 추가
ocx stop      # 네이티브 Codex 동작으로 복원
ocx claude    # 동일 프록시를 통해 Claude Code 기동
```

전체 서브커맨드 목록 `[미확인]` — `ocx --help` 실측 필요.

### 5.4 ★ 미확인 — 전환 전 반드시 확인할 것

| 항목 | 왜 중요한가 |
|---|---|
| `ocx init`이 `~/.codex/config.toml`을 **변조**하는가? 무엇을 쓰는가 | 되돌리기 위해 백업 필요 |
| `ocx claude`가 `~/.claude/settings.json`을 건드리는가, 아니면 env(`ANTHROPIC_BASE_URL`)만 쓰는가 | **하네스 생사 문제** — §6 참조 |
| 프록시 리슨 포트 | CCS 프록시와 충돌 가능 |
| 라우팅된 모델의 이름 규칙 | 모드팩 `command`에 박아야 함 |
| CCS와 공존 가능한가 | 순차 전환 vs 동시 병행 |
| "sub-agent surface (v1/base/v2)" 의미 | Codex 서브에이전트 노출 제어 — 문서상 `base` 시작 권장 |

출처: `https://opencodex.me/`, `https://lidge-jun.github.io/opencodex/guides/sub-agent-surface/`

---

## §6. ★★ 최대 위험: `[1m]` suffix 계약

`[실측]`(과거 사이클, 메모리 `project_autocompact_proxy_display.md`):

`~/.claude/settings.json`의 모델 ID에 붙은 **`[1m]` suffix**가 1M 컨텍스트 창을 활성화한다.
이게 빠지면 창이 200K로 붕괴 → auto-compact **죽음의 나선**(세션당 첫 compact 후 ~100K마다 발화,
작업 진행 불가)이 재발한다. 그리고 `CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000`과
`PCT_OVERRIDE`는 **세트** — 한쪽만 있으면 완전 inert.

**따라서**:
1. opencodex로 라우팅을 넘기기 **전에** `~/.claude/settings.json`을 백업한다.
2. `ocx claude`가 settings를 다시 쓴다면 `[1m]` suffix와 WINDOW 라인이 **살아남는지** 확인한다.
3. 전환 후 `/context`로 **1M 표시를 눈으로 확인**한다. 200K면 즉시 롤백.
4. `[1m]`은 wire 전송 전 strip되므로 프록시 exact-match 라우팅은 안 깨진다 `[문서]`(공식 docs) —
   단 이건 CCS 기준 검증이었고 **opencodex에서 재검증 필요** `[미확인]`.

---

## §5.4. ★★★ 정정 — `[1m]`은 게이트웨이 때문에 필요하다 (2026-08-09)

> **선행 SSOT 발견**: `C:\Users\12132\Documents\claude_routing_project\`
> 현행 문서 = `model-picker-1m-autocompact-fix-2026-07-05.md` (+ Opus 슬롯은
> `opus5-slot-swap-2026-07-25.md`로 갱신). `settings.json`은 즉흥 파일이 아니라
> **정밀 조율된 골든 컨피그**다.

### 5.4.1 문서가 확립한 규칙

> **"게이트웨이 뒤에서는 Anthropic 1M 모델 ID가 등장하는 모든 자리에 `[1m]`을 붙인다."**
> 원인: *게이트웨이(`ANTHROPIC_BASE_URL`) 뒤에서 Claude Code가 1M 지원을 **검증하지 못해**
> bare ID는 **200K 예산**이 된다.* `[1m]`은 **전송 전 클라이언트에서 제거**되므로 라우팅 무관.

실측 근거 2건 (문서 §4, "지시서와 실측이 다름"):
- ① bare `claude-fable-5` → `contextWindow: 200000` 실측. 자동 정규화는 **게이트웨이 뒤에선 미작동**
- ② `ANTHROPIC_MODEL`(Default 슬롯)도 bare면 200K — 슬롯 4개를 다 고쳐도 이게 남음

### 5.4.2 ★ 이것이 뒤집는 것

`[1m]`의 인과가 이렇다:

```
ANTHROPIC_BASE_URL 있음(게이트웨이) → Claude Code가 1M 검증 불가 → bare=200K → [1m] 수동 부착 필요
ANTHROPIC_BASE_URL 없음(네이티브)   → Claude Code가 직접 검증      → 1M 자동 인식 → [1m] 불필요할 가능성
```

즉 **`[1m]`은 게이트웨이의 *증상*에 대한 대응책**이지, 그 자체가 목적이 아니다.
게이트웨이를 걷어내면(네이티브 복귀) `[1m]`이 **불필요해질 수 있다** — 단 **실측 필요**.

> ⚠️ **이전 판정 정정**: 본 문서 §6이 "`[1m]`이 빠지면 죽음의 나선 재발"이라 했으나,
> 정확히는 **"게이트웨이가 있는데 `[1m]`이 빠지면"** 이다. 네이티브 복귀 시에는
> `[1m]` 유지가 **무해**(전송 전 strip)하되 **필수는 아닐 수** 있다.
> → 전환 후 `/context`로 실측하여 확정할 것. 성급히 제거하지 말 것(무해하므로 유지가 안전).

### 5.4.3 슬롯 정책 (문서 §3 골든 컨피그, Opus는 07-25 갱신 반영)

| 슬롯 | 현행 값 | `[1m]` |
|---|---|---|
| `ANTHROPIC_MODEL` (Default) | `claude-sonnet-5[1m]` | ✅ 필수(§4-②) |
| OPUS | `claude-opus-5[1m]` | ✅ |
| FABLE | `claude-fable-5[1m]` | ✅ 필수(§4-①) |
| SONNET | `claude-sonnet-5[1m]` | ✅ |
| HAIKU | `gpt-5.6-luna` | ❌ **비-Anthropic엔 금지** |
| CUSTOM | `gpt-5.6-sol` | ❌ 동일 |

**규칙**: 비-Anthropic 모델에 `[1m]` 금지 (실창 < 1M이라 과대 예산 = 위험 방향).

### 5.4.4 CCS 실측 (`ccs doctor`, 2026-08-09)

```
CCS v8.7.0 · CLIProxy Plus v7.2.62-5 · config v20
프로파일 4: haiku-direct / opus-direct / routed / sonnet-direct
위임 5: opus-direct / routed / sonnet-direct / codex / claude
Claude Auth : Authenticated (2026-08-09)  ← ★ 오늘 갱신 = CCS가 토큰을 살려주고 있음
Codex  Auth : Authenticated (2026-08-08)
전체 판정   : Installation healthy (경고 1 = 포트 8317 자기 점유, 정상)
cliproxy.routing.strategy: fill-first
```

**보조 프로파일도 `[1m]`을 공유**한다 (`opus5-slot-swap` §2): `~/.ccs/routed.settings.json`,
`opus-direct.settings.json`, `claude.settings.json` 전부 `claude-opus-5[1m]` 정합.
→ **네이티브 전환 시 이들도 함께 고려**해야 한다(당장은 CCS 유지이므로 무변경).

---

## §5.5. ★★ 네이티브 패스스루 — "Claude 구독 미등록" 전략의 근거 (소스 실독)

> **사용자 계획**: "opencodex에 ChatGPT/Codex만 등록하고 **Claude 구독은 등록하지 않는다**.
> 그러면 claude-* 는 원래 구독 경로를 쓰고, opencodex는 GPT 모델만 추가해준다."
> → **소스·실측 양쪽에서 성립 확인.** 오히려 등록 *안 하는* 게 패스스루 조건을 만족시킨다.

### 5.5.1 설계 의도 (소스 주석 원문)

`src/server/claude-messages.ts:85-91` `[문서]`:

> *"When Claude Code runs with ONLY ANTHROPIC_BASE_URL set (subscription mode — the
> connectors warning stays off), it sends its OWN claude.ai OAuth Bearer to us.
> Requests for genuine claude/anthropic models that **no alias/modelMap claims** are
> forwarded **VERBATIM** to api.anthropic.com with the caller's credential and all
> end-to-end headers, so **betas/thinking signatures/billing identity stay native**."*

즉 이 시나리오는 우회가 아니라 **명시적으로 설계된 1급 동작**이다.

### 5.5.2 판정 조건 4개

`src/server/claude-messages.ts:106-112` `[문서]`:

```typescript
function wantsNativePassthrough(req, config, model): model is string {
  if (config.claudeCode?.nativePassthrough === false) return false;   // ① 기본 활성(default: enabled)
  if (!/^(claude|anthropic)/i.test(model))            return false;   // ② claude-*/anthropic-* 모델
  if (!hasAnthropicNativeCredential(req))             return false;   // ③ sk-ant- 크리덴셜
  return resolveInboundModel(model, config.claudeCode) === model;     // ④ alias/modelMap 미적용
}

function hasAnthropicNativeCredential(req: Request): boolean {        // :100-104
  const bearer = req.headers.get("authorization")?.replace(/^Bearer\s+/i,"").trim() ?? "";
  const apiKey = req.headers.get("x-api-key")?.trim() ?? "";
  return bearer.startsWith("sk-ant-") || apiKey.startsWith("sk-ant-");
}
```

**④가 핵심**: alias나 modelMap이 그 모델을 "주장"하면 라우팅으로 넘어간다.
→ **Anthropic을 프로바이더로 등록하지 않으면 alias가 안 생기므로 ④가 자동 충족.**
즉 "등록 안 함"이 패스스루를 *깨는* 게 아니라 *보장*한다.

전송 시 제거되는 헤더는 홉-바이-홉뿐 (`PASSTHROUGH_STRIP_HEADERS`: connection/keep-alive/
transfer-encoding/upgrade/te/trailer/proxy-*/host/content-length/accept-encoding/
x-opencodex-api-key/origin). 인증 헤더는 **그대로 전달**된다.

### 5.5.3 ★ 조건 ③ 실측 (2026-08-09) — 최대 미확인 해소

정찰이 "claude.ai OAuth 토큰은 `sk-ant-` 키가 **아닐 수 있고**, 그러면 패스스루가 발동 안 한다"를
최대 위험으로 지목했음. **직접 확인 결과:**

```
~/.claude/.credentials.json
  claudeAiOauth.accessToken:      len=108  prefix="sk-ant-o…"   ← ★ sk-ant- 접두사 확인
  claudeAiOauth.subscriptionType: "pro"
  claudeAiOauth.rateLimitTier:    "default_…"
```
(값 미출력 — 접두사 8자와 길이만 확인)

→ **조건 ③ 충족.** 이 머신의 claude.ai OAuth 토큰은 `sk-ant-`로 시작하므로
`hasAnthropicNativeCredential()`이 true를 반환한다. `[실측]`

### 5.5.4 판정

| 조건 | 상태 |
|---|---|
| ① nativePassthrough 기본 활성 | ✅ `types.ts:373` "Default: enabled" |
| ② claude-*/anthropic-* 모델 | ✅ opus/sonnet/fable 전부 해당 |
| ③ sk-ant- 크리덴셜 | ✅ **실측 확인** |
| ④ alias/modelMap 미적용 | ✅ **Anthropic 미등록 시 자동 충족** |

**→ 4조건 전부 충족. claude-* 는 프록시를 통과하되 손대지 않고 Anthropic으로 직행한다.**
빌링·thinking signature·프롬프트 캐싱·베타 헤더가 네이티브로 보존된다.

> ⚠️ 단 이는 **정적 분석 + 크리덴셜 형태 확인**이다. 실제 트래픽 검증은
> `ocx start` 후 `ocx observe`/로그로 패스스루 발동을 **확인해야** 최종 확정.

---

## §6.5. 진행 방침 (2026-08-08 확정)

사용자 결정:
- **Phase 1 = 프록시 교체만** (opencodex). 되돌리기 비용이 압도적으로 싸고, Orca 없이도 단독 이득.
- **Phase 2 = Orca 대비 감지기** — seal #23이 Orca 훅을 못 봄(isHarness 필터가 `.claude/hooks/*.sh`만 매칭).
  하네스 비-소유 훅 출현 시 ALERT 하는 seal 추가. Orca 안 깔아도 유용.
- **Phase 3 = Orca 보류** — Windows 버그 잦아들 때까지. 재평가 트리거는 §9.
- 인증 모드 = **구독(subscription)**, RPI = **경량**.

### ★ 착수 전 실측 확인 (2026-08-08 23:15, 전 항목 PASS)

| 항목 | 결과 |
|---|---|
| `settings.json` | 백업과 byte 동일 — 무변경 |
| `~/.codex/config.toml` | 백업과 byte 동일 — 무변경 |
| `~/.opencodex/` | 미생성 (`ocx init` 미실행) |
| `~/.claude/agents/ocx-*.md` | 없음 |
| CCS 8317 | 정상 가동 (PID 33600) |
| Orca | **완전 미설치** (명령·`%LOCALAPPDATA%\Programs\orca`·`%APPDATA%\orca` 전부 없음) |

변경된 것은 단 2건: npm 전역 `ocx` 실행파일 추가, 본 문서(untracked). **하네스 무영향.**

> ⚠️ 설치 방법 정정: `--ignore-scripts`는 **금지된 설치법**(번들 Bun 깨짐).
> 공식: `npm install -g @bitkyc08/opencodex` (실패 시 `--allow-scripts=bun`).
> 최초 시도가 bun postinstall EPERM로 실패 → `--ignore-scripts` 우회 → **정공법으로 재설치 완료**.

### ★ 백업 위치

`~/.claude/backups/ade-migration-20260808/`
— `claude-settings.json` · `codex-config.toml` · `codex-auth.json` · `ccs-config.yaml`
· `npm-global-before.txt` · `ports-before.txt`

**롤백 = 파일 1개 복사.** `cp backups/.../claude-settings.json ~/.claude/settings.json`

---

## §6.6. ★ C17 → C18 재확인 트리거 (미해결)

아래 to-be 설계는 **C17 매트릭스 v2 기준**으로 작성됨. C18 §17(fable 판단-전용화 4레버)이
착륙 중이므로 **C18 종료 후 반드시 재확인**할 것:

- [ ] "조율 = fable" 배치가 §17 판단-전용화 이후에도 유효한가
      (판단-전용이면 실행 지시 불가 → 오케스트레이터 역할과 충돌 가능)
- [ ] 검증자 floor `max(작업자, opus)`가 **별도 OS 프로세스** 워커에도 적용되는가
      (현 규칙은 in-process 서브에이전트 전제 — Rule A/B/C/C2/C3는 Agent/Workflow 도구 호출을 가로챔.
       Orca가 띄운 독립 `claude` 프로세스는 이 매처에 **안 걸림**)
- [ ] C18 plan 미체크 20건 중 프록시/프로세스 모델 변경에 영향받는 항목

> **이것이 Orca 도입의 진짜 거버넌스 비용**: 하네스 훅은 *프로세스 내부*를 지배하지만,
> Orca는 *프로세스 바깥*에서 스폰한다. 모델-정책 Rule A/B/C는 Orca 스폰을 못 본다.
> Orca를 쓰려면 command 문자열이 정책을 만족하는지 **별도 검증 계층**이 필요.

---

## §6.7. ★ Phase 1 병행 구축 실측 (2026-08-09)

### 6.7.1 두 프록시 병존 확인

```
8317   PID 33600  cli-proxy-api-plus.exe   ← CCS (현 세션 생명줄, 무손상)
10100  PID 25228  opencodex 2.11.0         ← 신규 {"status":"ok"}
```

`ocx start --port 10100` 실행 후 **`settings.json`·`~/.codex/config.toml` 둘 다 무변경 확인.**
→ 병행 방침 성립. CCS 제거 없이 신규 프록시 검증 가능.

> ⚠️ **함정**: `ocx start`는 데몬이 아니라 **포그라운드 서버**다.
> `timeout N ocx start`로 돌리면 N초 후 죽는다(최초 시도에서 실제 발생).
> `nohup ocx start --port 10100 &` 또는 `ocx service install`을 쓸 것.

### 6.7.2 프로바이더 현황

```
Configured:  openai (default)  adapter=openai-responses
             baseUrl=https://chatgpt.com/backend-api/codex
             authMode=forward          ← ★ 크리덴셜 미보유, 클라이언트 것 전달
Account:     openai / codex / main / plus   ← 기존 ~/.codex/auth.json 재사용(별도 로그인 불요)
Registry:    77개
```

사용자 3개 구독 대응:

| 구독 | 레지스트리 id | 방침 |
|---|---|---|
| **Codex/ChatGPT** | `openai` | ✅ **이미 연결됨** — 추가 작업 불요 |
| **Claude** | `anthropic` (oauth) | ❌ **의도적 미등록** — §5.5 네이티브 패스스루 유지 |
| **Antigravity** | `google-antigravity` (oauth) | ⏸ 등록 가능 — Antigravity IDE를 버려도 **구독은 살릴 수 있음** |

### 6.7.3 ★ GPT 모델 제공 동등성 — CCS 대비 우위

`GET http://127.0.0.1:10100/v1/models` (설정 무변경 상태) `[실측]`:

| 모델 | CCS 현행 | opencodex |
|---|---|---|
| `gpt-5.6-sol` | ✅ (custom 슬롯) | ✅ |
| `gpt-5.6-luna` | ✅ (haiku 슬롯) | ✅ |
| `gpt-5.6-terra` | ❌ 없음 | ✅ **신규** |

reasoning effort: `low / medium / high / xhigh / max / **ultra**`
→ `ultra`는 현행 CCS 구성에 없는 티어.

`ocx provider test openai` → `connected` / *"Forwards your Codex login; no upstream /models"* / 0 ms

**판정: GPT 기능 동등성 확보 + 초과 달성.** 대체 전제 조건 충족.

### 6.7.4 ★ Codex CLI E2E 검증 — PASS (2026-08-09)

**`ocx sync` 주입 결과** — `~/.codex/config.toml`에 **정확히 3줄 추가**, 기존 전부 보존 `[실측]`:

```diff
  approvals_reviewer = "user"
  model = "gpt-5.6-sol"
  model_reasoning_effort = "xhigh"
+ model_catalog_json = "C:\\Users\\12132\\.codex\\opencodex-catalog.json"
+ # Auto-injected by opencodex          ← 마커 펜스
+ openai_base_url = "http://127.0.0.1:10100/v1"
  [projects.'C:\Windows\System32']
  ...
```

`model_provider`는 **안 건드림**(루프백 바인딩이라 thread history 보존). 문서와 일치.

**E2E 실행**:
```
codex exec --skip-git-repo-check "Reply with exactly: OCX_E2E_OK"
→ model: gpt-5.6-sol · reasoning effort: xhigh · tokens 2,895
→ 응답: OCX_E2E_OK                                   ✅ PASS
```

> ℹ️ **무해한 로그 노이즈**: `ERROR ... failed to connect to websocket: HTTP error: 426 Upgrade Required`
> 원인 = opencodex 기본 `websockets: false` → 카탈로그에서 `supports_websockets` 제거
> (`src/codex/catalog/sync.ts:392-394`). codex CLI가 한 번 시도 후 **SSE로 폴백**해 정상 응답.
> 설계된 동작이며 결과에 영향 없음.

### 6.7.5 ★★ 롤백 경로 검증 — 무손실 확인 (가장 중요)

```
ocx restore   → "Codex config restored from opencodex journal."
diff          → ★ byte 동일 (완전 복원) ✅
ocx restore back → 재주입 정상 (동일 3줄)
```

**되돌리기가 실증됐다.** 이후 모든 단계는 이 복원 경로를 신뢰할 수 있다.

### 6.7.6 Antigravity 프로바이더 (등록 결정)

`src/providers/registry.ts:1290` `[문서]`:
```
id: google-antigravity · adapter: google · authKind: oauth
baseUrl: https://daily-cloudcode-pa.googleapis.com
defaultModel: gemini-3.6-flash · googleMode: cloud-code-assist
```

**★ Antigravity CLI 설치 불필요** — opencodex가 자체 OAuth 구현(`src/oauth/google-antigravity.ts`).
브라우저 로그인만 하면 됨.

제공 모델 (`src/providers/antigravity-models.ts:86`) 및 컨텍스트 창:

| 모델 | 창 | 채택 |
|---|---|---|
| `gemini-3.6-flash` | 1M | ✅ (기본) |
| `gemini-3.1-pro` | 1M | ✅ |
| `gemini-3.1-flash-image` | 1M | ✅ (이미지) |
| `claude-sonnet-4-6` | 200K | ❌ 제외 |
| `claude-opus-4-6-thinking` | 1M | ❌ 제외 |
| `gpt-oss-120b-medium` | 131K | ❌ 제외 |

**결정: Gemini 계열만 허용** (`ocx provider selected google-antigravity …`).
사유 = Claude는 이미 네이티브 경로로 있어 중복이고, 경로를 단순하게 유지.
→ **제3 패밀리(Gemini) 확보** = 교차검증 다양성 증가.

### 6.7.7 Antigravity CLI (`agy`) 설치 — 완료 (2026-08-09)

사용자 요청으로 **opencodex 프로바이더와 별개로** CLI도 설치.

```powershell
irm https://antigravity.google/cli/install.ps1 | iex
```

> ⚠️ 실행 전 스크립트 전문(172줄) 검토함. **깨끗함**:
> - 설치 위치 `%LOCALAPPDATA%\agy\bin\agy.exe` (사용자 영역, 관리자 불요)
> - **SHA-512 검증 내장** — 매니페스트 해시 불일치 시 `"Security Halt"` 후 중단
> - TLS 1.2 강제 · 기존 설치 감지 시 무동작 · `finally`로 스테이징 정리
> - **우리 설정 무관** (`~/.claude`·`~/.codex`·`~/.opencodex` 안 건드림)
> 매니페스트: `antigravity-cli-auto-updater-974169037036.us-central1.run.app`

결과 `[실측]`:
```
agy.exe 1.1.11 · 175,861,400 bytes
%LOCALAPPDATA%\agy\bin 를 User PATH 레지스트리에 등록 (현 셸엔 미반영 → 새 터미널 필요)
```

**서브커맨드**: `agent(s)` · `changelog` · `help` · `install` · `models` · `plugin(s)` · `update`
**주요 플래그**: `--model` · `--effort {low|medium|high}` · `--print` ·
`--output-format {text|json|stream-json}` · `--json-schema` · `--mode {accept-edits,plan}` ·
`--sandbox` · `--dangerously-skip-permissions`

> ★ **Orca 워커 적합**: `--model`/`--effort`/`--print`를 갖췄고 Orca `TuiAgent` enum에
> `antigravity`가 이미 존재 → Phase 3에서 `workers[].command`로 배선 가능.

> ⚠️ `agy` **자체 로그인은 `ocx login google-antigravity`와 별개 경로**다.
> opencodex 라우팅에 필요한 것은 **후자**. `agy auth status`는 서브커맨드 목록에 없고
> 대화형 대기로 행(hang) — 백그라운드 셸에서 실행 금지.

### 6.7.9 ★★ Antigravity 프로바이더 등록 + Gemini E2E — PASS (2026-08-09)

**로그인** (`ocx login google-antigravity`, 브라우저 OAuth, 사용자 수행):
```
scope: cloud-platform · userinfo.email · userinfo.profile · cclog · experimentsandconfigs
PKCE S256 · redirect 127.0.0.1:51121/callback · access_type=offline
→ "Discovering Cloud Code Assist project" → ✅ Logged in
```

**등록 결과**:
```
Configured providers:
  openai (default)     adapter=openai-responses
  google-antigravity   adapter=google  model=gemini-3.6-flash
```

**Gemini 계열만 allowlist 적용** (결정: §6.7.6):
```bash
ocx provider selected google-antigravity --set "gemini-3.6-flash,gemini-3.1-pro,gemini-3.1-flash-image"
```
> ⚠️ 문법 주의: `--set` 필수 + **쉼표 구분**. 공백 나열은 `Unexpected argument(s)` 에러.

**`/v1/models` 반영 확인** — 총 10개 `[실측]`:
```
gpt-5.6-sol · gpt-5.6-terra · gpt-5.6-luna · gpt-5.5 · gpt-5.4 · gpt-5.4-mini · gpt-5.3-codex-spark
google-antigravity/gemini-3.6-flash · /gemini-3.1-pro · /gemini-3.1-flash-image
```
→ **`claude-sonnet-4-6`·`claude-opus-4-6-thinking`·`gpt-oss-120b-medium` 정상 제외 확인.**

**E2E**:
```
codex exec -m "google-antigravity/gemini-3.6-flash" "Reply with exactly: GEMINI_E2E_OK"
→ GEMINI_E2E_OK · tokens 10,042                        ✅ PASS
```

> ℹ️ `ocx provider test google-antigravity` = `not applicable`
> (정적 카탈로그 — live model-discovery 엔드포인트 없음). 정상.

**모델 참조 문법**: `provider/model` — 예 `google-antigravity/gemini-3.6-flash`.
OpenAI 계열은 접두사 없이 bare (`gpt-5.6-sol`).

### 6.7.10 ★ 달성 상태 — 3-패밀리 확보

| 패밀리 | 경로 | 상태 |
|---|---|---|
| **Claude** | 네이티브 (CCS 경유 중, 전환 후 직결) | 미등록 유지 = 패스스루 |
| **GPT** | `openai` (authMode=forward) | ✅ E2E PASS |
| **Gemini** | `google-antigravity` (oauth) | ✅ E2E PASS |

C16 교훈("슬롯 독립성이 발견율을 결정")에 비추어 **제3 독립 관점 확보**는 교차검증 실질 이득.

### 6.7.11 남은 검증

- [ ] `ocx sync` — 모델 카탈로그를 Codex에 주입 (★ `~/.codex/config.toml` **변조**. 백업 완료:
      `codex-config.toml.pre-ocx-start`. 복원 = `ocx stop`)
- [ ] codex CLI가 프록시 경유로 실제 응답하는지 E2E
- [ ] Antigravity 등록 여부 결정 (`ocx login google-antigravity` — 브라우저 OAuth, 사용자 작업)
- [ ] 전환 시 `claude /login` 재로그인 (§6.8)

---

## §6.8. ★★★ 로컬 Claude 크리덴셜 만료 — 전환 시 필수 단계

`[실측]` 2026-08-09:

```
~/.claude/.credentials.json
  claudeAiOauth.expiresAt   : 2026-05-12   ← ★ 만료됨 (약 3개월 경과)
  claudeAiOauth.refreshToken: len=0        ← 갱신 불가
  mtime                     : 2026-06-06   ← 6월 이후 미사용

~/.ccs/cliproxy/auth/
  claude-bizdev@nice.co.kr.json      mtime 2026-08-09 00:27  ← 살아있음
  claude-indietogo@gmail.com.json    mtime 2026-08-09 00:27  ← 살아있음

ccs doctor → Claude Auth: Authenticated (2026-08-09)
```

**현재 Claude Code가 도는 이유 = CCS가 자기 저장소의 신선한 토큰을 대신 실어주기 때문.**
Claude Code 자신의 OAuth는 6월부터 쓰이지 않았다.

→ **`ANTHROPIC_BASE_URL`을 제거하는 순간 `claude /login` 재로그인이 필수.**
   계획에 없던 단계이므로 전환 절차에 반드시 포함할 것.

> ⚠️ **본 문서 §5.5.3 판정 정정**: 접두사(`sk-ant-o…`)·길이(108)만 확인하고
> "조건 ③ 충족·최대 미확인 해소"로 판정했으나 **만료를 확인하지 않았다.**
> 토큰 *형태*는 맞으나 *유효하지 않다*. 형태 확인 ≠ 유효성 확인.
> 재로그인 후에는 조건 ③이 진짜로 충족된다(형태 자체는 정확).

---

## §6.9. ★★★ 전환 완료 — 네이티브 복귀 (2026-08-10)

### 6.9.1 적용된 변경 (`~/.claude/settings.json` env)

```diff
- "ANTHROPIC_AUTH_TOKEN": "ccs-internal-managed",
- "ANTHROPIC_BASE_URL": "http://127.0.0.1:8317",
- "ANTHROPIC_DEFAULT_HAIKU_MODEL": "gpt-5.6-luna",
- "ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME": "GPT-5.6 Luna",
- "ANTHROPIC_DEFAULT_HAIKU_MODEL_DESCRIPTION": "OpenAI GPT-5.6 Luna via codex (Haiku tier)",
+ "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-5-20251001",
+ "ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME": "Haiku 4.5",
+ "ANTHROPIC_DEFAULT_HAIKU_MODEL_DESCRIPTION": "Claude Haiku 4.5 via Claude provider",

- "ANTHROPIC_CUSTOM_MODEL_OPTION": "gpt-5.6-sol",
- "ANTHROPIC_CUSTOM_MODEL_OPTION_NAME": "GPT-5.6 Sol",
- "ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION": "OpenAI GPT-5.6 Sol via codex",
```

`[1m]` 4건 · auto-compact 2건 · hooks · permissions · statusLine 전부 **불변**.
백업: `~/.claude/settings.json.bak-cutover-20260810-153844`

### 6.9.2 ★ 검증 결과 — 전 항목 PASS

**`/context` 실측** (재로그인·재시작 후):
```
Auto-compact window: 1m tokens          ← ★★ 1M 창 생존 (200K 붕괴 없음)
claude-opus-5[1m]   30.2k/1m  (3%)
claude-sonnet-5[1m] 49.8k/1m  (5%)
```

> **§5.4.2 가설 판정**: "게이트웨이 제거 시 `[1m]`이 불필요해질 수 있다" → **검증 보류**.
> `[1m]`을 **유지한 채** 1M이 나왔으므로, 네이티브에서 bare ID가 어떻게 예산되는지는
> 미측정. 무해하므로 **현행 유지**. 제거 실험은 별도 사이클에서.

**`/model` 픽커** — 의도대로 5슬롯, GPT 행 소멸:
```
Default(→Opus 5 1M) · Opus 5 · Fable 5 · Sonnet 5 · Haiku 4.5
```

**크리덴셜 복구** `[실측]`:
```
expiresAt    : 2026-08-10T14:45Z  유효 ✅
refreshToken : len=108            ← ★ 이전 len=0 → 이제 자동 갱신 가능
subscription : max                ← ★ pro 아님(만료 토큰의 'pro'는 stale 값)
```
**refresh token 확보 = 만료 문제 구조적 해소.**

**하네스 회귀 검증**:
| 스위트 | 결과 |
|---|---|
| `verify-setup.sh` | **PASS=88 FAIL=0** (기준선 동일) |
| `hooks/tests/run-all.sh` | **291/291** (cases.tsv 정합 OK) |

→ **회귀 0.** 사전 예측("이 두 키를 참조하는 하네스 코드 0건")이 실측으로 확인됨.

### 6.9.3 opencodex 영속화 (재부팅 대응)

재부팅으로 `nohup` 프로세스가 소멸 → **Task Scheduler 등록으로 해결**:
```
ocx service install
→ TaskName: opencodex-proxy · State: Running · Trigger: MSFT_TaskLogonTrigger
```
CCS의 `Ensure-CLIProxyAtLogon.ps1`과 동일 방식. E2E 재검증 `READY_OK` 확인.

> ⚠️ **교훈**: `ocx start`는 포그라운드 서버 — 세션·재부팅에 죽는다.
> 상시 운용은 **반드시 `ocx service install`**.

### 6.9.4 최종 구성

```
Claude Code ─────────────────────→ api.anthropic.com     (직결, 계정 1개)
codex CLI ──→ opencodex:10100 ──┬→ ChatGPT (gpt-5.6-*)
                                 └→ Antigravity (gemini-3.*)
CCS:8317 ─ 가동 중이나 미사용 (롤백 경로로 당분간 보존)
```

**대가**: 계정 2개 fill-first → **1개** (단 구독이 `max`라 한도 여유 있음).
**이득**: 제3자 프록시 경유 종료 · 프록시 홉 제거 · 프록시 장애 무관.

---

## §7. 미해결 / 라이브 프로브 대상

- [ ] Orca 설치 경로·AppData 상태 경로 (설치 후 실측)
- [ ] Orca가 스폰 프로세스에 env 주입/오버라이드 하는가
- [ ] `orca.yaml` 실제 스키마 (존재하긴 하는가)
- [ ] `orca dispatch` / `--inject` 정식 문법 (orchestration ON 후)
- [ ] `ocx --help` 전체 서브커맨드
- [ ] `ocx init` / `ocx claude`의 파일 변조 범위
- [ ] opencodex 프록시 포트 + CCS 포트 충돌 여부
- [ ] opencodex 경유 시 `[1m]` 창 유지 여부 (`/context` 확인)
- [ ] 하네스 CCS 결합 지점 전수 (별도 감사 진행 중)

---

## §8.5. ★ Orca 훅 병합 의미론 — 소스 실독 (2026-08-09)

> **결론: Orca 훅은 우리 훅을 덮어쓰지 않는다. 배열에 *추가*된다.**
> 최초 우려("같은 자리를 다툰다")는 **틀렸음**. 정정 기록.

### 8.5.1 증거 — `applyManagedHooks()`

`src/main/claude/hook-settings.ts:117-136` `[문서]`:

```typescript
export function applyManagedHooks(config, command, scriptFileName) {
  const nextHooks = { ...config.hooks }
  const isManagedCommand = createManagedCommandMatcher(scriptFileName)

  for (const event of CLAUDE_EVENTS) {
    const current = Array.isArray(nextHooks[event.eventName]) ? nextHooks[event.eventName] : []
    const cleaned = removeManagedCommands(current, isManagedCommand)   // ← Orca 자기 것만 제거
    const definition = { ...event.definition, hooks: [buildManagedCommandHook(command)] }
    nextHooks[event.eventName] = [...cleaned, definition]              // ← ★ 기존 보존 + 뒤에 추가
  }
  return { ...config, hooks: nextHooks }
}
```

핵심은 `[...cleaned, definition]` — **배열 스프레드**. 할당(`=`)이 아니라 **append**.

### 8.5.2 왜 우리 훅이 안 지워지는가 — `createManagedCommandMatcher()`

`src/main/agent-hooks/installer-utils.ts:68-87` `[문서]`:

```typescript
const needles = [
  `agent-hooks/${scriptFileName}`,
  `agent-hooks/${scriptStem}.cmd`,
  `agent-hooks/${scriptStem}.ps1`,
  `agent-hooks/${scriptStem}.sh`
]
return (command) => { ... return needles.some(n => normalizedCommand.includes(n)) }
```

Orca는 훅 command 문자열에 **`agent-hooks/claude-hook.*`가 포함되는지**로만 자기 것을 식별한다.
우리 훅은 전부 `$HOME/.claude/hooks/*.sh` → **needle 미포함 → 절대 매칭 안 됨.**

`removeManagedCommands()` (`installer-utils.ts:209-247`)도 명시적:
```typescript
if (directManagedKeys.length === 0 && !hasManagedNestedHook) {
  return [definition]        // ← 관리 대상 아니면 원본 그대로 반환
}
```

### 8.5.3 실제로 추가되는 것 — 전부 UI 관측용

`CLAUDE_EVENTS` (`hook-settings.ts:30-60`)의 소스 주석이 용도를 직접 밝힌다 `[문서]`:

| 이벤트 | 소스 주석이 밝힌 용도 |
|---|---|
| `SessionStart` | "재개/유휴 세션이 첫 프롬프트 전 내는 유일한 이벤트 — 없으면 사이드바 행이 사용자 타이핑 전까지 존재 못 함 (STA-3386)" |
| `UserPromptSubmit` / `Stop` | 턴 경계 |
| `StopFailure` | "API/모델 오류 후 Stop 훅을 건너뛰는 경우 — 없으면 Orca가 턴을 계속 돌고 있다고 착각" |
| `SubagentStart/Stop`, `TeammateIdle` | "서브에이전트 생명주기가 사이드바 자식 행을 채움" |
| `PreToolUse('*')` | "대시보드에 진행 중 툴(이름+입력 미리보기) 라이브 readout" |
| `PostToolUse('*')`, `PostToolUseFailure('*')`, `PermissionRequest('*')` | 상태·권한 표면화 |

**전부 Orca GUI가 에이전트 상태를 보기 위한 것.** 우리 하네스 훅과 기능이 겹치지 않는다.

### 8.5.4 판정

| 질문 | 답 |
|---|---|
| 우리 훅이 지워지나? | **아니오** — needle 불일치로 `removeManagedCommands`가 원본 반환 |
| 같은 이벤트 공존 가능? | **예** — 이미 우리도 `Write\|Edit`에 훅 5개 운용 중 |
| 그럼 `hooks off`가 불필요한가? | **아니오, 여전히 권장** — 아래 사유 |

**여전히 `orca agent hooks off`를 권하는 이유**(위험이 아니라 위생):
1. `PreToolUse('*')`·`PostToolUse('*')`는 **모든 툴 호출마다** 발화 → 우리 훅 체인에 지연 추가
2. seal #23이 이 항목들을 하네스 소유로 인식 못 함 → 매 검증마다 노이즈
3. 훅 켜기는 **언제든 되돌릴 수 있음**(`hooks on`). 먼저 최소로 시작하는 게 정석

단 **끄면 Orca의 관측 기능(사이드바 상태·대시보드 라이브·모바일 알림)이 죽는다** —
그게 Orca를 쓰는 주된 이유이므로, Phase 3에서는 **켜고 쓰는 쪽이 합리적**일 수 있다.
→ 실제 착수 시 재판단. 안전 근거는 위 8.5.1-8.5.2로 확보됨.

---

## §9. Orca 재평가 트리거 (Phase 3 착수 조건)

Orca는 **보류**다. "이제 깔아도 되나"를 감이 아니라 아래 기준으로 판단한다.
아무것도 안 하고 기다리는 게 아니라, 재평가 시 이 목록을 실측한다.

### 9.1 보류 사유 (2026-08-08 조사 실측)

| 문제 | 근거 |
|---|---|
| conpty fork 폭주 | **9분에 238프로세스 / 19GB** 보고 |
| 터미널 데몬 메모리 누수 | 열린 이슈 |
| `%APPDATA%\orca` 수 GB 팽창 | staging bloat |
| **Windows e2e가 릴리스 CI에서 주석처리** | ★ 가장 나쁨 — 검증 없이 출시된다는 뜻 |
| 한국어 IME 버그 #10343 · #9803 | **열린 상태** — 이 머신은 한국어 로케일 |
| 서명 = SignPath Foundation OSS (non-EV) | SmartScreen 경고 지속 (메인테이너 확인) |

### 9.2 재평가 체크리스트

```bash
gh api repos/stablyai/orca/issues/10343 --jq '.state'   # 한국어 IME
gh api repos/stablyai/orca/issues/9803  --jq '.state'   # 한국어 IME
gh api "search/issues?q=repo:stablyai/orca+is:issue+is:open+windows+in:title" --jq '.total_count'
# Windows e2e가 릴리스 CI에 복귀했는지:
curl -sL https://raw.githubusercontent.com/stablyai/orca/main/.github/workflows/release-cut.yml | grep -in 'e2e'
```

**착수 조건 (전부 충족 시)**:
- [ ] #10343 · #9803 **둘 다 closed**
- [ ] Windows e2e가 릴리스 CI에서 **주석 해제**됨
- [ ] conpty fork 폭주 이슈 closed
- [ ] Phase 2 감지기 seal **착륙 완료** (하네스 비-소유 훅 ALERT)
- [ ] C18 종료 + §6.6 재확인 완료

### 9.3 Phase 3 진입 시 필수 순서 (순서 자체가 안전장치)

1. `settings.json` 백업 (§6.5 위치)
2. **winget 경로 우선** (`winget install --id StablyAI.Orca --exact`) — 브라우저 Mark-of-the-Web 회피.
   winget은 GitHub 릴리스보다 약 1버전 지연.
3. 설치 직후, **리포를 열기 전에**: Settings → General → Orca CLI 등록 (GUI 전용) → `orca agent hooks off --json` → `orca agent hooks status --json` 확인
4. `settings.json`을 백업과 **diff** — seal #23이 못 잡으므로 수동 대조가 유일한 탐지기
5. 브랜치 prefix **명시 지정** (기본값 미확인). 하네스 sweep이 고아 `worktree-*` 브랜치를 지우므로 충돌 회피
6. Orca 워크트리 루트(`<home>/orca/workspaces`)가 하네스 `.claude/worktrees`와 **다른 네임스페이스**인지 확인

### 9.4 ★ 미해결 설계 문제 — 프로세스 경계

훅 충돌보다 **더 근본적인 문제**다:

> 하네스의 모델-정책 Rule A/B/C/C2/C3는 **`Agent`/`Workflow` 도구 호출을 가로채는 PreToolUse 훅**이다.
> Orca가 띄운 독립 `claude` 프로세스는 **그 매처에 걸리지 않는다.**
> 즉 Orca 워커의 모델 선택은 정책 게이트를 **통과하지 않는다.**

`orca agent hooks off`로 풀리는 문제가 아니다 (그건 반대 방향 — Orca가 우리를 침범하는 것 방지).
이건 **우리 정책이 Orca 스폰에 도달하지 못하는** 문제다.

가능한 해법 (Phase 3에서 결정):
- (a) Orca 모드팩 `meta.json`의 `workers[].command`를 **정적 검증**하는 오라클 추가
      (모드팩은 파일이므로 검사 가능 — seal과 동형)
- (b) Orca 워커를 `ocx claude` 등 **래퍼 경유**로만 띄우고, 래퍼가 정책을 강제
- (c) Orca 워커는 정책 **범위 밖**으로 선언하고 문서화 (정직한 축소 — silent downgrade 금지)

→ (a)가 하네스 기존 패턴(파일 기반 seal)과 가장 정합. 단 모드팩 편집을 GUI로 하면 우회 가능.

---

## §8. 출처

- Orca: https://www.onorca.dev · https://github.com/stablyai/orca · https://www.onorca.dev/docs/cli/overview
- Orca 모드팩 스튜디오: https://orca.teaboard.link ·
  `/setup-mode-pack.sh` · `/generate-pack.sh` ·
  `/skills/orca-mode-pack/SKILL.md` · `/skills/orca-mode-pack/references/mode-pack.schema.json`
- opencodex: https://opencodex.me · https://lidge-jun.github.io/opencodex (→301→ opencodex.me)
- 로컬 실측: 2026-08-08, Windows 11 Education 26200, MSYS bash
