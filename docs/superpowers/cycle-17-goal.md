# cycle-17 — Goal Handoff (post-compact 읽기용)

> **[retired 2026-06-12 / cycle-23 — genesis-record]** 역사 기록. F2~F12는 cycle-17(84ad5a7)에서 구현 완료.
> next-cycle-goal 핸드오프는 이후 start-rpi-cycle Communication Protocol 고유 필수 필드(+seal #18)로 이관 —
> 이 파일은 그 필드의 1회성 파일화 선례로만 보존(본문 카운트는 당시 실측, 현재 SSOT 아님).

> 직전: **cycle-16**(커밋 `42836c2`) = F1(`harness-verify` 필드+#19) + ADOPT(`surface-constitution.sh` §5/§8) 완료.
> 이 문서는 `/compact` 후 cycle-17 진입 시 **가장 먼저 읽는 핸드오프**다. (advisory — start-rpi-cycle Closeout next-cycle-goal 산출물의 파일화)
> 범위 = **F2~F11**(직전 재점검 워크플로 wirrmbi91 확정) + **F12**(본 세션에서 발견한 R-phase skill silent-skip).

---

## goal

직전 재점검·세션이 확정한 **회피-불가/위생 결함 묶음**을 구현한다.

### A. 게이트·파서 사이드도어 (F2~F5)
- **F2** — `hooks/enforce-rpi-cycle.sh:31` 화이트리스트의 `*/README*` **prefix-글롭**이 "확장자 기준" 불변식을 깨, `lib/README.sh`·`src/README_helpers.py` 같은 *코드*가 §3 plan 게이트를 우회 → `*/README*.md`·`*/README*.txt` 식 **확장자 기준화**.
- **F3** — `hooks/lib/redirect-targets.js`가 `>`/`>>`/`tee`만 매칭 → **`sed -i`·`cp`/`mv`·`python -c open().write()`** 누락. §3 Bash 사이드도어 부분 봉인 보강(enforce-secret-scan과 동일 맹점 공유 — 같이 점검).
- **F4** — `settings.json` ↔ `settings.example.json` **identity drift** 무가드(verify-setup #14는 hook *개수*만 ≥9 확인). 시크릿 노출 없이 *hook 이름/순서* parity 체크 추가(값 비교 금지).
- **F5** — Closeout이 `state.json` `audit.last_drift_check`를 **무조건 today**로 손기록하나, 그를 정당화하는 sub-step 6(verify-setup)은 *하네스 수정 사이클일 때만* 실행 → 점검 안 해도 "오늘 점검함" 기록 가능. (F1/harness-verify와 한 뿌리 — 조건부 스탬프 또는 harness-verify와 연동.)

### B. 문서 카운트 drift (F7~F11)
- **F7** `skills/start-rpi-cycle/SKILL.md:172` 스키마 경로 `.claude/state.schema.json` → 실제 루트 `state.schema.json`(404).
- **F8** `README.md:277` "현재 46 PASS" → 실제 **55**(cycle-16 후). **F9** `README.md:271,499` cases "79" → **86**(cycle-16 후). **F10** README/spec E2E "5개/4개" → **8**(A–H). **F11** `README.md:26,228` doctor "24개" → 실제 **18** 섹션.
- ※ 카운트는 *cycle-17 시점 실측*으로 다시 확인할 것(이 사이클 변경으로 또 바뀜). 가능하면 verify-setup 체크로 "README 선언 카운트 == 실측" 봉인(재드리프트 방지).

### C. R-phase skill 자가-표면화 (F12 — 본 세션 발견)
- **증상:** cycle-16 Phase R에서 `brainstorming`·`grill-with-docs` skill을 Skill 도구로 호출하지 않음(inline 설계 + `claude-code-guide`로 대체). explore-strict/review-strict 서브에이전트는 호출됨.
- **근본 원인(시스템):** RPI *phase 실행*(어느 skill을 실제 호출했는가)에 **자가-표면 계약이 없다.** `enforce-rpi-cycle`은 plan-FILE 존재(proxy)만 검사 → R-phase skill 호출 여부를 보는 hook/verify/보고필드 0. 유일 산출물 plan 파일은 Plan은 증명해도 Research 하위절차는 증명 못 함. = 재점검 **finding #5**(§3=plan-file proxy) = F1/F6과 동일 "문서상 필수인데 무표면 silent-skip" 클래스. (보조 원인: SKILL.md "메인이 직접 따름" 문구가 "Skill 호출" 대신 "절차 체화"로 읽힘.)
- **수정 방향:** Communication Protocol에 **자가-표면 필수 필드 `phase-skills:`** — 각 Phase에서 호출한 skill을 선언(R: brainstorming/grill-with-docs/explore-strict · P: writing-plans · I: executing-plans|execute-strict|(d) · Gate/Closeout: review-strict). 각 항목은 `invoked` 또는 `skipped: <이유>`. 누락/무사유 skip = 구조적 불완전(harness-verify·next-cycle-goal 선례). 필드 토큰이 SKILL.md 두 곳에 중복되면 #19식 parity 가드.
- **정지점(과설계 주의):** 자가-표면은 skip을 *눈에 띄는 선언*으로 바꿀 뿐 호출을 물리적으로 강제하진 않음(F1 내용-잔여와 동급 수락). "Skill 도구용 PreToolUse hook이 호출을 탐지 가능한가"는 cycle-17 R에서 **평가만** — 가능·저비용일 때만 채택(상태추적·세션상관 복잡하면 advisory 표면으로 충분).
- ※ §4 non-obvious 등록은 **하지 않음** — 그건 실제 프로젝트 작업 중 발생 시 등록하는 절차이고, 전역 하네스 self-dev에는 부적합(사용자 확정).

### success criteria
- `bash ~/.claude/setup/verify-all.sh` → **ALL PASS**.
- 신규 회귀 케이스 green: (F2) 코드명 `README.sh` §3 차단 · (F3) `sed -i app.js`류 차단 · (F4) settings/example hook-이름 parity · (F12) `phase-skills` 필드 parity(있으면).
- README/spec/doctor 카운트가 **cycle-17 실측과 1:1**(가능하면 verify-setup 봉인).
- `phase-skills:` 필드가 Communication Protocol에 존재하고 SKILL.md 절차↔계약 parity green.
- cycle-17 자체가 `harness-verify`=PASS 증거 + `phase-skills` 선언으로 **dogfood**.

---

## read-before (존재하는 절대경로만)
- `C:\Users\12132\.claude\docs\superpowers\specs\2026-06-04-non-bypassable-rule-surfacing-design.md` — F1/ADOPT durable spec. **F12는 이 spec의 확장(D-F12 추가)** 후보; F2~F11 일부는 spec-less 소수정 또는 별도 판단(cycle-17 R에서 결정).
- `C:\Users\12132\.claude\docs\superpowers\plans\2026-06-04-non-bypassable-rule-surfacing.md` — cycle-16 plan(직전 작업 맥락).
- `C:\Users\12132\.claude\projects\C--Users-12132--claude\memory\project_non_bypassable_rule_surfacing.md` — cycle-16 요약 + F2~F11/F12 목록.
- `C:\Users\12132\.claude\projects\C--Users-12132--claude\memory\project_harness_ssot_drift_guard.md` — #17/#18/#19 패턴(새 카운트-봉인 체크의 선례).
- `C:\Users\12132\.claude\hooks\enforce-rpi-cycle.sh` (F2) · `C:\Users\12132\.claude\hooks\lib\redirect-targets.js` (F3) · `C:\Users\12132\.claude\hooks\_common.sh`(CODE_EXTS).
- `C:\Users\12132\.claude\setup\verify-setup.sh` (#14·신규 카운트 봉인) · `C:\Users\12132\.claude\settings.example.json` (F4).
- `C:\Users\12132\.claude\skills\start-rpi-cycle\SKILL.md` (F7 스키마 경로 · F12 Phase R 문구·Communication Protocol) · `C:\Users\12132\.claude\README.md` (F8~F11) · `C:\Users\12132\.claude\CLAUDE.md` §3.
- ※ `docs/ai-context/*`(CONTEXT.md·architecture.md·non-obvious.md 등)는 하네스 루트에 **부재**(init-ai-ready 템플릿만). 어휘 sync·non-obvious는 no-op.

---

## autonomy
F2~F11은 독립·저위험 수정 — 분기마다 멈추지 말고 best-practice로 진행. F12는 설계 결정이 있으니 R(brainstorming→grill→explore)을 **이번엔 실제 Skill 호출로** 수행. 멈춤은 (a) 문서 "정답 카운트" 판단이 모호 (b) redirect 파서 확장이 기존 테스트와 충돌 (c) F12에서 Skill-tool hook 탐지 채택 여부가 비용/복잡도 판단을 요구할 때만.

## scope/spec 메모
F12 = non-bypassable-rule-surfacing durable spec **확장(D-F12)**. F2~F5(게이트/파서)·F7~F11(문서)은 성격이 달라 cycle-17 R에서 (i) 같은 spec에 묶을지 (ii) 별도 소수정으로 spec-less 처리할지 판단. F2~F11을 한 plan에, F12를 그 plan의 한 task군으로 두는 구성이 자연스러움(전부 "회피-불가/위생" 관심사).
