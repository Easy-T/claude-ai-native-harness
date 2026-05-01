# 멜른버그 LLM Wiki — 전체 구조 개편 계획 (Sub-agent 오케스트레이션)

## Context

카파시(Karpathy) LLM Wiki 패턴 기반으로 부동산 투자 지식 위키를 구축 중. 현재 108개 wiki 페이지가 있으나 YAML frontmatter 없음, raw/ 레이어 미분리, Graphify 미통합, 224개 PDF 미처리 상태.

**핵심 전략**: 단일 세션(오케스트레이터)이 병렬 sub-agent를 자동 호출해 대량 작업 처리. 사용자는 Phase 시작 명령만 입력하면 됨.

---

## 아키텍처

```
사용자 → /wiki-phase1  (한 번 타이핑)
           └── 오케스트레이터 (Sonnet)
                ├── 파일/폴더 생성
                └── 완료 보고

사용자 → /wiki-phase2  (한 번 타이핑)
           └── 오케스트레이터 (Sonnet)
                ├── _progress.md 읽어서 배치 분할
                ├── Sub-agent A ──→ wiki 파일 1-36 업그레이드
                ├── Sub-agent B ──→ wiki 파일 37-72 업그레이드
                └── Sub-agent C ──→ wiki 파일 73-108 업그레이드
                     └── 완료 후 오케스트레이터가 index.md / _progress.md 통합

사용자 → /wiki-phase3-기타       → Sub-agent 1개 (24개)
사용자 → /wiki-phase3-인천경기   → Sub-agent 2개 (44개, 22개 배치)
사용자 → /wiki-phase3-서울       → Sub-agent 3개 (156개, 52개 배치)

사용자 → /wiki-phase4  (한 번 타이핑)
           └── wiki-lint → wiki-graphify 순차 실행
```

**Sub-agent 격리 원칙**:
- Sub-agent는 자신이 담당한 wiki .md 파일만 쓴다
- `index.md`, `log.md`, `_progress.md`는 **오케스트레이터만** 수정
- Sub-agent는 완료 목록을 반환만 하고 공유 파일에 손대지 않음

---

## 최종 폴더 구조 (To-Be)

```
멜른버그/
├── README.md                      ← LLM wiki 사용 가이드
├── CLAUDE.md                      ← Layer 3 스키마
├── .graphifyignore
├── .gitignore
├── .claude/
│   ├── settings.json              ← Graphify PreToolUse 훅
│   └── commands/                  ← 슬래시 커맨드 (스킬)
│       ├── wiki-phase1.md         ← 구조 셋업 오케스트레이터
│       ├── wiki-phase2.md         ← 업그레이드 오케스트레이터
│       ├── wiki-phase3.md         ← 신규 변환 오케스트레이터
│       ├── wiki-phase4.md         ← Graphify + Lint
│       ├── wiki-ingest.md         ← Sub-agent용: 단일 PDF 변환
│       ├── wiki-upgrade.md        ← Sub-agent용: 단일 파일 업그레이드
│       ├── wiki-lint.md           ← 위키 건강 점검
│       └── wiki-graphify.md       ← Graphify 빌드 + 분석
├── raw/                           ← Layer 1: 불변 원본
│   ├── 스타터팩/  (10)
│   ├── 기초/      (164)
│   ├── 서울/      (156)  ← 미처리
│   ├── 인천경기/  (44)   ← 미처리
│   └── 기타/      (24)   ← 미처리
├── wiki/                          ← Layer 2: 위키
│   ├── _system/
│   │   ├── _progress.md           ← 진척도 (오케스트레이터만 수정)
│   │   ├── _standards.md          ← 페이지 작성 표준
│   │   └── _templates/
│   │       └── note.md            ← 표준 페이지 템플릿
│   ├── hot.md                     ← 세션 컨텍스트 캐시
│   ├── index.md                   ← 마스터 인덱스
│   ├── log.md                     ← 작업 히스토리
│   └── *.md                       ← 108개 기존 + ~170개 신규
└── graphify-out/                  ← Graphify 자동생성
```

---

## 스킬 명세

### 오케스트레이터 스킬 (사용자가 직접 호출)

#### `/wiki-phase1` — 구조 셋업
```
역할: Phase 1 전체를 순서대로 자동 실행
작업:
1. raw/ 폴더 생성 후 스타터팩/, 기초/, 서울/, 인천경기/, 기타/ 이동
2. README.md, CLAUDE.md, .graphifyignore, .gitignore 생성
3. .claude/settings.json 생성 (Graphify 훅)
4. wiki/_system/ 생성: _progress.md (108+224개 전체 목록), _standards.md, _templates/note.md
5. wiki/hot.md 생성
6. wiki/index.md 갱신 (raw/ 경로 반영)
7. wiki/log.md에 Phase 1 완료 기록
완료 후: 변경 내역 요약 출력
```

#### `/wiki-phase2` — 108개 업그레이드 오케스트레이터
```
역할: _progress.md에서 미완료 파일 읽기 → 3개 배치 분할 → 병렬 sub-agent 실행
작업:
1. wiki/_system/_progress.md에서 [Phase2] 미완료 항목 수집
2. 3개 배치로 균등 분할
3. Agent 도구로 3개 sub-agent 동시 실행 (wiki-upgrade 스킬 지시)
   - 각 sub-agent: 담당 파일 목록 + wiki-upgrade 지시문 전달
   - 금지: index.md, _progress.md, log.md 수정
4. 3개 sub-agent 결과 수집
5. _progress.md 업데이트 (완료 항목 체크)
6. index.md에서 source 경로 raw/ 반영
7. log.md에 배치 완료 기록
```

#### `/wiki-phase3 [지역]` — 신규 변환 오케스트레이터
```
사용법: /wiki-phase3 기타 | /wiki-phase3 인천경기 | /wiki-phase3 서울
역할: 지정 지역의 미처리 PDF 목록 읽기 → 배치 분할 → 병렬 sub-agent 실행
작업:
1. raw/[지역]/ 에서 PDF 목록 수집
2. _progress.md에서 이미 완료된 항목 제외
3. 지역별 배치 크기: 기타(전체1개), 인천경기(22개x2), 서울(52개x3)
4. Agent 도구로 sub-agent 동시 실행 (wiki-ingest 스킬 지시)
   - 각 sub-agent: 담당 PDF 목록 + wiki-ingest 지시문 전달
   - 금지: index.md, _progress.md, log.md 수정
5. 결과 수집 → 공유 파일 통합 업데이트
```

#### `/wiki-phase4` — Graphify + Lint
```
역할: 전체 위키 품질 점검 + 지식 그래프 생성
작업:
1. wiki-lint 실행: 고아 페이지, 깨진 링크, YAML 누락, placeholder 잔존 탐지
2. Lint 결과 출력 → 사용자 확인 요청
3. (승인 후) wiki-graphify 실행: graphify-out/ 빌드
4. GRAPH_REPORT.md 분석 요약
5. index.md 최종 재구성 (신규 카테고리 반영)
```

### Sub-agent 스킬 (오케스트레이터가 내부 호출)

#### `wiki-upgrade` — 단일 파일 업그레이드
```
입력: wiki 파일 경로
작업:
1. wiki/[file].md 읽기
2. 하단 출처 메타데이터에서 원본 PDF 경로 파악
3. raw/[source].pdf 읽기 (Claude 네이티브 PDF 읽기)
4. YAML frontmatter 추가/보완 (표준 포맷 준수)
5. placeholder 제거 + PDF 내용으로 채우기
6. 이미지/표 인식 불량 구간 보완
7. 교차참조 → YAML related 필드로 이관 (본문 섹션도 유지)
8. 파일 저장
반환: {file: 경로, status: done|failed, notes: 비고}
금지: index.md, _progress.md, log.md 수정
```

#### `wiki-ingest` — 단일 PDF 변환
```
입력: raw/ PDF 경로, 카테고리
작업:
1. raw/[path].pdf 읽기 (Claude 네이티브 PDF 읽기)
2. _templates/note.md 기준 YAML frontmatter + 본문 작성
3. 파일명: snake_case 영문, 내용 기반으로 생성
4. wiki/[filename].md 저장
반환: {pdf: 경로, wiki: 생성된 파일 경로, status: done|failed}
금지: index.md, _progress.md, log.md 수정
```

---

## YAML Frontmatter 표준

```yaml
---
title: "페이지 제목"
type: concept | entity | source-summary | comparison
category: 투자전략 | 임장입지 | 투자실무 | 정책규제 | 거시경제 | 권리분석 | 투자복기 | 대출·금융 | 지역분석_서울 | 지역분석_수도권/지방
tags: [태그1, 태그2, 태그3]
source: raw/카테고리/파일명.pdf
related:
  - "[[연관페이지1]]"
  - "[[연관페이지2]]"
created: YYYY-MM-DD
updated: YYYY-MM-DD
confidence: high | medium | low
---
```

---

## Phase별 초보자 실행 가이드

### 사전 준비 (5분)

1. VS Code에서 `c:\Users\12132\Documents\멜른버그` 폴더 열기
2. Claude for VS Code 확장에서 새 채팅 시작
3. 모델: Sonnet 선택 (Claude for VS Code 채팅창 하단)

---

### Phase 1 — 구조 셋업 (자동, ~20분)

**사용자가 입력할 내용:**
```
/wiki-phase1
```

**이후 자동으로 일어나는 일:**
- PDF 폴더 5개가 raw/ 하위로 이동됨
- README.md, CLAUDE.md 등 골격 파일 생성됨
- wiki/_system/ 생성, _progress.md에 전체 작업 목록 작성됨

**완료 후 사용자 확인 사항:**
- `멜른버그/` 루트에 raw/ 폴더와 그 안에 PDF 폴더 5개가 있는지 확인
- `wiki/_system/_progress.md` 열어서 108개 + 224개 목록이 있는지 확인
- 이상 없으면 Phase 2로 진행

**소요 시간**: 약 20-30분 (파일 이동 + 생성)

---

### Phase 2 — 기존 108개 업그레이드 (자동, 배치당 ~30분)

> 기존 wiki 페이지에 YAML frontmatter 추가 + 원본 PDF 재독해로 내용 보완

**사용자가 입력할 내용:**
```
/wiki-phase2
```

**이후 자동으로 일어나는 일:**
1. _progress.md에서 미완료 파일 108개 읽기
2. 36개씩 3배치로 나누기
3. **Sub-agent 3개 동시 실행** (병렬 처리)
   - Sub-agent A: 파일 1-36번 업그레이드
   - Sub-agent B: 파일 37-72번 업그레이드
   - Sub-agent C: 파일 73-108번 업그레이드
4. 모든 sub-agent 완료 후 → 오케스트레이터가 _progress.md, index.md 갱신

**완료 후 사용자 확인 사항:**
- 아무 wiki 파일 3-5개 열어서 YAML frontmatter가 상단에 있는지 확인
- `---`로 시작하는 YAML 블록이 있고 title, category, tags 등이 채워져 있으면 OK
- `wiki/_system/_progress.md`에서 Phase2 항목이 모두 `[x]`인지 확인
- 이상 없으면 Phase 3으로 진행

**실패/재시작 시**: 다시 `/wiki-phase2` 입력하면 _progress.md에서 미완료 항목만 재처리

**소요 시간**: 배치 1회 기준 약 20-40분 (108개 × PDF 읽기 + 글쓰기)

---

### Phase 3 — 미처리 224개 신규 변환 (지역별 순서대로)

> PDF → 새 wiki 페이지 생성. 지역별로 순서대로 실행 권장.

#### 3-1. 기타/ 24개 (주주서한 시리즈)

**사용자가 입력할 내용:**
```
/wiki-phase3 기타
```

Sub-agent 1개 실행. 약 30-50분.

**완료 후 확인**: wiki/에 새 .md 파일 24개 생성 여부

---

#### 3-2. 인천경기/ 44개

**사용자가 입력할 내용:**
```
/wiki-phase3 인천경기
```

Sub-agent 2개 병렬 실행 (22개씩). 약 30-40분.

**완료 후 확인**: wiki/에 새 .md 파일 44개 생성 여부

---

#### 3-3. 서울/ 156개 (3회 분할 실행 권장)

서울은 156개로 많기 때문에 한 번에 실행하면 세션이 길어질 수 있음.
**3회로 나눠서 실행** (각 52개씩):

```
/wiki-phase3 서울
```
→ 오케스트레이터가 자동으로 52개씩 3배치로 나눠 sub-agent 3개 병렬 실행.

Sub-agent 3개 병렬 실행. 1회당 약 40-60분.

**완료 후 확인**: wiki/에 서울 관련 .md 파일 156개 생성 여부

---

### Phase 3 완료 후 전체 확인 사항

- `wiki/_system/_progress.md`에서 Phase3 항목 전체가 `[x]`인지 확인
- `wiki/index.md` 열어서 지역분석_서울, 지역분석_수도권/지방 카테고리에 새 페이지들이 추가되었는지 확인

---

### Phase 4 — Graphify + Lint (자동, ~30분)

> 전체 위키 건강 점검 + 지식 그래프 생성

**사용자가 입력할 내용:**
```
/wiki-phase4
```

**이후 자동으로 일어나는 일:**
1. **Lint 점검** 먼저 실행:
   - 고아 페이지 탐지 (index.md에 없는 .md)
   - 깨진 `[[wikilink]]` 탐지
   - YAML 누락 페이지 목록
   - placeholder 잔존 텍스트 탐지
2. **Lint 결과 출력** → 이 시점에 사용자가 검토

**Lint 검토 후 사용자가 입력할 내용:**
```
확인했어. Graphify 실행해줘
```
또는 오류가 있으면 수정 지시 후 재실행.

3. **Graphify 빌드**: `graphify-out/` 생성
4. GRAPH_REPORT.md 분석 요약 출력

**최종 확인:**
- `graphify-out/graph.html` 브라우저로 열어서 노드 그래프 확인
- 주요 카테고리별로 클러스터가 형성되어 있는지 시각적으로 확인

---

## _progress.md 구조 (참고)

```markdown
# _progress.md — 작업 진척도

## Phase 2: 기존 108개 업그레이드
<!-- 오케스트레이터가 관리. 수동 수정 금지 -->
- [x] wiki/goal_amount_setting.md | source: raw/스타터팩/스타터팩(1).pdf
- [ ] wiki/archive_best_contents.md | source: raw/기초/...
...

## Phase 3: 신규 변환 — 기타 (24개)
- [ ] raw/기타/주주서한_2024_1.pdf → wiki/shareholder_letter_2024_1.md
...

## Phase 3: 신규 변환 — 인천경기 (44개)
- [ ] raw/인천경기/인천_2024_1.pdf → wiki/incheon_2024_1.md
...

## Phase 3: 신규 변환 — 서울 (156개)
- [ ] raw/서울/서울_강남_2024.pdf → wiki/seoul_gangnam_2024.md
...
```

---

## 설계 결정 사항

| 결정 | 선택 | 이유 |
|------|------|------|
| 병렬 처리 방식 | 단일 세션 내 sub-agent | Worktree 불필요, 사용자 부담 최소화 |
| 공유 파일 수정 | 오케스트레이터만 | Race condition 방지 |
| PDF 읽기 | Claude 네이티브 | extract_pdf.py 삭제 |
| Backlink | [[wikilink]] 단방향, Graphify가 양방향 계산 | 수동 backlink 불필요 |
| 관리 파일 위치 | wiki/_system/ | 실제 콘텐츠와 분리 |
| index.md, log.md, hot.md | wiki/ 루트 유지 | 내비게이션 파일, 접근성 우선 |
| 스킬 구조 | 오케스트레이터 4개 + sub-agent용 2개 + 유틸 2개 = 총 8개 | 역할 명확히 분리 |
