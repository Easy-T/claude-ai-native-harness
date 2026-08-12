# 인계 프롬프트 — CCS → 네이티브 전환 (Claude Code 라우팅)

> **용도**: Claude Code 세션이 전환 중 끊겨서 스스로 마무리하지 못할 때,
> **codex CLI(또는 다른 에이전트)에 이 파일을 통째로 주어** 작업을 완결시킨다.
> **작성**: 2026-08-09 · **대상 머신**: Windows 11, `C:\Users\12132`
> **선행 문서**: `~/.claude/docs/ai-context/ade-migration-research.md` (전체 조사 기록)

---

## 0. 이 작업이 뭔가 (한 문단)

Claude Code가 지금 로컬 프록시 **CCS**(`127.0.0.1:8317`)를 경유해 Anthropic에 붙는다.
이 경유를 끊고 **api.anthropic.com에 직결**시키는 것이 목표다.
방법은 `~/.claude/settings.json`의 `env`에서 **2줄을 지우고**, haiku 슬롯을 되돌리고,
**`claude /login`으로 재로그인**한 뒤 Claude Code를 재시작하는 것.
GPT·Gemini는 이미 **opencodex**(`127.0.0.1:10100`)로 옮겨서 검증까지 끝났다 — 건드리지 말 것.

---

## 1. 시작 전 상태 확인 (그대로 실행)

```bash
# 현재 라우팅 라인
grep -nE 'ANTHROPIC_BASE_URL|ANTHROPIC_AUTH_TOKEN|DEFAULT_HAIKU' ~/.claude/settings.json

# 두 프록시
netstat -ano | grep -E ':(8317|10100)' | grep LISTEN

# 백업 존재 확인 (없으면 절대 진행 금지)
ls -la ~/.claude/backups/ade-migration-20260808/
```

기대값:
- `settings.json`에 `ANTHROPIC_BASE_URL="http://127.0.0.1:8317"` 존재
- 8317(CCS)·10100(opencodex) 둘 다 LISTEN
- 백업 디렉터리에 `claude-settings.json` 존재

---

## 2. ★ 수행할 변경 — `~/.claude/settings.json` 의 `env` 블록만

### 2.1 삭제할 2줄

```json
"ANTHROPIC_AUTH_TOKEN": "ccs-internal-managed",
"ANTHROPIC_BASE_URL": "http://127.0.0.1:8317",
```

- `ANTHROPIC_AUTH_TOKEN`은 실제 토큰이 아니라 더미. **이 값이 있으면 Claude Code 자신의
  OAuth 경로가 비활성화**되어 재로그인해도 소용없다. 반드시 지운다.
- `ANTHROPIC_BASE_URL`은 모든 요청을 CCS로 보내는 지시.

### 2.2 haiku 슬롯 되돌리기 (3줄 치환)

프록시가 빠지면 `gpt-5.6-luna`는 라우팅할 곳이 없어 **깨진다**.

```json
// 이전
"ANTHROPIC_DEFAULT_HAIKU_MODEL": "gpt-5.6-luna",
"ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME": "GPT-5.6 Luna",
"ANTHROPIC_DEFAULT_HAIKU_MODEL_DESCRIPTION": "OpenAI GPT-5.6 Luna via codex (Haiku tier)",

// 이후
"ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-5-20251001",
"ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME": "Haiku 4.5",
"ANTHROPIC_DEFAULT_HAIKU_MODEL_DESCRIPTION": "Claude Haiku 4.5 via Claude provider",
```

> ⚠️ **haiku에는 `[1m]`을 붙이지 말 것** — 200K 모델이다.
> 참조값 출처: `~/.claude/setup/settings.example.json`이 이미 이 ID를 쓴다.

### 2.3 GPT custom 슬롯 3줄 제거

프록시가 빠지면 픽커의 이 행도 라우팅 불가.

```json
"ANTHROPIC_CUSTOM_MODEL_OPTION": "gpt-5.6-sol",
"ANTHROPIC_CUSTOM_MODEL_OPTION_NAME": "GPT-5.6 Sol",
"ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION": "OpenAI GPT-5.6 Sol via codex",
```

→ GPT는 이제 `codex` CLI로 쓴다(이미 opencodex 경유 검증 완료).

### 2.4 ★ 절대 건드리지 말 것 (죽음의 나선 방지 계약)

```json
"ANTHROPIC_DEFAULT_OPUS_MODEL":   "claude-opus-5[1m]",
"ANTHROPIC_DEFAULT_FABLE_MODEL":  "claude-fable-5[1m]",
"ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-5[1m]",
"ANTHROPIC_MODEL":                "claude-sonnet-5[1m]",
"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "40",
"CLAUDE_CODE_AUTO_COMPACT_WINDOW": "1000000",
```

`[1m]`은 전송 전 클라이언트에서 제거되므로 **네이티브에서도 무해**하다.
네이티브에서 불필요해질 *가능성*은 있으나 **실측 전엔 절대 제거하지 말 것**
(제거했다가 200K로 붕괴하면 auto-compact 죽음의 나선 재발 — 과거 실사고).

`"model": "fable"` (톱레벨)도 유지 — 사용자 선택값.

`hooks` / `permissions` / `statusLine` / `enabledPlugins` 등 **다른 모든 키 유지.**

---

## 3. 실행 절차

```bash
# ① 백업 (필수)
cp ~/.claude/settings.json ~/.claude/settings.json.bak-cutover-$(date +%Y%m%d-%H%M%S)

# ② 위 2.1~2.3 편집을 적용 (JSON 유효성 유지)

# ③ JSON 검증 — 실패하면 즉시 §5로 롤백
node -e 'JSON.parse(require("fs").readFileSync(process.env.HOME+"/.claude/settings.json","utf8")); console.log("JSON OK")'

# ④ 잔존 확인 — 아래 두 grep은 결과가 없어야 정상
grep -n 'ANTHROPIC_BASE_URL\|ANTHROPIC_AUTH_TOKEN' ~/.claude/settings.json || echo "제거 확인 OK"
grep -n 'gpt-5.6' ~/.claude/settings.json || echo "GPT 참조 없음 OK"

# ⑤ [1m] 계약 살아있는지 확인 — 4건 나와야 정상
grep -c '\[1m\]' ~/.claude/settings.json
```

### ⑥ 재로그인 (★ 대화형 — 사람이 직접)

```
claude /login
```

> **왜 필수인가**: `~/.claude/.credentials.json`의 토큰은 **2026-05-12 만료**이고
> **refresh token이 없다**(len=0). 지금까지 동작한 이유는 CCS가 자기 저장소의 신선한
> 토큰을 대신 실어줬기 때문. `ANTHROPIC_AUTH_TOKEN` 더미를 지우는 순간 Claude Code는
> 자기 OAuth를 쓰려 하고, 그게 죽어 있으므로 재로그인 없이는 인증 실패한다.

### ⑦ Claude Code 재시작 후 확인 (사람이 눈으로)

```
/context     → Auto-compact window 가 1m 으로 표시되는지 (200K면 §5 롤백 검토)
/model       → Opus 5 / Fable 5 / Sonnet 5 / Haiku 4.5 가 보이고 GPT 행은 없어야 정상
```

간단한 프롬프트 하나 보내 응답 확인.

---

## 4. 완료 후 (선택, 급하지 않음)

```bash
# 하네스 검증 — 회귀 없는지
bash ~/.claude/setup/verify-setup.sh          # 기대 88/0
bash ~/.claude/setup/tests/seal-regression.test.sh
bash ~/.claude/hooks/tests/run-all.sh          # 기대 291/291
```

**CCS는 아직 제거하지 않는다.** 며칠 안정 운영 확인 후 별도 판단.
(제거 시 statusline 사용량 바가 죽고, `skills/ccs-delegation`·`commands/ccs*` 심링크 3개가
dangling 된다 — 이건 별도 작업.)

---

## 5. 롤백 (문제 발생 시 즉시)

```bash
cp ~/.claude/backups/ade-migration-20260808/claude-settings.json ~/.claude/settings.json
# 또는 ③에서 만든 .bak-cutover-* 사용
```

CCS(8317)는 계속 살아있으므로 **파일 복사 + Claude Code 재시작만으로 즉시 원복**된다.
롤백 후에는 재로그인 불필요(더미 토큰이 돌아오므로 CCS 경로가 다시 유효).

---

## 6. 알아둘 사실 (판단에 필요)

| 사실 | 내용 |
|---|---|
| **계정 2개 → 1개** | CCS는 `bizdev@nice.co.kr`·`indietogo@gmail.com` 2계정을 `fill-first`로 회전시켰다. 전환 후엔 `/login`한 **1개만** 사용 → **한도 실질 절반**. 이번 전환의 최대 실질 비용. 계정 바꾸려면 `/logout`→`/login`(자동 회전 없음). |
| **왜 전환하나** | Anthropic 공식 문서가 *"third-party developers… route requests through Free, Pro, or Max plan credentials"*를 금지. 2026-01-09 서버측 차단(`HTTP 400: This credential is only authorized for use with Claude Code`) 실재. 현 2계정 회전 구성이 그 패턴에 해당. |
| **GPT/Gemini는 무관** | opencodex(10100)가 이미 서빙 중이고 E2E 검증 완료(`OCX_E2E_OK`, `GEMINI_E2E_OK`). `~/.codex/config.toml`에 3줄 주입돼 있음. **이 전환과 독립** — 건드리지 말 것. |
| **`[1m]`의 정체** | 게이트웨이 뒤에서 Claude Code가 1M 지원을 검증 못 해 bare ID가 200K로 예산되는 문제의 대응책. 전송 전 strip되므로 네이티브에서도 무해. SSOT: `C:\Users\12132\Documents\claude_routing_project\model-picker-1m-autocompact-fix-2026-07-05.md` |
| **하네스 영향 0** | `grep -rn "ANTHROPIC_BASE_URL\|ANTHROPIC_AUTH_TOKEN" setup/ hooks/ skills/ workflows/ agents/` = **0건**. 이 두 키를 묶는 seal 없음 → 검증 카운트 불변 예상. |
| **statusline 열화** | `statusline.sh:15`가 `~/.ccs/cliproxy/auth`를 읽어 5h/7d 사용량 바를 그린다. CCS가 토큰 갱신을 멈추면 빈칸/stale. **표시 기능이며 게이트 아님** — 차단 사유 아님. |

---

## 7. codex에 넘길 때 쓸 한 줄

```
~/.claude/docs/ai-context/ade-cutover-handoff.md 를 읽고 §1~§3을 순서대로 수행해줘.
§2.4의 [1m] 4줄과 auto-compact 2줄은 절대 건드리지 마. ③ JSON 검증이 실패하면
즉시 §5로 롤백하고 멈춰. ⑥ 재로그인은 대화형이니 나에게 요청해.
```
