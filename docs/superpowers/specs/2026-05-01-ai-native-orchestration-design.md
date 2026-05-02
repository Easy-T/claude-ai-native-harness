# AI-Native Orchestration Design

**Author:** Easy-T (with Claude)
**Created:** 2026-05-01
**Status:** Implemented (2026-05-01)
**Spec location:** `~/.claude/docs/superpowers/specs/2026-05-01-ai-native-orchestration-design.md`

---

## §0. 개요

### 0.1 목적

`~/.claude/`(글로벌 Claude Code 환경)에 **예측 가능한 오케스트레이션 인프라**를 구축한다. 사용자가 매번 컨텍스트를 챙기거나 룰을 의식하지 않아도, 시스템이 강제적으로 일관된 워크플로우를 강요한다. 결과적으로:

1. AI가 **혼자 일관성 있게** 일하도록 보장
2. **사이클이 돌수록 강해지는** 컨텍스트 자산 누적
3. **사고 패턴은 시스템이 차단** (사람이 검토 단계에 끼어들지 않음)

### 0.2 배경 — 4개의 비교 기준

이 디자인의 모든 결정은 4개 기준 자료의 합의를 따른다.

#### (A) 강의 자료 — *AI-Ready Codebase* (Fast Campus, 실별개발자)

핵심 인용:
- *"AI를 쓰는 사람 vs 지휘하는 사람 격차가 100배까지 벌어진다."*
- *"AI-Ready란 AI가 읽기 좋은 문서가 아니라 검증된 문맥 인프라."*
- *"썩어가는 컨텍스트는 없는 것보다 나쁘다."*
- *"Hook = 거부권. Amazon이 했어야 하는 것 — 사인오프 제도가 아니라 두 사고의 패턴을 deny list에 박는 것."*
- *"Active Optimization은 잊어버린다. Passive(시스템이 강제)가 게임 체인저."*

Meta 사례 — 데이터 파이프라인 4 리포 / 3 언어 / 4,100 파일에 25~35줄짜리 CLAUDE.md 59개로 매핑. 작업시간 2일 → 30분, 품질 점수 3.65 → 4.20.

#### (B) AI 개발자 성숙도 4단계

| 단계 | 정의 |
|---|---|
| AI Aware | 도구의 존재만 알고 사용 안 함 |
| AI Enabled | 보조 도구로 활용, 개발자가 코드 주인 |
| AI Maximalist | AI에게 작업 위임, 3개 인스턴스 동시 실행 |
| **AI Native** | AI가 사고 흐름과 분리 불가능, 사용자는 Orchestrator로 작동 |

이 디자인의 목표는 **AI Native 단계로의 이행을 시스템적으로 강제**하는 것이다.

#### (C) Anthropic / 업계 베스트 프랙티스

직접 검증한 자료:
- [Anthropic Claude Code sub-agent docs](https://code.claude.com/docs/en/sub-agents) — `model: inherit`, `skills:` 필드, sub-agent는 sub-agent를 spawn 못 함
- [VILA-Lab/Dive-into-Claude-Code](https://github.com/VILA-Lab/Dive-into-Claude-Code) — *"Claude Code 코드의 1.6%만 AI 결정 로직, 98.4%는 결정론적 인프라"*
- [Google SRE — Postmortem Culture](https://sre.google/sre-book/postmortem-culture/) — *"Human error is a symptom, not a cause"*
- [Microsoft Azure ADR](https://learn.microsoft.com/en-us/azure/well-architected/architect-role/architecture-decision-record) — Append-only Decision Log
- [Eric Evans — Domain-Driven Design](https://martinfowler.com/bliki/UbiquitousLanguage.html) — Ubiquitous Language로서의 Glossary
- [Cortex — Runbook vs Playbook](https://www.cortex.io/post/runbooks-vs-playbooks) — Runbook = 운영, Playbook = 조정, Work Plan = 프로젝트 일회성

#### (D) 현재 환경 진단 (2026-05-01)

| 도구 | 상태 |
|---|---|
| Claude Code | 2.1.126 ✓ |
| node | v24.13.1 ✓ |
| git | 2.47.1 (Windows MSYS) ✓ |
| gh CLI | 2.89.0 ✓ + 인증 완료 (Easy-T) |
| python | 3.14.3 ✓ |
| bash | 5.2.37 (MSYS Git Bash) ✓ |
| jq | 미설치 — `doctor.sh`가 자동 설치 |
| 기존 글로벌 컴포넌트 | superpowers, context7, skill-creator, playwright, claude-md-management 플러그인 / `ccs-delegation` 커스텀 skill |

### 0.3 정체성 — 이 시스템이 해결하는 것 / 하지 않는 것

**해결하는 것**:
- 컨텍스트 일관성 (모든 세션이 같은 prefix로 시작)
- 작업 절차의 결정론화 (R → P → I → Closeout 강제)
- 실패 패턴의 자산화 (5 Whys 통과 항목만 누적, 사이클이 돌수록 강해짐)
- 사고 패턴의 자동 차단 (deny list + hook)
- 환경 의존성의 자가 진단·치료 (`doctor.sh`)

**해결하지 않는 것** (§9 미해결로 분리):
- 백그라운드 cron job (강의의 "자고 있을 때 브리핑")
- LLM 기반 의미 검증 (fitness function 자동화)
- 글로벌 사이클 통계 분석 / ML 기반 임계 학습

### 0.4 핵심 결정 (요약)

| 결정 | 이유 |
|---|---|
| **Path β — wrapper agent 3개** | 빌트인 Explore/Plan/general-purpose에 "표준 contract"를 강제하기 위해 얇은 wrapper 도입. `model: inherit` + `skills: [common-agent-contract]` 자동 주입 |
| **D2 — 모든 커스텀 skill을 orchestrator 패턴으로 강제** | 사용자가 만드는 모든 skill이 `create-orchestrator-skill`로 생성되어 sub-agent 호출 골격을 자동 보유 |
| **1 + 3 — 명시 호출 + Hook 강제** | 평소엔 `create-orchestrator-skill` 명시 호출, hook이 안전망 (`orchestrator_skill: true` 마커로 결정론적 차단) |
| **RPI Cycle 강제 — `start-rpi-cycle` skill** | Research → Plan → Implement → Closeout 4단계. enforce-rpi-cycle hook이 plan 부재 시 코드 변경 차단 |
| **`doctor.sh` 통합 진단·치료** | install-deps와 verify-env를 합쳐 단일 진입점. `/init-ai-ready` Phase 0에서 자동 호출 |
| **Bash hook + node JSON 파싱** | 시작 시간 ~85ms (업계 표준 PreToolUse 임계 100ms 이하). jq 미의존 (Claude Code 런타임의 node 활용) |

### 0.5 단계적 도입 — 처음부터 모든 걸 만들지 않는다

| 단계 | 시점 | 도입 항목 |
|---|---|---|
| **Day 0 (셋업)** | 즉시 | 글로벌 인프라 전체 + Hook 5개 + RPI 강제 모드 즉시 활성 |
| **Cycle 5 도달** | 첫 5번의 RPI 사이클 완료 후 | Non-Obvious v2 (재발 카운터 자동 갱신) — 사용자 승인형 알림 |
| **Cycle 20 도달** | 20번 누적 | Non-Obvious v3 (자동 deny 승격 권고) — 사용자 승인형 알림 |
| **(미정)** | 데이터 모인 후 | Agent memory 활용 / Fitness function 자동 작성 |

이 디자인은 Day 0의 인프라만 정의한다. v2/v3는 §5에서 명세, 도입은 트리거 시점.

### 0.6 위험과 완화

| 위험 | 완화 |
|---|---|
| Hook의 false positive로 작업 차단 | `RPI_SKIP=<reason>` 명시 우회 + `CLAUDE_CODE_HOOKS=disabled` 셸 환경변수 |
| 글로벌 인프라 셋업 중 실패 | `doctor.sh`가 `~/.claude.backup-YYYY-MM-DD/` 자동 생성. `git reset --hard`로 즉시 롤백 |
| Skill description 매칭 실패 | 슬래시 커맨드(`/init-ai-ready`)와 명시 Skill 도구 호출 둘 다 제공 |
| 사용자가 모든 강제를 우회 (시스템 무력화) | 시스템은 통제권을 사용자에게 주는 게 원칙. 우회는 명시적이어야 (env / 설정 파일 / 코멘트) |
| `~/.claude` 자체의 drift | `session-start-audit` hook + `/init-ai-ready` Phase 0 통합 점검 |
| Claude Code 업데이트로 인한 호환성 깨짐 | 모든 컴포넌트는 `Claude Code ≥ 2.1.0` 가정. 미래 변경은 `orchestrator_version` 마커로 점진 이행 |

### 0.7 이 문서의 구조

| § | 제목 | 내용 |
|---|---|---|
| 0 | 개요 | (현재 섹션) |
| 1 | 의사결정 요약 | Path β + D2 + 1+3 + RPI 강제 + 6대 메타 룰 |
| 2 | 글로벌 인프라 (`~/.claude/`) | 디렉터리, 인터페이스, frontmatter 규약, agent 3 / skill 4 / hook 5 / command 1 |
| 3 | 프로젝트 템플릿 | 9개 파일 본문 + placeholder + Mustache 형식 |
| 4 | Hook 5개 상세 | 의사코드, settings.json, 운영 정책, 모니터링 |
| 5 | 운영 정책 | Non-Obvious v1/v2/v3, drift, RPI 라이프사이클, 임계값 |
| 6 | 검증 체크리스트 | 환경 / 셋업 / Hook / Skill / E2E |
| 7 | 의존성·빌드 순서 | 13단계 |
| 8 | 단계적 도입 로드맵 | Day 0 / Cycle 5 / Cycle 20 |
| 9 | 미해결·향후 검토 | cron, fitness function, agent memory 등 |
| Appendix | 참조 링크, 인용, 출처 | — |

### 0.8 합의된 원칙

이 디자인 전체에 적용되는 원칙:

1. **Compass not Encyclopedia** — CLAUDE.md는 인덱스, 자세한 건 lazy load
2. **Cycle Strengthens Context** — 매 사이클이 다음 사이클의 prefix를 강화
3. **System Enforces, Not Human** — Passive Optimization (강의 사상)
4. **Sub-agent = Leaf Worker** — 다른 agent를 spawn 못 함, summary-only return
5. **Skill = Orchestrator** — 절차 강제, sub-agent에 위임
6. **Hook = Veto Power** — 결정론적 차단, false positive 시 명시 우회
7. **Append-only for History** — ADR / non-obvious / glossary는 누적, 절대 수정 금지

---

## §1. 의사결정 요약

§0이 "왜"를 다뤘다면, §1은 "무엇을"을 한 페이지에 시각화한다. 모든 결정·트레이드오프·미선택 옵션을 한곳에 모은다.

### 1.1 의사결정 매트릭스 (12개)

| # | 결정 | 선택 | 미선택 옵션 | 핵심 이유 |
|---|---|---|---|---|
| 1 | **Sub-agent 분리 전략** | 메서드 기반 wrapper 3개 (`explore-strict` / `review-strict` / `execute-strict`) | (a) 도메인×메서드 매트릭스 N개 (b) Anthropic 빌트인 직접 사용 | 단순성 + Contract 자동 주입 (`skills:` 필드) |
| 2 | **Sub-agent 모델** | `model: inherit` (메인 세션 모델 상속) | (a) 빌트인 Explore의 Haiku 강제 (b) 작업별 다른 모델 | 모델 차이로 인한 행동 분기 제거. 일관성 우선 |
| 3 | **공통 Contract 형식** | skill (`common-agent-contract`) — agent의 `skills:` 필드로 자동 주입 | 공유 마크다운 (`agents/_contract.md`) | Anthropic 표준 메커니즘 사용 |
| 4 | **Custom skill 강제 패턴** | 모든 커스텀 skill을 `create-orchestrator-skill`로 생성 → orchestrator 골격 자동 주입 | 사용자 수동 패턴 따르기 | Passive Optimization (강의 사상) |
| 5 | **Orchestrator skill 식별** | frontmatter 마커 3줄: `orchestrator_skill: true` + `generated_by` + `orchestrator_version` | 디렉터리 분리 / 매직 코멘트 | hook의 결정론적 grep |
| 6 | **Hook 강제 시점** | 1주차부터 차단 모드 (단계적 도입 X) | 경고 → 차단 단계적 | 마커 기반 식별로 false positive 0 |
| 7 | **RPI 강제** | `start-rpi-cycle` skill + `enforce-rpi-cycle` hook (4중: 메타룰·skill·hook·디렉터리) | superpowers brainstorming/writing-plans/executing-plans 직접 사용 | 4개 컨텍스트 자산을 prefix로 자동 주입 |
| 8 | **Hook 화이트리스트** | 비코드 / ≤5라인 / `RPI_SKIP` env | 모든 변경 차단 | trivial change에서 짜증 방지 |
| 9 | **Hook 언어** | Bash 골격 + node `json_get` | 순수 Python / 순수 Node / 순수 Bash + jq | 시작 시간 ~85ms (PreToolUse 임계 ≤100ms 만족) + jq 미의존 (Claude Code의 node 활용) |
| 10 | **환경 진단·치료** | `doctor.sh` 단일 진입점 (`install-deps` + `verify-env` 통합) | 분리된 두 스크립트 | 책임 중복 제거 |
| 11 | **Plan 활성 판별** | (1순위) frontmatter `Status:` (2순위) 미완료 체크박스 | superpowers writing-plans 산출물에 frontmatter 강제 주입 | superpowers 호환성 100% |
| 12 | **Cycle 카운트 영속화** | 프로젝트별 `.claude/state.json` | 글로벌 합산 / env / hook log | v2/v3 트리거가 프로젝트 단위 의미 |

### 1.2 6대 메타 룰 (글로벌 `~/.claude/CLAUDE.md`)

세션 prefix에 자동 로드되는 행동 규약. 각 룰은 메인 세션의 의사결정을 직접 바꾼다.

| § | 룰 | 트리거 | 메인 세션의 행동 |
|---|---|---|---|
| 1 | **Cache Stability** | 루트 CLAUDE.md 수정 요청 | 세션 종료 직전이 아니면 사용자에게 확인 — "캐시 미스 비용 ≈20배" 환기 |
| 2 | **Orchestrator Meta** | 새 커스텀 skill 만들 요청 | `create-orchestrator-skill`로 자동 라우팅 (단순 텍스트 변환은 예외) |
| 3 | **RPI Cycle Mandate** | 변경(기능·버그·리팩) 요청 | `start-rpi-cycle`로 자동 진입, R→P→I→Closeout 순서 (≤5라인 trivial 예외) |
| 4 | **Non-Obvious 등록 절차** | AI 실패 감지 | 5 Whys 통과 후만 `non-obvious.md` 등록. 사람/AI는 root cause 불가 |
| 5 | **ADR 자동 트리거** | 아키텍처 영향 변경 | `architecture.md`에 ADR append (수정 금지, supersede만) |
| 6 | **Domain Glossary 의미 확인** | 새 도메인 용어 인지 | confidence < 80%면 사용자에게 확인 → glossary 자동 추가 |

### 1.3 호출 흐름 다이어그램

```
사용자 입력
    │
    ├─ "/init-ai-ready <name>"        →  Phase 0~4 부트스트랩
    │
    ├─ "프로젝트 셋업해줘"             →  Skill description 매칭 → init-ai-ready-project
    │
    ├─ "<X> 추가/수정/구현해줘"        →  메타룰 §3 → start-rpi-cycle (R→P→I→C)
    │     │
    │     ├─ Phase R                   →  explore-strict + brainstorming
    │     ├─ Phase P                   →  writing-plans (산출물: plans/*.md)
    │     ├─ Phase I                   →  executing-plans 또는 execute-strict
    │     │     │
    │     │     └─ enforce-rpi-cycle  ─→  active plan 검증 (없으면 차단)
    │     │
    │     └─ Phase Closeout            →  review-strict (drift 검사) → state.json cycle++ → (5/20 도달시) v2/v3 알림
    │
    ├─ "이거 자주 쓸 것 같아 skill로"  →  메타룰 §2 → create-orchestrator-skill
    │     │
    │     └─ skill-creator 호출 후 골격 주입 + orchestrator 마커 자동 추가
    │           │
    │           └─ enforce-orchestrator ─→  marker 있으면 골격 검증 (Phase ≥3, Agent ≥1, Contract 존재)
    │
    ├─ 직접 코드 변경                  →  enforce-rpi-cycle 차단 (active plan 없으면)
    │
    ├─ DROP TABLE / rm -rf 등 위험 패턴  →  pre-commit-deny.sh 차단
    │
    ├─ 컨텍스트 사용 ≥40%             →  auto-compact-watch 알림
    │
    ├─ 루트 CLAUDE.md 수정             →  stable-claude-md 알림
    │
    └─ 새 세션 시작 + 30일 audit 경과   →  session-start-audit 알림
```

### 1.4 책임 매트릭스 (Who Does What)

| 컴포넌트 | 책임 | 책임 아님 |
|---|---|---|
| **Slash Command** (`/init-ai-ready`) | UX 단축 진입점, 결정론적 trigger | 비즈니스 로직 |
| **Skill** (orchestrator) | 절차 강제 (Phase 1/2/3), sub-agent 호출, TodoWrite로 체크리스트 강제 | 직접 파일 수정 (Agent에 위임) |
| **Skill** (`common-agent-contract`) | Input/Output 형식 정의 | 절차 강제 |
| **Sub-agent** (wrapper) | 명시 task만 수행, summary-only return | scope 외 행동, sub-agent 추가 spawn |
| **Hook** (PreToolUse) | 거부권 또는 알림 | 비즈니스 로직 / 사용자 컨텍스트 추정 |
| **`doctor.sh`** | 환경 진단·치료 | 컴포넌트 빌드 |
| **Templates** (bundled) | 결정론적 파일 생성의 골격 | 동적 콘텐츠 생성 |
| **글로벌 CLAUDE.md** | 메타 룰 6개로 메인 행동 유도 | 인덱스 / 백과사전 |

### 1.5 Common-Agent-Contract 미리보기

`~/.claude/skills/common-agent-contract/SKILL.md`의 핵심 (자세한 본문은 §2):

**모든 wrapper agent의 Input contract**:
- `task` (string) — 한 문장 작업 명세
- `context_paths` (list[path]) — 명시적으로 읽을 파일 경로
- `success_criteria` (string) — 검증 기준

**모든 wrapper agent의 Output contract**:
- `result` — `PASS` / `FAIL` / `COMPLETE`
- `evidence` — 근거 인용·diff·발견사항 (≤500단어)
- `unknowns` — 추측한 부분 명시

**Scope lock**:
- `success_criteria` 외 행동 금지
- 필요 시 `unknowns`에 적고 종료
- sub-agent를 추가 spawn하려는 시도는 거부

### 1.6 미선택 옵션 — 왜 우리가 안 했나

| 미선택 | 이유 |
|---|---|
| 메서드×도메인 N×M agent 매트릭스 | 관리 부담 폭증, 컨텍스트 오염 |
| superpowers 직접 사용 (start-rpi-cycle 없이) | 4개 자산 prefix 자동 주입 누락 |
| 인덱스 섹션을 글로벌 CLAUDE.md에 포함 | 자동 트리거되는 것을 적는 건 중복 + drift 위험 |
| 절대값 토큰 임계 (auto-compact) | effort 변동에 무력 — 비율 기반이 정확 |
| 환경 구분 deny-patterns (운영/dev) | GitOps/IaC 사상 위배. 환경 직접 접근 자체가 안티패턴 |
| 일자 기준 archive (90일) | 휴면 프로젝트에서 무의미. 양 기준이 정합 |
| 분기별 수동 audit 명령(`/audit`) | `/init-ai-ready` Phase 0이 자연스러운 자동 트리거 |
| Hook의 단계적 차단 도입 | 마커 기반 식별로 false positive 0, 1주차부터 차단 가능 |

### 1.7 보강된 위험 (§0.6 보완)

§0.6에서 누락된 항목 추가:

| 위험 | 완화 |
|---|---|
| **글로벌 `~/.claude/CLAUDE.md` 자체의 drift** | `session-start-audit` hook이 30일 경과 1회 알림 + `/init-ai-ready` Phase 0이 새 프로젝트마다 자동 점검 |
| **글로벌 인프라 업데이트 시 호환성** | `orchestrator_version` 마커로 점진적 이행. v1.0 skill은 v2.0 hook과 공존 가능 |
| **사이클 카운트 영속화 파일 손상** | `.claude/state.json` 누락 시 기본값 0으로 재시작. 알림으로 사용자 인지 |

### 1.8 §1 마감

§1은 모든 결정의 카탈로그. 다음 섹션부터는 각 컴포넌트의 본문·코드·검증.

---

## §2. 글로벌 인프라 (`~/.claude/`)

§1이 결정의 카탈로그였다면, §2는 글로벌 인프라의 **정확한 컴포넌트 명세**다. 각 파일의 frontmatter, 본문 골격, 책임 경계, 의존성을 정의한다.

### 2.1 디렉터리 구조 (변경 후)

```
~/.claude/
├── CLAUDE.md                                  # 재작성 (≤200줄, 메타 룰 6개)
├── settings.json                              # hooks 키 추가 (5개 등록)
├── settings.json.backup-YYYY-MM-DD            # doctor.sh 자동 백업
├── docs/superpowers/specs/                    # 디자인 문서 위치 (이 문서)
├── agents/                                    # NEW
│   ├── explore-strict.md
│   ├── review-strict.md
│   └── execute-strict.md
├── skills/
│   ├── ccs-delegation/                        # 기존 유지
│   ├── common-agent-contract/                 # NEW (1)
│   │   └── SKILL.md
│   ├── create-orchestrator-skill/             # NEW (2)
│   │   └── SKILL.md
│   ├── init-ai-ready-project/                 # NEW (3)
│   │   ├── SKILL.md
│   │   ├── templates/                         # bundled (8 .tpl 파일, §3에서 본문)
│   │   └── references/
│   │       ├── placeholder-spec.md
│   │       └── stack-presets.md
│   └── start-rpi-cycle/                       # NEW (4)
│       └── SKILL.md
├── commands/
│   ├── ccs.md                                 # 기존 유지
│   ├── ccs/continue.md                        # 기존 유지
│   └── init-ai-ready.md                       # NEW (얇은 진입점, 3줄)
├── hooks/                                     # NEW
│   ├── enforce-orchestrator.sh
│   ├── stable-claude-md.sh
│   ├── auto-compact-watch.sh
│   ├── enforce-rpi-cycle.sh
│   ├── session-start-audit.sh
│   ├── _common.sh                             # 공통 프롤로그 (json_get, log)
│   ├── tests/                                 # hook 단위 검증 fixture
│   │   ├── fixtures/
│   │   │   ├── enforce-orchestrator/
│   │   │   ├── stable-claude-md/
│   │   │   ├── auto-compact-watch/
│   │   │   ├── enforce-rpi-cycle/
│   │   │   └── session-start-audit/
│   │   └── run-all.sh
│   └── .log/                                  # 월별 로그
│       └── 2026-05.log
└── setup/                                     # NEW
    ├── doctor.sh                              # 진단·치료 (구 install-deps + verify-env)
    ├── verify-setup.sh                        # 셋업 검증 (5.1)
    ├── verify-integration.sh                  # 통합 시나리오 (5.4)
    ├── verify-all.sh                          # 4단계 일괄 launcher
    └── .installed                             # doctor.sh 실행 마커
```

**총 신규 파일 ~30개 + 수정 2개 (`CLAUDE.md`, `settings.json`).**

### 2.2 Agent 3개 명세

#### 2.2.1 `~/.claude/agents/explore-strict.md`

```yaml
---
name: explore-strict
description: |
  명시 범위 내에서 코드베이스를 탐색하고 발견 사항만 요약 반환. 읽기 전용. 코드 수정 불가.
  사용 시점: orchestrator skill의 Phase R(Research) 또는 Phase 1(Discover).
  scope 외 행동 금지 — 호출 시 success_criteria로 명시한 것만 수행.
  <example>
  Context: 결제 모듈 추가 전 기존 코드 영향 분석
  call: Agent(subagent_type="explore-strict",
              task="기존 결제 관련 파일 발견",
              context_paths=["docs/ai-context/architecture.md", "docs/ai-context/domain-glossary.md"],
              success_criteria="결제 키워드가 포함된 파일 목록 + 의존성 그래프")
  </example>
model: inherit
tools: Read, Grep, Glob, WebFetch
skills: ["common-agent-contract"]
---

You are an exploration specialist. You discover and summarize, you do not modify.

# Core Responsibilities
1. Read only files specified in `context_paths` and files explicitly relevant to `task`
2. Return findings in the structured Output Format defined by common-agent-contract
3. Do not exceed `success_criteria` — if more is needed, report as `unknowns`

# Process
1. Read context_paths in order
2. Plan minimal additional reads to satisfy success_criteria
3. Execute reads / greps
4. Synthesize into evidence (≤500 words)
5. Return per Communication Protocol

# Output Format
See common-agent-contract (auto-loaded). Result: PASS / FAIL / COMPLETE.

# Communication Protocol
- result: COMPLETE if findings synthesized, FAIL if context_paths missing
- evidence: file paths + relevant excerpts (≤500 words)
- unknowns: anything inferred or out-of-scope but relevant
```

#### 2.2.2 `~/.claude/agents/review-strict.md`

```yaml
---
name: review-strict
description: |
  명시 기준으로 검증하고 PASS/FAIL + 근거를 반환. 읽기 전용 + read-only bash.
  사용 시점: orchestrator skill의 Phase 3(Verify) / Phase Closeout / drift 검사 / 5 Whys 검증.
  scope 외 행동 금지.
model: inherit
tools: Read, Grep, Glob, Bash
skills: ["common-agent-contract"]
---

You are a verification specialist. You check whether evidence meets the success_criteria.

# Core Responsibilities
1. Treat success_criteria as the only quality gate
2. Use Bash only for read-only verification (e.g., `wc -l`, `jq`, `grep`, `git status`)
3. Reject the work if even one criterion fails — do not partially pass

# Process
1. Read context_paths
2. For each criterion in success_criteria, design a deterministic check
3. Execute checks (Bash for objective, Read+reasoning for subjective)
4. Aggregate per criterion: PASS / FAIL with evidence

# Output Format (overrides common-agent-contract for this agent)
- result: PASS (all criteria met) / FAIL (any criterion failed)
- evidence: per-criterion verdict + 1-line reason each
- unknowns: criteria that couldn't be objectively checked

# Refusal triggers
- Asked to modify files → refuse, report scope violation
- Asked to spawn another sub-agent → refuse (Anthropic limit)
```

#### 2.2.3 `~/.claude/agents/execute-strict.md`

```yaml
---
name: execute-strict
description: |
  명시 변경만 수행하고 diff 요약 반환. 코드 수정 가능.
  사용 시점: orchestrator skill의 Phase 2(Generate) / Phase I(Implement)의 task 위임.
  scope 외 변경 금지 — task에 적힌 파일만 수정.
  <example>
  Context: 부트스트랩 시 9개 파일 생성
  call: Agent(subagent_type="execute-strict",
              task="docs/ai-context/architecture.md 생성",
              context_paths=["templates/architecture.md.tpl"],
              success_criteria="placeholder 모두 치환, mermaid 블록 valid")
  </example>
model: inherit
tools: Read, Write, Edit, Bash
skills: ["common-agent-contract"]
isolation: (omitted; default off — orchestrator skill이 호출 시 worktree 옵션 명시)
---

You are an execution specialist. You make precisely the change specified, no more.

# Core Responsibilities
1. Modify exactly what task specifies, in files explicitly named
2. Do not "improve" adjacent code, comments, formatting
3. Return diff summary, not the full file content (preserve main context)

# Process
1. Read context_paths (templates, related code)
2. Plan the minimal change
3. Apply Write/Edit
4. Self-verify against success_criteria via Bash (lint, syntax check)
5. Return diff summary per Communication Protocol

# Scope Lock (강한 거부)
- 변경 파일 ≤ task에 명시된 파일. **scope 외 변경이 필요하다고 판단되면 변경하지 않고 unknowns에 보고 후 종료.**
  - 예: task에 `architecture.md` 작성만 명시 → 다른 파일 수정이 필요해 보여도 거부, unknowns에 권고
- 새 의존성 추가는 변경 거부 → unknowns에 보고
- 테스트가 없는 코드 변경 → unknowns에 보고 (TDD 강제는 호출자/orchestrator 책임)
- 거부 시 result: FAIL, evidence에 거부 사유 명시

# Output Format
See common-agent-contract.
- result: COMPLETE (변경 적용) / FAIL (success_criteria 미충족)
- evidence: 파일별 diff 요약 (≤200 lines per file 인용)
- unknowns: scope 우회 또는 부수 효과
```

### 2.3 Skill 4개 명세

#### 2.3.1 `~/.claude/skills/common-agent-contract/SKILL.md`

```yaml
---
name: common-agent-contract
description: |
  모든 wrapper agent에 자동 주입되는 Input/Output 표준. agent의 skills 필드로만 호출됨.
  사용자가 직접 호출하지 않음.
---

# Common Agent Contract

이 skill은 wrapper agent (`explore-strict`, `review-strict`, `execute-strict`)가 시작될 때 system prompt에 자동 주입된다.

## Input Contract

호출자(orchestrator skill)는 다음 3개 필드를 항상 명시한다:

| 필드 | 타입 | 설명 |
|---|---|---|
| `task` | string | 한 문장 작업 명세. 동사로 시작. |
| `context_paths` | list[path] | 명시적으로 읽을 파일 경로. 빈 리스트 가능. |
| `success_criteria` | string | 검증 기준. 측정 가능해야 함. |

위 3개 중 하나라도 누락 → agent는 `result: FAIL`로 즉시 종료.

## Output Contract

agent는 다음 형식으로만 반환한다:

```
result: PASS | FAIL | COMPLETE
evidence: |
  <자유 형식 ≤500 단어. 파일 인용·diff·발견사항>
unknowns: |
  <추측·scope 우회·미해결 항목>
```

- `PASS` — review-strict 전용. 모든 criterion 만족.
- `FAIL` — 미충족 또는 입력 누락.
- `COMPLETE` — explore-strict / execute-strict 전용. 작업 종료.

## Scope Lock

1. `success_criteria` 외 행동 금지.
2. 추가 sub-agent spawn 금지 (Anthropic 제약).
3. evidence는 ≤500 단어. 초과 시 핵심만 요약.
4. 메인 conversation의 cwd 공유 — `cd` 명령은 sub-agent 안에서 persist 안 됨.

## Refusal Examples

- "task가 명시되지 않음" → result: FAIL, unknowns에 보고
- "사용자가 추가 작업 의도를 암시" → 그래도 task에 적힌 것만 수행
- "다른 sub-agent 호출이 효율적이라 판단" → 거부, unknowns에 권고
```

#### 2.3.2 `~/.claude/skills/create-orchestrator-skill/SKILL.md` (요약 — full body는 §7 빌드 단계)

```yaml
---
name: create-orchestrator-skill
description: |
  새 커스텀 skill을 orchestrator 패턴으로 생성. 사용자가 "이거 자주 쓸 것 같아 skill로",
  "orchestrator로 자동화해줘", "<X> skill 만들어줘" 등을 말하면 무조건 사용.
  단순 텍스트 변환 skill은 예외 (사용자가 명시하면 일반 skill-creator 호출).
orchestrator_skill: true
generated_by: built-in
orchestrator_version: 1.0
---

# Phase 1 — Capture Intent
사용자에게 묻기:
1. 무엇을 자동화하고 싶은가? (목적)
2. 트리거 조건? (사용자 발화 예시)
3. 입력·출력 형식?
4. 사이클이 필요한가, 단발성 작업인가?

# Phase 2 — Follow skill-creator procedure (메인 세션이 직접)
※ skill-creator는 메인 세션의 skill (플러그인 제공). sub-agent에 위임 X — 메인이 절차를 따름.
1. 메인이 skill-creator skill의 절차 호출 (Skill 도구로 명시 invoke)
2. Phase 1에서 캡처한 의도를 입력으로 skill-creator의 SOP 진행:
   - description 작성 (트리거 정확도)
   - body 골격
   - test cases 작성 (선택)
3. skill-creator가 draft SKILL.md 생성

→ 결과: skill-creator의 표준 산출물 (frontmatter + body)
→ 메인이 이 draft를 받아 Phase 3에서 후처리

# Phase 3 — Inject Orchestrator Skeleton
draft에 다음을 자동 주입:
1. frontmatter에 마커 3줄: `orchestrator_skill: true`, `generated_by: create-orchestrator-skill`, `orchestrator_version: 1.0`
2. body에 Phase 1 / Phase 2 / Phase 3 섹션 (없으면 추가)
3. 각 Phase에 최소 1개 Agent(...) 호출 (없으면 권유)
4. body 끝에 Communication Protocol 섹션

# Phase 4 — Verify
Agent(subagent_type="review-strict",
      task="orchestrator 골격 검증",
      success_criteria="enforce-orchestrator hook 통과 조건 모두 만족")
→ 통과 시에만 파일 생성

## Communication Protocol
- result: COMPLETE / FAIL
- evidence: 생성 파일 경로 + 골격 마커 발견 보고서
- unknowns: 사용자 추가 입력 권고 사항
```

#### 2.3.3 `~/.claude/skills/init-ai-ready-project/SKILL.md` (요약 — full body는 §7)

```yaml
---
name: init-ai-ready-project
description: |
  AI-Ready 프로젝트 부트스트랩. 사용자가 "새 프로젝트 셋업", "AI-ready 만들어줘",
  "프로젝트 초기화" 등을 말하면 무조건 사용. 9개 파일 + 디렉터리 결정론적 생성.
orchestrator_skill: true
generated_by: built-in
orchestrator_version: 1.0
---

# Phase 0 — Self-Audit (글로벌 점검)
1. bash ~/.claude/setup/doctor.sh 실행 (환경 진단·치료)
2. 글로벌 ~/.claude/CLAUDE.md drift 점검:
   - 줄 수 ≤ 200
   - 메타 룰 6개 마커 존재
   - 마지막 audit 마커 (`<!-- audit: YYYY-MM-DD -->`) 30일 이내
3. Hook 로그 통계 (지난 7일):
   - enforce-orchestrator BLOCK 횟수
   - enforce-rpi-cycle BLOCK 횟수
   - 임계 초과 시 사용자에게 보고

# Phase 1 — Discover
Agent(subagent_type="explore-strict",
      task="대상 디렉터리 충돌 검사",
      context_paths=["./"],
      success_criteria="존재 파일 목록, 충돌 가능 항목 식별, 스택 감지(package.json/pyproject.toml/Cargo.toml)")

# Phase 2 — Generate
templates/*.tpl 8개 + .gitkeep 3개를 변수 치환 후 결정론적 생성. 병렬 호출(다른 파일이라 worktree 불필요).

# Phase 3 — Verify
Agent(subagent_type="review-strict",
      task="스캐폴드 무결성 검증",
      success_criteria="9개 파일 + 3개 디렉터리, CLAUDE.md ≤200줄, deny-patterns의 ❌ 마커 ≥8, hook 실행권한, settings.json jq 파싱 성공, placeholder 잔존 0")

# Phase 4 — Closing
사용자에게 안내: "부트스트랩 완료. 첫 사이클 시작하려면 'start-rpi-cycle' 사용."

## Communication Protocol
(common-agent-contract 형식)
```

#### 2.3.4 `~/.claude/skills/start-rpi-cycle/SKILL.md` (요약 — full body는 §7)

```yaml
---
name: start-rpi-cycle
description: |
  새 작업/기능/버그 수정 시작 시 RPI 사이클을 강제. 사용자가 "기능 추가", "이거 고쳐줘",
  "구현해줘", "리팩토링" 등을 말하면 무조건 사용. 직접 코드 작성 금지.
  trivial 변경(≤5라인 수정)은 예외 — enforce-rpi-cycle hook이 자동 통과시킴.
orchestrator_skill: true
generated_by: built-in
orchestrator_version: 1.0
---

# Phase R — Research
※ superpowers의 brainstorming / writing-plans / executing-plans는 모두 **메인 세션의 skill**.
   sub-agent에 위임 X — 메인이 절차를 따름.
   sub-agent 위임은 explore-strict / review-strict / execute-strict (우리 wrapper)만.

A. brainstorming skill 절차 (메인이 직접 따름) — 외향적 (요구·접근법·디자인)
   → 산출물: docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md
B. Agent(subagent_type="explore-strict",
        task="<요청 분석>",
        context_paths=["docs/ai-context/architecture.md",
                       "docs/ai-context/domain-glossary.md",
                       "docs/ai-context/non-obvious.md",
                       "docs/ai-context/deny-patterns.md"],
        success_criteria="발견사항·영향 모듈·신규 도메인 용어·deny pattern 충돌 식별")
   ※ CLAUDE.md는 메인이 자동 로드하므로 context_paths에 미포함 (중복 회피)
   ※ A와 B는 병렬·교차 가능 (brainstorming 도중 explore-strict 호출 OK)

[Gate R]
- 새 도메인 용어 confidence < 80% → 사용자 확인 → glossary 자동 추가
- 아키텍처 영향 → ADR 초안 작성 권유

# Phase P — Plan
writing-plans skill 절차 (메인이 직접) → docs/superpowers/plans/YYYY-MM-DD-<topic>.md
plan 상단 헤더 주입 (writing-plans 표준 헤더 위에):
  **Status:** active
  **RPI-Cycle:** N
  **Started:** YYYY-MM-DD

[Gate P] active plan 파일 존재 확인 (enforce-rpi-cycle hook이 의존)

# Phase I — Implement
구현 방식 선택:
- (a) **subagent-driven-development** (superpowers 권장) — 메인이 절차 따라 task별로 execute-strict 위임
- (b) **executing-plans** skill — 메인이 절차 따름 (단일 세션 내). 끝나면 superpowers의 finishing-a-development-branch가 자동 호출됨.
- (c) execute-strict 직접 위임 — 단순 task에 한해

권장:
- 큰 사이클 (≥5 task) → (a)
- 중간 사이클 (2~5 task) → (b)
- 작은 사이클 (≤2 task) → (c)

worktree 사용:
- 같은 파일을 동시 수정 / 격리된 검증 필요 시 → 호출 시 isolation: worktree 명시
- 부트스트랩처럼 다른 파일 병렬 → worktree 불필요

# Phase Closeout
※ Phase I에서 executing-plans (b)를 선택했다면, superpowers가 자동으로
   finishing-a-development-branch skill을 호출. 그 결과를 받아 우리 Closeout이 보강 검증.
   (a)/(c)를 선택했다면 우리 Closeout이 단독으로 실행.

1. Agent(subagent_type="review-strict",
        task="사이클 마감 점검 (drift + 자산 갱신 검증)",
        success_criteria="
          - architecture.md 갱신 (모듈/의존성 변경 반영) 또는 변경 없음 확인
          - domain-glossary.md 갱신 또는 변경 없음 확인
          - 사이클 중 발생한 실패가 5 Whys 통과 후 non-obvious.md 누적 (또는 명시 면제)
          - plan 모든 체크박스 [x] 또는 명시적 미완료 사유 기록
          - finishing-a-development-branch 산출물(브랜치/PR)이 존재 시 일관성 (선택)
        ")
2. plan 헤더 갱신: **Status:** active → completed (메인이 직접 Edit)
3. .claude/state.json 갱신 (스키마 §2.12 참조)
   - cycle_count +1
   - last_cycle_completed: today
4. cycle_count == 5 → "v2 도입 가능" 알림 (state.v2_enabled가 false일 때만)
   cycle_count == 20 → "v3 도입 가능" 알림 (state.v3_enabled가 false일 때만)
5. Non-obvious archive 검사: active ≥30 또는 ≥100줄 → 가장 오래된 비재발 5개 archive

## Communication Protocol
(common-agent-contract 형식)
```

### 2.4 Command 1개

`~/.claude/commands/init-ai-ready.md`:
```markdown
init-ai-ready-project skill을 다음 인자로 명시 호출 (Skill 도구 사용):
project_name: $ARGUMENTS
```

3줄. 결정론적 trigger (description 매칭 우회).

### 2.5 Hook 5개 등록 (`settings.json` diff)

기존 `settings.json`에 **추가만** (기존 키 보존):

```json
{
  "_existing_keys": "env, permissions, model, enabledPlugins, ... (preserved)",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/enforce-orchestrator.sh" },
          { "type": "command", "command": "$HOME/.claude/hooks/stable-claude-md.sh" },
          { "type": "command", "command": "$HOME/.claude/hooks/enforce-rpi-cycle.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Read|Bash|Agent",
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/auto-compact-watch.sh" }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/session-start-audit.sh" }
        ]
      }
    ]
  }
}
```

같은 matcher의 hook은 등록 순서대로 실행. 하나라도 exit 2면 즉시 차단.
프로젝트 hook은 Claude Code가 자동 머지 — 글로벌 + 프로젝트 hook 모두 실행.

### 2.6 글로벌 `~/.claude/CLAUDE.md` 재작성 본문 (≤200줄)

```markdown
# 글로벌 Claude 행동 규약

> 이 파일은 모든 Claude 세션의 prefix에 자동 로드됩니다. ≤200줄.
> 변경은 의식적으로 — 변경 시 캐시 무효화 (다음 세션 비용 ~20배).

<!-- audit: 2026-05-01 -->

---

## §1. Cache Stability
루트 `CLAUDE.md`(글로벌·프로젝트 모두) 수정은 세션 종료 직전에만.
중간 수정 = prefix 캐시 미스 = 비용 약 20배.
사용자가 세션 중 수정 요청 → 한 번 환기 후 진행 가능.

## §2. Orchestrator Meta Rule
새 커스텀 skill 생성 요청은 항상 `create-orchestrator-skill` 사용.
단순 텍스트 변환 skill은 사용자가 명시할 때만 일반 skill-creator 사용.
이유: 모든 skill이 sub-agent에 위임하는 일관 패턴 유지.

## §3. RPI Cycle Mandate
변경 작업(기능 추가·버그 수정·리팩토링)은 항상 R→P→I→Closeout.
- Research: brainstorming + explore-strict
- Plan: writing-plans
- Implement: executing-plans 또는 execute-strict
- Closeout: review-strict drift 검사 + 자산 갱신
예외: ≤5라인 trivial change. 또는 사용자가 `RPI_SKIP=<reason>` 명시.

## §4. Non-Obvious 등록 절차
AI 실패 감지 시:
1. 등록 가치 있는지 사용자에게 확인
2. review-strict로 5 Whys 진행
3. 사람/AI는 root cause 불가 (시스템·프로세스만)
4. SMART action item 명시
5. 통과 시에만 `docs/ai-context/non-obvious.md` 추가

## §5. ADR Auto-Trigger
아키텍처 영향 변경 (모듈 추가/삭제, 의존성 추가, 데이터 흐름 변경, 인증/저장소/통신 패턴 변경):
- 변경 전 또는 직후 ADR 작성
- `docs/ai-context/architecture.md`는 append-only
- 결정 변경 시 새 ADR로 supersede (이전 항목 수정 X)

## §6. Domain Glossary 의미 확인
사용자가 도메인 용어 사용 시:
- 의미 confidence < 80% → 즉시 확인 질문
- 확인된 용어 + 코드 식별자 매핑 → glossary 자동 추가
- 같은 단어 다른 컨텍스트 → "Identical-Looking" 섹션에

---

## (기존 유지) Think Before Coding
[기존 내용 압축]

## (기존 유지) Simplicity First
[기존 내용 압축]

## (기존 유지) Surgical Changes
[기존 내용 압축]

## (기존 유지) Goal-Driven Execution
[기존 내용 압축]

---

이 파일이 작동하는 기준:
- 새 프로젝트마다 /init-ai-ready Phase 0이 이 파일을 점검
- 30일 이상 audit 마커 미갱신 시 session-start-audit이 알림
- 200줄 초과 시 doctor.sh가 경고
```

(실제 본문은 약 90~120줄. 위는 골격.)

### 2.7 `doctor.sh` 명세 (요약 — full script는 §7)

**책임**:
1. 진단 — 환경 15개 항목
2. 자동 수복 — jq 설치 / .installed 마커 / audit 마커 / backup 디렉터리 / git init 권유
3. 재진단
4. 보고

**실패 시 정책**:
- 자동 수복 가능한 것은 최선 시도 (실패해도 계속 진행)
- 사용자 조치 필요 항목은 명시 안내 후 exit 1
- node 미설치 = 치명적, 즉시 exit 1
- jq 설치 실패 = 비치명적, 알림만 (hook은 node로 동작)

### 2.8 Templates (init-ai-ready-project 안 bundled)

8개 .tpl 파일 + 2개 references. 본문은 §3에서 정의.

```
~/.claude/skills/init-ai-ready-project/templates/
├── CLAUDE.md.tpl
├── architecture.md.tpl
├── runbook.md.tpl
├── deny-patterns.md.tpl
├── non-obvious.md.tpl
├── domain-glossary.md.tpl
├── project-settings.json.tpl
└── pre-commit-deny.sh.tpl

~/.claude/skills/init-ai-ready-project/references/
├── placeholder-spec.md      # Mustache 변수 명세
└── stack-presets.md         # 스택별 STACK_ALLOW_LIST / STACK_GITIGNORE 매핑
```

### 2.9 Setup Scripts (`~/.claude/setup/`)

| 파일 | 책임 |
|---|---|
| `doctor.sh` | 환경 진단·치료 (위 §2.7) |
| `verify-setup.sh` | §6.1 셋업 검증 (9개 파일 존재) |
| `verify-integration.sh` | §6.4 E2E 시나리오 4개 |
| `verify-all.sh` | doctor + verify-setup + hooks/tests/run-all + verify-integration 일괄 |

모든 스크립트:
- 첫 줄: `#!/usr/bin/env bash`
- `set -euo pipefail`
- exit 0 = 통과, exit 1 = 불합격, exit 2 = 차단
- 진행 상황 stderr로 출력

### 2.10 의존성 그래프 (빌드 순서 미리보기)

§7에서 13단계로 풀어서 정의. 핵심 의존성:

```
doctor.sh ──── (자립)
templates/*.tpl ──── (자립)
common-agent-contract ──── (자립)
agents/*-strict ──── common-agent-contract
init-ai-ready-project ──── agents + templates
start-rpi-cycle ──── agents + writing-plans (superpowers 플러그인)
create-orchestrator-skill ──── agents + skill-creator (플러그인)
commands/init-ai-ready ──── init-ai-ready-project
hooks/*.sh ──── (정책 약속만)
hooks/_common.sh ──── (자립)
hooks/tests/* ──── hooks/*.sh
settings.json hooks 키 ──── hooks/*.sh 존재
CLAUDE.md 재작성 ──── (위 모두 위치 확정 후)
verify-* 스크립트 ──── 모든 컴포넌트
test-ai-ready 검증 환경 ──── verify-* 스크립트 통과 후
```

### 2.12 프로젝트별 영속화 — `.claude/state.json` 스키마

`start-rpi-cycle` skill의 Phase Closeout이 갱신하는 프로젝트 단위 상태 파일.
글로벌 합산 X — 프로젝트마다 독립.

#### 위치
`<project_root>/.claude/state.json`

#### 스키마 (v1)

```json
{
  "schema_version": 1,
  "project_name": "payflow",
  "created_at": "2026-05-01",

  "cycle": {
    "count": 0,
    "last_completed_at": null,
    "last_cycle_id": null
  },

  "features": {
    "v2_enabled": false,
    "v2_enabled_at": null,
    "v2_skipped_permanently": false,
    "v3_enabled": false,
    "v3_enabled_at": null,
    "v3_skipped_permanently": false
  },

  "non_obvious": {
    "active_count": 0,
    "archive_count": 0,
    "last_archived_at": null
  },

  "audit": {
    "last_doctor_run": "2026-05-01",
    "last_drift_check": "2026-05-01"
  }
}
```

#### 필드 의미

| 필드 | 갱신 주체 | 사용처 |
|---|---|---|
| `cycle.count` | start-rpi-cycle Phase Closeout (+1) | v2/v3 트리거 |
| `cycle.last_completed_at` | Phase Closeout (today) | 휴면 감지 |
| `features.v2_enabled` | 사용자 승인 시 true (Phase Closeout이 묻기) | v2 로직 활성화 |
| `features.v3_enabled` | 동일 | v3 로직 활성화 |
| `non_obvious.active_count` | Phase Closeout이 갱신 | archive 임계 (≥30) |
| `audit.last_doctor_run` | doctor.sh 마지막 성공 시 갱신 | 글로벌 audit과 별개 |

#### 생성·복구 정책

- **첫 생성**: `init-ai-ready-project` skill의 Phase 2가 빈 `.claude/state.json`을 templates/state.json.tpl으로 생성 (모든 카운터 0).
- **손상 시**: start-rpi-cycle이 jq 파싱 실패 감지 → 사용자에게 보고 + `.claude/state.json.broken-YYYY-MM-DD`로 백업 → 새 빈 파일 생성 + cycle_count 0부터 재시작.
- **마이그레이션**: `schema_version`을 비교. 불일치 시 마이그레이션 필요 알림 (직접 자동 변환 X).

#### 메인 컨텍스트 노출

`state.json`은 prefix에 자동 포함되지 않음. start-rpi-cycle이 호출될 때만 메인이 jq로 read.
이유: 매 세션에 prefix 부담 주지 않기 위해.

### 2.11 §2 마감

§2는 글로벌 인프라의 정확한 인터페이스. 다음 섹션에서:
- §3 — 프로젝트 템플릿 8개의 본문 (변경된 §2.6의 5개 자산 포함)
- §4 — Hook 5개의 의사코드와 운영 정책
- §5 — Non-Obvious v1/v2/v3 / drift / RPI 라이프사이클

---

## §3. 프로젝트 템플릿

§2가 글로벌 인프라의 인터페이스였다면, §3은 **`init-ai-ready-project` skill이 생성하는 프로젝트 자산의 정확한 본문**이다. 모두 `~/.claude/skills/init-ai-ready-project/templates/` 안에 bundled.

### 3.1 템플릿 파일 목록 (10개)

| # | 파일 | 출력 위치 (프로젝트) | 역할 |
|---|---|---|---|
| 1 | `CLAUDE.md.tpl` | `<root>/CLAUDE.md` | 프로젝트 컴퍼스 (≤200줄) |
| 2 | `architecture.md.tpl` | `docs/ai-context/architecture.md` | ADR + 모듈 그래프 |
| 3 | `runbook.md.tpl` | `docs/ai-context/runbook.md` | 운영·배포·장애 |
| 4 | `deny-patterns.md.tpl` | `docs/ai-context/deny-patterns.md` | hook이 파싱하는 deny list |
| 5 | `non-obvious.md.tpl` | `docs/ai-context/non-obvious.md` | 5 Whys 누적 |
| 6 | `domain-glossary.md.tpl` | `docs/ai-context/domain-glossary.md` | Ubiquitous Language |
| 7 | `project-settings.json.tpl` | `.claude/settings.json` | 프로젝트 hook + 권한 |
| 8 | `pre-commit-deny.sh.tpl` | `.claude/hooks/pre-commit-deny.sh` | deny pattern enforcement |
| 9 | `.gitignore.tpl` | `<root>/.gitignore` | VCS 위생 |
| 10 | `state.json.tpl` | `.claude/state.json` | 사이클 카운트 영속화 (§2.12) |

추가로 디렉터리만 생성 (`.gitkeep`):
- `docs/superpowers/specs/`
- `docs/superpowers/plans/`

### 3.2 본문 — `CLAUDE.md.tpl`

```markdown
# {{PROJECT_NAME}}

> AI-Ready 코드베이스. 이 파일은 모든 세션의 prefix에 자동 로드됩니다.
> 변경은 세션 종료 직전에만 (캐시 미스 비용 ≈20배).
> ≤200줄 유지. 백과사전이 아닌 나침반.

Created: {{CREATED_AT}}

## Stack
{{STACK_DESCRIPTION}}

## Modules
{{MODULES_INDEX}}

## Top 5 Non-Obvious Patterns
참조: [docs/ai-context/non-obvious.md](docs/ai-context/non-obvious.md)

(아직 누적되지 않음)

## Pointers
- 절대 금지: [docs/ai-context/deny-patterns.md](docs/ai-context/deny-patterns.md)
- 아키텍처: [docs/ai-context/architecture.md](docs/ai-context/architecture.md)
- 운영·배포: [docs/ai-context/runbook.md](docs/ai-context/runbook.md)
- 도메인 용어: [docs/ai-context/domain-glossary.md](docs/ai-context/domain-glossary.md)
```

**의도**: prefix 자동 로드 → 모든 세션 캐시 hit. 세부는 lazy-load 포인터.

### 3.3 본문 — `architecture.md.tpl`

```markdown
# Architecture — {{PROJECT_NAME}}

> Append-only Decision Log. 결정 변경 시 새 ADR로 supersede (이전 항목 수정 X).
> 모듈 그래프는 review-strict가 변경 시 자동 갱신.

## Module Dependency Graph (live)

```mermaid
graph TD
{{DEPENDENCY_DIAGRAM}}
```

> 갱신 정책: 모듈 추가/삭제/의존성 변경 시 review-strict가 갱신.

## Data Flow

{{DATA_FLOW_DESCRIPTION}}

## Architecture Decision Records (Append-only)

번호는 자연수 순서. 한번 적힌 ADR은 수정하지 않음. 결정이 바뀌면 새 ADR을 추가하고
`Supersedes: ADR-NNN` 명시.

(부트스트랩 시 비어 있음)

<!-- ADR 형식:
### ADR-001: <제목>
- 날짜: YYYY-MM-DD
- 상태: Proposed | Accepted | Superseded by ADR-NNN | Deprecated
- 결정: <무엇>
- 이유: <왜>
- 대안: <고려한 옵션>
- 트레이드오프: <포기한 것>
-->
```

### 3.4 본문 — `runbook.md.tpl`

```markdown
# Runbook — {{PROJECT_NAME}}

> ⚠️ 이 파일은 **운영·배포·장애 대응**의 기술적 실행 절차입니다.
> ⚠️ 프로젝트 작업 계획(Work Plan)은 `docs/superpowers/specs/` 와
>    `docs/superpowers/plans/`에 보관됩니다.
> ⚠️ 의사결정·전략은 ADR(`architecture.md`)에 보관됩니다.

## Deploy
{{DEPLOY_PROCEDURE}}

## Rollback
{{ROLLBACK_PROCEDURE}}

## Common Operations
(예: cache flush, queue drain, log rotation, certificate renewal 등)

## Health Checks / Dashboards
{{DASHBOARDS}}

## Incident Response (간단 — 자세한 건 별도 playbook으로 분리 권장)
{{INCIDENT_RESPONSE}}
```

**의도**: Runbook ≠ Work Plan ≠ ADR — 강의 표준에 부합. 사용자 혼동 방지 헤더.

### 3.5 본문 — `deny-patterns.md.tpl` ★ (hook이 직접 파싱)

```markdown
# Deny Patterns — {{PROJECT_NAME}}

> 절대 금지. .claude/hooks/pre-commit-deny.sh가 이 파일을 파싱.
> 형식 규약: 차단 항목은 반드시 `- ❌ ` 마커로 시작.
> 환경(dev/staging/prod) 구분 없음 — 모든 환경에 동일 적용.

## Schema / DB
- ❌ DROP TABLE
- ❌ TRUNCATE
- ❌ DELETE FROM (without WHERE)
- ❌ ALTER TABLE (use migration file instead)

## Migrations
- ❌ 머지된 마이그레이션 파일 수정 (always create new migration)

## Git
- ❌ git push --force origin main
- ❌ git push --force origin master
- ❌ git reset --hard (공유 브랜치)
- ❌ --no-verify

## Filesystem
- ❌ rm -rf /
- ❌ rm -rf ~
- ❌ rm -rf *

## Production Direct Access (모든 직접 접근 금지)
- ❌ ssh prod
- ❌ kubectl exec (prod context)
- ❌ psql -h prod-
- ❌ 운영 자격증명을 코드/커밋에 포함

## (허용) — 다음은 deny 아님
- ✅ npm install / pip install / cargo build (dev에서 자유)
- ✅ git push (force 아닌 경우)
- ✅ 마이그레이션 파일 신규 생성

## Past Incidents (이 프로젝트 사고 기록)
{{#INCIDENTS}}
- {{date}}: {{description}} → 그래서 `{{rule}}`
{{/INCIDENTS}}

(부트스트랩 시 INCIDENTS는 비어 있음. 사고가 발생할 때마다 한 줄 추가.)
```

**핵심**: `- ❌ ` 마커가 hook 파싱 규약. 사람과 hook 둘 다 읽기 쉬움.

### 3.6 본문 — `non-obvious.md.tpl` ★ (5 Whys 누적)

```markdown
# Non-Obvious Patterns — {{PROJECT_NAME}}

> AI/사람의 잘못된 추론·해석은 여기 적지 않습니다.
> 시스템·프로세스·도구의 결함이 root cause인 항목만 누적.
> 등록 전 review-strict 5 Whys 통과 필수.
>
> 형식:
> ## YYYY-MM-DD: <한 줄 제목>
> - 증상: <관찰 내용>
> - 트리거: <활성화 행동>
> - Root cause: <시스템/프로세스 단위>
> - Action: <SMART, 가능하면 자동화 fitness function>
> - 재발 카운터: 0 (재발 시 +1)

## Active Patterns

(아직 비어 있음)

## High Priority (재발 ≥ 2회)

(없음)

## Archive (해결 또는 휴면 패턴)

(없음 — active ≥30 또는 줄 수 ≥100 시 가장 오래된 비재발 항목 5개 자동 이동)

---
Last updated: {{CREATED_AT}}
```

### 3.7 본문 — `domain-glossary.md.tpl`

```markdown
# Domain Glossary — {{PROJECT_NAME}}

> 사내 용어 ↔ 코드 식별자 매핑. AI가 도메인 언어를 정확히 사용하도록.
> 새 용어 등장 시 메인이 confidence < 80%면 사용자에게 확인 후 자동 추가.

## Domain → Code

| 도메인 용어 | 코드 식별자 | 비고 |
|---|---|---|
{{#TERMS}}
| {{domain_term}} | `{{code_identifier}}` | {{note}} |
{{/TERMS}}

(부트스트랩 시 비어 있음. 모듈 추가 시 동시에 갱신)

## Identical-Looking, Different Meaning

(같은 단어인데 컨텍스트마다 의미가 다른 경우. 예: price vs amount)

{{#AMBIGUITIES}}
- **{{term}}**:
  - `{{context_a}}`: {{meaning_a}}
  - `{{context_b}}`: {{meaning_b}}
{{/AMBIGUITIES}}
```

### 3.8 본문 — `project-settings.json.tpl`

```json
{
  "permissions": {
    "allow": [
      {{STACK_ALLOW_LIST}}
    ],
    "deny": [
      "Bash(rm -rf*)",
      "Bash(git push --force*)",
      "Bash(npm publish*)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|Bash",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/pre-commit-deny.sh" }
        ]
      }
    ]
  }
}
```

**의도**: 글로벌 hook 5개에 더해 프로젝트별 deny pattern 검증 hook이 자동 머지됨.

### 3.9 본문 — `pre-commit-deny.sh.tpl`

```bash
#!/usr/bin/env bash
# Project-level deny pattern enforcement.
# Parses docs/ai-context/deny-patterns.md, blocks tool calls matching any "- ❌ " line.

set -euo pipefail

# 공통 프롤로그 (글로벌 _common.sh 가용 시 source)
[ -f "$HOME/.claude/hooks/_common.sh" ] && source "$HOME/.claude/hooks/_common.sh"

INPUT="$(cat)"
DENY_FILE="docs/ai-context/deny-patterns.md"
[ ! -f "$DENY_FILE" ] && exit 0

# tool_input 직렬화 (node 사용 — _common.sh의 json_get 또는 inline)
TOOL_INPUT="$(echo "$INPUT" | node -e '
  let d=""; process.stdin.on("data",c=>d+=c); process.stdin.on("end",()=>{
    try { const o=JSON.parse(d); console.log(JSON.stringify(o.tool_input||{})); } catch(e){}
  });
')"
[ -z "$TOOL_INPUT" ] && exit 0

# "- ❌ " 마커 줄에서 패턴 추출 후 substring 매칭
while IFS= read -r pattern; do
  [ -z "$pattern" ] && continue
  if echo "$TOOL_INPUT" | grep -qiF -- "$pattern"; then
    echo "[deny-pattern] 차단: $pattern" >&2
    echo "[deny-pattern] 출처: $DENY_FILE" >&2
    exit 2
  fi
done < <(grep -E '^- ❌ ' "$DENY_FILE" | sed 's/^- ❌ //')

exit 0
```

**의도**: 패턴 정의(deny-patterns.md) ↔ 강제(스크립트) 분리. 사용자는 markdown만 편집하면 강제 자동 갱신.

### 3.10 본문 — `.gitignore.tpl`

```gitignore
# Dependencies
node_modules/
__pycache__/
*.pyc
.venv/
vendor/

# Build outputs
dist/
build/
*.log

# Environment / secrets
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp

# OS
.DS_Store
Thumbs.db

# Claude Code project-local
.claude/sessions/
.claude/cache/

# Stack-specific
{{STACK_GITIGNORE}}
```

### 3.11 본문 — `state.json.tpl`

```json
{
  "schema_version": 1,
  "project_name": "{{PROJECT_NAME}}",
  "created_at": "{{CREATED_AT}}",

  "cycle": {
    "count": 0,
    "last_completed_at": null,
    "last_cycle_id": null
  },

  "features": {
    "v2_enabled": false,
    "v2_enabled_at": null,
    "v2_skipped_permanently": false,
    "v3_enabled": false,
    "v3_enabled_at": null,
    "v3_skipped_permanently": false
  },

  "non_obvious": {
    "active_count": 0,
    "archive_count": 0,
    "last_archived_at": null
  },

  "audit": {
    "last_doctor_run": "{{CREATED_AT}}",
    "last_drift_check": "{{CREATED_AT}}"
  }
}
```

### 3.12 Placeholder 명세 (`references/placeholder-spec.md`)

#### 단순 변수 (Mustache `{{VAR}}`)

| 변수 | 타입 | 출처 | 부트스트랩 시 기본값 |
|---|---|---|---|
| `PROJECT_NAME` | string | command 인자 (`/init-ai-ready <name>`) | 필수 |
| `CREATED_AT` | ISO date | 시스템 시간 | `2026-05-01` |
| `STACK_DESCRIPTION` | string | Phase 1 explore-strict 감지 | `(미감지 — 빈 디렉터리)` |
| `STACK_ALLOW_LIST` | JSON 부분 | stack-presets 매핑 | `[]` (빈 배열) |
| `STACK_GITIGNORE` | text 라인 | stack-presets 매핑 | `(빈 줄)` |
| `DEPENDENCY_DIAGRAM` | mermaid 노드 | 빈 mermaid 노드 | `_initial_["empty"]` |
| `DATA_FLOW_DESCRIPTION` | text | 자유 기술 (초기 빈) | `(미정의)` |
| `DEPLOY_PROCEDURE` | text | 자유 기술 | `(아직 정의되지 않음)` |
| `ROLLBACK_PROCEDURE` | text | 자유 기술 | `(아직 정의되지 않음)` |
| `INCIDENT_RESPONSE` | text | 자유 기술 | `(아직 정의되지 않음)` |
| `DASHBOARDS` | text | 자유 기술 | `(아직 정의되지 않음)` |
| `MODULES_INDEX` | bullet list | Phase 1 감지 결과 | `(아직 모듈 없음)` |

#### 반복 블록 (Mustache `{{#list}}...{{/list}}`)

| 블록 | 항목 필드 | 부트스트랩 기본 |
|---|---|---|
| `INCIDENTS` | `date`, `description`, `rule` | 빈 리스트 |
| `TERMS` | `domain_term`, `code_identifier`, `note` | 빈 리스트 |
| `AMBIGUITIES` | `term`, `context_a`, `meaning_a`, `context_b`, `meaning_b` | 빈 리스트 |

### 3.13 Stack Presets (`references/stack-presets.md`)

Phase 1의 explore-strict가 감지한 결과 → Phase 2의 변수 치환에 사용.

| 감지 신호 | `STACK_DESCRIPTION` | `STACK_ALLOW_LIST` 추가 | `STACK_GITIGNORE` 추가 |
|---|---|---|---|
| `package.json` 존재 + 의존성에 `next` | `Next.js + Node.js` | `"Bash(npm run *)", "Bash(npm test*)", "Bash(npx*)"` | `.next/`, `out/` |
| `package.json` 존재 (Next 외) | `Node.js + npm` | `"Bash(npm run *)", "Bash(npm test*)"` | `coverage/` |
| `pyproject.toml` 존재 | `Python (pyproject)` | `"Bash(pytest*)", "Bash(uv run*)", "Bash(uv add*)"` | `.venv/`, `*.egg-info/`, `.pytest_cache/` |
| `Cargo.toml` 존재 | `Rust` | `"Bash(cargo build*)", "Bash(cargo test*)", "Bash(cargo run*)"` | `target/`, `Cargo.lock`(library 한정) |
| `go.mod` 존재 | `Go` | `"Bash(go build*)", "Bash(go test*)", "Bash(go run*)"` | `/bin/`, `*.out` |
| `pubspec.yaml` 존재 | `Flutter / Dart` | `"Bash(flutter test*)", "Bash(dart run*)"` | `build/`, `.dart_tool/` |
| 빈 디렉터리 (감지 실패) | `(미감지)` | `[]` | `(빈 줄)` |

→ Phase 1이 감지 결과를 Phase 2에 넘기고, Phase 2가 매핑 적용. 결정론적·확장 가능.

### 3.14 일관성 보장 메커니즘 (3중)

같은 skill을 N번 실행해도 결정론적으로 동일한 골격이 생성되도록.

1. **Phase 2의 execute-strict**: 각 파일을 `templates/*.tpl` + 변수로만 생성. 자유 기술 금지.
2. **Phase 3의 review-strict**: 생성된 파일이 templates 골격(섹션 헤더, 마커)을 유지하는지 검증.
3. **Skill 자체 명시**: `init-ai-ready-project/SKILL.md` body에 *"파일 생성은 반드시 templates/*.tpl 사용. 새 섹션 추가 금지. 누락 금지."*

### 3.15 Phase 3 review-strict 검증 체크리스트

각 항목은 deterministic. Bash 한 줄로 검증 가능.

| # | 검증 | 통과 조건 | 검증 명령 예 |
|---|---|---|---|
| 1 | 파일 존재 | 10개 파일 모두 | `[ -f docs/ai-context/architecture.md ]` 등 10번 |
| 2 | 디렉터리 존재 | 3개 디렉터리 (specs, plans, hooks) | `[ -d docs/superpowers/plans ]` 등 |
| 3 | CLAUDE.md 길이 | ≤ 200줄 | `[ "$(wc -l < CLAUDE.md)" -le 200 ]` |
| 4 | deny-patterns.md 형식 | `- ❌ ` 마커 ≥ 8개 (기본 deny들) | `[ "$(grep -c '^- ❌' docs/ai-context/deny-patterns.md)" -ge 8 ]` |
| 5 | non-obvious.md 마커 | "(아직 비어 있음)" 텍스트 존재 | `grep -q '아직 비어 있음' docs/ai-context/non-obvious.md` |
| 6 | hook 실행권한 | `.claude/hooks/pre-commit-deny.sh`이 +x | `[ -x .claude/hooks/pre-commit-deny.sh ]` |
| 7 | settings.json 유효성 | jq 또는 node로 파싱 성공 | `node -e "JSON.parse(require('fs').readFileSync('.claude/settings.json'))"` |
| 8 | state.json 유효성 + 스키마 | schema_version=1, cycle.count=0 | node로 파싱 + 필드 검사 |
| 9 | placeholder 잔존 검사 | `{{...}}` 패턴이 어떤 파일에도 존재하지 않음 (모두 치환됨) | `! grep -rE '{{[^}]+}}' docs/ai-context/ CLAUDE.md .claude/` |
| 10 | gitignore 라인 수 | ≥ 15 | `[ "$(wc -l < .gitignore)" -ge 15 ]` |
| 11 | 한국어 인코딩 | UTF-8 (BOM 없음) | `file CLAUDE.md \| grep -q UTF-8` |

→ 하나라도 실패하면 review-strict가 `result: FAIL` + per-criterion evidence 반환. 메인이 사용자에게 보고하고 재시도 제안.

### 3.16 §3 마감

§3은 결정론적 골격의 본문. 다음 섹션:
- §4 — Hook 5개의 의사코드 (Bash + node json_get) + 등록 + 운영
- §5 — 사이클이 돌수록 자산이 강해지는 운영 정책

---

## §4. Hook 5개 상세

§2가 인터페이스, §3이 콘텐츠였다면, §4는 **거부권의 실제 동작**이다. 강의 사상 *"Hook = 거부권"*과 *"Passive Optimization"*의 구체적 구현.

### 4.0 의도와 원칙

| 원칙 | 출처 | 적용 |
|---|---|---|
| Bash + node JSON 파싱 | 업계 표준 — PreToolUse 시작 시간 ≤100ms | 5개 hook 모두 |
| 장애 안전 (graceful fail) | Google SRE | hook 자체 오류 시 exit 0 (작업 안 막음) |
| Hook은 단순·예측가능 | Google SRE *"Avoid magic"* | 정규식·grep만, ML 임계 X |
| False Positive Rate < 5% | KPI 표준 | 마커 기반 결정론적 식별 |
| 모든 alert는 actionable | Google SRE | exit 2 시 stderr에 "어떻게 해결할지" 명시 |

### 4.1 공통 프롤로그 — `~/.claude/hooks/_common.sh`

5개 hook 모두가 source하는 공통 함수 라이브러리.

```bash
#!/usr/bin/env bash
# Common prologue for all ~/.claude/hooks/*.sh
# Sourced, not executed. Provides json_get, log, common error handling.

set -euo pipefail

# --- json_get: stdin JSON에서 dot-path로 값 추출 ---
# Usage: VAR=$(echo "$INPUT" | json_get 'tool_input.file_path')
# - 값 없으면 빈 문자열 출력
# - JSON 파싱 실패 시 빈 문자열 (장애 안전)
json_get() {
  node -e '
    let data = "";
    process.stdin.on("data", c => data += c);
    process.stdin.on("end", () => {
      try {
        const obj = JSON.parse(data);
        const keys = process.argv[1].split(".");
        let v = obj;
        for (const k of keys) v = v?.[k];
        if (v !== undefined && v !== null) {
          console.log(typeof v === "string" ? v : JSON.stringify(v));
        }
      } catch (e) { /* silent — graceful fail */ }
    });
  ' "$1"
}

# --- hook_log: ~/.claude/hooks/.log/YYYY-MM.log에 한 줄 누적 ---
# Usage: hook_log "<hook-name>" "<target>" "<verdict>" "[<reason>]"
hook_log() {
  local hook="$1"; local target="$2"; local verdict="$3"; local reason="${4:-}"
  local logdir="$HOME/.claude/hooks/.log"
  local logfile="$logdir/$(date +%Y-%m).log"
  mkdir -p "$logdir" 2>/dev/null || return 0
  local ts
  ts=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")
  printf "%s\t%s\t%s\t%s\t%s\n" "$ts" "$hook" "$target" "$verdict" "$reason" >> "$logfile" 2>/dev/null || true
}

# --- node 가용성 체크 (Claude Code 런타임이라 보장되지만 방어적) ---
require_node() {
  command -v node >/dev/null 2>&1 || {
    # node 없으면 작업을 막지 않고 통과 (장애 안전)
    exit 0
  }
}

# --- INPUT 읽기 헬퍼 (모든 hook이 첫 줄로 사용) ---
read_input() {
  cat
}
```

→ 각 hook은 첫 줄에 `source "$HOME/.claude/hooks/_common.sh"` 한 줄로 모든 공통 기능 확보.

### 4.2 `enforce-orchestrator.sh` — 차단 (orchestrator 골격 검증)

```bash
#!/usr/bin/env bash
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
FILE_PATH=$(echo "$INPUT" | json_get 'tool_input.file_path')

# 1. 대상 path 확인 — */skills/*/SKILL.md
[[ "$FILE_PATH" != */skills/*/SKILL.md ]] && exit 0

# 2. 작성될 컨텐츠 추출
CONTENT=$(echo "$INPUT" | json_get 'tool_input.content')
[ -z "$CONTENT" ] && CONTENT=$(echo "$INPUT" | json_get 'tool_input.new_string')
[ -z "$CONTENT" ] && exit 0

# 3. orchestrator 마커 검사 (검증 대상 결정론화)
echo "$CONTENT" | grep -q '^orchestrator_skill: true$' || {
  hook_log "enforce-orchestrator" "$FILE_PATH" "PASS" "no-marker"
  exit 0
}

# 4. 골격 검증 — 3가지 (Phase ≥3, Agent ≥1, Communication Protocol)
# Note: || true로 zero-match abort 방지 (set -euo pipefail 하에서 grep -c 0매치 = exit 1)
PHASE_COUNT=$(echo "$CONTENT" | grep -cE '^# Phase ' || true)
AGENT_CALLS=$(echo "$CONTENT" | grep -cE 'Agent\(subagent_type=' || true)
HAS_CONTRACT=$(echo "$CONTENT" | grep -c 'Communication Protocol' || true)

REASON=""
if (( PHASE_COUNT < 3 )); then
  REASON="phase=${PHASE_COUNT}<3"
elif (( AGENT_CALLS < 1 )); then
  REASON="agent_calls=0"
elif (( HAS_CONTRACT < 1 )); then
  REASON="no-protocol-section"
fi

if [ -n "$REASON" ]; then
  hook_log "enforce-orchestrator" "$FILE_PATH" "BLOCK" "$REASON"
  cat >&2 <<EOF
[orchestrator] FAIL: $REASON
  Orchestrator skill 골격 누락:
    - Phase 마커 ≥ 3 (현재 $PHASE_COUNT)
    - Agent(subagent_type=...) 호출 ≥ 1 (현재 $AGENT_CALLS)
    - Communication Protocol 섹션 ≥ 1 (현재 $HAS_CONTRACT)
  해결: create-orchestrator-skill을 사용해 다시 생성하거나, 골격을 직접 추가하세요.
  검증 우회 (단순 텍스트 변환 skill 등): frontmatter에서 \`orchestrator_skill: true\` 제거.
EOF
  exit 2
fi

hook_log "enforce-orchestrator" "$FILE_PATH" "PASS" ""
exit 0
```

**모드**: 차단 (1주차부터)
**False Positive 방어**: orchestrator 마커 없는 skill은 무조건 통과.

### 4.3 `stable-claude-md.sh` — 알림

```bash
#!/usr/bin/env bash
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
FILE_PATH=$(echo "$INPUT" | json_get 'tool_input.file_path')
CWD=$(echo "$INPUT" | json_get 'cwd')
[ -z "$CWD" ] && CWD="."

# 글로벌 ~/.claude/CLAUDE.md 제외 (글로벌은 별도 audit hook이 관리)
[[ "$FILE_PATH" == "$HOME/.claude/CLAUDE.md" ]] && exit 0

# 모듈 CLAUDE.md 제외 (docs/modules/*/CLAUDE.md 등)
[[ "$FILE_PATH" == */modules/*/CLAUDE.md ]] && exit 0

# 루트 CLAUDE.md 매칭 (정확히 "CLAUDE.md" 또는 "<cwd>/CLAUDE.md" 또는 "./CLAUDE.md")
case "$FILE_PATH" in
  "$CWD/CLAUDE.md"|"./CLAUDE.md"|"CLAUDE.md") ;;
  *) exit 0 ;;
esac

hook_log "stable-claude-md" "$FILE_PATH" "ALERT" ""
cat >&2 <<EOF
[cache-stability] 루트 CLAUDE.md 수정 감지.
  세션 중 수정 시 prefix 캐시가 무효화됩니다 (다음 세션 비용 ≈20배).
  가능하면 세션 종료 직전에 모아서 수정하세요.
  (작업은 허용됨)
EOF
exit 0
```

**모드**: 알림 (exit 0)
**1세션 다회 알림 방어**: 알림은 매번. 세션 중 여러 번 수정하면 매번 환기 (의도).

### 4.4 `auto-compact-watch.sh` — 알림 (40% 임계)

```bash
#!/usr/bin/env bash
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
TRANSCRIPT=$(echo "$INPUT" | json_get 'transcript_path')
SESSION_ID=$(echo "$INPUT" | json_get 'session_id')

[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0
[ -z "$SESSION_ID" ] && SESSION_ID="unknown"

# 1세션 1회 알림 마커 (중복 방지)
ALERT_MARKER="/tmp/compact-alerted-${SESSION_ID}"
[ -f "$ALERT_MARKER" ] && exit 0

# 모델 컨텍스트 한도 (env로 override 가능)
LIMIT="${CONTEXT_LIMIT:-200000}"
THRESHOLD=$(( LIMIT * 40 / 100 ))

# transcript에서 누적 토큰 추출 (jsonl 가정)
USED=$(node -e '
  const fs = require("fs");
  try {
    const lines = fs.readFileSync(process.argv[1], "utf8").trim().split("\n");
    let last = 0;
    for (const ln of lines) {
      try {
        const obj = JSON.parse(ln);
        const u = obj?.message?.usage;
        if (u) {
          const total = (u.input_tokens || 0) + (u.cache_read_input_tokens || 0) + (u.cache_creation_input_tokens || 0);
          if (total > last) last = total;
        }
      } catch (e) { /* skip bad lines */ }
    }
    console.log(last);
  } catch (e) { console.log(0); }
' "$TRANSCRIPT")

[ -z "$USED" ] && USED=0

if (( USED >= THRESHOLD )); then
  PCT=$(( USED * 100 / LIMIT ))
  touch "$ALERT_MARKER"
  hook_log "auto-compact-watch" "session=$SESSION_ID" "ALERT" "${PCT}%"
  cat >&2 <<EOF
[auto-compact] 컨텍스트 사용률 ${PCT}% (${USED}/${LIMIT}).
  /compact 사용을 권장합니다 (강의 기준 40% 임계).
  세션당 1회만 알립니다.
EOF
fi
exit 0
```

**모드**: 알림 (exit 0)
**임계**: 컨텍스트 한도의 40% (강의 자료 기준).
**중복 방지**: 1세션 1회 (마커 파일 `/tmp/compact-alerted-<sid>`).

### 4.5 `enforce-rpi-cycle.sh` — 차단 + 화이트리스트

```bash
#!/usr/bin/env bash
source "$HOME/.claude/hooks/_common.sh"
require_node

INPUT=$(read_input)
FILE_PATH=$(echo "$INPUT" | json_get 'tool_input.file_path')
TOOL=$(echo "$INPUT" | json_get 'tool_name')
CWD=$(echo "$INPUT" | json_get 'cwd')
[ -z "$CWD" ] && CWD="."

# === 화이트리스트 1: 비코드 파일 통과 ===
case "$FILE_PATH" in
  *.md|*.txt|*.gitignore|*/CLAUDE.md|*/README*|*/.gitkeep) exit 0 ;;
  */docs/*) exit 0 ;;
  */.claude/*) exit 0 ;;          # 프로젝트 .claude 설정
  */.github/*) exit 0 ;;          # CI 설정
  */superpowers/*) exit 0 ;;      # superpowers 디렉터리
esac

# === 화이트리스트 2: trivial change (≤5 라인) ===
if [[ "$TOOL" == "Edit" ]]; then
  OLD=$(echo "$INPUT" | json_get 'tool_input.old_string')
  NEW=$(echo "$INPUT" | json_get 'tool_input.new_string')
  TOTAL_LINES=$(printf '%s\n%s\n' "$OLD" "$NEW" | wc -l)
  (( TOTAL_LINES <= 5 )) && {
    hook_log "enforce-rpi-cycle" "$FILE_PATH" "PASS" "trivial"
    exit 0
  }
fi

# === 화이트리스트 3: 명시 우회 ===
if [ -n "${RPI_SKIP:-}" ]; then
  hook_log "enforce-rpi-cycle" "$FILE_PATH" "PASS" "skip:${RPI_SKIP}"
  echo "[rpi] SKIP: $RPI_SKIP" >&2
  exit 0
fi

# === 검증: 활성 plan 존재 확인 ===
PLAN_DIR="$CWD/docs/superpowers/plans"
if [ ! -d "$PLAN_DIR" ]; then
  hook_log "enforce-rpi-cycle" "$FILE_PATH" "BLOCK" "no-plans-dir"
  cat >&2 <<EOF
[rpi] 차단: docs/superpowers/plans/ 디렉터리 없음.
  코드 변경 전 RPI 사이클을 시작하세요:
    "start-rpi-cycle 사용해서 <작업 설명>"
  trivial한 변경(≤5라인)이거나 docs 변경은 자동 허용됩니다.
  명시 우회: export RPI_SKIP="<이유>"
EOF
  exit 2
fi

# 활성 plan 식별 (우선순위)
ACTIVE=""
for plan in "$PLAN_DIR"/*.md; do
  [ ! -f "$plan" ] && continue
  # 1순위: 명시적 Status (있으면 우선). || true로 Status 부재 시 abort 방지.
  STATUS=$(head -20 "$plan" | grep -m1 -E '^\*?\*?[Ss]tatus:?\*?\*?' | sed -E 's/^\*?\*?[Ss]tatus:?\*?\*?\s*//' | tr -d ' ' || true)
  case "$STATUS" in
    completed|abandoned|archived|paused) continue ;;     # paused 명시 (체크박스 fallback 회피)
    active|in_progress) ACTIVE="$plan"; break ;;
  esac
  # 2순위: frontmatter 없으면 미완료 체크박스 존재 여부로 판별
  if grep -qE '^- \[ \]' "$plan"; then
    ACTIVE="$plan"
    break
  fi
done

if [ -z "$ACTIVE" ]; then
  hook_log "enforce-rpi-cycle" "$FILE_PATH" "BLOCK" "no-active-plan"
  cat >&2 <<EOF
[rpi] 차단: 활성 plan 없음 (docs/superpowers/plans/*.md).
  start-rpi-cycle을 사용해 R→P 단계를 먼저 완료하세요.
  trivial 변경(≤5라인) 또는 docs 변경은 자동 허용.
  명시 우회: export RPI_SKIP="<이유>"
EOF
  exit 2
fi

hook_log "enforce-rpi-cycle" "$FILE_PATH" "PASS" "plan=$(basename "$ACTIVE")"
exit 0
```

**모드**: 차단 + 3중 화이트리스트 (비코드 / ≤5라인 / RPI_SKIP)
**1주차부터**: 마커 + 화이트리스트로 false positive 방어.

### 4.6 `session-start-audit.sh` — 알림 (30일 경과)

```bash
#!/usr/bin/env bash
source "$HOME/.claude/hooks/_common.sh"

CLAUDE_MD="$HOME/.claude/CLAUDE.md"
[ ! -f "$CLAUDE_MD" ] && {
  echo "[audit] 글로벌 CLAUDE.md 없음. /init-ai-ready 1회 실행 권장." >&2
  exit 0
}

# audit 마커 추출 — 가장 최근 것
MARKER=$(grep -E '<!-- audit: [0-9]{4}-[0-9]{2}-[0-9]{2} -->' "$CLAUDE_MD" | tail -1 | sed -E 's/.*audit: ([0-9-]+).*/\1/')

if [ -z "$MARKER" ]; then
  echo "[audit] 마커 없음. 다음 /init-ai-ready 실행 시 자동 점검됩니다." >&2
  exit 0
fi

# 30일 경과 계산 (YYYY-MM-DD 비교)
TODAY=$(date +%Y-%m-%d)
DAYS_AGO=$(node -e '
  const m = process.argv[1];
  const t = process.argv[2];
  const ms = (new Date(t) - new Date(m)) / 86400000;
  console.log(isNaN(ms) ? 0 : Math.floor(ms));
' "$MARKER" "$TODAY")

if (( DAYS_AGO > 30 )); then
  hook_log "session-start-audit" "global-CLAUDE.md" "ALERT" "${DAYS_AGO}d"
  cat >&2 <<EOF
[audit] 마지막 audit 후 ${DAYS_AGO}일 경과 (마커: $MARKER).
  다음 /init-ai-ready 실행 시 자동 점검됩니다.
  강제 점검: bash ~/.claude/setup/doctor.sh
EOF
fi
exit 0
```

**모드**: 알림 (exit 0)
**트리거**: 30일 경과 시. 매 세션 시작 시 1회 평가.
**미래 날짜 마커**: DAYS_AGO ≤ 0 → 알림 미발동 (시계 문제 안전).

### 4.7 `~/.claude/settings.json` — hooks 키 등록

```json
{
  "_existing_keys_preserved": "env, permissions, model, enabledPlugins, ...",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/enforce-orchestrator.sh" },
          { "type": "command", "command": "$HOME/.claude/hooks/stable-claude-md.sh" },
          { "type": "command", "command": "$HOME/.claude/hooks/enforce-rpi-cycle.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Read|Bash|Agent",
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/auto-compact-watch.sh" }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/session-start-audit.sh" }
        ]
      }
    ]
  }
}
```

**실행 순서**: 같은 matcher의 hook은 등록 순서대로. 하나라도 exit 2면 즉시 차단 (이후 hook 미실행).
**프로젝트·글로벌 머지**: Claude Code가 자동. 프로젝트 hook(예: pre-commit-deny.sh)은 같은 matcher에 추가됨.

### 4.8 운영 정책

#### 4.8.1 모니터링 임계 (베스트 프랙티스 기반)

| 지표 | 우수 | 허용 | 경고 |
|---|---|---|---|
| **False Positive Rate** (RPI_SKIP 우회 비율) | < 2% | 2~5% | > 5% |
| **enforce-orchestrator BLOCK / 7일** | 0 | ≤ 2 | ≥ 3 |
| **enforce-rpi-cycle BLOCK / 7일** | ≤ 5 | ≤ 9 | ≥ 10 |
| **stable-claude-md ALERT / 세션** | ≤ 1 | — | ≥ 2 |
| **auto-compact-watch ALERT / 세션** | ≤ 1 | ≤ 2 | ≥ 3 |
| **Hook 실행 시간 (p95)** | < 100ms | < 200ms | ≥ 200ms |

→ 경고 임계 도달 시 검증 로직 점검 또는 화이트리스트 갱신.

#### 4.8.2 검증 자동화 (수동 점검 X)

`/init-ai-ready` Phase 0에 다음이 자동 통합:
1. `doctor.sh` 환경 진단·치료
2. 글로벌 CLAUDE.md drift 점검 (줄 수, 메타 룰 마커, audit 일자)
3. Hook 로그 통계 분석 (지난 7일):
   ```bash
   awk -F'\t' '$3 ~ /BLOCK|ALERT/' ~/.claude/hooks/.log/$(date +%Y-%m).log | wc -l
   ```
4. 임계 초과 시 사용자 보고

새 프로젝트를 한 달에 한 번도 안 만드는 경우 → `session-start-audit` hook이 30일 경과 시 1회 환기.

#### 4.8.3 비활성화 옵션 (사용자 통제권)

| 범위 | 방법 |
|---|---|
| 임시 (현재 세션) | `CLAUDE_CODE_HOOKS=disabled` env (셸에서 export) |
| 임시 (RPI만) | `RPI_SKIP="<이유>"` env |
| 영구 (특정 hook만) | `~/.claude/settings.local.json`에서 해당 hook 제거 |
| 영구 (모든 hook) | `~/.claude/settings.json`의 hooks 키 전체 제거 (비추천) |

**중요**: 사용자 통제권은 항상 우선. 시스템은 강제하되 우회는 명시적이어야.

#### 4.8.4 로그 형식 — `~/.claude/hooks/.log/YYYY-MM.log`

탭 구분 5개 필드:
```
2026-05-01T09:23:11+09:00	enforce-orchestrator	/path/SKILL.md	PASS	no-marker
2026-05-01T09:24:02+09:00	enforce-rpi-cycle	src/auth.ts	BLOCK	no-active-plan
2026-05-01T09:24:50+09:00	auto-compact-watch	session=abc123	ALERT	44%
```

월별 파일 로테이션 (자동 정리 X — 사용자 책임).

#### 4.8.5 단위 테스트 (`~/.claude/hooks/tests/`)

§3.15 Phase 3 review-strict와 별도로, hook 자체 동작 검증.

```
~/.claude/hooks/tests/
├── fixtures/
│   ├── enforce-orchestrator/
│   │   ├── 01-no-marker.input.json
│   │   ├── 01-no-marker.expected_exit         # 0
│   │   ├── 02-marker-complete.input.json
│   │   ├── 02-marker-complete.expected_exit   # 0
│   │   ├── 03-marker-no-phase.input.json
│   │   ├── 03-marker-no-phase.expected_exit   # 2
│   │   └── ... (총 12개 케이스 / §6.2.1 참조)
│   ├── stable-claude-md/        (9 케이스)
│   ├── auto-compact-watch/      (11 케이스)
│   ├── enforce-rpi-cycle/       (18 케이스)
│   ├── session-start-audit/     (7 케이스)
│   └── pre-commit-deny/         (8 케이스, 프로젝트 hook fixture)
├── run-all.sh                   # 모든 fixture 일괄 실행
└── README.md
```

`run-all.sh` 의사코드:
```bash
for fixture in fixtures/*/*.input.json; do
  expected=$(cat "${fixture%.input.json}.expected_exit")
  hook_name=$(basename "$(dirname "$fixture")")
  actual=$(cat "$fixture" | "$HOME/.claude/hooks/${hook_name}.sh"; echo $?)
  [ "$actual" = "$expected" ] || echo "FAIL: $fixture (expected $expected, got $actual)"
done
```

### 4.9 §4 마감

§4은 강제력의 정확한 동작. 다음 섹션:
- §5 — 사이클이 돌수록 자산이 강해지는 운영 정책 (Non-Obvious v1/v2/v3, drift, RPI 라이프사이클)
- §6 — 검증 체크리스트 (환경 / 셋업 / Hook / Skill / E2E)

---

## §5. 운영 정책

§4가 거부권의 동작이라면, §5는 **시간이 흐를 때 시스템이 어떻게 강해지느냐**의 정의다. 강의의 *"사이클이 돌수록 컨텍스트가 누적되어 다음 작업이 더 확실해진다"*를 구체화.

### 5.0 운영 원칙

| 원칙 | 출처 |
|---|---|
| 처음부터 모든 걸 만들지 않는다 | 강의 — Day 0 / Cycle 5 / Cycle 20 단계적 |
| 자동 트리거 우선, 수동 점검 회피 | 강의 — Passive Optimization |
| 사용자 승인 필요한 변경은 항상 묻기 | 통제권 보장 |
| 사이클 자산은 누적 (append-only)·아카이브는 양 기준 | 휴면 프로젝트 고려 |
| Drift 자동 감지, 강제 차단은 화이트리스트 | False positive 방어 |

### 5.1 Non-Obvious 누적·승격·소거 — v1 / v2 / v3

#### v1 (Day 0 — 셋업 직후 즉시 활성)

- `non-obvious.md`에 **5 Whys 통과 항목만** 누적
- 등록 절차 (글로벌 CLAUDE.md §4 메타 룰 강제):
  1. AI 실패 감지
  2. 메인이 사용자에게 묻기: "이거 등록 가치 있어 보이는데 5 Whys 진행할까?"
  3. 사용자 OK → review-strict로 5 Whys 진행
  4. 거부 조건 검증:
     - root cause가 사람/AI인가? → 거부
     - Why가 1단계에서 멈췄나? → 거부
     - action item이 vague한가? → 거부
  5. 통과 시에만 등록

- 등록 형식 (§3.6 참조):
  ```
  ## 2026-05-01: <한 줄 제목>
  - 증상: <관찰>
  - 트리거: <행동>
  - Root cause: <시스템·프로세스 단위>
  - Action: <SMART>
  - 재발 카운터: 0
  ```

- 첫 항목 추가 시 처리 (§3 약점 #3 보강):
  - "(아직 비어 있음)" 텍스트는 첫 항목 추가 시 자동 제거
  - review-strict가 RPI Closeout에서 검증 — 빈 텍스트와 항목이 공존하면 FAIL

#### v2 — Cycle 5 도달 시 사용자 승인형 알림

**도입 트리거**: 프로젝트의 `state.json.cycle.count` == 5
**도입 방법**: `start-rpi-cycle`의 Phase Closeout이 사용자에게 묻기:
> "🎯 RPI Cycle 5 도달.
>  Non-Obvious v2 (재발 카운터 자동 갱신) 도입할까요?
>  활성화하면 다음 사이클부터 매칭 패턴 자동 카운트됩니다.
>  건너뛰려면 다음 5 사이클 후 다시 묻습니다."

**활성화 시 동작**:
- `state.json.features.v2_enabled` = true
- start-rpi-cycle의 Phase Closeout에 **재발 매칭 로직** 추가:
  ```
  사이클 중 발생한 실패 패턴 vs non-obvious.md의 active patterns
  매칭 알고리즘 (v1):
    - 제목의 substring (소문자 정규화) 매칭
    - Root cause 키워드 (가장 빈번한 명사 5개) 비교
  매칭 시:
    - 재발 카운터 +1
    - 카운터 ≥ 2 → "High Priority" 섹션으로 이동
    - High Priority는 다음 사이클 Research Phase의 prefix에 우선 노출
  ```

- 매칭 정확도 한계: substring + 키워드는 false positive/negative 가능. v1 한계 명시. 향후 개선은 §9.

#### v3 — Cycle 20 도달 시 사용자 승인형 알림

**도입 트리거**: `state.json.cycle.count` == 20
**도입 방법**: 동일 방식으로 사용자에게 묻기

**활성화 시 동작**:
- `state.json.features.v3_enabled` = true
- 재발 카운터 ≥ 5 → **deny-patterns.md 자동 승격 권고** (사용자 승인 후 추가)
- 승격 후 30일간 재발 0건 → archive로 이동
- 승격 거부 시 → non-obvious의 High Priority에 그대로 유지

#### Soft Archive — 양 기준 (일자 X)

**검사 시점**: 매 RPI Closeout
**임계**:

| 임계 | 액션 |
|---|---|
| Active 항목 수 ≥ 30 | 가장 오래된 비재발(카운터=0) 5개를 archive로 이동 |
| Active 섹션 줄 수 ≥ 100 | 동일 |
| Archive 줄 수 ≥ 500 | "오래된 archive 정리할까요?" 사용자에게 묻기 |

**선정 우선순위**:
1. 재발 카운터 == 0 (한 번도 재발 없음)
2. 등록일 오래된 순
3. action item이 완료된 순 (별도 마커 시)

활발한 패턴(재발 있는 것)은 archive 안 됨.

#### Archive 항목의 재발 (v2 활성 시)

archive에 있던 패턴이 다시 매칭되면:
- archive에서 active로 복귀 (이동)
- 재발 카운터 +1 (archive 시점 카운트는 보존)
- High Priority 즉시 승격 (이미 한 번 archive까지 갔는데 재발 = 시스템 이슈)
- archive 줄에 "[2026-05-01 재발 → active 복귀]" 노트 추가 후 active로

### 5.2 Drift 검출 — 코드와 컨텍스트 자산 동기화

**Drift란?** 코드는 변했는데 자산(architecture/glossary/non-obvious)이 안 갱신된 상태. 강의의 *"썩어가는 컨텍스트는 없는 것보다 나쁘다"*.

#### 검출 시점·로직

| 자산 | 검출 시점 | 로직 |
|---|---|---|
| `architecture.md` | RPI Closeout | 새/삭제 모듈 디렉터리 ↔ 모듈 그래프 노드 매칭. 불일치 시 갱신 권고 |
| `domain-glossary.md` | RPI Closeout | 새 클래스/함수/엔티티 식별자 추출 → glossary에 등재 안 됐으면 후보 목록을 메인에 보고 |
| `non-obvious.md` | 사이클 중 실패 발생 시 | 5 Whys 통과 항목만 등록 (위 §5.1) |
| `deny-patterns.md` | High Priority 승격 시 | 자동 권고 (사람 승인 후 추가) |
| `runbook.md` | 새 배포 명령·환경 변수 발견 시 | 메인이 사용자에게 갱신 권유 |

#### Drift 자동 검출 — `start-rpi-cycle` Phase Closeout이 호출

```
Agent(subagent_type="review-strict",
      task="drift 검사",
      context_paths=["docs/ai-context/architecture.md",
                     "docs/ai-context/domain-glossary.md",
                     "docs/ai-context/non-obvious.md"],
      success_criteria="
        - 새 디렉터리/모듈이 architecture.md에 반영
        - 새 도메인 식별자(클래스·함수·엔티티)가 glossary에 등재 (또는 등재 면제 사유 명시)
        - 사이클 중 실패가 5 Whys 통과 후 non-obvious에 누적 (또는 명시 면제)
      ")
```

→ FAIL 반환 시 사용자에게 항목별 갱신 요청. 사용자가 "면제" 명시 시 통과.

### 5.3 RPI 사이클 라이프사이클

#### 사이클 상태 머신

```
[Idle 상태]
   ↓ 사용자 변경 요청 (코드)
[start-rpi-cycle 호출]
   ↓
[Phase R: Research] (active plan 아직 없음 — enforce-rpi-cycle은 ≤5라인 화이트리스트로 통과)
   ↓ docs/superpowers/specs/<topic>-design.md 산출
   ↓
[Phase P: Plan] (writing-plans)
   ↓ docs/superpowers/plans/<topic>.md 산출 (Status: active 주입)
   ↓ 이 시점부터 enforce-rpi-cycle hook이 plan 인지 → 코드 변경 통과
   ↓
[Phase I: Implement] (executing-plans 또는 execute-strict)
   ↓ 사이클 중 실패 → 5 Whys → non-obvious.md 후보 누적
   ↓
[Phase Closeout]
   ↓ review-strict drift 검사 → 통과
   ↓ plan Status: active → completed (메인이 직접 Edit)
   ↓ state.json.cycle.count +1
   ↓ Cycle 5/20 도달 시 v2/v3 알림
   ↓ Non-Obvious archive 검사
   ↓
[Idle 상태]
```

#### 사이클 중단 (abandon)
- 사용자 명시 요청: "이 사이클 그만"
- Phase Closeout 건너뛰고 plan Status를 `abandoned`로 표시
- abandoned plan은 enforce-rpi-cycle의 활성 plan 검색에서 제외
- state.json.cycle.count는 증가 안 함 (완료된 사이클만 카운트)

#### 사이클 일시 중지 (pause)
- 사용자 명시 요청: "잠시 보류"
- plan Status를 `paused`로 표시
- 다른 사이클 시작 가능 (하지만 권장 X)
- paused plan을 다시 활성화하려면 명시적으로 `Status: active` 갱신

#### 사이클 중첩 정책

**한 시점 활성 plan = 0 또는 1**:
- 활성 plan이 있는데 사용자가 다른 작업 시작 시도 → 메인이 묻기:
  > "현재 활성 사이클이 있습니다. 어떻게 할까요?
  >  (a) 현재 사이클 종료 후 진행
  >  (b) 현재 사이클을 paused로 표시 후 새 사이클 시작
  >  (c) 새 작업을 현재 사이클에 통합 (스코프 확장)"
- 다중 활성은 컨텍스트 분산 → 금지

### 5.4 Hook 모니터링 운영

#### 5.4.1 임계 (§4.8.1 그대로)

| 지표 | 우수 | 허용 | 경고 |
|---|---|---|---|
| FPR (RPI_SKIP 비율) | < 2% | 2~5% | > 5% |
| enforce-orchestrator BLOCK / 7일 | 0 | ≤ 2 | ≥ 3 |
| enforce-rpi-cycle BLOCK / 7일 | ≤ 5 | ≤ 9 | ≥ 10 |
| stable-claude-md ALERT / 세션 | ≤ 1 | — | ≥ 2 |
| auto-compact-watch ALERT / 세션 | ≤ 1 | ≤ 2 | ≥ 3 |
| Hook p95 실행 시간 | < 100ms | < 200ms | ≥ 200ms |

#### 5.4.2 자동 점검 통합

`/init-ai-ready` Phase 0이 매 새 프로젝트 셋업마다 실행:
1. doctor.sh (환경 진단·치료)
2. 글로벌 CLAUDE.md drift 점검
3. Hook 로그 통계 (지난 7일):
   ```bash
   # 7일 이내 BLOCK·ALERT 카운트
   THRESH_DATE=$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d)
   awk -F'\t' -v d="$THRESH_DATE" '$1 >= d && $4 ~ /BLOCK|ALERT/' \
     ~/.claude/hooks/.log/$(date +%Y-%m).log | \
     awk -F'\t' '{c[$2"-"$4]++} END {for (k in c) print k, c[k]}'
   ```
4. 임계 초과 시 사용자 보고

→ 새 프로젝트를 한 달 동안 안 만드는 경우 → `session-start-audit`이 30일 경과 시 환기.

#### 5.4.3 session-start-audit 알림 정책 (§4 약점 #5 보강)

**행동**: 30일 경과 시 매 세션 시작마다 1회 알림.
**의도**: SessionStart hook 빈도가 낮아 (세션당 1회) 잡음 거의 없음.
**완화**: 사용자가 의도적으로 audit 미루고 싶으면 `~/.claude/CLAUDE.md`의 audit 마커를 수동 갱신 (`<!-- audit: 2026-05-01 -->`).
**자동 갱신 주체**: `/init-ai-ready` Phase 0이 점검 후 갱신. doctor.sh도 점검 후 갱신.

#### 5.4.4 비활성화 (§4.8.3 동일)

사용자 통제권 항상 우선. 셋업·인프라가 사용자 작업 흐름을 막을 가능성을 인정.

### 5.5 글로벌 CLAUDE.md drift 정책

#### 검출 방식 (자동 통합)

| 시점 | 동작 |
|---|---|
| 새 프로젝트 만들 때 (`/init-ai-ready` Phase 0) | drift 점검 + 필요 시 갱신 권고 |
| 30일 경과 (session-start-audit hook) | 1회 알림 — 다음 `/init-ai-ready` 실행 시 점검 권유 |

#### 점검 항목

1. 줄 수 ≤ 200 (강의 기준)
2. 6대 메타 룰 마커 모두 존재 (`## §1 ~ ## §6` headings)
3. audit 마커 존재 + 30일 이내
4. 위반 빈도 높은 룰 식별 (hook 로그 7일 통계 기반)

#### 갱신 주체

- 사용자가 직접 편집 (캐시 비용 환기 후)
- 또는 `/init-ai-ready` Phase 0이 사용자에게 묻고 자동 갱신:
  - audit 마커 갱신 (`<!-- audit: TODAY -->`)
  - 줄 수 초과 시 압축 권고

#### 분기별 수동 점검 — 불필요 (자동 통합)

이전에 검토했던 *"분기별 수동 점검"* 정책은 폐기. 자동 트리거 두 개로 충분.

### 5.6 v2/v3 자동 도입 트리거 — 사용자 승인형

**원칙**: 자동 활성 X, 도달 시 알림 + 사용자 승인.

#### 흐름

```
[Cycle N 완료, Phase Closeout 끝]
   ↓ N == 5 && state.features.v2_enabled == false
[v2 알림]
   ↓ 사용자: "활성화" / "건너뛰기" / "다시 묻지 마"
   ├─ 활성화: state.features.v2_enabled = true, v2_enabled_at = TODAY
   ├─ 건너뛰기: 다음 5 사이클 후 다시 묻기 (cycle 10에)
   └─ 다시 묻지 마: state.features.v2_skipped_permanently = true (스키마 추가)
   ↓
[다음 사이클부터 v2 로직 적용]
```

#### state.json features 필드 활용

§2.12 schema_version=1에 이미 포함된 필드:
```json
"features": {
  "v2_enabled": false,
  "v2_enabled_at": null,
  "v2_skipped_permanently": false,
  "v3_enabled": false,
  "v3_enabled_at": null,
  "v3_skipped_permanently": false
}
```

알림 트리거 조건:
- v2 알림: `cycle.count == 5 && !v2_enabled && !v2_skipped_permanently`
- v3 알림: `cycle.count == 20 && !v3_enabled && !v3_skipped_permanently`

→ "다시 묻지 마" 선택 시 `*_skipped_permanently` = true → 영구 알림 미발동.

### 5.7 첫 사이클 vs N번째 사이클의 차이 — 강화 효과

| 자산 | Cycle 1 | Cycle 5 | Cycle 20 |
|---|---|---|---|
| `architecture.md` | 빈 그래프 | ADR 5개, 의존성 정확 | ADR 20개, 큰 결정 모두 추적 |
| `domain-glossary.md` | 빈 표 | 30 용어, 5 모호성 | 100+ 용어 |
| `non-obvious.md` | 빈 파일 | 10 active, 3 archive | 5 active, 30 archive (학습됨) |
| `deny-patterns.md` | 기본 deny | 사고 1건 추가 | 사고 + non-obvious 5회+ 자동 승격 |
| **다음 사이클 prefix 품질** | (낮음) | (중) | (높음 — AI Native) |

→ Cycle 20쯤이면 모든 비명백 패턴, 도메인 언어, 결정 이력이 prefix로 자동 주입. 강의의 *"AI Native"* 단계.

### 5.8 §5 마감

§5는 시간 축의 운영. 사이클이 돌수록 자산이 강해지는 메커니즘 정의.

다음 섹션:
- §6 — 검증 체크리스트 (환경 / 셋업 / Hook / Skill / E2E)
- §7-9 — 빌드 순서, 도입 로드맵, 미해결

---

## §6. 검증 체크리스트

§6은 디자인이 의도대로 동작하는지 **반복 가능하게 확인**하는 절차. 셋업 직후 1회, 그리고 분기마다 또는 큰 변경 후 재실행.

### 6.0 검증 의도

| 원칙 | 적용 |
|---|---|
| Deterministic — 같은 입력 → 같은 결과 | 모든 검증은 Bash로 자동화 |
| Layered — 환경 → 셋업 → Hook → Skill → E2E 단계별 통과 | 하나라도 실패하면 다음 단계 의미 없음 |
| Reproducible — 별도 디렉터리에서 격리 검증 | `~/Documents/test-ai-ready/` 활용 |
| Honest — 실패는 명시적, 우회 없음 | exit 1 = 불합격 |

### 6.1 환경 베이스라인 검증 (15개 항목)

`~/.claude/setup/doctor.sh`가 진단·치료. 진단만 따로 실행하려면 `bash ~/.claude/setup/doctor.sh --diagnose-only`.

| # | 항목 | 통과 조건 | 자동 수복 가능? |
|---|---|---|---|
| 1 | Claude Code 버전 | ≥ 2.1.0 (subagent isolation, skills 필드) | ❌ |
| 2 | node 버전 | ≥ v18 (json_get 구문) | ❌ |
| 3 | bash 버전 | ≥ 4.0 (associative arrays) | ❌ |
| 4 | git 설치 | `git --version` 응답 | ❌ |
| 5 | git config user.name | 비어있지 않음 | ❌ (안내) |
| 6 | git config user.email | 비어있지 않음, 형식 valid | ❌ (안내) |
| 7 | gh CLI 설치 | `gh --version` 응답 | ❌ (OS별 가이드) |
| 8 | gh 인증 | `gh auth status` exit 0 | ❌ (`gh auth login` 안내) |
| 9 | 인터넷 연결 | `curl -sI https://api.anthropic.com` 응답 | ❌ |
| 10 | 디스크 공간 | `~/.claude` 위치 ≥ 1GB 여유 | ❌ |
| 11 | `~/.claude/` 쓰기 권한 | `touch` 테스트 | ❌ |
| 12 | OS 호환성 | Linux / macOS / Windows(Git Bash 또는 WSL) | ❌ |
| 13 | python (선택) | `python3 --version` 응답 | ❌ (선택) |
| 14 | node JSON 파싱 | `echo '{"a":1}' \| node -e "..."` 정상 | ❌ |
| 15 | jq (선택) | 미설치면 자동 설치 시도 | ✅ (winget/choco/scoop/brew/apt) |
| 16 | install 마커 | `~/.claude/setup/.installed` | ✅ (자동 생성) |
| 17 | audit 마커 | `~/.claude/CLAUDE.md`의 `<!-- audit: ... -->` | ✅ (오늘 날짜로 생성) |
| 18 | backup 디렉터리 | `~/.claude.backup-YYYY-MM-DD/` | ✅ (cp -r) |
| 19 | git 관리 권유 | `~/.claude/`가 git 저장소면 OK, 아니면 권유 | ⚠️ (강제 X) |

**통과 기준**: 1~14가 ✓, 15~19는 자동 수복 가능. 0~14 중 하나라도 ✗면 exit 1.

### 6.2 Hook 단위 검증 — Fixture 기반 (총 65 케이스)

`~/.claude/hooks/tests/run-all.sh`가 자동 실행.

#### 6.2.1 `enforce-orchestrator.sh` (12 케이스)

| # | 케이스 | 입력 | 기대 |
|---|---|---|---|
| 1 | 마커 없는 단순 skill 신규 | Write, no marker | exit 0 |
| 2 | 마커 + 골격 완전 (Phase 3, Agent 1, Contract) | Write | exit 0 |
| 3 | 마커 + Phase 0개 | Write | exit 2 |
| 4 | 마커 + Phase 2개 | Write | exit 2 |
| 5 | 마커 + Agent 호출 0개 | Write | exit 2 |
| 6 | 마커 + Communication Protocol 누락 | Write | exit 2 |
| 7 | 기존 skill Edit (Phase 추가) | Edit, new_string에 새 Phase | exit 0 |
| 8 | 기존 skill Edit (Phase 삭제 → 2개) | Edit | exit 2 |
| 9 | 마커 키 오타 (`orchestrator_skil:`) | Write | exit 0 (검증 대상 아님) |
| 10 | Agent 호출이 주석 안에 (`# Agent(...)`) | Write | exit 2 (substring 매칭) |
| 11 | Phase 마커 한국어 (`# Phase 1 — 탐색`) | Write | exit 0 |
| 12 | 매우 큰 SKILL.md (2000줄) | Write | exit 0 + 처리 시간 < 200ms |

#### 6.2.2 `stable-claude-md.sh` (9 케이스)

| # | 케이스 | 경로 | 기대 |
|---|---|---|---|
| 1 | 프로젝트 루트 CLAUDE.md Edit | `<repo>/CLAUDE.md` | 알림 |
| 2 | 프로젝트 루트 CLAUDE.md Write 신규 | 동일 | 알림 |
| 3 | 모듈 CLAUDE.md (`docs/modules/x/CLAUDE.md`) | 모듈 경로 | 미발동 |
| 4 | 글로벌 `~/.claude/CLAUDE.md` | 절대경로 | 미발동 |
| 5 | 상대경로 `./CLAUDE.md` | 상대 | 알림 |
| 6 | Windows 절대경로 `C:\path\CLAUDE.md` | Windows | 알림 (Claude Code 정규화 후) |
| 7 | MSYS 변환 경로 `/c/path/CLAUDE.md` | MSYS | 알림 |
| 8 | `MY_CLAUDE.md` (유사 이름) | 다른 파일 | 미발동 |
| 9 | 심볼릭 링크 통한 수정 | symlink | 알림 |

#### 6.2.3 `auto-compact-watch.sh` (11 케이스)

| # | 케이스 | 입력 | 기대 |
|---|---|---|---|
| 1 | 사용량 30% (60K/200K) | 정상 transcript | 미발동 |
| 2 | 사용량 정확히 40% (80K) | 임계 도달 | **알림** |
| 3 | 사용량 41% (80.2K) | 임계 초과 | 알림 |
| 4 | 사용량 80% (160K) | 높음 | 알림 |
| 5 | transcript_path 누락 | JSON 키 없음 | 미발동 (장애 안전) |
| 6 | transcript 파일 없음 | path 있는데 파일 X | 미발동 |
| 7 | 잘못된 JSONL (깨진 줄) | 일부 파싱 실패 | 미발동 또는 부분 데이터 |
| 8 | usage 필드 없는 메시지만 | 모든 line 누락 | 미발동 |
| 9 | 같은 세션 두 번째 호출 (마커 존재) | `/tmp/compact-alerted-<sid>` | 미발동 (중복 방지) |
| 10 | 다른 세션 신규 | sid 다름 | 알림 |
| 11 | CONTEXT_LIMIT env 변경 (100K) | 임계 절반 | 41K부터 알림 |

#### 6.2.4 `enforce-rpi-cycle.sh` (18 케이스)

| # | 케이스 | 입력 | 기대 |
|---|---|---|---|
| 1 | `*.md` Edit | `docs/foo.md` | 통과 |
| 2 | `.gitignore` Edit | `.gitignore` | 통과 |
| 3 | `README.md` 신규 | `README.md` | 통과 |
| 4 | 코드 1줄 Edit (≤5라인) | `src/foo.ts` Edit | 통과 |
| 5 | 코드 6줄 Edit | `src/foo.ts` Edit | active plan 검사 |
| 6 | `RPI_SKIP=hotfix` env | env 설정 | 통과 |
| 7 | `plans/` 디렉터리 자체 없음 | (Phase R 안 함) | 차단 |
| 8 | plan 파일 0개 | dir 비어있음 | 차단 |
| 9 | active plan 1개 (체크박스 미완료) | superpowers 기본 | 통과 |
| 10 | plan에 `Status: completed` | 모든 체크박스 완료 | 차단 |
| 11 | plan에 `Status: abandoned` | abandoned | 차단 |
| 12 | plan에 `Status: paused` | paused | 차단 (§5 보강 검증) |
| 13 | 2개 plan: 1 active + 1 completed | 혼재 | 통과 |
| 14 | 신규 코드 파일 Write | `Write` 도구 | active plan 필수 |
| 15 | 확장자별 (`.py`/`.go`/`.rs`/`.tsx`/`.java`) | 코드 | 모두 active plan 검사 |
| 16 | 특수 파일 (Dockerfile, Makefile) | 확장자 없음 | active plan 검사 |
| 17 | `.config.js`, `webpack.config.ts` | 설정 파일 | active plan 검사 |
| 18 | 테스트 파일 (`*.test.ts`, `*_test.py`) | 코드 취급 | active plan 검사 |

#### 6.2.5 `session-start-audit.sh` (7 케이스)

| # | 케이스 | 마커 상태 | 기대 |
|---|---|---|---|
| 1 | 첫 실행 (마커 없음) | 없음 | "마커 없음" 안내 |
| 2 | 25일 전 마커 | `<!-- audit: 2026-04-06 -->` | 미발동 |
| 3 | 정확히 30일 전 (경계) | `<!-- audit: 2026-04-01 -->` | 미발동 |
| 4 | 31일 전 | `<!-- audit: 2026-03-31 -->` | 알림 |
| 5 | 마커 형식 손상 | `<!-- audit: bad-date -->` | 미발동 (장애 안전) |
| 6 | 여러 audit 마커 | tail -1 사용 | 가장 최근 일자 |
| 7 | 미래 날짜 마커 | `<!-- audit: 2027-01-01 -->` | 미발동 (시계 문제) |

#### 6.2.6 `pre-commit-deny.sh` (프로젝트 hook, 8 케이스)

| # | 케이스 | tool_input | 기대 |
|---|---|---|---|
| 1 | "DROP TABLE users" | Bash command | 차단 |
| 2 | "drop table users" (소문자) | Bash command | 차단 (대소문자 무관) |
| 3 | "git push --force origin main" | Bash command | 차단 |
| 4 | "git push origin main" (force 아님) | Bash command | 통과 |
| 5 | "rm -rf node_modules" | Bash command | 통과 (구체 경로) |
| 6 | "rm -rf /" | Bash command | 차단 |
| 7 | deny-patterns.md 파일 없음 | 외부에서 호출 | 통과 (장애 안전) |
| 8 | deny 한국어 패턴 | "운영 자격증명을 코드에" | 차단 (substring) |

**Hook 단위 합격 기준**: 65 케이스 중 통과율 ≥ 95% (3개 false positive 허용).

### 6.3 셋업 검증 (`verify-setup.sh`)

`~/.claude/` 글로벌 인프라 파일·디렉터리 존재 검증.

| # | 검증 항목 | 통과 조건 |
|---|---|---|
| 1 | `~/.claude/CLAUDE.md` 존재 + ≤200줄 | `wc -l` ≤ 200 |
| 2 | 메타 룰 6개 마커 | `grep -c '^## §[1-6]'` = 6 |
| 3 | `~/.claude/agents/*.md` 3개 | explore-strict, review-strict, execute-strict |
| 4 | 각 agent에 `skills: ["common-agent-contract"]` | grep 검증 |
| 5 | 각 agent에 `model: inherit` | grep 검증 |
| 6 | `~/.claude/skills/` 4개 | common-agent-contract, create-orchestrator-skill, init-ai-ready-project, start-rpi-cycle |
| 7 | orchestrator skills에 마커 3줄 | `orchestrator_skill: true`, `generated_by:`, `orchestrator_version:` |
| 8 | `~/.claude/hooks/*.sh` 5개 | 모두 +x |
| 9 | `~/.claude/hooks/_common.sh` 존재 | source 가능 |
| 10 | `~/.claude/commands/init-ai-ready.md` | 1줄 이상 |
| 11 | `~/.claude/skills/init-ai-ready-project/templates/` 8 .tpl + 2 references | 파일 카운트 |
| 12 | `~/.claude/setup/doctor.sh`, `verify-setup.sh`, `verify-integration.sh`, `verify-all.sh` | 모두 +x |
| 13 | `~/.claude/setup/.installed` 마커 | doctor.sh 1회 실행 흔적 |
| 14 | `settings.json` hooks 키 | jq로 파싱 + 5개 hook 등록 확인 |

**셋업 합격 기준**: 14개 항목 모두 ✓.

### 6.4 Skill 트리거 정확도

각 skill의 description이 의도된 사용자 발화에 정확히 매칭되는지.

#### 6.4.1 `init-ai-ready-project`

| 사용자 발화 | 트리거 기대 |
|---|---|
| "새 프로젝트 payflow 셋업해줘" | ✅ |
| "AI-ready 만들어줘" | ✅ |
| "프로젝트 초기화" | ✅ |
| "결제 모듈 추가해줘" (기존 프로젝트) | ❌ (start-rpi-cycle이 트리거되어야) |
| "버그 고쳐줘" | ❌ (start-rpi-cycle) |

#### 6.4.2 `start-rpi-cycle`

| 사용자 발화 | 트리거 기대 |
|---|---|
| "결제 도메인 추가" | ✅ |
| "이거 고쳐줘" | ✅ |
| "리팩토링 해줘" | ✅ |
| "이 함수 뭐 하는 거야?" (질문) | ❌ |
| "타이포 하나 고쳐줘" (≤5라인) | ❌ (hook 화이트리스트로 통과) |

#### 6.4.3 `create-orchestrator-skill`

| 사용자 발화 | 트리거 기대 |
|---|---|
| "이거 자주 쓸 것 같아 skill로 만들어줘" | ✅ |
| "orchestrator로 자동화" | ✅ |
| "단순 텍스트 변환 skill 만들어줘" | ❌ |

**Skill 트리거 합격 기준**: 정확도 ≥ 90% (10건 중 9건).

### 6.5 End-to-End 시나리오 — 4개

검증 환경: `C:\Users\12132\Documents\test-ai-ready\`

#### 6.5.1 Happy Path — 빈 디렉터리에서 첫 사이클 완주

```bash
mkdir -p /c/Users/12132/Documents/test-ai-ready && cd $_
git init
```

| 단계 | 명령 | 기대 |
|---|---|---|
| 1 | `/init-ai-ready test-ai-ready` | Phase 0~4 통과. 10개 파일 (9 .tpl + state.json) + 3개 디렉터리 (specs/plans/hooks). doctor 1회 실행. drift 보고 |
| 2 | `vim docs/ai-context/domain-glossary.md` 결제 용어 추가 | enforce-rpi-cycle 통과 (md 화이트리스트). stable-claude-md 미발동 |
| 3 | "결제 도메인 모듈 추가해줘" | start-rpi-cycle 트리거 → Phase R |
| 4 | (R) "OK 진행해" | Phase P → plans/<topic>.md 생성 (Status: active) |
| 5 | (P 후) 코드 파일 작성 시도 | enforce-rpi-cycle 통과 (active plan) |
| 6 | Phase I 완료 후 "사이클 종료" | Phase Closeout → architecture/glossary/non-obvious 검증 → plan Status: completed |
| 7 | 다른 코드 변경 시도 | enforce-rpi-cycle 차단 (active plan 0개) |
| 8 | "타이포 하나 고쳐" 1줄 | enforce-rpi-cycle 통과 (≤5라인) |

#### 6.5.2 Negative Path — 차단 동작 검증

| 단계 | 시도 | 기대 |
|---|---|---|
| A | 마커 있는 skill을 골격 없이 작성 | enforce-orchestrator 차단 |
| B | plans 없이 코드 변경 | enforce-rpi-cycle 차단 |
| C | "DROP TABLE users" Bash 시도 | pre-commit-deny 차단 |

#### 6.5.3 Recovery Path — 차단 후 복구

| 단계 | 시도 | 기대 |
|---|---|---|
| A | enforce-rpi-cycle 차단 → start-rpi-cycle 실행 → plan 생성 → 다시 변경 | 통과 |
| B | enforce-orchestrator 차단 → orchestrator 골격 추가 | 통과 |
| C | enforce-rpi-cycle 차단 → `RPI_SKIP=hotfix` 명시 | 통과 |

#### 6.5.4 Continuity Path — 사이클 N+1의 prefix 강화 검증

| 단계 | 동작 | 기대 |
|---|---|---|
| A | Cycle 1 완료 후 architecture.md, glossary, non-obvious 누적 데이터 | 자동 갱신 검증 |
| B | Cycle 2 시작 → Phase R explore-strict가 4개 자산을 prefix로 받음 | 동일 실수 식별 시간 단축 |
| C | non-obvious에 누적된 패턴이 같은 실수 시 빠르게 매칭 (v2 활성 후) | 재발 카운터 +1, High Priority 승격 |

### 6.6 합격 기준 (전체)

전체 시스템 합격 = 다음 모두 통과:

| 카테고리 | 합격 기준 |
|---|---|
| 환경 (6.1) | 19개 항목 모두 ✓ |
| Hook 단위 (6.2) | 6 hook × 65 케이스 통과율 ≥ 95% |
| 셋업 (6.3) | 14 항목 모두 ✓ |
| Skill 트리거 (6.4) | 정확도 ≥ 90% |
| E2E (6.5) | 4 시나리오 모두 통과 |

→ 불합격 시 디자인 갱신 + 재구현 후 재검증.

### 6.7 롤백·복구 시나리오

| 문제 | 즉시 대응 | 영구 대응 |
|---|---|---|
| Hook이 정당한 작업 차단 | `RPI_SKIP=<reason>` env 또는 `CLAUDE_CODE_HOOKS=disabled` | 화이트리스트 추가 또는 검증 로직 수정 |
| Skill description 매칭 실패 | 명시 호출 (`/init-ai-ready` 또는 Skill 도구로 직접) | description 보강 |
| 글로벌 CLAUDE.md drift | `/init-ai-ready` Phase 0이 자동 보고 | 메타 룰 갱신 |
| 모든 hook 잠시 끄기 | `mv ~/.claude/settings.json ~/.claude/settings.json.bak` | settings.json에서 특정 hook만 제거 |
| 글로벌 인프라 전체 롤백 | `git checkout` (`~/.claude/` git 관리 가정) | — |
| `doctor.sh` 자체 손상 | 수동 복구 — git에서 복구 또는 spec 문서 참조해 재작성 | git 백업 권장 |

**롤백 가능성 보장**: doctor.sh가 첫 실행 시 `~/.claude.backup-YYYY-MM-DD/` 자동 생성. git 관리도 권장.

### 6.8 검증 자동화 — 실행 순서

```bash
# 1단계: 환경 진단·치료
bash ~/.claude/setup/doctor.sh                  || exit 1   # 6.1

# 2단계: 셋업 검증
bash ~/.claude/setup/verify-setup.sh            || exit 1   # 6.3

# 3단계: hook 단위
bash ~/.claude/hooks/tests/run-all.sh           || exit 1   # 6.2

# 4단계: 통합 시나리오 (test-ai-ready 임시 디렉터리)
bash ~/.claude/setup/verify-integration.sh      || exit 1   # 6.4, 6.5

echo "ALL PASS"
```

한 줄 launcher: `bash ~/.claude/setup/verify-all.sh` (위 4단계 순차 실행).

### 6.9 §6 마감

§6은 시스템이 의도대로 동작하는지의 합격 기준. 셋업 후 1회 + 분기마다 또는 큰 변경 후 재실행 권장.

다음 섹션:
- §7 — 의존성·빌드 순서 (13단계)
- §8 — 단계적 도입 로드맵
- §9 — 미해결·향후 검토
- Appendix — 참조

---

## §7. 의존성·빌드 순서

§7은 **이 시스템을 처음부터 만들 때의 정확한 순서**다. 각 컴포넌트의 의존성이 무엇이고, 무엇을 먼저 만들어야 다음을 만들 수 있는지 명시한다.

### 7.0 의존성 그래프

```
                    [doctor.sh]
                         │ (자립)
                         ▼
                  ┌──── 환경 검증 통과 ────┐
                  │                       │
                  ▼                       ▼
        [templates/*.tpl]    [common-agent-contract skill]
        (자립)                 (자립)
                  │                       │
                  └───────────┬───────────┘
                              ▼
                   [agents/*-strict.md × 3]
                   (skills: [common-agent-contract] 의존)
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
   [init-ai-ready-      [start-rpi-cycle]  [create-orchestrator-
     project skill]     skill              skill]
   (agents + tem-       (agents + super-   (agents + skill-creator
    plates 의존)         powers 의존)        플러그인 의존)
              │
              ▼
   [commands/init-ai-ready.md]
   (init-ai-ready-project 의존)

                              │
                              ▼
         ┌─────── [hooks/_common.sh] ────────┐
         │              │                    │
         ▼              ▼                    ▼
   [hooks/*.sh × 5]  [hooks/tests/         [pre-commit-deny.sh
                      fixtures/*]           (프로젝트 hook)]
                                            (자립, 정책만)
              │
              ▼
   [settings.json hooks 키]
   (hooks/*.sh 존재 의존)

              │
              ▼
   [~/.claude/CLAUDE.md 재작성]
   (위 모두 위치 확정 의존)

              │
              ▼
   [verify-setup.sh / verify-integration.sh / verify-all.sh]
   (모든 컴포넌트 의존)

              │
              ▼
   [test-ai-ready 검증 환경 구성]
   (verify-* 통과 의존)
```

### 7.1 13단계 빌드 순서 — 상세

각 단계: **산출물 / 의존 / 검증 / 롤백 비용**.

#### 단계 1 — `doctor.sh` 작성

| 항목 | 내용 |
|---|---|
| 산출물 | `~/.claude/setup/doctor.sh` (실행권한 +x) |
| 의존 | 없음 (자립) |
| 검증 | `bash ~/.claude/setup/doctor.sh` exit 0 + 19개 항목 보고 |
| 롤백 비용 | 거의 0 (단일 파일 삭제) |
| 주의 | node 미설치 시 즉시 exit 1로 fail-fast. jq 자동 설치 시도. |

#### 단계 2 — Templates 작성

| 항목 | 내용 |
|---|---|
| 산출물 | `~/.claude/skills/init-ai-ready-project/templates/*.tpl` (8개) + `references/*.md` (2개) |
| 의존 | 없음 (자립 — 정적 파일) |
| 검증 | 파일 존재 + Mustache 문법 valid (placeholder 매칭 균형) |
| 롤백 비용 | 거의 0 (디렉터리 삭제) |
| 주의 | state.json.tpl 포함 (10번째 .tpl). placeholder-spec.md와 stack-presets.md는 §3.12, §3.13 본문 그대로 |

#### 단계 3 — `common-agent-contract` skill 작성

| 항목 | 내용 |
|---|---|
| 산출물 | `~/.claude/skills/common-agent-contract/SKILL.md` |
| 의존 | 없음 (자립 — Input/Output 형식만 정의) |
| 검증 | YAML frontmatter valid + body에 Input Contract / Output Contract / Scope Lock 섹션 존재 |
| 롤백 비용 | 거의 0 |
| 주의 | orchestrator skill 아님 (마커 X) |

#### 단계 4 — Wrapper Agent 3개 작성

| 항목 | 내용 |
|---|---|
| 산출물 | `~/.claude/agents/{explore-strict, review-strict, execute-strict}.md` |
| 의존 | 단계 3 (common-agent-contract — `skills:` 필드로 참조) |
| 검증 | YAML valid + `model: inherit` + `skills: ["common-agent-contract"]` + `<example>` 블록 |
| 롤백 비용 | 거의 0 |
| 주의 | 단계 3 없이 만들면 Claude Code 시작 시 skill 참조 실패 경고 (작동은 함) |

#### 단계 5 — `init-ai-ready-project` skill 작성

| 항목 | 내용 |
|---|---|
| 산출물 | `~/.claude/skills/init-ai-ready-project/SKILL.md` (templates/는 단계 2에서 만듦) |
| 의존 | 단계 4 (agent 3개), 단계 2 (templates) |
| 검증 | orchestrator 마커 3줄 + Phase 0~4 마커 + `Agent(subagent_type=)` 호출 ≥ 1 |
| 롤백 비용 | 거의 0 (skill 삭제) |
| 주의 | Phase 2가 templates를 사용하므로 단계 2 선행 필수 |

#### 단계 6 — `start-rpi-cycle` skill 작성

| 항목 | 내용 |
|---|---|
| 산출물 | `~/.claude/skills/start-rpi-cycle/SKILL.md` |
| 의존 | 단계 4 (agent 3개), superpowers 플러그인 (brainstorming, writing-plans, executing-plans, finishing-a-development-branch) |
| 검증 | orchestrator 마커 + Phase R/P/I/Closeout 마커 + Agent 호출 |
| 롤백 비용 | 거의 0 |
| 주의 | superpowers가 enabledPlugins에 있어야 함 — `~/.claude/settings.json`에서 확인 |

#### 단계 7 — `create-orchestrator-skill` skill 작성

| 항목 | 내용 |
|---|---|
| 산출물 | `~/.claude/skills/create-orchestrator-skill/SKILL.md` |
| 의존 | 단계 4 (agent 3개), skill-creator 플러그인 |
| 검증 | orchestrator 마커 + Phase 1~4 + Agent 호출 |
| 롤백 비용 | 거의 0 |
| 주의 | skill-creator 플러그인이 enabledPlugins에 있어야 함 |

#### 단계 8 — Slash Command 작성

| 항목 | 내용 |
|---|---|
| 산출물 | `~/.claude/commands/init-ai-ready.md` (3줄) |
| 의존 | 단계 5 (init-ai-ready-project skill 존재) |
| 검증 | 명령 실행 시 skill 호출 |
| 롤백 비용 | 거의 0 |
| 주의 | skill 없으면 명령은 정의되지만 실행 시 skill 매칭 실패 |

#### 단계 9 — Hook 스크립트 작성 (`_common.sh` + 5개)

| 항목 | 내용 |
|---|---|
| 산출물 | `~/.claude/hooks/_common.sh` + `enforce-orchestrator.sh` / `stable-claude-md.sh` / `auto-compact-watch.sh` / `enforce-rpi-cycle.sh` / `session-start-audit.sh` (모두 +x) |
| 의존 | 없음 (정책만 약속). 단 `_common.sh`는 다른 hook의 source 의존 |
| 검증 | 각 스크립트 fixture로 단위 테스트 (단계 10에서 실행) |
| 롤백 비용 | 낮음 (settings.json에서 hooks 키 제거하면 즉시 비활성) |
| 주의 | hook 스크립트는 만들어 놓고 settings.json 등록은 단계 11에서. 등록 전엔 무동작. |

#### 단계 10 — Hook 단위 테스트 fixture 작성

| 항목 | 내용 |
|---|---|
| 산출물 | `~/.claude/hooks/tests/fixtures/*/<case>.input.json` + `.expected_exit` (총 65 케이스) + `run-all.sh` |
| 의존 | 단계 9 (hook 스크립트) |
| 검증 | `bash ~/.claude/hooks/tests/run-all.sh` 통과율 ≥ 95% |
| 롤백 비용 | 거의 0 |
| 주의 | 단계 9 직후 실행 — hook이 의도대로 동작하는지 검증해야 단계 11에서 등록 안전 |

#### 단계 11 — `settings.json` hooks 키 등록

| 항목 | 내용 |
|---|---|
| 산출물 | `~/.claude/settings.json`에 hooks 키 추가 (PreToolUse 3 + PostToolUse 1 + SessionStart 1) |
| 의존 | 단계 9 (hook 스크립트 존재), 단계 10 (단위 테스트 통과 — false positive 방어) |
| 검증 | `node -e "JSON.parse(require('fs').readFileSync('$HOME/.claude/settings.json'))"` 성공 + Claude Code 재시작 후 hook 등록 인지 |
| 롤백 비용 | 매우 낮음 (settings.json.backup-YYYY-MM-DD에서 즉시 복구) |
| 주의 | **이 단계가 활성화 시점**. 등록 전엔 hook이 동작 안 함. 등록 후 false positive 발생하면 즉시 settings.json 롤백. |

#### 단계 12 — `~/.claude/CLAUDE.md` 재작성

| 항목 | 내용 |
|---|---|
| 산출물 | `~/.claude/CLAUDE.md` (≤200줄, 메타 룰 6개 + 기존 4개 압축) |
| 의존 | 단계 1~11 (모든 컴포넌트가 위치 확정되어야 메타 룰이 의미 있음) |
| 검증 | `wc -l` ≤ 200 + `grep -c '^## §[1-6]'` = 6 + audit 마커 존재 |
| 롤백 비용 | 매우 낮음 (이전 버전 git 또는 backup에서 복구) |
| 주의 | 이 시점에서 메타 룰이 메인 세션 prefix에 자동 로드됨. 강의 사상 *"Cache Stability"* 적용 — 다음 세션부터 캐시 hit |

#### 단계 13 — 검증 자동화 스크립트 + 검증 환경 구성

| 항목 | 내용 |
|---|---|
| 산출물 | `~/.claude/setup/{verify-setup, verify-integration, verify-all}.sh` (모두 +x) + `~/Documents/test-ai-ready/` 검증 디렉터리 |
| 의존 | 단계 1~12 모두 |
| 검증 | `bash ~/.claude/setup/verify-all.sh` exit 0 (§6 합격 기준) |
| 롤백 비용 | 거의 0 (검증 스크립트는 read-only) |
| 주의 | test-ai-ready 디렉터리에서 `/init-ai-ready test-ai-ready` 실행 후 §6.5 E2E 시나리오 4개 모두 통과 확인 |

### 7.2 의존성 위반 시 동작

만약 순서를 어기면:

| 위반 | 결과 |
|---|---|
| 단계 4 (agent) 만들기 전 단계 5 (skill)부터 만듦 | skill의 `Agent(subagent_type="explore-strict")` 호출이 "agent not found" 오류 |
| 단계 9 (hook) 만들기 전 단계 11 (settings.json 등록) | Claude Code가 hooks 키 파싱 시 "command not found" 무시 (graceful fail) — 작업은 정상 |
| 단계 10 (단위 테스트) 건너뛰고 단계 11 (등록) | 정상 작업이 hook으로 차단될 위험 (false positive) — 즉시 롤백 필요 |
| 단계 3 (contract) 없이 단계 4 (agent) | agent 시작 시 `skills: ["common-agent-contract"]` 참조 실패 — Claude Code가 경고 후 무시. agent는 동작하지만 contract 없음 |
| 단계 12 (CLAUDE.md) 먼저 → 단계 1~11 | 메타 룰이 참조하는 컴포넌트가 없어 사용자 혼란. 메인이 룰 따르려 해도 실행 불가 |

→ **순서 준수가 중요**. 특히 단계 10이 단계 11 바로 앞에 있는 이유: false positive를 사전 차단.

### 7.3 단계별 롤백 가능성

전체 시스템 롤백 시나리오:

```bash
# 즉시 롤백 (활성 hook 비활성화)
mv ~/.claude/settings.json ~/.claude/settings.json.bak
# 또는
export CLAUDE_CODE_HOOKS=disabled

# 글로벌 인프라 전체 복구 (git 관리 시)
cd ~/.claude && git reset --hard <baseline-commit>

# git 미사용 시 doctor.sh가 만든 backup에서
rm -rf ~/.claude/{agents,skills/{common-agent-contract,create-orchestrator-skill,init-ai-ready-project,start-rpi-cycle},hooks,setup,docs}
cp -r ~/.claude.backup-YYYY-MM-DD/* ~/.claude/
```

각 단계는 독립적으로 롤백 가능하므로, 문제 발생 시 마지막 추가한 단계만 되돌리고 진행 가능.

### 7.4 빌드 vs 운영 — 한 줄 launcher

#### 빌드 (1회만)
```bash
# 단계 1~13 순서대로 (수동 또는 빌드 스크립트)
bash ~/.claude/setup/build.sh    # NEW — 13단계 자동화 (선택)
```

> `build.sh`는 본 spec의 의무 구현 항목이 아니지만, 향후 자동화하면 셋업 재현성↑.
> 현재는 plan 단계(writing-plans)에서 13단계를 task로 분해하여 수동 빌드.

#### 운영 (매번)
```bash
# 검증
bash ~/.claude/setup/verify-all.sh

# 진단 (분기별 또는 30일 경과 알림 후)
bash ~/.claude/setup/doctor.sh
```

### 7.5 §7 마감

§7은 디자인을 코드로 옮길 때의 길잡이. 이 13단계가 plan(writing-plans)에서 task로 분해될 것이다.

---

## §8. 단계적 도입 로드맵

§8은 시간 축의 도입 로드맵. *"처음부터 모든 걸 만들지 않는다"* (강의 사상 — Day 0 / Cycle 5 / Cycle 20).

### 8.1 Day 0 — 셋업 (즉시)

**범위**: §7의 13단계 빌드 + §6의 검증 통과.

**활성 컴포넌트**:
- Wrapper agent 3개
- 글로벌 skill 4개 (common-agent-contract, create-orchestrator-skill, init-ai-ready-project, start-rpi-cycle)
- Hook 5개 (전부 차단/알림 모드 활성)
- 메타 룰 6개 (글로벌 CLAUDE.md prefix)
- doctor.sh + 검증 스크립트

**미활성**:
- Non-Obvious v2 (재발 카운터 자동 갱신)
- Non-Obvious v3 (자동 deny 승격)

**합격 기준**: §6.6 (환경 19 + Hook ≥95% + 셋업 14 + Skill ≥90% + E2E 4).

**소요 추정**: 단계 1~13을 plan에 옮긴 후 약 8~12시간 (병렬 task 가능 시 더 짧음).

### 8.2 Cycle 5 — Non-Obvious v2 도입 검토

**트리거**: 어느 한 프로젝트의 `state.json.cycle.count == 5`.

**도입 시 활성화**:
- 사이클 중 발생 실패 패턴 vs active patterns 자동 매칭 (§5.1 v2)
- 매칭 시 재발 카운터 +1
- 카운터 ≥ 2 → High Priority 승격

**도입 결정 흐름** (§5.6):
- start-rpi-cycle Phase Closeout이 사용자에게 묻기
- 활성화 / 건너뛰기 / 영구 건너뛰기 3택
- 영구 건너뛰기 시 `state.features.v2_skipped_permanently = true`

**소요 추정**: 5 사이클 누적 후 메타 변경 1회 (start-rpi-cycle Phase Closeout 본문 갱신). 약 30분.

**전환 위험**: v2 매칭 알고리즘의 false positive — 매칭 너무 느슨하면 무관한 패턴이 카운트됨. 1주일 모니터링 후 임계 조정.

### 8.3 Cycle 20 — Non-Obvious v3 도입 검토

**트리거**: 어느 한 프로젝트의 `state.json.cycle.count == 20`.

**도입 시 활성화**:
- 재발 카운터 ≥ 5 → deny-patterns.md 자동 승격 권고
- 사용자 승인 시 deny에 추가 → hook으로 차단
- 30일 재발 0 → archive

**도입 결정 흐름**: v2와 동일 (사용자 승인형).

**소요 추정**: start-rpi-cycle 갱신 + 검증 약 1시간.

**전환 위험**: deny 승격이 너무 공격적이면 정당한 작업 차단 → §4 운영 정책의 false positive 임계 (FPR < 5%) 모니터링 후 결정.

### 8.4 Beyond Cycle 20 — 향후

§9 미해결 항목들이 도입 후보:
- Agent memory 활용 (cycle 50+ 데이터 모인 후)
- Fitness function 자동 작성
- skill-creator 자체 wrap (Anthropic이 hook 인터페이스 열면)
- Cron job (별도 인프라 필요)

각 항목은 별도 spec → plan → 구현 사이클로.

### 8.5 §8 마감

도입 로드맵은 강의의 *"먼저 측정하고 그 다음 자동화"* 흐름. Day 0은 즉시, 그 외는 데이터가 모인 후 사용자 승인.

---

## §9. 미해결·향후 검토

§9는 본 spec의 범위 밖이지만 인지하고 있는 항목. 별도 spec으로 발전시킬 후보.

### 9.1 Cron Job — "잠자는 동안 도착한 브리핑"

**강의 인용**: 슬라이드 8번 — 사용자가 잠자는 동안 cron이 GitHub/Calendar/MCP 로그를 분석해 아침 7시에 브리핑.

**왜 이 spec에 없나**:
- Claude Code의 `CronCreate`는 세션 안에서만 동작. 사용자가 Claude를 안 켜면 안 돌아감.
- 진정한 background는 별도 인프라 (GitHub Actions, ECS, cron+systemd) 필요.
- 우리 글로벌 인프라 범위 밖.

**향후 검토**:
- 별도 GitHub Actions 워크플로우로 매일 7시 실행 → 결과를 `~/.claude/briefings/YYYY-MM-DD.md`에 저장 → SessionStart hook이 이 파일을 메인에 알림.
- 또는 macOS launchd / Windows Task Scheduler로 로컬 cron.

**선결 조건**: 사용자의 인프라 선호 + GitHub Actions 비용 검토.

### 9.2 Fitness Function 자동 작성 (v3+)

**현재 한계**: deny-patterns.md의 `❌` 마커는 결정적 substring 매칭. *"운영 자격증명을 코드/커밋에 포함"* 같은 의미 기반 패턴은 substring으로 한계.

**미래 옵션**:
- 의미 기반 검증을 LLM 호출로 (PreToolUse hook 안에서 작은 모델 호출)
- 트레이드오프: 비용·지연
  - Haiku 호출 ~50ms + ~$0.0001/call → 매 Write/Edit마다 발동 시 누적 부담
  - 캐싱: 같은 패턴 반복 시 결과 재사용 가능

**선결 조건**: v3 활성화 후 deny 패턴 누적 데이터로 비용 모델링.

### 9.3 Skill-creator 자체 Wrap

**현재 구조**: `create-orchestrator-skill`이 skill-creator를 호출 후 결과 후처리 (마커·골격 주입).

**한계**:
- skill-creator 플러그인 업데이트 시 출력 형식 변경 가능 → 후처리 로직 깨질 위험
- 사용자가 직접 skill-creator를 호출하면 우리 마커가 안 붙음 (의도된 우회)

**미래 옵션**:
- Anthropic이 plugin 안에 hook 인터페이스를 열면 skill-creator 자체에 후처리 로직 주입 가능
- 또는 skill-creator를 fork해서 우리 버전 만들기 (plugin 업데이트 추적 부담)

**선결 조건**: Anthropic의 plugin hook API 출시 또는 skill-creator의 stable 인터페이스 합의.

### 9.4 Agent Persistent Memory 활용

**기능**: Claude Code의 sub-agent에 `memory: user | project | local` 필드로 영속 메모리 부여.

**현재 미사용 이유**:
- sub-agent가 메모리를 어떻게 활용할지 패턴이 미성숙
- 디버깅 어려움 (메모리 안에 무엇이 있는지 사용자가 모름)
- 잘못 누적되면 정확도 하락

**미래 옵션**:
- Cycle 50+ 데이터로 어떤 sub-agent가 어떤 컨텍스트를 학습하면 효과적인지 측정
- 예: review-strict가 자주 보는 deny 패턴을 메모리에 캐시 → 호출당 토큰 절감

**선결 조건**: 50+ 사이클 누적 + Claude Code의 메모리 디버깅 도구 성숙.

### 9.5 글로벌 사이클 통계 분석

**현재**: 사이클 카운트는 프로젝트별. 글로벌 합산 X.

**미래 옵션**:
- 여러 프로젝트의 state.json 합산 → "전체 cycle 100회 도달 시 도구 자체 개선 트리거"
- 예: `enforce-rpi-cycle` BLOCK 패턴 분석 → 화이트리스트 자동 제안

**선결 조건**: 사용자 데이터 수집 동의 + 분석 인프라.

### 9.6 자동 ADR 생성 (LLM 기반)

**현재**: 메인 세션이 메타 룰 §5에 따라 ADR 작성 권유. 사람이 결정.

**미래 옵션** (adolfi.dev 사례):
- AI agent가 변경 직후 자동으로 ADR 초안 생성 → 사람 승인 후 append
- agents.md 설정에 *"Always create an ADR when..."* 추가하는 패턴

**선결 조건**: ADR 자동 생성의 false positive 모니터링 — 사소한 변경이 ADR 남기면 잡음.

### 9.7 Hook 로그 자동 정리

**현재**: `~/.claude/hooks/.log/YYYY-MM.log` 무한 증가 (사용자 책임).

**미래 옵션**:
- 12개월 이상 자동 archive 또는 삭제
- 또는 매 분기별 로그 압축 (`gzip` + 통계 요약 추출 후 원본 삭제)

**선결 조건**: 6개월 사용 후 로그 크기 측정.

### 9.8 §9 마감

이 항목들은 본 spec의 V1 범위 밖. 시스템이 운영되며 데이터가 모이면 별도 spec으로 발전.

---

## Appendix

### A.1 참조 자료 (외부)

#### 강의 자료
- *AI-Ready Codebase* (Fast Campus, 실별개발자, 2026.04.29) — 본 디자인의 핵심 사상 출처
- 슬라이드 8: AI-Native cron 브리핑
- 슬라이드 17: CLAUDE.md 실전 — Non-Obvious Patterns
- 슬라이드 25: 적용 4단계 (측정 → 수정 → 자동화)
- 슬라이드 28: Amazon 사고 — *"시스템이 자동으로 막는 것"*
- 슬라이드 29: 실용 Hook 4가지

#### Anthropic 공식
- [Claude Code sub-agents](https://code.claude.com/docs/en/sub-agents) — frontmatter 필드, model: inherit, skills 필드, isolation: worktree
- [Claude Code hooks](https://code.claude.com/docs/en/hooks) — lifecycle, exit code, stdin JSON
- [Anthropic plugin-dev/skills/agent-development](https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/agent-development/SKILL.md) — agent template

#### 업계 베스트 프랙티스
- [VILA-Lab/Dive-into-Claude-Code](https://github.com/VILA-Lab/Dive-into-Claude-Code) — *"Claude Code 1.6%만 AI, 98.4%는 결정론적 인프라"*
- [shanraisshan/claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice) — fresh isolated context + persistent identity
- [wshobson/agents](https://github.com/wshobson/agents) — 184 agent 8 도메인
- [Piebald-AI/claude-code-system-prompts](https://github.com/Piebald-AI/claude-code-system-prompts) — 빌트인 sub-agent 시스템 프롬프트

#### Hook 언어 선택
- [claudefa.st — Hooks Guide](https://claudefa.st/blog/tools/hooks/hooks-guide) — Bash ~10ms / Node ~50-100ms / Python ~200-400ms
- [pydevtools — Python hooks](https://pydevtools.com/handbook/how-to/how-to-write-claude-code-hooks-for-python-projects/)
- [Anthropic — bash_command_validator example](https://github.com/anthropics/claude-code/blob/main/examples/hooks/bash_command_validator_example.py) — Python 예시

#### Postmortem / RCA
- [Google SRE — Postmortem Culture](https://sre.google/sre-book/postmortem-culture/) — *"Human error is a symptom, not a cause"*
- [Atlassian — 5 Whys](https://www.atlassian.com/incident-management/postmortem/5-whys)

#### ADR
- [Microsoft Azure ADR](https://learn.microsoft.com/en-us/azure/well-architected/architect-role/architecture-decision-record) — Append-only log
- [Martin Fowler — ADR](https://martinfowler.com/bliki/ArchitectureDecisionRecord.html)
- [adolfi.dev — AI generated ADR](https://adolfi.dev/blog/ai-generated-adr/) — agents.md instruction 패턴
- [adr.github.io](https://adr.github.io/) — 템플릿 허브

#### Runbook vs Playbook vs Work Plan
- [Cortex — Runbooks vs Playbooks](https://www.cortex.io/post/runbooks-vs-playbooks)
- [minware — Runbooks and Playbooks](https://www.minware.com/guide/best-practices/runbooks-and-playbooks-1)

#### Domain-Driven Design (Ubiquitous Language)
- [Martin Fowler — Ubiquitous Language](https://martinfowler.com/bliki/UbiquitousLanguage.html)
- [Eric Evans — DDD Reference](https://www.domainlanguage.com/wp-content/uploads/2016/05/DDD_Reference_2015-03.pdf)

#### Hook 모니터링 / SRE
- [KPI Depot — False Positive Rate](https://kpidepot.com/kpi/false-positive-rate-security-monitoring) — < 2% excellent / 2~5% acceptable / > 5% concerning
- [Google SRE — Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/)
- [Prophet Security — SOC Alert Tuning](https://www.prophetsecurity.ai/blog/security-operations-center-soc-best-practices-alert-tuning)

### A.2 환경 진단 결과 (2026-05-01)

본 디자인 작성 시점의 사용자 환경 (§0.2 D 그대로):

| 도구 | 버전 |
|---|---|
| Claude Code | 2.1.126 |
| node | v24.13.1 |
| git | 2.47.1 (Windows MSYS) |
| gh CLI | 2.89.0 + 인증 (Easy-T) |
| python | 3.14.3 |
| bash | 5.2.37 (MSYS Git Bash) |
| jq | 미설치 (doctor.sh가 설치 시도) |

### A.3 용어집 (Glossary)

| 용어 | 정의 |
|---|---|
| **AI Native** | AI가 사고 흐름과 분리 불가능, 사용자는 Orchestrator로 작동하는 단계 (강의 4단계 중 4단계) |
| **Orchestrator skill** | Phase 1/2/3 골격 + Agent 호출 + Communication Protocol을 가진 skill. `orchestrator_skill: true` 마커로 식별. |
| **Wrapper agent** | 빌트인 agent(Explore/Plan/general-purpose)에 표준 contract를 강제하는 얇은 sub-agent. `model: inherit` + `skills: [common-agent-contract]`. |
| **RPI Cycle** | Research → Plan → Implement → Closeout 4단계 사이클. `start-rpi-cycle` skill이 강제. |
| **Phase Closeout** | RPI 사이클의 마지막 단계 — drift 검사, 자산 갱신 검증, cycle_count 갱신. |
| **5 Whys** | Toyota / Google SRE 표준 RCA 기법. 증상에서 root cause까지 5회 "왜?" 반복. |
| **ADR** | Architecture Decision Record. Append-only log. |
| **Drift** | 코드는 변했는데 자산(architecture/glossary/non-obvious)이 안 갱신된 상태. |
| **Compass not Encyclopedia** | CLAUDE.md는 인덱스, 자세한 건 lazy load (강의 사상). |
| **Passive Optimization** | 사용자가 잊어도 시스템이 강제 (강의 사상). |
| **Cache Stability** | 루트 CLAUDE.md 세션 중 수정 금지 — 캐시 미스 비용 ≈20배. |

### A.4 변경 이력

| 일자 | 변경 |
|---|---|
| 2026-05-01 | 최초 작성 (브레인스토밍 합의 후) |

---

## 문서 마감

본 디자인 문서는 §0~§9 + Appendix 총 **약 2,800줄**.

**다음 단계**:
1. 사용자 spec 검토 (이 문서 읽고 OK/수정)
2. OK 시 `writing-plans` skill로 13단계를 task 분해한 implementation plan 작성
3. plan을 `executing-plans` 또는 `subagent-driven-development`로 구현
4. §6.5 E2E 시나리오 통과로 합격

**Status:** Approved (2026-05-01) → 다음 단계: writing-plans로 13단계 task 분해.







