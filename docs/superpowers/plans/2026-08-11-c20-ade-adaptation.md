# C20 ADE 적합화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** active
**RPI-Cycle:** 71
**Started:** 2026-08-11

**Goal:** ADE(Orca)+opencodex 환경으로 이전한 하네스에서, 문서가 기술하는 사실과 실물이 어긋난 지점을 정정하고, 브리지 실행 자산을 추적 자산으로 승격하며, 프로세스-경계 정책 공백을 L3 오라클로 덮는다.

**Architecture:** 3축. ⑴ **문서-거짓 정정**(T3/T4/T5/T10 + 경로 B 캐리어 이관 T11) — 실물과 어긋난 서술을 실측값으로 교체. ⑵ **브리지 자산화**(bin/claude-ocx git 추적 + install.sh 안내 + README 절) — 신규 환경 재현 가능성 확보. ⑶ **모드팩 + L3 오라클 동시 착륙** — 검사 대상 없는 vacuous seal 방지.

**Tech Stack:** bash(POSIX/MSYS) · node(JSON 파싱) · git · verify-setup.sh seal 프레임워크

**Best-Direction Check:** 최선안 = ⑴문서 정정을 실측-앵커로 봉인(seal) + ⑵브리지 자산 추적 + ⑶모드팩·오라클 동시 착륙 / 채택안 = **동일**.
- **DOWNGRADE-DECLARED: 없음.**
- 근거: 대안으로 "오라클 없이 모드팩만" 또는 "문서 정정만"이 있었으나 전자는 정책 공백을 남기고 후자는 재현성을 남기지 않는다. 난이도를 이유로 축소하지 않았다.
- 스코프 축소 아님: T11(경로 B 이관)은 Phase R 이 발견한 **거버넌스 기능 정지** 결함이라 주축의 직접 귀결로 포함.

## Global Constraints

- **spec §19 가 SSOT** — `docs/superpowers/specs/2026-07-25-model-policy-design.md:2230-2396`. 모든 task 는 여기 착륙한 규범을 구현한다.
- **자동 설치·로그인·인증·업데이트 절차 생성 금지** — `docs/ai-context/cross-family-review.md:15`. 안내(echo/문서)만 허용.
- **CCS 제거 금지** — 사용자 명시 보류. CCS 프로세스·심링크 3건 건드리지 않는다.
- **미측정 단언 금지** — 문서에 쓰는 수치·동작 주장은 실행 출력 근거 필수. 불가하면 "미검증(신규 세션 필요)" 명기.
- **개행**: `CONTEXT.md`·`spec`·`README.md`·`SECURITY.md` 는 혼합 개행 파일. **Edit 도구 사용 금지, `python` 바이트 치환 사용**(`_goal/c20-i1-repro-measured.md` — Edit 이 혼합 파일을 전 LF 통일시킴).
- **신규 seal 번호는 Task 7 에서 origin/master 실측 발급** — 임의 배정 금지(spec §6).
- 각 task 종료 시 `bash ~/.claude/setup/verify-setup.sh` PASS 유지(카운트는 Task 7 에서만 증가).

---

## File Structure

| 파일 | 책임 | task |
|---|---|---|
| `statusline.sh` | 모델별 컨텍스트 창 표기 | T1 |
| `SECURITY.md` | 신뢰 모델·의존성 기술 | T2 |
| `README.md` | 하네스 사용자 문서(2사이트 + 브리지 절 + seal 카운트) | T2·T4·T7 |
| `docs/ai-context/cross-family-review.md` | 교차패밀리 탐지·실행 규약(L1 SSOT) | T3 |
| `skills/closeout-pr-cycle/SKILL.md` + opencode 미러 | 경로 B probe 소비자 | T3 |
| `bin/claude-ocx`, `bin/claude-ocx.cmd` | 브리지 실행 자산 | T4 |
| `setup/install.sh` | 설치 안내(REQUIRED + STEP echo) | T4 |
| `modes/orca-rpi-implement.json` | 모드팩 선언(신규) | T5 |
| `setup/lib/modepack-oracle.sh` | L3 정적 오라클(신규) | T6 |
| `setup/verify-setup.sh` | seal 배선 | T7 |

---

### Task 1: statusline Haiku 창 정정 (T3)

**Files:**
- Modify: `statusline.sh:147`

**Interfaces:**
- Consumes: 없음(독립)
- Produces: 없음(독립)

**배경:** `:147` 이 `*Haiku*` 를 CW=272000 으로 잡는다. 이는 CCS 시절 `gpt-5.4-mini` 슬롯 별칭 때문이었다. 네이티브 전환 후 `ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku-4-5-20251001` 의 실제 창은 **200k** 이고, `statusline.sh` 의 FLOOR 로직(`if (( CW > 0 && SIZE < CW )); then SIZE=$CW`)이 표기를 272k 로 부풀린다.

- [ ] **Step 1: RED — 현재 오표기 재현**

```bash
cd ~/.claude
printf '{"model":{"display_name":"Haiku 4.5"},"workspace":{"current_dir":"%s"},"session_id":"t1"}' "$HOME/.claude" \
  | bash statusline.sh | grep -oE '[0-9]+k/[0-9]+k'
```
Expected: `0k/272k` 를 포함(결함 재현). `272k` 가 안 나오면 이미 정정된 것이니 중단하고 보고.

- [ ] **Step 2: 정정 — `*Haiku*` 를 별도 분기로 분리**

`:147` 을 아래로 치환(python 바이트 치환):

```bash
python -c "
import io
p='statusline.sh'
b=io.open(p,'rb').read()
old=b'       *Haiku*|*mini*|*Mini*)        CW=272000  ;;  # legacy haiku slot -> gpt-5.4-mini'
new=(b'       *Haiku*)                      CW=0       ;;  # native Haiku 4.5 reports correctly (C20: CCS mini alias retired)\n'
     b'       *mini*|*Mini*)                CW=272000  ;;  # legacy CCS custom slot -> gpt-5.4-mini')
assert b.count(old)==1, ('anchor count', b.count(old))
io.open(p,'wb').write(b.replace(old,new))
print('ok')
"
```

- [ ] **Step 3: GREEN — 재실행**

```bash
printf '{"model":{"display_name":"Haiku 4.5"},"workspace":{"current_dir":"%s"},"session_id":"t1"}' "$HOME/.claude" \
  | bash statusline.sh | grep -oE '[0-9]+k/[0-9]+k'
```
Expected: `272k` **미포함**(CW=0 → CC 자체 보고값 사용).

- [ ] **Step 4: 무회귀 — GPT/Opus 분기 불변 확인**

```bash
for m in "GPT-5.6 Sol" "Opus 5" "gpt-5.4-mini"; do
  printf '{"model":{"display_name":"%s"},"workspace":{"current_dir":"%s"},"session_id":"t1"}' "$m" "$HOME/.claude" \
    | bash statusline.sh | grep -oE '[0-9]+k/[0-9]+k' | sed "s/^/  $m → /"
done
bash setup/verify-setup.sh 2>&1 | tail -1
```
Expected: GPT-5.6→`372k`, Opus→`1000k`(=1m 표기 가능), mini→`272k` 유지. verify-setup `FAIL=0`.

- [ ] **Step 5: Commit**

```bash
git add statusline.sh
git commit -m "fix(c20): statusline Haiku 창 272k→네이티브 자체보고 (T3)"
```

---

### Task 2: SECURITY.md·README 의 CCS 의존 서술 정정 (T4·T5)

**Files:**
- Modify: `SECURITY.md:30-31`
- Modify: `README.md:522`

**Interfaces:**
- Consumes: 없음
- Produces: 없음

**배경:** 두 사이트가 "모델 트래픽은 CCS 프록시 경유"를 **현행 사실**로 기술한다. 컷오버 후 거짓이다(`settings.json` env 에 `ANTHROPIC_BASE_URL` 부재 — spec §19.0 ⓐ). CCS 프로세스 자체는 생존하나 **모델 트래픽 경로가 아니다**(statusline rate-limit 조회 용도로만 남음).

- [ ] **Step 1: RED — 거짓 서술 실재 확인**

```bash
cd ~/.claude
grep -n "127.0.0.1:8317" SECURITY.md
grep -n "CCS 프록시 의존" README.md
node -e 'const j=require(process.env.HOME+"/.claude/settings.json"); console.log("ANTHROPIC_BASE_URL in settings.env:", "ANTHROPIC_BASE_URL" in (j.env||{}))'
```
Expected: SECURITY.md·README.md 각 1건 매칭 + `false`(env 부재 = 서술이 거짓임의 근거).

- [ ] **Step 2: SECURITY.md 정정**

```bash
python -c "
import io
p='SECURITY.md'
b=io.open(p,'rb').read()
old='- 모델 트래픽은 로컬 CCS 프록시(\`127.0.0.1:8317\`) 경유. 이 프록시는 신뢰·가용성 단일 의존성이며\n  하네스 범위 밖에서 관리된다(키는 \`ccs-internal-managed\` placeholder, 실제 키는 프록시가 보유).'.encode('utf-8')
new=('- 모델 트래픽은 **Anthropic API 직결**이다(C20 컷오버, 2026-08-11 — \`settings.json\` \`env\` 에\n'
     '  \`ANTHROPIC_BASE_URL\` 부재로 확인). 과거의 로컬 CCS 프록시(\`127.0.0.1:8317\`) 경유는 **종료**됐다.\n'
     '  CCS 프로세스는 생존하나 모델 트래픽 경로가 아니며 statusline 의 rate-limit 조회에만 쓰인다.\n'
     '- **브리지 실행**(\`bin/claude-ocx\`)을 쓰는 경우에 한해 트래픽이 로컬 opencodex 프록시\n'
     '  (\`127.0.0.1:10100\`) 경유가 된다 — 그 경로의 신뢰·가용성은 하네스 범위 밖에서 관리되며,\n'
     '  프록시 미가동 시 \`/healthz\` 프로브가 **exit 1 로 실패**해 네이티브로 조용히 새지 않는다.').encode('utf-8')
assert b.count(old)==1, ('anchor', b.count(old))
io.open(p,'wb').write(b.replace(old,new)); print('ok')
"
```

- [ ] **Step 3: README.md:522 정정**

```bash
python -c "
import io
p='README.md'
b=io.open(p,'rb').read()
old='- 잔여 위험·CCS 프록시 의존·자격증명 처리·secret-scan 한계'.encode('utf-8')
new='- 잔여 위험·모델 트래픽 경로(네이티브 직결·브리지 실행)·자격증명 처리·secret-scan 한계'.encode('utf-8')
assert b.count(old)==1, ('anchor', b.count(old))
io.open(p,'wb').write(b.replace(old,new)); print('ok')
"
```

- [ ] **Step 4: GREEN — 잔존 0 확인 + 무회귀**

```bash
grep -n "CCS 프록시 의존" README.md; echo "README 잔존: $(grep -c 'CCS 프록시 의존' README.md)"
grep -c "모델 트래픽은 로컬 CCS 프록시" SECURITY.md
bash setup/verify-setup.sh 2>&1 | tail -1
```
Expected: 둘 다 `0`. verify-setup `FAIL=0`.

- [ ] **Step 5: Commit**

```bash
git add SECURITY.md README.md
git commit -m "docs(c20): 모델 트래픽 경로 서술을 네이티브 직결로 정정 (T4·T5)"
```

---

### Task 3: 교차패밀리 경로 B 캐리어 이관 (T11)

**Files:**
- Modify: `docs/ai-context/cross-family-review.md:12`, `:30`, `:81`
- Modify: `skills/closeout-pr-cycle/SKILL.md:161`
- Modify: `opencode-harness/skill/closeout-pr-cycle/SKILL.md:166`

**Interfaces:**
- Consumes: Task 4 의 `bin/claude-ocx`(추적 자산). **Task 4 이후에 실행할 것** — 문서가 추적되지 않는 자산을 참조하면 안 된다.
- Produces: 없음

**배경:** spec §19.2. 경로 B 는 `claude --model "${ANTHROPIC_CUSTOM_MODEL_OPTION:-gpt-5.6-sol}"` 로 CCS 라우팅을 전제하는데 env 가 부재해 **다음 세션부터 무효**다. 캐리어를 opencodex 브리지로 이관한다. **판별자(`modelUsage` 에 `gpt-*`)는 불변.**

- [ ] **Step 1: RED — 전파 대상 5사이트 실재 확인**

```bash
cd ~/.claude
grep -rn -e ANTHROPIC_CUSTOM_MODEL_OPTION -e 'claude --model' \
  docs/ai-context/cross-family-review.md \
  skills/closeout-pr-cycle/SKILL.md \
  opencode-harness/skill/closeout-pr-cycle/SKILL.md
```
Expected: 정확히 5행(`cross-family-review.md` :12/:30/:81 · `SKILL.md` :161 · 미러 :166).

- [ ] **Step 2: cross-family-review.md :12 이관**

```bash
python -c "
import io
p='docs/ai-context/cross-family-review.md'
b=io.open(p,'rb').read()
old='2. **경로 B — CCS/CLIProxy 라우팅 (폴백; CCS 있는 PC만)**: A 불가 시 \`claude --model \"\${ANTHROPIC_CUSTOM_MODEL_OPTION:-gpt-5.6-sol}\" -p \"Reply: OK\" --output-format json\` 1회'.encode('utf-8')
new='2. **경로 B — opencodex 브리지 (폴백; ocx 프록시 있는 PC만)**: A 불가 시 \`OCX_MODEL=gpt-5.6-sol ~/.claude/bin/claude-ocx -p \"Reply: OK\" --output-format json\` 1회'.encode('utf-8')
assert b.count(old)==1, ('anchor12', b.count(old))
io.open(p,'wb').write(b.replace(old,new)); print('ok :12')
"
```

- [ ] **Step 3: :12 잔여 문언(캐리어 설명)·:30·:81 이관**

```bash
python - <<'PY'
import io
p='docs/ai-context/cross-family-review.md'
b=io.open(p,'rb').read()
subs=[
 # :12 꼬리 — 모델명 SSOT 설명이 CCS env 를 가리킴
 ('모델명은 custom 슬롯 env가 SSOT(버전-무관 — GPT 세대 교체 시 settings.json env만 갱신; 폴백 리터럴은 env 부재 머신용).',
  '모델명은 `OCX_MODEL` env가 SSOT(버전-무관 — GPT 세대 교체 시 이 값만 갱신; 무지정 시 `claude-ocx` 기본값 `gpt-5.6-sol`). ★A·B 인증 공통모드: ocx `openai` provider 는 `authMode=forward` 라 codex CLI 인증(`~/.codex/auth.json`)을 전달한다 — codex 로그인 만료 시 A·B 가 동시에 불가해지며, 그때 SKIP 사유는 "GPT 경로 부재"가 아니라 **"codex 인증 만료"** 여야 정직하다.'),
 # :30 본호출
 ('경로 B는 `cat <대상문서> | claude --model <gpt-모델> -p "<프롬프트>"` (제어 지점 없음 — 세션 effort 상속).',
  '경로 B는 `cat <대상문서> | OCX_MODEL=<gpt-모델> ~/.claude/bin/claude-ocx -p "<프롬프트>"` (제어 지점 없음 — 세션 effort 상속).'),
 # :3 SKIP 사유
 ('("이 머신 GPT 경로 부재(codex CLI 미설치/미로그인·CCS 라우팅 없음)")',
  '("이 머신 GPT 경로 부재(codex CLI 미설치/미로그인·opencodex 프록시 미가동)" 또는 "codex 인증 만료")'),
 # :81 실증 provenance — 역사 기록이므로 당시 사실 유지 + 현행 캐리어 부기
 ('- **경로 B**: `claude --model gpt-5.6-sol -p` 헤드리스가 CLIProxy Plus(핀 7.2.62-5) 경유 GPT 응답, `modelUsage`에 `gpt-*` 확인.',
  '- **경로 B**: (C11 당시) `claude --model gpt-5.6-sol -p` 헤드리스가 CLIProxy Plus(핀 7.2.62-5) 경유 GPT 응답, `modelUsage`에 `gpt-*` 확인. **C20(2026-08-11) 캐리어 이관 후 실측**: `OCX_MODEL=gpt-5.6-sol claude-ocx -p --output-format json` → `modelUsage` 키 `gpt-5.6-sol`·`is_error:false`(판별자 불변).'),
]
for old,new in subs:
    ob,nb=old.encode('utf-8'),new.encode('utf-8')
    assert b.count(ob)==1, ('anchor', old[:40], b.count(ob))
    b=b.replace(ob,nb)
io.open(p,'wb').write(b); print('ok 4 subs')
PY
```

- [ ] **Step 4: SKILL.md 정본 + 미러 이관 (동일 문자열 — 2파일)**

```bash
python - <<'PY'
import io
old='B: `claude --model <gpt-모델> -p --output-format json`의 `modelUsage`에 `gpt-*`'
new='B: `OCX_MODEL=<gpt-모델> ~/.claude/bin/claude-ocx -p --output-format json`의 `modelUsage`에 `gpt-*`'
for p in ['skills/closeout-pr-cycle/SKILL.md','opencode-harness/skill/closeout-pr-cycle/SKILL.md']:
    b=io.open(p,'rb').read(); ob,nb=old.encode('utf-8'),new.encode('utf-8')
    assert b.count(ob)==1, (p, b.count(ob))
    io.open(p,'wb').write(b.replace(ob,nb)); print('ok', p)
PY
```

- [ ] **Step 5: GREEN — 전파 완결 확인**

```bash
# 기계 판정: 허용 사이트(:81 역사 인용 1건)를 제외한 잔존이 0 이어야 한다.
REMAIN=$(grep -rn -e ANTHROPIC_CUSTOM_MODEL_OPTION -e 'claude --model' \
  docs/ai-context/cross-family-review.md \
  skills/closeout-pr-cycle/SKILL.md \
  opencode-harness/skill/closeout-pr-cycle/SKILL.md \
  | grep -v '^docs/ai-context/cross-family-review.md:81:')
echo "$REMAIN"
echo "허용분 제외 잔존: $(printf '%s' "$REMAIN" | grep -c . )"
# :81 은 C11 당시 실증 기록(역사)이라 리터럴 보존이 의도된 것 — 정확히 1건이어야 한다.
echo ":81 역사 인용: $(grep -c 'CLIProxy Plus' docs/ai-context/cross-family-review.md)"
bash setup/verify-setup.sh 2>&1 | tail -1
```
Expected: `허용분 제외 잔존: 0` · `:81 역사 인용: 1` · verify-setup `FAIL=0`. 어느 하나라도 어긋나면 FAIL(눈 판정 아님).

- [ ] **Step 6: Commit**

```bash
git add docs/ai-context/cross-family-review.md skills/closeout-pr-cycle/SKILL.md opencode-harness/skill/closeout-pr-cycle/SKILL.md
git commit -m "fix(c20): 교차패밀리 경로 B 캐리어 CCS→opencodex 이관 (T11, spec §19.2)"
```

---

### Task 4: 브리지 자산 git 추적 + 설치 안내 정규화 (N1·N2·T10)

**Files:**
- Add(track): `bin/claude-ocx`, `bin/claude-ocx.cmd`
- Modify: `setup/install.sh` (REQUIRED 배열 + STEP 안내)
- Modify: `README.md:320` (T10 — "비추적" 거짓 정정) + 브리지 절 신설

**Interfaces:**
- Consumes: **Task 2 의 README:522 정정 산출물**. Step 4 의 절 삽입 앵커는 `- 잔여 위험·모델 트래픽 경로(네이티브 직결·브리지 실행)·…` 로, **Task 2 Step 3 이 만들어야 존재한다**(정정 전 원문은 `- 잔여 위험·CCS 프록시 의존·…`). 실측: 정정 전 상태에서 T4 앵커 count=**0**, T2 앵커 count=**1**. **T2 를 건너뛰면 T4 Step 4 가 AssertionError 로 중단된다.**
- Produces: `bin/claude-ocx` 를 **추적 자산**으로 만든다 → Task 3 이 이 경로를 참조. **Task 3 보다 먼저 실행.**
- **실행 순서 제약: T2 → T4 → T3.**

**배경:** spec §19.1. 브리지는 현재 미추적이라 신규 환경에서 재현 불가. 자동 설치는 금지(`cross-family-review.md:15`)이므로 **자산 동봉 + 안내 문서**로 정규화한다. 또 `README.md:320` 이 ccs-delegation 을 "비추적"이라 하는데 실제로는 추적 심링크(mode 120000)다.

- [ ] **Step 1: RED — 현재 미추적/거짓 서술 확인**

```bash
cd ~/.claude
git ls-files bin/ | wc -l                        # 0 기대
git ls-files -s skills/ccs-delegation            # 120000 = 추적 심링크
grep -n "비추적" README.md | head -3
```
Expected: `0` / `120000 … skills/ccs-delegation` / `:320` 매칭(둘이 모순 = T10).

- [ ] **Step 2: 브리지 자산 추적 + 실행권한**

```bash
chmod +x bin/claude-ocx
git add bin/claude-ocx bin/claude-ocx.cmd
git ls-files -s bin/
```
Expected: 2행. `bin/claude-ocx` 는 `100755`.

- [ ] **Step 3: install.sh — REQUIRED 배열에 브리지 추가 + STEP 안내**

```bash
python - <<'PY'
import io
p='setup/install.sh'
b=io.open(p,'rb').read()
old='  "$TARGET/setup/doctor.sh"'.encode('utf-8')
new='  "$TARGET/bin/claude-ocx"\n  "$TARGET/setup/doctor.sh"'.encode('utf-8')
assert b.count(old)==1, ('req', b.count(old))
b=b.replace(old,new)

old2='echo "  [STEP 4] 첫 사용 (선택)"'.encode('utf-8')
new2=('echo "  [STEP 4] (선택) 브리지 실행 — 하네스는 그대로, 추론만 GPT/Gemini 로"\n'
      'echo "           하네스 훅·RPI 게이트를 유지한 채 비-Anthropic 모델로 돌리려면"\n'
      'echo "           로컬 opencodex 프록시가 필요합니다. 이 설치 스크립트는 외부 도구를"\n'
      'echo "           설치하지 않습니다(의식적 정책 — 인증 사고 이력, SECURITY.md 참조)."\n'
      'echo "           준비 순서는 README의 \\"브리지 실행\\" 절을 보고 직접 수행하세요:"\n'
      'echo "             1) codex CLI 로그인  2) opencodex 설치·서비스 등록  3) ocx status 확인"\n'
      'echo "           준비되면:  ~/.claude/bin/claude-ocx -p \\"Reply: OK\\""\n'
      'echo\n'
      'echo "  [STEP 5] 첫 사용 (선택)"').encode('utf-8')
assert b.count(old2)==1, ('step', b.count(old2))
io.open(p,'wb').write(b.replace(old2,new2)); print('ok')
PY
bash -n setup/install.sh && echo "syntax OK"
```

- [ ] **Step 4: README — T10 정정 + 브리지 절 신설**

```bash
python - <<'PY'
import io
p='README.md'
b=io.open(p,'rb').read()
old='ccs-delegation(로컬 정션·비추적 — CCS CLI 위임용, 하네스 게이트와 무관)'.encode('utf-8')
new='ccs-delegation(git 추적 심링크 mode 120000 — CCS CLI 위임용, 하네스 게이트와 무관)'.encode('utf-8')
assert b.count(old)==1, ('t10', b.count(old))
b=b.replace(old,new)

anchor='- 잔여 위험·모델 트래픽 경로(네이티브 직결·브리지 실행)·자격증명 처리·secret-scan 한계'.encode('utf-8')
assert b.count(anchor)==1, ('anchor', b.count(anchor))
section=('''## 브리지 실행 (선택) — 하네스는 유지, 추론만 다른 모델

`bin/claude-ocx` 는 **Claude Code 프로세스로 실행하되 추론만 비-Anthropic 모델에 위임**한다.
훅·CLAUDE.md·RPI 게이트가 그대로 발화하므로, 교차패밀리 리뷰(독립성 목적으로 하네스 *밖*에서
별도 CLI 를 부르는 것)와는 목적이 반대다.

**하네스는 외부 도구를 설치하지 않는다**(의식적 정책 — 인증 공유 사고 이력, `SECURITY.md`).
아래는 *권고 순서*이며 각 단계는 사용자가 직접 수행한다.

1. **codex CLI 로그인** — opencodex 의 `openai` provider 는 `authMode=forward` 라
   codex 인증(`~/.codex/auth.json`)을 전달한다. **이 순서를 뒤집으면** provider 가
   설정된 것처럼 보이는데 401 이 난다.
2. **opencodex 설치 + 서비스 등록** — 재부팅 생존이 필요하면 서비스로 등록한다.
3. **확인** — `ocx status` 로 포트(기본 10100)와 provider 를 본다.
4. **사용** — `~/.claude/bin/claude-ocx -p "Reply: OK"` · 모델은 `OCX_MODEL` 로 지정
   (기본 `gpt-5.6-sol`).

**설계 불변식 3가지**

| # | 불변식 | 왜 |
|---|---|---|
| ① | CC **프로세스**로 실행 | 훅·게이트가 그대로 적용된다 |
| ② | 네이티브 별칭 `unset`(`ANTHROPIC_MODEL`·`ANTHROPIC_DEFAULT_*`) | 프록시가 모르는 별칭이 남으면 라우팅이 깨진다 |
| ③ | `/healthz` 실패 시 **exit 1** | 조용히 네이티브로 새면 "GPT 로 돌렸다"가 거짓이 된다 |

**Windows 런처**(`bin/claude-ocx.cmd`) 주의 3가지 — PowerShell/cmd 의 bare `bash` 는 WSL 런처로
해석되므로 Git Bash 절대경로를 쓰고, npm `claude` shim 이 coreutils 를 필요로 하므로 **로그인 셸
`-lc`** 로 부르며, `.cmd` 주석은 **영문만**(한글은 mojibake 로 깨져 명령으로 실행된다).

''').encode('utf-8')
io.open(p,'wb').write(b.replace(anchor, section+anchor)); print('ok')
PY
```

- [ ] **Step 5: GREEN — 추적·구문·서술 확인**

```bash
echo "추적 자산: $(git ls-files bin/ | wc -l)"                    # 2 기대
echo "T10 잔존: $(grep -c '로컬 정션·비추적' README.md)"           # 0 기대
echo "브리지 절: $(grep -c '브리지 실행 (선택)' README.md)"        # 1 기대
bash -n setup/install.sh && echo "install.sh syntax OK"
# N2 기계 판정: 외부 도구를 *실행*하는 줄이 0 이어야 한다.
# echo 로 시작하는 안내 줄은 실행이 아니므로 제외한다(spec §19.6 N2 표적 = 설치 실행).
EXEC_HITS=$(grep -nE 'opencodex|ocx |codex login' setup/install.sh | grep -vE ':\s*echo ')
echo "외부도구 실행 줄: $(printf '%s' "$EXEC_HITS" | grep -c .)"
bash setup/verify-setup.sh 2>&1 | tail -1
```
Expected: `추적 자산: 2` · `T10 잔존: 0` · `브리지 절: 1` · syntax OK · **`외부도구 실행 줄: 0`** · verify-setup `FAIL=0`. 모두 기계 판정이며 하나라도 어긋나면 FAIL.

- [ ] **Step 6: Commit**

```bash
git add bin/claude-ocx bin/claude-ocx.cmd setup/install.sh README.md
git commit -m "feat(c20): 브리지 실행 자산 git 추적 + 설치 안내 정규화 (N1·N2·T10)"
```

---

### Task 5: Orca 모드팩 1개 착륙

**Files:**
- Create: `modes/orca-rpi-implement.json`

**Interfaces:**
- Consumes: 없음
- Produces: `modes/*.json` 을 **Task 6 오라클의 검사 대상**으로 제공. 오라클보다 먼저 실행(vacuous seal 방지 — spec §19.3).

**배경:** spec §19.3. 오라클만 착륙하면 검사 대상 0 = vacuous. 모드팩 1개를 동시 착륙시킨다. 워커 커맨드의 모델 티어가 오라클 검사 표적이다.

- [ ] **Step 1: 모드팩 작성**

```bash
mkdir -p modes
cat > modes/orca-rpi-implement.json <<'JSON'
{
  "modeName": "rpi-implement",
  "displayName": "RPI Implement (harness-governed)",
  "coordination": "coordinator-workers",
  "coordinator": {
    "role": "orchestrator",
    "agent": "claude",
    "command": "claude --model opus"
  },
  "workers": [
    {
      "role": "implementer",
      "agent": "claude",
      "model": "opus",
      "command": "claude --model opus"
    },
    {
      "role": "verifier",
      "agent": "claude",
      "model": "opus",
      "ownership": "review-only",
      "command": "claude --model opus"
    }
  ],
  "worktreePolicy": "per-worker"
}
JSON
node -e 'JSON.parse(require("fs").readFileSync("modes/orca-rpi-implement.json","utf8")); console.log("JSON valid")'
```

- [ ] **Step 2: 스키마 required 충족 확인**

```bash
node - <<'JS'
const fs=require('fs');
const m=JSON.parse(fs.readFileSync('modes/orca-rpi-implement.json','utf8'));
const top=["modeName","displayName","coordination","coordinator","workers","worktreePolicy"];
const w=["role","agent","command"];
const missTop=top.filter(k=>!(k in m));
const missW=m.workers.map((x,i)=>w.filter(k=>!(k in x)).map(k=>`worker[${i}].${k}`)).flat();
console.log("missing top:", missTop.length?missTop:"none");
console.log("missing worker:", missW.length?missW:"none");
process.exit(missTop.length+missW.length?1:0);
JS
```
Expected: `none` / `none`, exit 0.

- [ ] **Step 3: Commit**

```bash
git add modes/orca-rpi-implement.json
git commit -m "feat(c20): Orca 모드팩 rpi-implement 착륙 (오라클 검사 대상)"
```

---

### Task 6: 모드팩 L3 정책 오라클

**Files:**
- Create: `setup/lib/modepack-oracle.sh`

**Interfaces:**
- Consumes: Task 5 의 `modes/*.json`
- Produces: `modepack_oracle_scan <dir>` — stdout 에 `TOTAL=<n> LITERAL=<n> DYNAMIC=<n> VIOLATION=<n>` 1행, 위반 상세는 stderr. exit 0=위반없음 / 1=위반. Task 7 이 이 계약에 배선.

**배경:** spec §19.3. 워커 커맨드의 모델 티어를 **3값 계약**(리터럴 / `-`=부재 / `*`=동적)으로 판정한다. 면제(`*`/`-`)는 침묵이 아니라 **계수**한다.

**정책:** `ownership: "review-only"` 워커는 판단-게이트이므로 floor = `max(작업자, opus)`. 이 모드팩에선 작업자가 opus 이므로 검증자도 opus 이상이어야 한다. sonnet/haiku/fable 이면 위반.

- [ ] **Step 1: RED — 오라클 부재 확인 후 위반 픽스처 준비**

```bash
cd ~/.claude
[ -f setup/lib/modepack-oracle.sh ] && echo "이미 존재 — 중단" || echo "부재 확인 OK"
mkdir -p /tmp/mp-red && cp modes/orca-rpi-implement.json /tmp/mp-red/ 2>/dev/null || true
```

- [ ] **Step 2: 오라클 구현**

```bash
mkdir -p setup/lib
cat > setup/lib/modepack-oracle.sh <<'SH'
#!/usr/bin/env bash
# modepack-oracle.sh — L3 정적 오라클: Orca 모드팩 워커의 모델 티어 판정 (C20 spec §19.3).
#
# 왜 L3 인가: 하네스 훅 *자체*는 별도 프로세스(Orca 워커)에도 발화하지만,
# 모델-정책 매처(Rule A/B/C/C2/C3)는 `Agent|Workflow` 도구 호출 한정이라
# (hooks/surface-model-policy.sh:18) CLI `--model` 인자의 티어 선언을 관측하지 못한다.
# 그 선언을 잡을 수 있는 유일한 정적 지점이 모드팩 JSON 이다.
#
# 3값 계약(hooks/lib/workflow-spawns.js 승계): 리터럴 / `-`=부재 / `*`=동적.
# 면제는 안전 인증이 아니라 판정 불가의 정직 표기 → 계수해서 보고한다.

modepack_oracle_scan() {
  local dir="${1:-$HOME/.claude/modes}"
  [ -d "$dir" ] || { echo "TOTAL=0 LITERAL=0 DYNAMIC=0 VIOLATION=0"; return 0; }
  command -v node >/dev/null 2>&1 || { echo "TOTAL=0 LITERAL=0 DYNAMIC=0 VIOLATION=0"; return 0; }

  MP_DIR="$dir" node - <<'JS'
const fs=require('fs'), path=require('path');
const dir=process.env.MP_DIR;
const TIER={haiku:1,sonnet:2,opus:3,fable:4};
let total=0, literal=0, dynamic=0, violation=0; const details=[];

let files=[]; try{ files=fs.readdirSync(dir).filter(f=>f.endsWith('.json')); }catch(e){}
for(const f of files){
  let m; try{ m=JSON.parse(fs.readFileSync(path.join(dir,f),'utf8')); }catch(e){
    details.push(`${f}: JSON 파싱 실패 — ${e.message}`); violation++; continue;
  }
  const workers=Array.isArray(m.workers)?m.workers:[];
  // 작업자 티어 = review-only 아닌 워커들의 최댓값
  let workerTier=0;
  for(const w of workers){
    if((w.ownership||'')==='review-only') continue;
    const t=tierOf(String(w.command||''));
    if(t.kind==='literal' && TIER[t.model]>workerTier) workerTier=TIER[t.model];
  }
  const floor=Math.max(workerTier, TIER.opus);   // 판단-게이트 floor = max(작업자, opus)

  for(let i=0;i<workers.length;i++){
    const w=workers[i]; total++;
    const t=tierOf(String(w.command||''));
    if(t.kind!=='literal'){ dynamic++; continue; }
    literal++;
    if((w.ownership||'')==='review-only' && TIER[t.model]<floor){
      violation++;
      details.push(`${f}: workers[${i}] (role=${w.role||'?'}) review-only 인데 ${t.model}(tier ${TIER[t.model]}) < floor ${floor}`);
    }
  }
}
function tierOf(cmd){
  if(!cmd.trim()) return {kind:'absent'};
  // 문자 클래스에 $ { } % 포함 — 없으면 `--model $VAR` 가 매칭 자체에 실패해
  // absent 로 떨어지고 아래 동적 판정이 죽은 코드가 된다(3값 계약 붕괴).
  const mm=cmd.match(/--model[= ]+"?([A-Za-z0-9._${}%()-]+)"?/);
  if(!mm) return {kind:'absent'};                       // `-` : 선언 부재(상속)
  const raw=mm[1].toLowerCase();
  if(/[${}%]/.test(raw)) return {kind:'dynamic'};       // `*` : 셸/env 확장
  for(const k of Object.keys(TIER)) if(raw.includes(k)) return {kind:'literal', model:k};
  return {kind:'dynamic'};                              // 미지 리터럴 = 판정 불가
}
process.stdout.write(`TOTAL=${total} LITERAL=${literal} DYNAMIC=${dynamic} VIOLATION=${violation}\n`);
if(details.length) process.stderr.write(details.map(d=>'  '+d).join('\n')+'\n');
process.exit(violation?1:0);
JS
}
SH
bash -n setup/lib/modepack-oracle.sh && echo "syntax OK"
```

- [ ] **Step 3: GREEN — 정상 모드팩은 위반 0**

```bash
source setup/lib/modepack-oracle.sh
modepack_oracle_scan "$HOME/.claude/modes"; echo "exit=$?"
```
Expected: `TOTAL=2 LITERAL=2 DYNAMIC=0 VIOLATION=0`, `exit=0`.

- [ ] **Step 4: RED 실증 — 판별력 확인(위반 픽스처)**

```bash
mkdir -p /tmp/mp-bad && python -c "
import json,io
m=json.load(io.open('modes/orca-rpi-implement.json'))
m['workers'][1]['command']='claude --model sonnet'   # review-only 를 floor 미만으로
json.dump(m, io.open('/tmp/mp-bad/bad.json','w'), ensure_ascii=False, indent=2)
print('fixture written')
"
modepack_oracle_scan /tmp/mp-bad; echo "exit=$?"
```
Expected: `VIOLATION=1`, `exit=1`, stderr 에 `review-only 인데 sonnet(tier 2) < floor 3`.
**이 RED 가 안 나오면 오라클이 vacuous 하다 — 중단하고 보고.**

- [ ] **Step 5: 동적 계수 확인(면제=침묵 아님)**

```bash
mkdir -p /tmp/mp-dyn && python -c "
import json,io
m=json.load(io.open('modes/orca-rpi-implement.json'))
m['workers'][1]['command']='\$HOME/.claude/bin/claude-ocx.cmd'   # --model 부재
json.dump(m, io.open('/tmp/mp-dyn/dyn.json','w'), ensure_ascii=False, indent=2)
"
modepack_oracle_scan /tmp/mp-dyn; echo "exit=$?"
rm -rf /tmp/mp-bad /tmp/mp-dyn /tmp/mp-red
```
Expected: `DYNAMIC=1`(계수됨), `VIOLATION=0`, `exit=0`.

- [ ] **Step 6: Commit**

```bash
git add setup/lib/modepack-oracle.sh
git commit -m "feat(c20): 모드팩 L3 정책 오라클 (3값 계약·review-only floor)"
```

---

### Task 7: verify-setup seal 배선 + 카운트 동기

**Files:**
- Modify: `setup/verify-setup.sh` (신규 seal 1개 추가)
- Modify: `README.md` ("현재 N PASS" 동기)

**Interfaces:**
- Consumes: Task 6 의 `modepack_oracle_scan` 계약
- Produces: 없음(최종 task)

**배경:** 카운트 seal(`verify-setup.sh` 말미)이 `README "현재 N PASS"` 와 런타임 실측 일치를 강제한다. seal 추가 시 README 동기가 필수다.

- [ ] **Step 1: 신규 seal 번호 실측 발급**

```bash
cd ~/.claude
git fetch origin master -q 2>/dev/null || true
grep -oE '^# [0-9]+\.' setup/verify-setup.sh | grep -oE '[0-9]+' | sort -n | tail -1
```
→ 출력값 +1 이 신규 번호. 아래 `<N>` 을 그 값으로 치환한다(spec §6: closeout 직전 실측 발급).

- [ ] **Step 2: seal 추가**

```bash
python - <<'PY'
import io,re
p='setup/verify-setup.sh'
b=io.open(p,'rb').read()
nums=[int(x) for x in re.findall(rb'(?m)^# (\d+)\.', b)]
N=max(nums)+1
anchor='#     이 시점까지의 PASS+FAIL+1(이 체크 자신) == README "(현재 N PASS)" 선언.'.encode('utf-8')
assert b.count(anchor)==1, ('anchor', b.count(anchor))
seal=(f'''# {N}. 모드팩 L3 정책 오라클 (C20 spec §19.3) — 프로세스-경계 정책 공백의 유일한 정적 지점.
#     모델-정책 매처(Rule A/B/C)는 Agent|Workflow 한정이라 Orca 워커의 CLI --model 을 못 본다.
MP_ORACLE="$HOME/.claude/setup/lib/modepack-oracle.sh"
if [ -f "$MP_ORACLE" ]; then
  # shellcheck source=/dev/null
  . "$MP_ORACLE"
  MP_OUT=$(modepack_oracle_scan "$HOME/.claude/modes" 2>/dev/null); MP_RC=$?
  MP_TOTAL=$(printf '%s' "$MP_OUT" | grep -oE 'TOTAL=[0-9]+' | cut -d= -f2)
  MP_DYN=$(printf '%s' "$MP_OUT" | grep -oE 'DYNAMIC=[0-9]+' | cut -d= -f2)
  if [ "$MP_RC" -eq 0 ] && [ "${{MP_TOTAL:-0}}" -gt 0 ]; then
    ok "모드팩 오라클: 워커 ${{MP_TOTAL}} (동적/면제 ${{MP_DYN:-0}} — 계수됨) 위반 0"
  elif [ "${{MP_TOTAL:-0}}" -eq 0 ]; then
    fail "모드팩 오라클: 검사 대상 0 (modes/*.json 부재 — vacuous seal 방지, spec §19.3)"
  else
    fail "모드팩 오라클: 정책 위반 검출 — review-only 워커가 floor max(작업자,opus) 미만"
  fi
else
  fail "모드팩 오라클 스크립트 부재: setup/lib/modepack-oracle.sh"
fi

'''.encode('utf-8'))
io.open(p,'wb').write(b.replace(anchor, seal+anchor)); print('seal #%d 추가'%N)
PY
bash -n setup/verify-setup.sh && echo "syntax OK"
```

- [ ] **Step 3: RED — README 미동기로 카운트 seal 발화 확인**

```bash
bash setup/verify-setup.sh 2>&1 | tail -3
```
Expected: **카운트 drift FAIL** 1건(`README 선언(88) != 런타임 실측(89)`) — 이것이 seal 이 살아있다는 증거. FAIL=1.

- [ ] **Step 4: GREEN — README 동기**

```bash
python - <<'PY'
import io,re,subprocess
out=subprocess.run(['bash','setup/verify-setup.sh'],capture_output=True,text=True).stdout
m=re.search(r'런타임 실측\((\d+)\)', out)
assert m, out[-500:]
n=m.group(1)
p='README.md'; b=io.open(p,'rb').read()
old=re.search(rb'\xed\x98\x84\xec\x9e\xac \d+ PASS', b)   # "현재 N PASS"
assert old, 'README 선언 미발견'
io.open(p,'wb').write(b.replace(old.group(0), ('현재 %s PASS'%n).encode('utf-8')))
print('README →', n)
PY
bash setup/verify-setup.sh 2>&1 | tail -1
```
Expected: `verify-setup: PASS=89 FAIL=0`(정확한 수는 Step 1 실측에 따름).

- [ ] **Step 5: 전 스위트 회귀 검증**

```bash
bash hooks/tests/run-all.sh 2>&1 | tail -3
bash setup/tests/seal-regression.test.sh 2>&1 | tail -3
```
Expected: run-all `291/291`(불변 — hooks/ 무터치) · seal-regression `26/0`.
※ seal-regression 은 `setup/` diff 가 있으므로 **full 실행 필수**(spec §17.5 ③).

- [ ] **Step 6: Commit**

```bash
git add setup/verify-setup.sh README.md
git commit -m "feat(c20): 모드팩 오라클 seal 배선 + README 카운트 동기"
```

---

## Self-Review

**1. Spec coverage**

| spec §19 규범 | task |
|---|---|
| N1 브리지 자산화 | T4 |
| N2 안내-only(자동설치 금지) | T4 Step 3 |
| N3 경로 B 캐리어 이관 | T3 |
| N4 모드팩 오라클 L3 | T5+T6+T7 |
| N5 Orca 훅 seal 불요 | **task 없음 — 판정이 산출물**(spec §19.4 에 이미 착륙, 코드 변경 없음이 결론) |
| §19.5 floor 재심 | **판정은 spec 착륙 완료**. 처분(게이트 지시문 조항)은 §19.5 가 "Phase P 소관"이라 했으나 **본 plan 은 문안을 신설하지 않는다** — 이유: 지시문 축 보강은 `start-rpi-cycle` SKILL 의 success_criteria 개정이라 **하네스 거버넌스 표면 변경**이고, 이번 사이클의 ADE 주축과 독립이다. **차기 사이클 이월**(next-cycle-goal 에 표면화). |
| T3/T4/T5/T10 문서 정정 | T1·T2·T4 |

**2. Placeholder scan** — TBD/TODO/"적절히" 0건. 모든 코드 스텝이 실행 가능한 명령을 담음. seal 번호만 Step 1 실측 치환(`<N>`)이며 이는 spec §6 규약상 의도된 지연 바인딩.

**3. Type consistency** — 오라클 계약 `modepack_oracle_scan <dir>` → `TOTAL=/LITERAL=/DYNAMIC=/VIOLATION=` + exit code. T6 Step 2 정의 ↔ T7 Step 2 소비 일치 확인.

**4. 의존 순서** — T4(브리지 추적) → T3(브리지 경로 참조) 순서 강제. T5(모드팩) → T6(오라클) → T7(seal) 순서 강제. T1·T2 는 독립.

## 수용 잔여

1. **신규 세션 런타임 검증 미수행** — 경로 B 이관 후 실동작은 신규 세션에서만 확인 가능(세션-동결 env).
2. **§19.5 처분 이월** — 게이트 지시문 조항 신설은 차기 사이클.
3. **오라클 상한** — 손으로 친 `orca worktree create --model sonnet` 은 정적 오라클이 못 본다(의식적 우회, L1 규범 소관).
