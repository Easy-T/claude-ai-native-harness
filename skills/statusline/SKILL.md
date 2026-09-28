---
name: statusline
description: >-
  Claude Code 커스텀 상태줄(~/.claude/statusline.sh, v3 5-line: 모델/effort ·
  워크스페이스/비용 · 컨텍스트 바 · 5h/7d 레이트리밋 바) 유지보수 orchestrator.
  상태줄을 바꾸거나("상태줄에 X 추가/제거", "색상·아이콘 바꿔줘", "바 길이 조절"),
  고치거나("상태줄 깨졌어", "% 안 맞아", "리밋 바 이상해", "잘려 보여"),
  복원하거나("상태줄 원래대로", "새 PC에 상태줄 설치") 할 때 — statusline/status line/
  상태줄/상태바가 언급되면 항상 이 skill 사용. 하드 제약(1KB 절단, 프록시 창
  과소보고, stdin rate_limits 계약)을 모르고 고치면 조용히 망가지기 때문.
  강제 하네스 아님 — 상태줄 작업이 아닐 땐 무관.
orchestrator_skill: true
generated_by: create-orchestrator-skill
orchestrator_version: 1.0
---

# statusline — 커스텀 상태줄 유지보수

SSOT (복사 금지 — 항상 원본을 읽고 원본을 수정):
- 스크립트: `~/.claude/statusline.sh`
- 테스트: `~/.claude/tests/statusline/run-tests.sh` + `fixtures/` (4종)
- 설계 spec: `~/.claude/docs/superpowers/specs/2026-05-31-statusline-balanced-design.md` (v3 절 · v2.1 corrections 섹션 필독)
- 등록: `~/.claude/settings.json` → `"statusLine": {"type":"command","command":"bash $HOME/.claude/statusline.sh","padding":0}`

# Phase 1 — Load Context

1. 위 SSOT 4개를 읽는다. spec이 설계 결정의 권위, 스크립트가 구현의 권위.
2. 하드 제약 확인 — 이걸 위반한 수정은 화면에서 조용히 깨진다:
   - **출력 총량 raw ≤1000 bytes.** Claude Code가 상태줄 출력을 ~1024바이트에서
     절단한다(터미널 폭 무관). 그래서 mkbar는 run-length ANSI(색이 바뀔 때만 코드
     방출). 테스트에 하드 단언 있음 — 세그먼트를 늘리면 반드시 바이트 재감사.
   - **창 크기 FLOOR 테이블.** CC/프록시가 `context_window_size`를 과소보고
     (base Fable·Opus → 실제 1M인데 200K로 옴). `model.id`의 `[1m]` 접미사 = 1M SSOT.
     gpt 라우팅 슬롯 = GPT-5.6(Sol/Luna) 372k · legacy GPT-5.5/mini 272k (v2.2).
     FLOOR는 올리기만 — 절대 내리지 않는다.
   - **rate_limits 계약 (v3).** L4/L5 데이터는 Claude Code 가 stdin 으로 주는
     `.rate_limits.{five_hour,seven_day}.{used_percentage,resets_at}` 뿐이다(로그인 계정 자체 데이터,
     CC 2.1.283 실측). `resets_at` 은 epoch 초(현행) 또는 ISO8601 문자열을 받는다. 필드가 없으면
     (API 키 인증·구버전·첫 응답 전) `…` placeholder. **자격증명 파일 읽기·네트워크 호출 0 — 추가 금지**
     (테스트 T8 이 봉인).
   - **포그라운드 비용.** ~300ms마다 재실행되므로: 단일 jq pass, epoch/tz는
     `printf '%(%s)T'` 빌트인, 백그라운드 서브셸 없음.
     이모지 폭 주의: ✚✖ 같은 글자는 2칸 렌더되어 숫자와 겹침 → ASCII 사용.

# Phase 2 — Modify

요청 유형별 경로:
- **복원/설치**: `git -C ~/.claude log --oneline -- statusline.sh`로 버전 확인 →
  `git checkout <sha> -- statusline.sh`. 새 환경이면 settings.json에 위 등록 블록 추가
  + `jq` 존재 확인.
- **수정/확장**: spec을 먼저 in-place 개정(개정일+근거 한 줄) → 스크립트 수정 →
  `run-tests.sh`에 새 동작의 단언 추가. 테스트 없는 세그먼트 추가 금지.
- **격상**: 설계가 바뀌는 큰 변경(레이아웃 개편, 새 데이터 소스)은 start-rpi-cycle로
  정식 R→P→I 사이클을 돈다. 이 skill은 그 사이클의 Phase R 컨텍스트 로더로 재사용.

# Phase 3 — Verify

1. `bash ~/.claude/tests/statusline/run-tests.sh` → 마지막 줄 `fail=0` + exit 0 필수.
2. 라이브 렌더 + 바이트 감사:
   `bash ~/.claude/statusline.sh < ~/.claude/tests/statusline/fixtures/base-fable.json | LC_ALL=C wc -c` → ≤1000.
3. 독립 검증 위임:
   Agent(subagent_type="review-strict",
         task="statusline 수정 검증 — 테스트 green + 바이트 예산 + 하드 제약 보존",
         context_paths=["~/.claude/statusline.sh",
                        "~/.claude/docs/superpowers/specs/2026-05-31-statusline-balanced-design.md"],
         success_criteria="run-tests.sh fail=0; 총 출력 ≤1000 bytes; FLOOR 테이블·
           run-length mkbar·자격증명·네트워크 0(T8)·rate_limits 부재 시 placeholder 가 수정 후에도 유지; spec
           개정 기록이 변경과 일치")
4. 실화면 확인을 사용자에게 요청 (이모지 폭·색은 터미널 의존이라 기계 검증 불가).

## Communication Protocol
- result: COMPLETE / FAIL
- evidence: 수정 diff 요약 + 테스트 결과(`pass=N fail=0`) + 바이트 수 + spec 개정 위치
- unknowns: 터미널 렌더링 확인 요청 등 사용자 판단 항목
