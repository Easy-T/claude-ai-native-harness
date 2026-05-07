# Housing Benefits Notification PWA — Design Spec

**Author:** Easy-T (with Claude Opus 4.7)
**Created:** 2026-05-08
**Status:** Approved (brainstorming complete, ready for writing-plans)
**Spec location:** `~/.claude/docs/superpowers/specs/2026-05-08-housing-benefits-app-design.md`
**Target project dir:** WSL Ubuntu — `~/projects/housing-benefits-app` (created at handoff)

---

## §0. 개요

### 0.1 문제 정의

한국의 정부 주거 혜택은 매매(청약/디딤돌)·전세(버팀목)·임대(공공/매입)로 갈리며, 1인 가구·신혼부부·신생아·다자녀·한부모 등 라이프 단계마다 자격 조건이 정밀하게 분기된다. 정책 자체가 매년 변경되며(예: 2025-10-15 부동산 대책으로 LTV·DSR·토허재 일괄 변경), 신규 정책(예: 미리내집 = 서울 SH 장기전세 II, 신생아 특례 디딤돌)이 수시로 추가된다.

현재 시장 서비스의 한계:

| 서비스 | 한계 |
|--------|------|
| 청약홈 청약알리미 | 청약만, 1년 재신청, 관심지역 10개 제한, 자격 매칭 X |
| SH/3기 신도시 알리미 | 권역 한정, 카톡만 |
| 호갱노노/직방 | 단지 중심, 자격 매칭 X, 임대정책 통합 X |
| 분양알리미류 민간 앱 | 마케팅 위주, 라이프이벤트 X |

**결과**: 사용자가 본인 라이프 단계와 조건에 맞는 혜택을 자동으로 추적·알림 받을 수 없다.

### 0.2 목표

1. 사용자 프로필(본인 + 배우자 + 자녀) 입력 → 모든 활성 정부 주거 혜택과 자동 매칭
2. 매일 전수조사로 신규 공고·정책 변경 감지 → 자격 충족 시 Google Calendar + 웹푸시 알림
3. **두 레이어 분리**:
   - **가이드 레이어**: 모든 정부 주거 혜택의 항상 최신 카탈로그
   - **매칭/알림 레이어**: 우선순위 정책(청약 + 임대 필수)부터 단계적 구현
4. 라이프 이벤트(혼인·출산·이사) 발생 시 자동 재매칭 + 미래 시점 시뮬레이션
5. 부동산 정책 현황(토허재·LTV·DSR) 실시간 요약 표시

### 0.3 비목표 (Non-Goals)

- 부동산 매매·임대 거래 중개
- 단지 평가 / 매물 추천 (호갱노노 영역)
- 청약 신청 자동화 (사용자가 정부 사이트 직접 접속)
- 다국어 지원 (Phase C 이후)
- 부동산 투자 자문

### 0.4 범위 — 정책 우선순위

**Phase A 필수 구현**:
- 매매 — 청약 (생애최초·신혼·다자녀·노부모·신생아 특공 + 일반공급)
- 임대 — 공공 (행복주택 청년·신혼, 국민임대, 영구임대, 매입임대, 전세임대, 미리내집)

**Phase A 후순위 카테고리** (가이드만, 매칭은 Phase B):
- 매매 — 디딤돌 / 신생아 특례 디딤돌
- 전세 — 버팀목 / 청년·신혼·신생아 버팀목
- 임대 — 민간 지원형

---

## §1. 단계 전략 (Phase Strategy)

```
Phase A.1 — 로컬 검증 (먼저, 길게)
  ├─ WSL Ubuntu 24.04 본인 PC
  ├─ Docker Compose: Postgres + 앱 + 크론 워커
  ├─ ngrok HTTPS (PWA 푸시 테스트)
  └─ 1~2주 안정 운영 검증
              ↓
Phase A.2 — GCP 배포 (검증 후)
  ├─ Cloud Run + Cloud SQL + Cloud Scheduler
  ├─ Cloud Storage (PDF) + Secret Manager
  ├─ GitHub Actions CI/CD
  └─ asia-northeast3 (Seoul) 리전
              ↓
Phase B — 지인 베타 (5~20명)
  ├─ NextAuth 다중 사용자
  ├─ 스코어링 카테고리 확장 (교통·학군·호재·공급량·등급)
  ├─ HWP 파서 워커 (kordoc)
  ├─ 청약 신청 추적기 (확장)
              ↓
Phase C — 공개 서비스
  ├─ 회원가입 / 약관 / 개인정보 처리방침 (KISA)
  ├─ Phase C 진입 시 데이터 이용 협의 (정부 기관)
  └─ 다국어, 결제 등
```

**중요**: Phase A.1이 먼저, 배포는 가장 마지막. 기능 검증을 비용 0으로 끝낸 뒤 GCP 인프라에 진입.

---

## §2. 두 레이어 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│ 가이드 레이어 (Always-Current Catalog)                      │
│   - 모든 정부 주거 혜택 카탈로그                            │
│   - 카테고리별 분류 + 검색 + 필터                           │
│   - 정책 본문 (LLM 요약) + 원문 링크                        │
│   - 매칭 자체는 안 함 — 백과사전                            │
└─────────────────────────────────────────────────────────────┘
                          ↓ 동일 policy DB 사용
┌─────────────────────────────────────────────────────────────┐
│ 매칭/알림 레이어 (Active Matching + Notification)           │
│   - 사용자 프로필 × 활성 공고 × 룰 매칭                     │
│   - 자격 충족 → 캘린더 + 웹푸시 알림                        │
│   - 라이프 이벤트 → 자동 재매칭 + What-if 시뮬             │
│   - 우선순위 정책만 (Phase A: 청약 + 임대)                  │
└─────────────────────────────────────────────────────────────┘
```

데이터 정형도가 다른 두 레이어를 한 DB에서 관리. 가이드는 텍스트 요약 + 링크만 있어도 OK. 매칭은 정밀 룰 JSON 필요.

---

## §3. 데이터 소스 5계층 (V2)

| 계층 | 역할 | Phase A 적용 |
|------|------|------------|
| **L1. 공공데이터포털 OpenAPI** | 마이홈 모집공고 + LH 단지정보 + 공동주택 정보 | 최우선 (정식 API) |
| **L2. 핵심 사이트 직접 스크래핑** | 청약홈·SH(미리내집)·GH (Playwright) | 필수 보강 |
| **L3-A. 자격 룰 변경 모니터링** | 보도자료 RSS/HTML → LLM 추출 → Verifier 검증 → 룰 DB 자동 갱신 | 필수 |
| **L3-B. 거시 정책 모니터링** | 토허재·LTV·DSR·세제 → 매일 요약 → 웹 첫 화면 카드 | 필수 |
| **L4. 공식 알림 미러링** | 청약홈 공식 알리미 카톡/SMS 수신 → 메시지 파싱 (백업) | 선택 |
| **L5. PDF/HWP 자동 다운로드 + 파싱** | pdfplumber/pdfjs + (Phase B) kordoc → LLM 요약 → DB | 필수 (PDF만, HWP는 Phase B) |

**주요 외부 출처:**

- 마이홈 OpenAPI: https://www.data.go.kr/data/15108420/openapi.do
- LH 단지 OpenAPI: https://www.data.go.kr/data/15058476/openapi.do
- 공동주택 OpenAPI: https://www.data.go.kr/data/15058453/openapi.do
- 청약홈: https://www.applyhome.co.kr
- 마이홈포털: https://www.myhome.go.kr
- LH 청약플러스: https://apply.lh.or.kr
- SH 청약시스템: https://www.i-sh.co.kr (미리내집 포함)
- GH 청약센터: https://apply.gh.or.kr
- 정책브리핑: https://www.korea.kr
- 금융위원회: https://fsc.go.kr
- 국토교통부: https://www.molit.go.kr

**제약 사항:**

- 공공 API 트래픽: 개발계정 1,000건/일 → 운영계정 신청 시 증가
- 일부 API 국내 IP 한정 → GCP Seoul 리전 필수
- 인증키 동기화 오류 (`SERVICE_KEY_IS_NOT_REGISTERED_ERROR`) 간헐 발생 → 재시도 로직

---

## §4. 시스템 아키텍처

```
사용자 (본인 + 배우자)
    │ PWA
    ▼
┌──────────────────────────────────────────┐
│  Next.js 15 App (Cloud Run)              │
│  - shadcn/ui Dashboard (모바일 우선)     │
│  - Service Worker (Web Push + 오프라인)  │
│  - Server Actions + API Routes           │
└──────────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────────┐
│  Cloud SQL Postgres (asia-northeast3)    │
│  - household / person / child / event    │
│  - policy / announcement / match         │
│  - rule_change_proposal / lookup_table   │
│  - announcement_score / supply_breakdown │
│  - policy_status / crawler_health        │
└──────────────────────────────────────────┘
    ▲
    │
┌──────────────────────────────────────────┐
│  Cloud Scheduler (cron)                  │
│  - 매일 N회 전수조사 트리거              │
│  - 매일 1회 헬스체크                     │
└──────────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────────┐
│  Cloud Run Jobs (워커)                   │
│  ├─ Sweep Worker (API + Playwright)      │
│  ├─ PDF Parser (pdfjs + LLM)             │
│  ├─ Extractor (LLM)                      │
│  ├─ Verifier Sub-Agent (웹서치 + LLM)    │
│  ├─ Matcher (TS 함수 + JSON 룰)          │
│  ├─ Score Computer                       │
│  ├─ Notification Dispatcher              │
│  └─ Health Check                         │
└──────────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────────┐
│  외부                                    │
│  ├─ 공공데이터포털 OpenAPI               │
│  ├─ 청약홈/SH/LH/GH (스크래핑)           │
│  ├─ 보도자료 RSS                         │
│  ├─ Anthropic Claude / OpenAI GPT-5.5    │
│  ├─ Tavily Search (Verifier)             │
│  ├─ Google Calendar API                  │
│  ├─ Web Push (VAPID)                     │
│  └─ Telegram Bot (헬스체크 알림)         │
└──────────────────────────────────────────┘
```

---

## §5. 기술 스택

| 레이어 | 선택 | 비고 |
|--------|------|------|
| Frontend | Next.js 15 App Router + shadcn/ui + Tailwind v4 | 2026 표준 |
| 베이스 템플릿 | next-shadcn-dashboard-starter + Vercel Registry Starter | AI 코딩 도구 친화 |
| Backend | Next.js Server Actions + API Routes | 모놀리스 |
| DB | PostgreSQL 16 (Cloud SQL Seoul) | 로컬은 Docker Postgres |
| ORM | Drizzle | TypeScript-first, SQL 직접 쓰기 좋음 |
| Auth (Phase A) | 단일 세션 토큰 | Phase B에서 NextAuth |
| Scheduler | Cloud Scheduler → Cloud Run Job | 로컬은 node-cron |
| Crawling | Playwright (Linux) | 청약홈·SH 동적 페이지 |
| API client | 공공데이터포털 SDK (자체 wrapper) | |
| PDF | `pdfjs-dist` (Node) | Phase B kordoc 추가 |
| HWP | LLM Vision으로 우회 (Phase A) → kordoc (Phase B) | Windows 의존성 회피 |
| LLM (Extractor/Summary) | Claude Sonnet 4.6 (기본) — env 교체 가능 | 비용 균형 |
| LLM (Judge/Verifier) | Claude Opus 4.7 또는 GPT-5.5 | 추론력 우선 |
| Verifier 웹서치 | Tavily API (1000 req/월 무료) | |
| Push | Web Push (VAPID 자체 생성) | iOS 16.4+ 호환 |
| Calendar | Google Calendar API (OAuth) | |
| 헬스체크 | Telegram Bot | 즉시성 |
| CI/CD | GitHub Actions → Cloud Build → Cloud Run | Phase A.2 |
| Observability | Cloud Logging + Sentry (무료 티어) | |
| Local Dev | WSL Ubuntu 24.04 + Node 22 + pnpm + Docker + ngrok | |

---

## §6. 데이터 모델

### 6.1 세대·구성원·라이프이벤트 (시계열)

```sql
household (
  household_id        PK,
  user_id             INT NOT NULL DEFAULT 1,  -- Phase B 대비 미리 추가
  household_type      ENUM('SINGLE', 'COUPLE', 'SINGLE_PARENT', 'PRE_NEWLYWED'),
  created_at, updated_at
)

person (
  person_id            PK,
  household_id         FK,
  role                 ENUM('PRIMARY', 'SPOUSE'),
  birth_date,
  nationality          ENUM('KOR', 'FOREIGNER'),
  income_yearly        BIGINT,           -- 세전 연소득 (원), 암호화
  income_source_type   ENUM('LABOR','BUSINESS','MIXED','RETIRED'),
  years_of_employment  INT,
  military_service_months INT DEFAULT 0,
  assets_real_estate   BIGINT,           -- 공시가 (원), 암호화
  assets_vehicle       BIGINT,
  assets_financial     BIGINT,
  has_subscription_account BOOLEAN,
  subscription_account_type ENUM('GENERAL', 'YOUTH'),
  subscription_open_at DATE,
  subscription_payment_count INT,
  subscription_payment_total BIGINT,
  homeless_since       DATE,             -- 무주택 시작일
  residence_sido,
  residence_sigungu,
  residence_dong,
  residence_since      DATE,
  is_household_head    BOOLEAN,
  credit_score_kcb     INT,              -- 옵션
  credit_score_nice    INT,              -- 옵션
  has_existing_didimdol_loan BOOLEAN,
  has_existing_jeonse_loan BOOLEAN,
  existing_loan_balance BIGINT,
  is_subscription_winner_within_5y BOOLEAN,
  -- 등 50+ 컬럼
)

child (
  child_id             PK,
  household_id         FK,
  birth_date,
  disposition_date,    -- 사망/입양취소 시
  disposition_type     ENUM('DEATH','ADOPTION_REVOKED', NULL),
  is_adopted           BOOLEAN
)

household_event (
  event_id             PK,
  household_id         FK,
  event_type           ENUM(
    'MARRIAGE','MARRIAGE_END',
    'CHILD_BIRTH','CHILD_LOSS',
    'PREGNANCY_START','PREGNANCY_END',
    'RELOCATION',
    'INCOME_CHANGE','ASSET_CHANGE',
    'HOMELESS_START','HOMELESS_END',
    'HOUSE_DISPOSAL_START','HOUSE_DISPOSAL_END',
    'HOUSEHOLD_TYPE_CHANGE'
  ),
  event_date           DATE NOT NULL,
  meta                 JSONB
)
```

→ 라이프 변화는 **이벤트 시계열**로 기록. 매칭 시 "오늘 기준" facts를 events에서 derive.

### 6.2 정책·공고·매칭

```sql
policy (
  policy_id            PK (예: 'loan-didimdol-newlywed:2026.04'),
  category             ENUM(
    '매매-청약','매매-대출',
    '전세-대출',
    '임대-공공','임대-매입','임대-전세',
    '정책현황'
  ),
  name                 VARCHAR(200),
  issuing_org,
  status               ENUM('ACTIVE','DEPRECATED','SUPERSEDED'),
  effective_from       DATE,
  effective_to         DATE NULL,
  supersedes           FK NULL,           -- 이전 버전 룰
  source_url,
  description_md       TEXT,
  rule_json            JSONB NOT NULL,    -- §7 룰 형식
  verifier_status      ENUM('VERIFIED','WEAK_VERIFIED','AMBIGUOUS','CONTRADICTED'),
  last_verified_at     TIMESTAMP,
  created_at, updated_at
)

announcement (
  announcement_id      PK,
  policy_id            FK,
  source               ENUM('API','CRAWL'),
  source_external_id,                    -- 외부 사이트의 ID
  title,
  publish_date,
  apply_start          DATE,
  apply_end            DATE,
  target_region        JSONB,            -- {sido, sigungu, dong[]}
  units_total          INT,
  rule_overrides       JSONB,            -- 공고별 추가/완화 조건
  pdf_url,
  pdf_text_md          TEXT,             -- 파싱된 본문 마크다운
  body_hash            VARCHAR(64),      -- SHA-256, 변경 감지용
  first_seen_at,
  last_changed_at,
  status               ENUM('OPEN','CLOSED','DRAFT','CANCELED')
)

match (
  match_id             PK,
  household_id         FK,
  announcement_id      FK,
  match_status         ENUM('ELIGIBLE','LIKELY_ELIGIBLE','NEEDS_REVIEW','INELIGIBLE'),
  confidence           INT,              -- 0-100
  criterion_results    JSONB,            -- 조건별 통과/실패
  applied_rule_version VARCHAR(50),      -- 어떤 룰 버전으로 매칭됐는지
  applied_at           TIMESTAMP,
  valid_until          TIMESTAMP NULL,
  calendar_event_id    VARCHAR(255),
  notification_sent_at TIMESTAMP,
  is_dismissed         BOOLEAN DEFAULT false,
  is_favorite          BOOLEAN DEFAULT false
)

rule_change_proposal (
  proposal_id          PK,
  target_policy_id     FK NULL,          -- NULL = NEW_POLICY
  change_type          ENUM(
    'MINOR_THRESHOLD','NEW_RULE','DEPRECATE',
    'EFFECTIVE_DATE_SHIFT','PHASE_IN_OUT'
  ),
  proposed_rule_json   JSONB,
  source_news_url,
  source_pdf_url,
  extracted_fields_evidence JSONB,       -- {field, snippet, offset}[]
  extractor_confidence FLOAT,
  verifier_findings    JSONB,            -- {web_results[], contradictions[], score}
  status               ENUM('PENDING','AUTO_APPLIED','NEEDS_REVIEW','REJECTED'),
  reviewed_at, applied_at
)

policy_status (                          -- L3-B: 토허재/LTV/DSR
  status_id            PK,
  status_type          ENUM('토허재','LTV규제','DSR규제','세제','규제지역'),
  region               JSONB,
  effective_period     JSONB,
  value_summary        VARCHAR(200),
  summary_md           TEXT,
  source_urls          JSONB,
  verifier_status      ENUM('VERIFIED','WEAK_VERIFIED','AMBIGUOUS'),
  extracted_at         TIMESTAMP
)

lookup_table (                           -- 도시근로자 소득표·디딤돌 금리표·LTV/DSR 표
  table_id             PK,               -- 'urban_worker_income_yearly_2026'
  version,
  effective_from       DATE,
  data                 JSONB,            -- {key: value, ...}
  source_url,
  verifier_status,
  updated_at
)
```

### 6.3 스코어 + 공급 구조

```sql
announcement_score (
  score_id             PK,
  announcement_id      FK,
  score_type           ENUM('COMPETITION','PRICE_VALUE','LIQUIDITY','COMPOSITE'),
  normalized_score     INT 0-100,
  details              JSONB,            -- 산정 근거
  source_urls          JSONB,
  computed_at,
  expires_at
)

announcement_supply_breakdown (
  breakdown_id         PK,
  announcement_id      FK,
  total_units          INT,
  general_supply       JSONB,            -- {total, score_units, lottery_units}
  special_supply       JSONB,            -- {category: units, ...}
  unranked_units       INT,              -- 무순위
  area_distribution    JSONB,            -- {평형: 호수}
  source_urls          JSONB,
  parsed_at
)
```

### 6.4 운영·헬스체크·사용자 학습

```sql
crawler_health (
  source_id            PK,                -- 'applyhome', 'sh', 'lh', ...
  selector_path,
  last_success_at,
  last_failure_at,
  consecutive_failures INT,
  status               ENUM('HEALTHY','DEGRADED','BROKEN')
)

match_dismissed (                         -- "관심 없음" 학습
  dismissal_id         PK,
  household_id         FK,
  policy_id            FK,
  dismissed_at,
  expires_at                              -- 30일 후 자동 해제
)

match_report (                            -- 사용자 신고
  report_id            PK,
  match_id             FK,
  reason               TEXT,
  reported_at,
  status               ENUM('PENDING','REVIEWED','APPLIED')
)

notification_log (                        -- 알림 이력
  log_id               PK,
  household_id         FK,
  channel              ENUM('PUSH','CALENDAR','TELEGRAM'),
  category,
  payload              JSONB,
  sent_at,
  delivered            BOOLEAN
)

user_settings (
  household_id         PK FK,
  quiet_hours_start    TIME DEFAULT '22:00',
  quiet_hours_end      TIME DEFAULT '07:00',
  digest_time          TIME DEFAULT '08:00',
  enabled_categories   JSONB,             -- {매매-청약: true, 전세-대출: false, ...}
  theme                ENUM('AUTO','LIGHT','DARK')
)
```

**모든 사용자 데이터 테이블에 `user_id` 또는 `household_id` 추가** — Phase B 멀티유저 마이그레이션 부담 0.

---

## §7. 룰 표현 형식

18F 정부 자격 매칭 5년 운영 결론 차용: 룰 엔진 X, **선언적 JSON + TS 평가기**.

### 7.1 룰 JSON V2.1 스키마

```json
{
  "policy_id": "loan-didimdol-newlywed:2026.04",
  "version": "2026.04",
  "name": "신혼부부 디딤돌 대출",
  "effective_from": "2026-04-01",
  "effective_to": null,
  "supersedes": "loan-didimdol-newlywed:2025.10",
  "transition_rules": {
    "applications_before": "2026-01-01",
    "applications_after": "2026-01-01"
  },

  "criteria": {
    "all": [
      { "field": "household.type", "op": "eq", "value": "COUPLE" },
      { "field": "household.years_since_marriage", "op": "lte", "value": 7 },
      {
        "field": "household.combined_income_yearly",
        "op": "lookup_lte",
        "table": "urban_worker_income_yearly_2026",
        "key": "household.member_count",
        "multiplier_formula": {
          "base": 1.0,
          "modifiers": [
            { "if": "household.is_dual_earner", "set_base": 2.0 },
            { "else": true, "set_base": 1.3 },
            { "per_unit": "household.children_count", "add": 0.10 }
          ]
        }
      },
      { "field": "household.combined_assets", "op": "lte", "value": 506000000 },
      { "field": "household.all_members_homeless", "op": "eq", "value": true },
      { "any": [
        { "field": "primary.has_subscription_account", "op": "eq", "value": true },
        { "field": "spouse.has_subscription_account", "op": "eq", "value": true }
      ]}
    ]
  },

  "disqualifiers": [
    { "field": "primary.is_subscription_winner_within_5y", "op": "eq", "value": true },
    { "field": "primary.has_existing_didimdol_loan", "op": "eq", "value": true }
  ],

  "outputs": {
    "loan_limit": {
      "type": "computed",
      "regional_thresholds": {
        "수도권": { "formula": "min(target_house_price * 0.7, 400000000)" },
        "지방":   { "formula": "min(target_house_price * 0.7, 300000000)" }
      }
    },
    "interest_rate": {
      "type": "lookup",
      "table": "didimdol_rate_2026.04",
      "key": ["household.combined_income_yearly", "household.has_newborn"]
    }
  },

  "score_formula": null,

  "applies_to_announcement": {
    "category": "매매-대출",
    "region": "*"
  }
}
```

### 7.2 지원 연산자

`eq | neq | lt | lte | gt | gte | in | not_in | between | contains | regex_match | lookup_eq | lookup_lte | regional_lte | regional_eq`

### 7.3 평가기 시그니처

```typescript
type CriterionResult = {
  passed: boolean;
  field: string;
  operator: string;
  expected: Fact;
  actual: Fact;
  reason?: string;
};

type EvaluationResult = {
  matched: boolean;
  confidence: number;          // 0-100
  criterion_results: CriterionResult[];
  disqualified: boolean;
  outputs: Record<string, Fact>;
  applied_rule_version: string;
};

function evaluate(
  rule: PolicyRule,
  facts: Facts,
  evalDate: Date = new Date()
): EvaluationResult;
```

룰은 git diff로 추적 가능 → audit·테스트·LLM 자동 생성 모두 가능.

---

## §8. Computed Fields (106개, 12 카테고리)

매칭 시 today 기준으로 동적 산출. DB에 저장 X.

### 카테고리 1. 세대 구성 (8)
`household.type, member_count, children_count, minor_children_count, is_multi_child, youngest_child_age_months, has_newborn, has_pregnancy`

### 카테고리 2. 소득 (10) — Lookup table 의존
`primary.income_yearly, spouse.income_yearly, household.combined_income_yearly, combined_income_monthly_avg, income_pct_of_urban_avg (lookup), income_decile, primary.income_source_type, primary.is_employed, primary.years_of_employment, household.has_dependent_elderly`

### 카테고리 3. 자산 (9)
`primary.assets_real_estate_official, primary.assets_vehicle, primary.assets_financial, spouse.assets_real_estate_official, spouse.assets_vehicle, spouse.assets_financial, household.combined_assets, household.combined_assets_minus_debt, household.has_subscription_account_balance_ge_24m`

### 카테고리 4. 무주택·주택 보유 이력 (12)
`primary.is_homeless, primary.homeless_since, primary.homeless_period_years, primary.homeless_score, spouse.is_homeless, spouse.homeless_period_years, household.all_members_homeless, primary.had_house_in_past_5y, primary.is_subscription_winner_5y, primary.has_owned_house_5y_old_30plus, primary.house_disposed_pending, household.disqualified_under_recent_winner_rule`

### 카테고리 5. 거주 (8)
`primary.residence_sido, primary.residence_sigungu, primary.residence_dong, primary.residence_since, primary.residence_years, primary.residence_in_metro, primary.residence_in_regulated_zone (lookup), primary.residence_in_toheoja (lookup)`

### 카테고리 6. 혼인·자녀 (10)
`primary.marriage_date, household.years_since_marriage, household.is_pre_newlywed, household.is_newlywed, household.is_post_newlywed, household.children, household.has_child_in_school, household.is_single_parent, household.is_grandparent_household, household.is_multicultural`

### 카테고리 7. 청약통장 (10)
`primary.subscription_account_type, primary.subscription_open_at, primary.subscription_age_months, primary.subscription_age_score, primary.subscription_payment_count, primary.subscription_payment_total, primary.subscription_recognized_amount, primary.subscription_youth_type, spouse.subscription_account_type, household.has_any_subscription_account`

### 카테고리 8. 청약 가점 (5) — Computed
`primary.score_homeless (32만점), primary.score_dependents (35만점), primary.score_subscription (17만점), primary.score_total (84만점), primary.dependents_count`

### 카테고리 9. 특별공급 / 우선공급 자격 (15)
`life_first, newlywed_special, newlywed_hope_town, multi_child, elder_parent, institution_recommended, newborn, youth_happy_house, newlywed_happy_house, elderly_purchase, basic_living, lower_class, disabled, national_merit, north_korea_defector`

### 카테고리 10. 대출 한도·자격 (8) — Lookup table 의존
`loan.ltv_max_for_region (lookup), loan.dsr_max, loan.dsr_stress_rate, primary.existing_loan_balance, primary.existing_didimdol_loan, primary.existing_jeonse_loan, primary.credit_score_kcb, primary.credit_score_nice`

### 카테고리 11. 신분·자격·이력 (8)
`primary.nationality, primary.is_separated_household, primary.is_household_head, primary.is_subscription_winner_within_5y, primary.subscription_account_canceled_within_1y, primary.has_existing_lh_rental, primary.has_housing_subsidy, primary.is_youth`

### 카테고리 12. 시점별 정책 매핑 (3)
`policy_timeline.toheoja_zones_today, policy_timeline.regulated_zones_today, policy_timeline.ltv_dsr_rules_today`

→ **합계 약 106개**. 평가기는 `computeFacts(household, today)` 호출로 한 번에 모두 산출.

---

## §9. LLM Provider 추상화

### 9.1 분리된 모델 역할

| 역할 | 기본 모델 | 환경변수 |
|------|----------|---------|
| Extractor (정책 텍스트 → 룰 JSON) | Claude Sonnet 4.6 | `EXTRACTOR_MODEL` |
| Judge (Verifier 진위 판단) | Claude Opus 4.7 / GPT-5.5 | `JUDGE_MODEL` |
| Summary (공고 본문 사용자용 요약) | Claude Sonnet 4.6 | `SUMMARY_MODEL` |

### 9.2 GPT 사용 시

GPT는 항상 GPT-5.5 사용 (4.1 등 하위 모델 사용 X). 비용 예산 안에서 정확도 최우선.

### 9.3 인터페이스

```typescript
export interface LLMProvider {
  extract<T>(input: { prompt: string; schema: ZodSchema<T> }): Promise<T>;
  judge(input: { claim: string; evidence: SearchResult[] }): Promise<JudgeResult>;
  summarize(input: { text: string; max_chars: number }): Promise<string>;
}

export function createLLM(): LLMProvider {
  // env로 모델 선택
}
```

### 9.4 PII 마스킹 강제

LLM 호출 wrapper가 입력 텍스트에서 사용자 PII 패턴 검출 시 throw. 정책 텍스트만 LLM 입력.

---

## §10. 사용자 플로우

### 10.1 온보딩 (5~7단계 위저드, 4~6분)

1. 세대 유형 (1인 / 부부 / 한부모 / 예비 신혼)
2. 본인 정보 (생년월일, 주민등록 시군구·동, 거주 시작일, 직업·학력·근로기간)
3. 소득·자산 (세전 연소득, 부동산 공시가, 자동차, 금융, 기존 대출, 신용점수 옵션)
4. 청약·주택 이력 (통장 종류·가입일·총납입, 무주택 시작일, 5년 내 당첨/취소)
5. (부부) 배우자 동일 항목
6. 자녀·라이프 이벤트 (자녀 생년월일, 임신 중, 입양, 한부모 사유)
7. 권한 (웹푸시 + Google Calendar OAuth)

→ 첫 매칭 즉시 실행 → 결과 화면.

### 10.2 일일 홈 대시보드

```
🏛️ 오늘의 부동산 정책 현황 카드
   - 토허재 / LTV / DSR / 규제지역 요약
🆕 매칭 공고 목록 (마감 임박 정렬)
   - 자격 충족 / 자격 임박 / 미충족 분리
📊 내 자격 요약
   - 청약 가점 64/84
   - 도시근로자 평균 대비 110%
   - 무주택 기간, 통장 가입기간
📚 전체 혜택 가이드 (카탈로그)
   - 카테고리별 + 검색·필터
```

### 10.3 푸시 → 상세 → 캘린더

푸시 알림 (35~42자 이내) → 탭 → 공고 상세:
- 공고 요약 (LLM 3줄)
- 자격 조건별 통과/실패 (criterion breakdown — 숫자 표시)
- **공급 구조 분석** (특공/일반공급/추첨제 분배)
- **스코어** (경쟁률·안전마진·유동성 + 종합)
- 신청 방법 (외부 사이트 링크)
- PDF 원문 다운로드/뷰어
- 캘린더 등록 (자동) — apply_start ~ apply_end 멀티데이 이벤트 1개

### 10.4 라이프 이벤트 → 자동 재매칭 + What-if

이벤트 입력 → 백그라운드 재매칭 (5~10초) → 변화 요약:
- 🎉 새 자격 N건
- ⚠️ 자격 강화·완화 M건
- 🔮 1년 후 / 결혼 5년 후 시뮬 자격 (`evaluate(rule, computeFacts(household, future_date))`)
- ⏳ 만료 임박 자격 (혼인 7년 만료 D-365 등)

### 10.5 룰 변경 일일 다이제스트

매일 오전 8시 1회. `WEAK_VERIFIED / AMBIGUOUS / NEW_RULE / DEPRECATE`만 큐에 표시:
- 변경 내용 + Verifier 결과 + 출처
- diff 표시
- 적용 / 거부 / 나중에 버튼

`MINOR_THRESHOLD + VERIFIED`는 자동 적용 (큐에 표시 X).

---

## §11. 스코어링 + 공급 구조 분석

### 11.1 Phase A 수치 스코어 3개 + 종합

| 스코어 | 산정 |
|--------|------|
| **① 경쟁률** | 같은 단지·평형 과거 경쟁률 + 동급 단지 평균 → 0~100 (낮을수록 ↑) |
| **② 시세 대비 가격 (안전마진)** ⭐ | (주변 신축 실거래가 - 분양가) / 분양가 % → 0~100 |
| **③ 유동성** | 단지 규모(세대수) + 거래 회전 + 환금성 → 0~100 |
| **종합** | 가중평균 (30% / 50% / 20% — 안전마진 강조) |

**주변 신축 실거래가 매칭 알고리즘:**
- 동일 시군구 + 도보 1km 이내 + 입주 5년 이내 신축
- 평균 또는 중간값 평당가
- 매칭 단지 < 3개면 "데이터 부족" 표시

### 11.2 공급 구조 분석 패널 (수치 X, 정보)

```
🎯 공급 구조 분석 — 당신이 진입 가능한 Lane

총 500세대 분양
├─ 특별공급 350 (70%)
│  ├─ 생애최초    100 (20%) ✅ 자격
│  ├─ 신혼부부    150 (30%) ✅ 자격 (우선)
│  ├─ 다자녀       50 (10%) ✗
│  ├─ 기관추천     30 (6%)  ✗
│  ├─ 노부모       20 (4%)  ✗
│  └─ 신생아 우선  ─        ⚠ 24개월 후 자격
├─ 일반공급  150 (30%)
│  ├─ 가점제 75% (113호)
│  └─ 추첨제 25% (37호)    ✓ 진입 가능
└─ 무순위 잔여 시 별도

🛣️ 추천 진입 경로
  1순위: 신혼특공 (150호)
  2순위: 생애최초 (100호)
  3순위: 일반공급 추첨제 (37호)

📐 면적별 분배
  39㎡ 80호 / 49㎡ 220호 / 59㎡ 200호
  → 본인 거주 인원 권장: 49㎡ 또는 59㎡
```

→ **숫자 점수보다 "어디로 들어가야 하나"를 직접 보여주는 게 진짜 가치**.

### 11.3 Phase B/C 추가 스코어 (후순위)

`TRANSIT (교통), SCHOOL (학군), CATALYST (호재), SUPPLY_CONTEXT (공급량 컨텍스트), GRADE_ABC (단지 등급 A/B/C), LIQUIDITY 확장` — `score_type` ENUM 확장만으로 추가.

---

## §12. 알림·UX 정책

| 항목 | 정책 |
|------|------|
| 무소음 시간대 | 기본 22:00~07:00, 사용자 조정 가능 |
| 카테고리별 알림 ON/OFF | 매매-청약 / 매매-대출 / 전세-대출 / 임대-공공 / 임대-매입 / 정책 변경 |
| 다이제스트 시간 | 기본 08:00 |
| 다크 모드 | 자동 / 켜기 / 끄기 |
| 알림 텍스트 한도 | 35~42자 (모바일 미리보기 기준) |
| 캘린더 이벤트 | 1 공고 = 1 이벤트 (apply_start ~ apply_end 멀티데이) |
| 마감 임박 알림 | 웹푸시만 (캘린더 X), D-7 / D-3 / D-1 |
| 면책 문구 | "최종 자격은 해당 기관에 직접 확인하세요" — 매칭 결과·푸시·PDF 뷰어 모두에 명시 |

---

## §13. 위험 완화 + 헬스체크

### 13.1 12개 잠재 실패 모드

| # | 실패 모드 | 대응 |
|---|----------|------|
| 1 | 사이트 구조 변경 → 셀렉터 깨짐 | `crawler_health` + 24h 무결과 알림 |
| 2 | 마이홈 API 응답 지연/장애 | API 우선 + 크롤링 폴백 + 재시도 큐 |
| 3 | 공공 API 트래픽 1,000건/일 초과 | 운영계정 신청 + 캐싱 + diff 전송 |
| 4 | HWP 공고문 | Phase A: LLM Vision 우회 / Phase B: kordoc 워커 |
| 5 | 스캔 PDF (OCR 필요) | LLM Vision 또는 별도 OCR |
| 6 | 국내 IP 제약 | GCP Seoul 리전 / Phase A.1은 본인 PC |
| 7 | LLM 정책 추출 환각 | Verifier (independent 출처 ≥ 2) + 신뢰도 + 원본 PDF 링크 |
| 8 | 시간 의존 필드 동기화 누락 | events에서 매칭 시 today 기준 재계산 |
| 9 | 로그인 필요 정보 | Phase A 본인 계정 자동 로그인 / Phase B 공식 API 우선 |
| 10 | 알림 피로도 | 다이제스트 + 카테고리 ON/OFF + 무소음 시간 |
| 11 | 개인정보 보안 | application-level AES-256-GCM 컬럼 암호화 |
| 12 | Google Calendar API quota | 일괄 생성 + 중복 감지 |

### 13.2 헬스체크 cron (매일 09:00)

```typescript
async function healthCheck() {
  const checks = {
    sweep_recent_24h: await countAnnouncementsSeenLast24h(),
    crawler_errors_24h: await countCrawlerErrorsLast24h(),
    api_errors_24h: await countAPIErrorsLast24h(),
    rule_proposals_pending_72h: await countOldProposals(),
    llm_cost_daily: await sumLLMCostToday(),
    db_size_pct: await getDBSizePct(),
  };
  await sendTelegramAlertIfBad(checks);
}
```

→ **Telegram Bot**으로 본인에게 매일 ✅/⚠️ 요약. 침묵하면 정상.

### 13.3 사이트 구조 변경 감지

각 크롤러 셀렉터별 마지막 success/fail 기록. 3회 연속 실패 또는 24h 무결과 → BROKEN + 헬스체크 알림.

### 13.4 데이터 정합성

- 동일 공고 중복: `(issuing_org, source_external_id)` 정규화 키 + fuzzy match
- 공고 수정: `body_hash` 변경 감지 → 재매칭 + 변경 알림
- API vs 크롤링 충돌: API 우선
- 룰 변경 후 기존 매칭: `applied_rule_version` 비교 → 백그라운드 재평가 → 결과 변경된 매칭만 알림
- 사용자 신고 (`match_report`): 본인 검토 후 룰 수정 후보로

---

## §14. 보안·개인정보

| 항목 | Phase | 구현 |
|------|-------|------|
| **D1. 민감 컬럼 암호화** | A | `income_*`, `assets_*`, `credit_score_*`, `subscription_payment_*` → AES-256-GCM application-level |
| **D2. TLS 강제** | A | Next.js HSTS + Cloud Run 자동 HTTPS / 로컬은 ngrok |
| **D3. 데이터 export** | A | "내 데이터 다운로드" → JSON 전체 |
| **D4. 데이터 삭제** | A | 이중 확인 → 하드 딜리트 + 30일 후 백업 제거 |
| **D5. LLM PII 마스킹** | A | wrapper 강제 — PII 패턴 검출 시 throw |
| **D6. KISA 표준 준수** | C | 개인정보 처리방침 정식 작성 |

---

## §15. 엣지 케이스 처리 (필요 컬럼만)

| 케이스 | 처리 |
|--------|------|
| 이혼·재혼 | `household_event` 시계열 — MARRIAGE/MARRIAGE_END 다중. is_active_marriage derive |
| 자녀 사망/입양취소 | `child.disposition_date`, `disposition_type` |
| 무주택 ↔ 유주택 반복 | events HOMELESS_START/END → 현재 상태 derive |
| 다주택 처분 진행 | events HOUSE_DISPOSAL_START/END + `is_disposal_in_progress` derive |
| 시도 이주 | events RELOCATION → 거주 시작일 reset |
| 외국인 배우자 | `person.nationality` = FOREIGNER → 일부 정책 결격 자동 |
| 사업자 vs 근로자 | `person.income_source_type` |
| 군 복무 | `person.military_service_months` (5년 근로 산정 합산) |

---

## §16. 비용 추정 (Phase A 월간)

| 항목 | 무료 티어 | 예상 |
|------|----------|------|
| Cloud Run (PWA + API) | 2M req/월 | $0 |
| Cloud Run Jobs (sweep) | 동일 | $0 |
| Cloud Scheduler | 3 job/월 | $0 |
| Cloud SQL Postgres (db-f1-micro) | 유료 | ~$10/월 |
| Cloud Storage (PDF) | 5GB | $0 |
| Cloud Logging/Monitoring | 50GB | $0 |
| Secret Manager | 6 secrets | $0 |
| Anthropic Claude (Extractor: Sonnet) | — | ~$15/월 |
| Verifier (Opus 또는 GPT-5.5) | — | ~$8~10/월 |
| Tavily Search | 1000 req/월 | $0 |
| Web Push VAPID | 자체 운영 | $0 |
| Google Calendar API | 무료 | $0 |
| Telegram Bot | 무료 | $0 |
| 도메인 (선택) | — | ~$1/월 |
| **합계 Phase A.2 배포 후** | — | **~$35~40/월** |
| **Phase A.1 (로컬)** | — | **~$25/월 (LLM API만)** |

---

## §17. 핸드오프 패키지

브레인스토밍 종료 후 다음 산출물을 묶어 WSL Ubuntu 새 프로젝트로 이전:

```
~/projects/housing-benefits-app/
├─ docs/
│  ├─ design.md              ← 이 문서 복사
│  ├─ architecture.md        ← 다이어그램 분리
│  ├─ data-model.md          ← §6 분리
│  ├─ rule-format.md         ← §7 분리
│  ├─ user-flows.md          ← §10 분리
│  └─ ops-runbook.md         ← §13 + 운영 가이드
├─ plans/
│  └─ phase-a-implementation.md  ← writing-plans skill 산출물
├─ env.example               ← 환경변수 템플릿
├─ docker-compose.yml        ← Postgres + 앱 + 워커
├─ package.json              ← Next.js 15 + Drizzle + Playwright + Anthropic SDK
├─ scripts/
│  ├─ bootstrap.sh           ← 초기 셋업
│  └─ healthcheck.sh
├─ src/
│  └─ (Phase A.1 1단계 task 결과)
└─ .gitignore
```

### 17.1 사전 발급 필요 키

1. **공공데이터포털 인증키** (data.go.kr 가입 → 마이홈/LH API 활용신청 — 1~2시간 승인)
2. **Anthropic API key**
3. **OpenAI API key** (선택, GPT-5.5 사용 시)
4. **Tavily API key**
5. **Google OAuth Client ID/Secret** (Calendar API)
6. **VAPID 키 쌍** (`web-push generate-vapid-keys`)
7. **Telegram Bot Token** (BotFather에서 생성)
8. (Phase A.2) GCP 프로젝트 + 서비스 계정 + Cloud SQL 인스턴스

### 17.2 Phase A.1 마일스톤 (로컬 검증 — 13단계)

1. 프로젝트 스캐폴드 (Next.js 15 + shadcn/ui + Drizzle)
2. DB 스키마 + 마이그레이션
3. 온보딩 위저드 (5~7단계)
4. 룰 평가기 + Computed Fields (106개)
5. 공공데이터 API 클라이언트 (마이홈, LH)
6. 청약홈/SH/GH Playwright 크롤러
7. 보도자료 RSS + Extractor + Verifier 흐름
8. 매칭 엔진 + 스코어링 (Phase A 3개)
9. 공급 구조 분석 (특공/일반/추첨)
10. 푸시 + Google Calendar 연동
11. 룰 변경 ACK 큐 + 다이제스트
12. 헬스체크 cron + Telegram Bot 알림 + 사이트 구조 변경 감지
13. 보안 (D1~D5 — 암호화·TLS·export·삭제·PII 마스킹) + 1~2주 본인 운영 검증

### 17.3 Phase A.2 마일스톤 (배포)

GCP 인프라 셋업 + Cloud SQL 마이그레이션 + Cloud Run 배포 + Cloud Scheduler + Secret Manager + GitHub Actions CI/CD + 도메인 연결 (선택)

---

## §18. Appendix — 외부 출처

### 18.1 정부·공공

- 마이홈포털 모집공고 OpenAPI: https://www.data.go.kr/data/15108420/openapi.do
- LH 단지정보 OpenAPI: https://www.data.go.kr/data/15058476/openapi.do
- 공동주택 정보 OpenAPI: https://www.data.go.kr/data/15058453/openapi.do
- 청약홈: https://www.applyhome.co.kr
- 마이홈포털: https://www.myhome.go.kr
- LH 청약플러스: https://apply.lh.or.kr
- SH 청약시스템: https://www.i-sh.co.kr
- GH 청약센터: https://apply.gh.or.kr
- 정책브리핑: https://www.korea.kr
- 금융위원회: https://fsc.go.kr
- 국토교통부: https://www.molit.go.kr
- 부동산계산기.com (DSR 보조): https://xn--989a00af8jnslv3dba.com/DSR

### 18.2 기술 참고

- shadcn/ui CLI v4 (March 2026): https://dev.to/codedthemes/shadcnui-march-2026-update
- Vercel Registry Starter: https://vercel.com/templates/next.js/shadcn-ui-registry-starter
- next-shadcn-dashboard-starter: https://adminlte.io/blog/shadcn-ui-templates/
- v0.app: https://v0.app/docs/design-systems
- Next.js 15 → Cloud Run 공식 가이드: https://docs.cloud.google.com/run/docs/quickstarts/frameworks/deploy-nextjs-service
- Cloud SQL Postgres + Next.js codelab: https://codelabs.developers.google.com/codelabs/deploy-application-with-database/cloud-sql-nodejs-connector-nextjs

### 18.3 도메인 참고

- 18F "Implementing rules without a rules engine" (룰 엔진 무용론): https://18f.gsa.gov/2018/10/09/implementing-rules-without-rules-engines/
- 18F "Centralized eligibility rules service": https://18f.gsa.gov/2018/10/16/exploring-a-new-way-to-make-eligibility-rules-easier-to-implement/
- 보도자료 PDF 자동 요약 사례: https://www.gpters.org/nocode/post/29-press-release-pdfs-yuaulmQEHTh2tDe
- kordoc (HWP/HWPX/PDF → Markdown): https://github.com/chrisryugj/kordoc
- YouthHousing 참고 아키텍처: https://github.com/yoonwooseong/YouthHousing
- LHhome 참고: https://github.com/shinsangeun/LHhome

### 18.4 시장 컨텍스트 (2026)

- 10·15 부동산 대책 토스피드: https://toss.im/tossfeed/article/tossmoment-14
- 10·15 부동산 대책 (정책브리핑): https://www.korea.kr/news/policyNewsView.do?newsId=148950959
- 청약 가점제 가이드: https://help.3o3.co.kr/hc/ko/articles/36653669296537
- 2026 LH 임대주택 공급 정리: https://dearmyhealths.com/notice/2026%EB%85%84-lh-%EC%9E%84%EB%8C%80%EC%A3%BC%ED%83%9D-%EA%B3%B5%EA%B8%89/
- 국토부 2026 업무계획: https://www.molit.go.kr/2026plan/sub3_realestate.html
- KB 2026 입주 캘린더: https://kbthink.com/realestate/issue/hosing-251229.html

---

## 변경 이력

| 일자 | 변경 |
|------|------|
| 2026-05-08 | 초안 작성 (브레인스토밍 합성) |
