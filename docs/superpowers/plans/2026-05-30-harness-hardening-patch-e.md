# Harness Hardening — Patch (E): S12 + doc consistency & user-understanding

**Status:** completed
**RPI-Cycle:** 8
**Started:** 2026-05-30
**Completed:** 2026-05-30
**Result:** verify-all ALL PASS (setup 47/0, unit 68/68, integration 8/8 incl. new E2E.F/G/H); S12 fail-open verified; doc-consistency audit (6-area workflow) resolved

## Provenance (Phase R)
S12 from the 2026-05-29 audit + a 6-area doc-consistency workflow (README/CLAUDE.md/setup
scripts/skills+agents/config/env-discoverability). Findings: 16 stale refs + 18 gaps →
synthesized to 11 deduped doc-fixes + 5 README additions + 2 coverage gaps.

## Tasks
- [x] E1 (S12) `enforce-rpi-cycle.sh` + `enforce-rpi-bash.sh`: empty/missing cwd → fail-OPEN
      (exit 0 + log "no-cwd") instead of resolving to "." (non-deterministic plan resolution).
- [x] E2 README enrichment (user understanding — the main ask):
      (a) `## 🔒 보안 모델` section + link to SECURITY.md (bypassPermissions tradeoff).
      (b) `### 환경 변수 (env knobs)` table: RPI_SKIP / SECRET_SCAN_SKIP / CONTEXT_LIMIT /
          COMPACT_WARN_PCT / CLAUDE_AUTOCOMPACT_PCT_OVERRIDE (효과 + 설정 위치).
      (c) troubleshooting: "Bash 명령이 차단됨(리다이렉션)" + "시크릿 감지로 차단됨(false positive)".
      (d) 멀티 HOME (Windows/WSL) + restart 주의 callout (settings per-HOME).
      (e) `### Hook enforcement 조정`에 자기보호 경고 (.sh 수정엔 active plan 필요).
- [x] E2b README stale fixes: "7개 orchestrator skill"→"6 + 1 contract"; restart NEW-vs-modified
      distinction; whitelist bullet "code ext never dir-exempt" clause; "3-단계"→"4 단계" back-ref.
- [x] E3 other-doc stale fixes: install.sh "hook 5개"→8 + add SECURITY.md to REQUIRED + count(→21);
      execute-strict.md "9개 파일"→"13개"; verify-setup.sh comment "6 meta"→"8" + add SECURITY.md check;
      doctor.sh "(will be created in Task 12)" → real message.
- [x] E4 (coverage) `verify-integration.sh`: add E2E for enforce-rpi-bash, enforce-secret-scan,
      verify-loop-watch (currently only enforce-rpi-cycle + enforce-orchestrator are E2E-tested).
- [x] E5 (LAST, §1 cache) `CLAUDE.md` footer: "200줄 초과 시 doctor.sh가 경고" → verify-setup.sh.
- [x] E6 Closeout: verify-all ALL PASS; plan completed; state 7→8; commit+push.

## Non-goals
- Do NOT edit start-rpi-cycle/SKILL.md frontmatter (low-value, and it's the skill in use);
  its "≤5라인" wording is acceptable. Do NOT bloat CLAUDE.md (§1) — only the 1-line footer fix.
- No new env knobs; no behavior changes beyond S12.

## Acceptance
- `bash -n` clean; verify-all ALL PASS (incl. new E2E); README renders; every changed line traces
  to a finding. CLAUDE.md edit done LAST + minimal (§1).
