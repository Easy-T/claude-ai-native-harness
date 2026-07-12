# hooks/.runlog — 사이클 run-log (GAP-003)

`hooks/.runlog/YYYY-MM.jsonl` — hook 게이트 판정의 구조화 관측 로그. `hooks/.log/*.log`(TSV, 사람용 postmortem)와 병행하며, JSONL은 기계 소비(집계·이상 탐지·향후 예산 계량)용이다. gitignored.

## 발생 경로
`_common.sh`의 `hook_log()` 초크포인트가 `run_log_event()`를 피기백 호출 → hook_log를 부르는 **모든 verdict**(발화·차단·우회·FAILOPEN·active-plan PASS)가 1줄씩 누적. silent `exit 0` 비-verdict 경로·secret-scan clean-pass(고빈도)는 기존 hook_log 설계상 무기록.

## 스키마 (1 이벤트 = 1 줄 JSON, OTel GenAI semconv 정렬)
| 필드 | 의미 | 출처 |
|---|---|---|
| `ts` | ISO-8601 타임스탬프 | `date -Iseconds` |
| `session_id` | 세션 ID | `RL_SID` env (차단 hook이 설정; 비면 "") |
| `gen_ai.tool.name` | 트리거 도구(Write/Edit/Bash 등) | `RL_TOOL` env (rpi-bash="Bash"; 비면 "") |
| `gen_ai.operation.name` | hook 이름 | hook_log arg1 |
| `verdict` | BLOCK / PASS / FAILOPEN / ALERT | hook_log arg3 |
| `target` | 대상 경로·명령·kind | hook_log arg2 |
| `reason` | 판정 사유(`skip:<사유>`=우회 등) | hook_log arg4 |

값은 `_json_escape`로 `\ " 개행/탭/CR` 이스케이프 — 항상 1줄 유효 JSON 불변식.

## 소비
- `runlog_summary <file>` (`_common.sh`): `EVENTS=n BLOCK=n PASS=n SKIP=n FAILOPEN=n ALERT=n` (값 미표시, 카운트만).
- `doctor.sh` 20e: 당월 집계 + 로테이션(≤6 월파일) + `FAILOPEN>0` 시 WARN(파서 크래시 이상 신호).
- `start-rpi-cycle` Step C-1: 하네스 수정 사이클의 사이클 보고에 요약 1줄 포함(관측 가능성).

## 설계 불변식
- **fail-open**: 로깅 실패(`mkdir`/`printf`)는 `|| return 0`·`|| true` — hook 판정에 영향 0.
- **node 무의존**: `run_log_event`·`runlog_summary` 모두 printf/awk만 — 파서 손상 시에도 동작.
- **hermetic 테스트**: `RUNLOG_DIR` env override(기본 `$HOME/.claude/hooks/.runlog`).
