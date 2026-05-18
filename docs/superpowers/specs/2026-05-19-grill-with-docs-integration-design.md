# grill-with-docs Harness Integration — Design Spec

**Status:** active
**Date:** 2026-05-19

---

## Goal

Phase R의 맨 앞에 `grill-with-docs`를 필수 단계로 통합하여, 모든 RPIC 전에 도메인 어휘가 `CONTEXT.md`에 확립되도록 강제한다. 이를 통해 brainstorming·explore-strict·writing-plans·improve-codebase-architecture 전 단계가 일관된 어휘 위에서 동작하게 한다.

---

## Architecture

### Phase R 새 구조

```
Phase R = A(grill-with-docs) → B(brainstorming) → C(explore-strict)

A. grill-with-docs  — 도메인 용어 확립 (CONTEXT.md 생성/갱신)
B. brainstorming    — spec 작성 (CONTEXT.md 어휘 기반)
C. explore-strict   — 코드베이스 분석 (CONTEXT.md + domain-glossary.md 둘 다 읽음)

※ B와 C는 A 완료 후 병렬 가능
```

### 어휘 파일 역할 분리

```
CONTEXT.md  (프로젝트 루트)
  owner   : grill-with-docs (Matt Pocock 외부 스킬)
  content : 순수 vocabulary — 용어 정의·관계·회피어·예시 대화·Flagged ambiguities
  format  : Matt의 CONTEXT-FORMAT.md 엄격 적용
  rule    : 구현 세부사항·스펙·ADR 기록 금지

docs/ai-context/domain-glossary.md
  owner   : RPIC 메인 세션 (grill 완료 후 sync)
  content : CONTEXT.md 포인터 + 하네스 메타데이터
             (용어별 첫 등장 날짜·RPIC·confidence·코드 식별자)
  rule    : CONTEXT.md 정의를 절대 중복 기재 금지
```

### context_paths 원칙

CONTEXT.md와 domain-glossary.md는 **항상 함께** context_paths에 포함:

```python
context_paths=[
  "CONTEXT.md",                         # primary vocabulary
  "docs/ai-context/domain-glossary.md", # harness metadata + pointer
  ...
]
```

적용 대상:
- `start-rpi-cycle` Phase R.C explore-strict
- `start-rpi-cycle` Closeout C-1 drift check
- `improve-codebase-architecture` Phase 1 explore-strict

---

## grill-with-docs 설치 전략

- **소유자**: Matt Pocock (`mattpocock/skills` GitHub repo)
- **우리 역할**: 재작성 없이 외부 스킬 그대로 사용 (업그레이드는 Matt에게 위임)
- **설치 경로**: `~/.claude/skills/grill-with-docs/` (SKILL.md + CONTEXT-FORMAT.md + ADR-FORMAT.md)
- **자동화**: `doctor.sh` check #20에서 존재 확인 → 없으면 gh API로 자동 다운로드
- **심각도**: WARN (not FAIL) — core harness 동작을 막지 않음

doctor.sh 자동 설치 로직:
```bash
for f in SKILL.md CONTEXT-FORMAT.md ADR-FORMAT.md; do
  gh api repos/mattpocock/skills/contents/skills/engineering/grill-with-docs/$f \
    | node -e "decode base64 → write to file"
done
```

---

## 변경 상세

### 1. `templates/CONTEXT.md.tpl` (신규)

Matt의 CONTEXT-FORMAT.md 기반 스텁. 섹션:
- `## Language` — 용어 등록 형식 주석 포함, 부트스트랩 시 비어 있음
- `## Relationships` — 관계 표기 형식 주석 포함
- `## Example dialogue` — 부트스트랩 시 비어 있음
- `## Flagged ambiguities` — 부트스트랩 시 비어 있음

### 2. `templates/domain-glossary.md.tpl` (수정)

기존 독립 glossary 포맷 → 포인터 + 메타데이터 포맷:

```markdown
# Domain Glossary — {{PROJECT_NAME}}

## Primary Vocabulary
→ [CONTEXT.md](../../CONTEXT.md) 참조 (grill-with-docs 관리)

## Harness Metadata
| 용어 | 첫 등장 날짜 | RPIC | Confidence | 코드 식별자 |
|---|---|---|---|---|

## Flagged for Review
```

### 3. `init-ai-ready-project/SKILL.md` (수정)

- **Phase 0**: `메타 룰 6개` → `메타 룰 8개` (`## §1` ~ `## §8`)
- **Phase 2**: 파일 목록에 `13. <root>/CONTEXT.md ← templates/CONTEXT.md.tpl` 추가, 설명 `12개` → `13개`
- **Phase 3**: verify success_criteria에 `CONTEXT.md 존재` 추가, `12개 파일` → `13개 파일`

### 4. `start-rpi-cycle/SKILL.md` (수정)

**Phase R 전면 교체:**

```markdown
# Phase R — Research

A. grill-with-docs skill 절차 (메인이 직접 따름) — 도메인 용어 확립
   ※ 미설치 시: bash ~/.claude/setup/doctor.sh 로 자동 설치
   → 산출물: CONTEXT.md 갱신 (프로젝트 루트), docs/adr/*.md (조건부)
   → grill 세션 종료 후 메인이 직접: domain-glossary.md 메타데이터 테이블에 신규 용어 기록

B. brainstorming skill 절차 (메인이 직접 따름) — 외향적 (요구·접근법·디자인)
   ※ CONTEXT.md에 확정된 용어를 언어 기반으로 사용
   → 산출물: docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md

C. Agent(subagent_type="explore-strict",
        task="<요청 분석>",
        context_paths=["CONTEXT.md",
                       "docs/ai-context/architecture.md",
                       "docs/ai-context/domain-glossary.md",
                       "docs/ai-context/non-obvious.md",
                       "docs/ai-context/deny-patterns.md"],
        success_criteria="발견사항·영향 모듈·신규 도메인 용어·deny pattern 충돌 식별")
   ※ CLAUDE.md는 메인이 자동 로드하므로 context_paths에 미포함 (중복 회피)
   ※ B와 C는 병렬·교차 가능 (A 완료 후)

## Gate R
- CONTEXT.md 갱신 확인 (A 완료 검증)
- 신규 도메인 용어 confidence < 80% → 사용자 확인 → domain-glossary.md 메타데이터 추가
- 아키텍처 영향 → ADR 초안 작성 권유 (architecture.md append-only)
```

**Closeout C-1 수정:**
- context_paths에 `"CONTEXT.md"` 추가
- success_criteria 첫 줄에 `"CONTEXT.md 갱신 (신규 용어 추가됨) 또는 변경 없음 확인"` 추가

### 5. `improve-codebase-architecture/SKILL.md` (수정)

- **Phase 1** context_paths: `"CONTEXT.md"` 추가 (맨 앞)
- **Phase 4** 입력 파일: `CONTEXT.md` 추가 (용어 기반 README 생성 품질 향상)

### 6. `setup/doctor.sh` (수정)

check #20 추가 (`# Report` 블록 직전):

```bash
# 20. grill-with-docs skill (auto-install from mattpocock/skills)
GRILL_SKILL="$CLAUDE_HOME/skills/grill-with-docs/SKILL.md"
if [ -f "$GRILL_SKILL" ]; then
  check "grill-with-docs skill" "PASS" ""
else
  [gh 인증된 경우 node로 base64 decode → 3개 파일 다운로드]
  PASS → "auto-installed" / WARN → "수동 설치 URL 안내"
fi
```

### 7. `setup/verify-setup.sh` (수정)

```bash
# 변경 전
[ "$T" -ge 12 ] && ... fail "templates=$T (need 12) ..."
# 변경 후
[ "$T" -ge 13 ] && ... fail "templates=$T (need 13) ..."
```

### 8. `README.md` (수정)

- 필수 플러그인 표에 `mattpocock/skills` 의존성 행 추가
- 프로젝트 구조 트리에 `CONTEXT.md.tpl` 추가
- 시나리오 2 설명에 Phase R.A grill-with-docs 언급 추가

### 9. `CLAUDE.md §6` (세션 끝 수정)

```markdown
# 변경 전
- 확인된 용어 + 코드 식별자 매핑 → glossary 자동 추가
- 같은 단어 다른 컨텍스트 → "Identical-Looking" 섹션에

# 변경 후
- 확인된 용어 → CONTEXT.md 갱신 → domain-glossary.md 메타데이터 sync
- 같은 단어 다른 컨텍스트 → CONTEXT.md "Flagged ambiguities"에
```

---

## 전체 사이클 흐름 (적용 후)

```
사용자: "기능 추가해줘"
  ↓ start-rpi-cycle 발동
  ↓
Phase R:
  A. grill-with-docs → CONTEXT.md 확립 (어휘 정의)
     → domain-glossary.md 메타데이터 sync
  B. brainstorming   → spec 작성 (CONTEXT.md 어휘 사용)
  C. explore-strict  → 코드 분석 (CONTEXT.md + domain-glossary.md 읽음)

Gate R: CONTEXT.md 갱신 확인 + 잔여 confidence 체크

Phase P: writing-plans → plan.md (B의 spec 어휘 자동 반영)

Gate P: review-strict alignment check

Phase I: 구현

Closeout:
  C-1 drift: CONTEXT.md + domain-glossary.md + architecture.md 갱신 확인
  state.json +1, improve-codebase-architecture 제안 (5 배수)

  ↑ 사이클 반복 시 CONTEXT.md가 누적 → Phase R.A 점점 짧아짐
  ↑ improve-codebase-architecture Phase 1: CONTEXT.md 기반 naming drift 탐지
```

---

## 파일 의존 순서

```
병렬 가능:
  [1] CONTEXT.md.tpl 신규
  [5] improve-codebase-architecture/SKILL.md 수정
  [6] doctor.sh 수정
  [4] start-rpi-cycle/SKILL.md 수정

순차:
  [2] domain-glossary.md.tpl 수정   (1 이후 — 포인터 경로 확인)
  [3] init-ai-ready-project/SKILL.md 수정  (1, 2 이후 — 파일 목록 카운트)
  [7] verify-setup.sh 수정   (1 이후 — 카운트 확인)
  [8] README.md 수정   (전체 이후)
  [9] CLAUDE.md §6 수정   (세션 끝)
```
