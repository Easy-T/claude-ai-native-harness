# Housing Benefits PWA — Phase A.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a working local-PC PWA that matches Korean government housing benefits to the user's profile, sends notifications via Web Push + Google Calendar, and auto-updates policy rules via LLM extraction with verifier sub-agent — all running on WSL Ubuntu with Docker, before any cloud deployment.

**Architecture:** Next.js 15 App Router monolith (PWA + API routes) + Drizzle ORM + Postgres 16 (Docker) + Cloud Run-style worker containers driven by node-cron locally. Two-layer system: always-current policy catalog + active matching/notification engine. Declarative JSON rules + TypeScript evaluator (no rule engine). LLM Extractor → Verifier sub-agent (web search) → auto-applied or queued for ACK.

**Tech Stack:** Next.js 15, shadcn/ui, Tailwind CSS v4, Drizzle ORM, PostgreSQL 16, Anthropic SDK + OpenAI SDK, Playwright, pdfjs-dist, LibreOffice (Docker), node-cron, web-push (VAPID), googleapis (Calendar), Telegram Bot API, Tavily Search API, Vitest, Playwright tests, Zod, ngrok.

**Spec reference:** `~/.claude/docs/superpowers/specs/2026-05-08-housing-benefits-app-design.md` (v2)

**Working directory:** `~/projects/housing-benefits-app/` (WSL Ubuntu) — created in Task 1.

---

## Parallelism Map

Tasks are organized into **waves**. Tasks within the same wave have no shared state and can run as parallel subagents. Tasks across waves are sequential.

```
Wave 1 (Foundation, sequential):
  T1 Project Scaffold  →  T2 DB Schema & Migrations
                                    │
                                    ▼
Wave 2 (Parallel — 4 subagents OK):
  T3 Onboarding UI     T4 Rule Engine     T5 OpenAPI Client     T6 Playwright Crawler
       │                    │                  │                      │
       └────────┬───────────┴──────────────────┴──────────────────────┘
                ▼
Wave 3 (Parallel — 3 subagents OK):
  T7 PDF/LLM Pipeline  T8 Matching + Scoring  T9 Supply Analysis
       │                    │                      │
       └────────┬───────────┴──────────────────────┘
                ▼
Wave 4 (Parallel — 3 subagents OK):
  T10 Push + Calendar  T11 Rule Change Queue  T12 Health Check + Telegram
       │                    │                      │
       └────────┬───────────┴──────────────────────┘
                ▼
Wave 5 (Final, sequential):
  T13 Security (D1~D5) → 1~2 weeks operation verification
```

**Inter-wave dependencies (do NOT skip):**
- T3 needs T2 schema for forms.
- T4 needs T2 schema for facts shape.
- T5/T6 need T2 schema for `announcement` / `crawler_health`.
- T7 needs T5 (sweep delivers PDFs) and T6 (crawl delivers PDFs).
- T8 needs T4 evaluator and T5/T6 announcements + T2 schema.
- T9 needs T7 (LLM extracts supply structure from PDF body).
- T10 needs T8 (matches drive notifications).
- T11 needs T7 (LLM proposes rule changes).
- T12 needs T1~T11 (it monitors all of them).
- T13 wraps everything.

---

## File Structure

Locked-in module boundaries. Each file has one clear responsibility.

```
~/projects/housing-benefits-app/
├─ docker-compose.yml                       # Postgres + libreoffice + ngrok
├─ Dockerfile.libreoffice                   # HWP→PDF converter image
├─ package.json                             # pnpm workspace
├─ tsconfig.json
├─ drizzle.config.ts                        # Drizzle Kit migration config
├─ next.config.mjs
├─ tailwind.config.ts
├─ postcss.config.mjs
├─ vitest.config.ts
├─ .env.example                             # All required env vars (no secrets)
├─ .env.local                               # gitignored — actual local secrets
├─ .gitignore
├─ README.md
├─ scripts/
│  ├─ bootstrap.sh                          # One-shot setup: deps + db + migrate
│  ├─ generate-vapid.sh                     # web-push generate-vapid-keys → .env
│  ├─ run-cron.ts                           # node-cron entry, dispatches workers
│  └─ healthcheck.ts                        # T12 — runs the daily health check
├─ src/
│  ├─ app/                                  # Next.js App Router
│  │  ├─ layout.tsx                         # PWA shell, theme provider, manifest
│  │  ├─ page.tsx                           # Home dashboard (T3 redirect or T8 result)
│  │  ├─ manifest.ts                        # PWA manifest
│  │  ├─ sw.ts                              # Service worker (web push) — T10
│  │  ├─ onboarding/
│  │  │  ├─ page.tsx                        # T3 — wizard shell
│  │  │  └─ steps/                          # T3 — 7 step components
│  │  │     ├─ HouseholdTypeStep.tsx
│  │  │     ├─ PrimaryInfoStep.tsx
│  │  │     ├─ IncomeAssetsStep.tsx
│  │  │     ├─ HousingHistoryStep.tsx
│  │  │     ├─ SpouseStep.tsx
│  │  │     ├─ ChildrenStep.tsx
│  │  │     └─ PermissionsStep.tsx
│  │  ├─ catalog/
│  │  │  └─ page.tsx                        # T8/T9 — full benefits guide
│  │  ├─ matches/
│  │  │  ├─ page.tsx                        # match list
│  │  │  └─ [id]/page.tsx                   # match detail (criterion breakdown + supply panel + scores)
│  │  ├─ rule-changes/
│  │  │  └─ page.tsx                        # T11 — ACK queue
│  │  ├─ settings/
│  │  │  └─ page.tsx                        # T10 quiet hours, categories, export, delete
│  │  └─ api/
│  │     ├─ matches/route.ts                # match list API
│  │     ├─ rule-changes/[id]/ack/route.ts  # T11 ACK endpoint
│  │     ├─ push/subscribe/route.ts         # T10 push subscribe
│  │     ├─ data/export/route.ts            # T13 D3 export
│  │     ├─ data/delete/route.ts            # T13 D4 delete
│  │     └─ healthcheck/route.ts            # T12 manual trigger
│  ├─ db/
│  │  ├─ schema.ts                          # T2 — Drizzle schema definitions (all tables)
│  │  ├─ client.ts                          # T2 — pooled connection
│  │  ├─ encryption.ts                      # T13 D1 — AES-256-GCM column helpers
│  │  └─ queries/                           # T2+ — typed query functions
│  │     ├─ household.ts
│  │     ├─ policy.ts
│  │     ├─ announcement.ts
│  │     ├─ match.ts
│  │     └─ ...
│  ├─ rules/
│  │  ├─ types.ts                           # T4 — PolicyRule, Facts, EvaluationResult types
│  │  ├─ evaluator.ts                       # T4 — evaluate(rule, facts) — operator dispatch
│  │  ├─ operators.ts                       # T4 — eq/lte/lookup_lte/regional_lte/etc.
│  │  ├─ multiplier-formula.ts              # T4 — set_base + per_unit_add evaluation
│  │  ├─ compute-facts.ts                   # T4 — computeFacts(household, today) → 107 facts
│  │  ├─ scores/                            # T4 — score sub-functions
│  │  │  ├─ subscription-score.ts           # 청약 가점 (84점)
│  │  │  └─ urban-income-pct.ts             # 도시근로자 평균 대비
│  │  └─ examples/                          # T4 — JSON rule examples for tests
│  │     ├─ newlywed-special.json
│  │     ├─ youth-happy-house.json
│  │     └─ kookmin-rental.json
│  ├─ data-sources/
│  │  ├─ openapi/                           # T5 — public API clients
│  │  │  ├─ client.ts                       # base wrapper (retry, rate limit, cache)
│  │  │  ├─ myhome.ts                       # 마이홈 모집공고
│  │  │  ├─ lh.ts                           # LH 단지정보
│  │  │  └─ molit-realprice.ts              # 국토부 실거래가
│  │  ├─ crawlers/                          # T6 — Playwright crawlers
│  │  │  ├─ base.ts                         # crawler_health tracking, selector wrapping
│  │  │  ├─ applyhome.ts                    # 청약홈
│  │  │  ├─ sh.ts                           # SH 미리내집
│  │  │  └─ gh.ts                           # GH
│  │  └─ rss/                               # T7 — press release RSS
│  │     ├─ molit.ts
│  │     ├─ fsc.ts
│  │     └─ korea-kr.ts
│  ├─ pdf/
│  │  ├─ download.ts                        # T7 — fetch + cache PDF
│  │  ├─ parse.ts                           # T7 — pdfjs-dist text extraction
│  │  └─ hwp-to-pdf.ts                      # T7 — LibreOffice container call
│  ├─ llm/
│  │  ├─ provider.ts                        # T7 — LLMProvider interface
│  │  ├─ anthropic-impl.ts                  # T7 — Anthropic implementation
│  │  ├─ openai-impl.ts                     # T7 — OpenAI implementation
│  │  ├─ pii-mask.ts                        # T7+T13 D5 — PII pattern detection
│  │  ├─ extractor.ts                       # T7 — policy text → rule JSON
│  │  ├─ verifier.ts                        # T7 — sub-agent web search + judge
│  │  ├─ summarizer.ts                      # T7 — body → 3-line user summary
│  │  └─ cost-tracker.ts                    # T7+T12 — llm_cost_log entries
│  ├─ matching/
│  │  ├─ engine.ts                          # T8 — re-match all active announcements
│  │  ├─ recompute-on-event.ts              # T8 — life-event triggered re-match
│  │  ├─ what-if.ts                         # T8 — future date simulation
│  │  └─ scores/                            # T8 — Phase A 3 scores
│  │     ├─ competition.ts
│  │     ├─ price-value.ts
│  │     ├─ liquidity.ts
│  │     └─ composite.ts
│  ├─ supply-analysis/                      # T9 — supply structure parser
│  │  ├─ sale.ts                            # 매매-청약 lane parser (특공/일반/추첨)
│  │  ├─ rental.ts                          # 임대-공공 lane parser (청년/신혼/우선/일반)
│  │  └─ recommend-path.ts                  # T9 — 추천 진입 경로 알고리즘
│  ├─ notifications/
│  │  ├─ web-push.ts                        # T10 — VAPID send
│  │  ├─ calendar.ts                        # T10 — Google Calendar event create
│  │  ├─ dispatcher.ts                      # T10 — fan-out to push + calendar
│  │  ├─ digest.ts                          # T11 — daily digest builder
│  │  └─ telegram.ts                        # T12 — Telegram Bot send
│  ├─ rule-changes/
│  │  ├─ proposal-handler.ts                # T11 — extract → verify → auto-apply or queue
│  │  └─ ack-handler.ts                     # T11 — apply / reject / defer
│  ├─ workers/                              # T1 — locally invoked via node-cron
│  │  ├─ sweep.ts                           # T5+T6+T7 dispatch (every N hours)
│  │  ├─ matcher.ts                         # T8 dispatch (after sweep)
│  │  ├─ digest.ts                          # T11 dispatch (08:00)
│  │  └─ healthcheck.ts                     # T12 dispatch (09:00)
│  └─ lib/
│     ├─ env.ts                             # T1 — Zod-validated env loader
│     ├─ telemetry.ts                       # T12 — log to Postgres llm_cost_log + ops
│     ├─ time.ts                            # date/time helpers (KST handling)
│     └─ region.ts                          # 시도/시군구 lookup utilities
├─ tests/
│  ├─ unit/                                 # Vitest unit tests
│  │  ├─ rules/
│  │  ├─ matching/
│  │  ├─ supply-analysis/
│  │  ├─ pdf/
│  │  └─ ...
│  ├─ integration/                          # API + DB tests (testcontainers Postgres)
│  └─ fixtures/
│     ├─ pdfs/                              # sample announcement PDFs
│     ├─ rss/                               # sample press releases
│     └─ households/                        # sample household JSON
└─ migrations/                              # Drizzle Kit generated SQL
```

---

## Wave 1 — Foundation (sequential)

### Task T1: Project Scaffold + Dev Environment

**Goal:** Bootable Next.js 15 + Tailwind + shadcn + ESLint + Prettier project with Postgres+LibreOffice in Docker. After this task, `pnpm dev` runs and `curl localhost:3000` returns 200.

**Files:**
- Create: `package.json`, `tsconfig.json`, `next.config.mjs`, `tailwind.config.ts`, `postcss.config.mjs`, `.eslintrc.json`, `.prettierrc`, `vitest.config.ts`
- Create: `docker-compose.yml`, `Dockerfile.libreoffice`
- Create: `.env.example`, `.gitignore`, `README.md`
- Create: `src/app/layout.tsx`, `src/app/page.tsx`
- Create: `src/lib/env.ts`
- Create: `scripts/bootstrap.sh`
- Test: `tests/unit/lib/env.test.ts`

- [ ] **Step 1: Create the project root and git init**

```bash
mkdir -p ~/projects/housing-benefits-app
cd ~/projects/housing-benefits-app
git init -b main
```

- [ ] **Step 2: Bootstrap Next.js with TypeScript, App Router, Tailwind**

```bash
pnpm create next-app@latest . --typescript --tailwind --app --eslint \
  --src-dir --import-alias "@/*" --no-turbopack --no-experimental-app
```

When prompted "directory not empty", proceed.

- [ ] **Step 3: Pin dependencies — replace `package.json` with the curated set**

Replace `package.json` with:

```json
{
  "name": "housing-benefits-app",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "test": "vitest run",
    "test:watch": "vitest",
    "db:generate": "drizzle-kit generate",
    "db:migrate": "drizzle-kit migrate",
    "db:studio": "drizzle-kit studio",
    "cron": "tsx scripts/run-cron.ts",
    "healthcheck": "tsx scripts/healthcheck.ts"
  },
  "dependencies": {
    "next": "^15.1.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "drizzle-orm": "^0.36.0",
    "postgres": "^3.4.5",
    "zod": "^3.23.8",
    "@anthropic-ai/sdk": "^0.30.0",
    "openai": "^4.70.0",
    "playwright": "^1.49.0",
    "pdfjs-dist": "^4.8.69",
    "web-push": "^3.6.7",
    "googleapis": "^144.0.0",
    "node-cron": "^3.0.3",
    "node-telegram-bot-api": "^0.66.0",
    "p-retry": "^6.2.0",
    "p-limit": "^6.1.0",
    "lru-cache": "^11.0.0",
    "fast-xml-parser": "^4.5.0",
    "rss-parser": "^3.13.0"
  },
  "devDependencies": {
    "@types/node": "^22.0.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@types/web-push": "^3.6.4",
    "@types/node-cron": "^3.0.11",
    "@types/node-telegram-bot-api": "^0.64.7",
    "typescript": "^5.7.0",
    "tailwindcss": "^4.0.0",
    "@tailwindcss/postcss": "^4.0.0",
    "postcss": "^8.4.49",
    "drizzle-kit": "^0.28.0",
    "tsx": "^4.19.0",
    "eslint": "^9.16.0",
    "eslint-config-next": "^15.1.0",
    "prettier": "^3.4.0",
    "vitest": "^2.1.0",
    "@vitest/ui": "^2.1.0"
  },
  "packageManager": "pnpm@9.14.0"
}
```

Run `pnpm install`.

- [ ] **Step 4: Set up shadcn/ui**

```bash
pnpm dlx shadcn@latest init
```

Choices: TypeScript yes, default style "New York", base color "Slate", CSS variables yes, alias `@/*`.

Then add the component primitives we'll need across the app:

```bash
pnpm dlx shadcn@latest add button card input label form select checkbox \
  dialog sheet tabs toast progress badge separator
```

- [ ] **Step 5: Write a failing test for the env loader**

Create `tests/unit/lib/env.test.ts`:

```typescript
import { describe, it, expect, beforeEach } from "vitest";
import { loadEnv } from "@/lib/env";

describe("loadEnv", () => {
  beforeEach(() => {
    process.env = {};
  });

  it("throws when DATABASE_URL is missing", () => {
    expect(() => loadEnv()).toThrow(/DATABASE_URL/);
  });

  it("returns parsed env when all required vars are present", () => {
    process.env.DATABASE_URL = "postgres://localhost/test";
    process.env.ANTHROPIC_API_KEY = "sk-ant-test";
    process.env.SESSION_SECRET = "x".repeat(32);
    process.env.ENCRYPTION_KEY = "y".repeat(32);
    process.env.VAPID_PUBLIC_KEY = "vp";
    process.env.VAPID_PRIVATE_KEY = "vk";
    process.env.VAPID_SUBJECT = "mailto:owner@example.com";

    const env = loadEnv();
    expect(env.DATABASE_URL).toBe("postgres://localhost/test");
    expect(env.EXTRACTOR_MODEL).toBe("claude-sonnet-4-6");
  });
});
```

Create `vitest.config.ts`:

```typescript
import { defineConfig } from "vitest/config";
import path from "node:path";

export default defineConfig({
  test: { environment: "node", globals: false },
  resolve: { alias: { "@": path.resolve(__dirname, "./src") } },
});
```

- [ ] **Step 6: Run the test and verify it fails**

```bash
pnpm test tests/unit/lib/env.test.ts
```

Expected: FAIL — module `@/lib/env` not found.

- [ ] **Step 7: Implement the env loader**

Create `src/lib/env.ts`:

```typescript
import { z } from "zod";

const schema = z.object({
  DATABASE_URL: z.string().min(1),
  SESSION_SECRET: z.string().min(32),
  ENCRYPTION_KEY: z.string().min(32),

  ANTHROPIC_API_KEY: z.string().min(1),
  OPENAI_API_KEY: z.string().optional(),
  TAVILY_API_KEY: z.string().optional(),

  EXTRACTOR_MODEL: z.string().default("claude-sonnet-4-6"),
  JUDGE_MODEL: z.string().default("claude-opus-4-7"),
  SUMMARY_MODEL: z.string().default("claude-sonnet-4-6"),

  VAPID_PUBLIC_KEY: z.string().min(1),
  VAPID_PRIVATE_KEY: z.string().min(1),
  VAPID_SUBJECT: z.string().min(1),

  GOOGLE_OAUTH_CLIENT_ID: z.string().optional(),
  GOOGLE_OAUTH_CLIENT_SECRET: z.string().optional(),

  TELEGRAM_BOT_TOKEN: z.string().optional(),
  TELEGRAM_CHAT_ID: z.string().optional(),

  PUBLIC_DATA_SERVICE_KEY: z.string().optional(),

  APP_BASE_URL: z.string().url().default("http://localhost:3000"),
  CRON_SCHEDULE_SWEEP: z.string().default("0 */6 * * *"),
  CRON_SCHEDULE_DIGEST: z.string().default("0 8 * * *"),
  CRON_SCHEDULE_HEALTH: z.string().default("0 9 * * *"),
});

export type Env = z.infer<typeof schema>;

let cached: Env | null = null;

export function loadEnv(): Env {
  if (cached) return cached;
  const parsed = schema.safeParse(process.env);
  if (!parsed.success) {
    const issues = parsed.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`).join("\n");
    throw new Error(`Invalid env:\n${issues}`);
  }
  cached = parsed.data;
  return cached;
}

export function resetEnvForTesting() { cached = null; }
```

- [ ] **Step 8: Run the test and verify it passes**

```bash
pnpm test tests/unit/lib/env.test.ts
```

Expected: PASS.

- [ ] **Step 9: Create `.env.example` with all required keys**

Create `.env.example`:

```
DATABASE_URL=postgres://app:app@localhost:5432/housing
SESSION_SECRET=                  # openssl rand -base64 32
ENCRYPTION_KEY=                  # openssl rand -hex 32 (64 hex chars = 32 bytes)

ANTHROPIC_API_KEY=
OPENAI_API_KEY=                  # optional, only if using GPT-5.5
TAVILY_API_KEY=                  # optional but needed for verifier

EXTRACTOR_MODEL=claude-sonnet-4-6
JUDGE_MODEL=claude-opus-4-7
SUMMARY_MODEL=claude-sonnet-4-6

VAPID_PUBLIC_KEY=                # scripts/generate-vapid.sh
VAPID_PRIVATE_KEY=
VAPID_SUBJECT=mailto:you@example.com

GOOGLE_OAUTH_CLIENT_ID=
GOOGLE_OAUTH_CLIENT_SECRET=

TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=

PUBLIC_DATA_SERVICE_KEY=         # data.go.kr decoding key

APP_BASE_URL=http://localhost:3000
CRON_SCHEDULE_SWEEP=0 */6 * * *
CRON_SCHEDULE_DIGEST=0 8 * * *
CRON_SCHEDULE_HEALTH=0 9 * * *
```

- [ ] **Step 10: Create `docker-compose.yml`**

```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app
      POSTGRES_DB: housing
    ports: ["5432:5432"]
    volumes:
      - housing-pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d housing"]
      interval: 5s
      timeout: 3s
      retries: 10

  libreoffice:
    build:
      context: .
      dockerfile: Dockerfile.libreoffice
    volumes:
      - ./tmp/hwp:/work
    # Used as one-shot via `docker compose run`, kept idle otherwise
    command: ["tail", "-f", "/dev/null"]

volumes:
  housing-pgdata:
```

- [ ] **Step 11: Create `Dockerfile.libreoffice`**

```dockerfile
FROM debian:stable-slim
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      libreoffice-writer libreoffice-core libreoffice-common \
      fonts-nanum fonts-nanum-coding fonts-nanum-extra ca-certificates && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /work
```

- [ ] **Step 12: Create `scripts/bootstrap.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

[ -f .env.local ] || cp .env.example .env.local
echo "→ Edit .env.local before continuing if you haven't already." >&2

pnpm install
docker compose up -d postgres
echo "→ Waiting for Postgres..."
until docker compose exec -T postgres pg_isready -U app -d housing >/dev/null 2>&1; do sleep 1; done

echo "→ Postgres ready. Run 'pnpm db:migrate' after T2 schema is in place."
```

```bash
chmod +x scripts/bootstrap.sh
```

- [ ] **Step 13: Create minimal `src/app/layout.tsx` and `src/app/page.tsx`**

Replace `src/app/layout.tsx`:

```tsx
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "주거혜택 알리미",
  description: "정부 주거 혜택 자동 매칭 + 알림",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
```

Replace `src/app/page.tsx`:

```tsx
export default function Home() {
  return (
    <main className="min-h-screen p-8">
      <h1 className="text-2xl font-semibold">주거혜택 알리미</h1>
      <p className="text-sm text-muted-foreground">Phase A.1 — local dev</p>
    </main>
  );
}
```

- [ ] **Step 14: Add `.gitignore`**

```
node_modules
.next
.env.local
.env*.local
tmp/
*.log
playwright-report/
test-results/
coverage/
```

- [ ] **Step 15: Boot the stack and verify**

```bash
cp .env.example .env.local
# Fill ENCRYPTION_KEY, SESSION_SECRET with: openssl rand -hex 32
docker compose up -d postgres
pnpm dev
```

In another terminal:

```bash
curl -sf http://localhost:3000 | grep "주거혜택 알리미"
```

Expected: matches.

- [ ] **Step 16: Commit**

```bash
git add .
git commit -m "feat(scaffold): bootstrap Next.js 15 + Drizzle stack with Docker (T1)"
```

---

### Task T2: DB Schema + Migrations

**Goal:** All tables from spec §6 created via Drizzle migrations. Connection pool ready. Seed loader for `lookup_table`.

**Files:**
- Create: `drizzle.config.ts`, `src/db/schema.ts`, `src/db/client.ts`
- Create: `src/db/queries/index.ts` (placeholder; table-specific files added per task that needs them)
- Create: `migrations/` (generated)
- Create: `src/db/seed-lookups.ts`
- Test: `tests/integration/db/schema.test.ts`

- [ ] **Step 1: Configure Drizzle Kit**

Create `drizzle.config.ts`:

```typescript
import { defineConfig } from "drizzle-kit";

export default defineConfig({
  schema: "./src/db/schema.ts",
  out: "./migrations",
  dialect: "postgresql",
  dbCredentials: { url: process.env.DATABASE_URL ?? "postgres://app:app@localhost:5432/housing" },
  strict: true,
});
```

- [ ] **Step 2: Write a failing test for schema imports**

Create `tests/integration/db/schema.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import * as schema from "@/db/schema";

describe("schema exports", () => {
  it("exports all required tables", () => {
    const expected = [
      "household", "person", "child", "householdEvent",
      "policy", "announcement", "match", "ruleChangeProposal",
      "policyStatus", "lookupTable",
      "announcementScore", "announcementSupplyBreakdown",
      "crawlerHealth", "matchDismissed", "matchReport",
      "notificationLog", "userSettings", "llmCostLog",
    ];
    for (const name of expected) {
      expect(schema, `missing table: ${name}`).toHaveProperty(name);
    }
  });
});
```

- [ ] **Step 3: Run the test and verify it fails**

```bash
pnpm test tests/integration/db/schema.test.ts
```

Expected: FAIL — module not found.

- [ ] **Step 4: Write `src/db/schema.ts` (full schema per spec §6)**

```typescript
import { pgEnum, pgTable, serial, integer, bigint, varchar, text, timestamp, date, time, boolean, jsonb, decimal } from "drizzle-orm/pg-core";

// Enums (spec §6)
export const householdTypeEnum = pgEnum("household_type", ["SINGLE", "COUPLE", "SINGLE_PARENT", "PRE_NEWLYWED"]);
export const personRoleEnum = pgEnum("person_role", ["PRIMARY", "SPOUSE"]);
export const nationalityEnum = pgEnum("nationality", ["KOR", "FOREIGNER"]);
export const incomeSourceEnum = pgEnum("income_source", ["LABOR", "BUSINESS", "MIXED", "RETIRED"]);
export const subscriptionTypeEnum = pgEnum("subscription_type", ["GENERAL", "YOUTH"]);
export const eventTypeEnum = pgEnum("event_type", [
  "MARRIAGE", "MARRIAGE_END", "CHILD_BIRTH", "CHILD_LOSS",
  "PREGNANCY_START", "PREGNANCY_END", "RELOCATION",
  "INCOME_CHANGE", "ASSET_CHANGE", "HOMELESS_START", "HOMELESS_END",
  "HOUSE_DISPOSAL_START", "HOUSE_DISPOSAL_END", "HOUSEHOLD_TYPE_CHANGE",
]);
export const dispositionTypeEnum = pgEnum("disposition_type", ["DEATH", "ADOPTION_REVOKED"]);
export const policyCategoryEnum = pgEnum("policy_category", [
  "매매-청약", "매매-대출", "전세-대출", "임대-공공", "임대-매입", "임대-전세", "정책현황",
]);
export const policyStatusEnum = pgEnum("policy_status", ["ACTIVE", "DEPRECATED", "SUPERSEDED"]);
export const verifierStatusEnum = pgEnum("verifier_status", ["VERIFIED", "WEAK_VERIFIED", "AMBIGUOUS", "CONTRADICTED"]);
export const announcementTypeEnum = pgEnum("announcement_type", ["SALE", "RENTAL"]);
export const announcementSourceEnum = pgEnum("announcement_source", ["API", "CRAWL"]);
export const announcementOpenStatusEnum = pgEnum("announcement_open_status", ["OPEN", "CLOSED", "DRAFT", "CANCELED"]);
export const matchStatusEnum = pgEnum("match_status", ["ELIGIBLE", "LIKELY_ELIGIBLE", "NEEDS_REVIEW", "INELIGIBLE"]);
export const changeTypeEnum = pgEnum("change_type", [
  "MINOR_THRESHOLD", "NEW_RULE", "DEPRECATE", "EFFECTIVE_DATE_SHIFT", "PHASE_IN_OUT",
]);
export const proposalStatusEnum = pgEnum("proposal_status", ["PENDING", "AUTO_APPLIED", "NEEDS_REVIEW", "REJECTED"]);
export const policyStatusTypeEnum = pgEnum("policy_status_type", ["토허재", "LTV규제", "DSR규제", "세제", "규제지역"]);
export const policyStatusVerifierEnum = pgEnum("policy_status_verifier", ["VERIFIED", "WEAK_VERIFIED", "AMBIGUOUS"]);
export const supplyTypeEnum = pgEnum("supply_type", ["SALE", "RENTAL"]);
export const scoreTypeEnum = pgEnum("score_type", ["COMPETITION", "PRICE_VALUE", "LIQUIDITY", "COMPOSITE"]);
export const crawlerHealthStatusEnum = pgEnum("crawler_health_status", ["HEALTHY", "DEGRADED", "BROKEN"]);
export const reportStatusEnum = pgEnum("report_status", ["PENDING", "REVIEWED", "APPLIED"]);
export const notifChannelEnum = pgEnum("notif_channel", ["PUSH", "CALENDAR", "TELEGRAM"]);
export const themeEnum = pgEnum("theme", ["AUTO", "LIGHT", "DARK"]);
export const llmTaskTypeEnum = pgEnum("llm_task_type", ["EXTRACT", "JUDGE", "SUMMARIZE"]);

// Tables
export const household = pgTable("household", {
  householdId: serial("household_id").primaryKey(),
  userId: integer("user_id").notNull().default(1),
  householdType: householdTypeEnum("household_type").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});

export const person = pgTable("person", {
  personId: serial("person_id").primaryKey(),
  householdId: integer("household_id").notNull().references(() => household.householdId, { onDelete: "cascade" }),
  role: personRoleEnum("role").notNull(),
  birthDate: date("birth_date"),
  nationality: nationalityEnum("nationality"),
  incomeYearly: bigint("income_yearly_enc", { mode: "bigint" }), // encrypted via app layer (T13 D1)
  incomeSourceType: incomeSourceEnum("income_source_type"),
  yearsOfEmployment: integer("years_of_employment"),
  militaryServiceMonths: integer("military_service_months").default(0),
  assetsRealEstate: bigint("assets_real_estate_enc", { mode: "bigint" }),
  assetsVehicle: bigint("assets_vehicle", { mode: "bigint" }),
  assetsFinancial: bigint("assets_financial_enc", { mode: "bigint" }),
  hasSubscriptionAccount: boolean("has_subscription_account"),
  subscriptionAccountType: subscriptionTypeEnum("subscription_account_type"),
  subscriptionOpenAt: date("subscription_open_at"),
  subscriptionPaymentCount: integer("subscription_payment_count"),
  subscriptionPaymentTotal: bigint("subscription_payment_total_enc", { mode: "bigint" }),
  subscriptionCanceledWithin1y: boolean("subscription_canceled_within_1y"),
  homelessSince: date("homeless_since"),
  residenceSido: varchar("residence_sido", { length: 50 }),
  residenceSigungu: varchar("residence_sigungu", { length: 50 }),
  residenceDong: varchar("residence_dong", { length: 50 }),
  residenceSince: date("residence_since"),
  isHouseholdHead: boolean("is_household_head"),
  isSeparatedHousehold: boolean("is_separated_household"),
  creditScoreKcb: integer("credit_score_kcb_enc"),
  creditScoreNice: integer("credit_score_nice_enc"),
  hasExistingDidimdolLoan: boolean("has_existing_didimdol_loan"),
  hasExistingJeonseLoan: boolean("has_existing_jeonse_loan"),
  hasExistingLhRental: boolean("has_existing_lh_rental"),
  hasHousingSubsidy: boolean("has_housing_subsidy"),
  existingLoanBalance: bigint("existing_loan_balance", { mode: "bigint" }),
  isSubscriptionWinnerWithin5y: boolean("is_subscription_winner_within_5y"),
});

export const child = pgTable("child", {
  childId: serial("child_id").primaryKey(),
  householdId: integer("household_id").notNull().references(() => household.householdId, { onDelete: "cascade" }),
  birthDate: date("birth_date").notNull(),
  isAdopted: boolean("is_adopted").default(false),
  dispositionDate: date("disposition_date"),
  dispositionType: dispositionTypeEnum("disposition_type"),
});

export const householdEvent = pgTable("household_event", {
  eventId: serial("event_id").primaryKey(),
  householdId: integer("household_id").notNull().references(() => household.householdId, { onDelete: "cascade" }),
  eventType: eventTypeEnum("event_type").notNull(),
  eventDate: date("event_date").notNull(),
  meta: jsonb("meta"),
});

export const policy = pgTable("policy", {
  policyId: varchar("policy_id", { length: 80 }).primaryKey(),
  category: policyCategoryEnum("category").notNull(),
  name: varchar("name", { length: 200 }).notNull(),
  issuingOrg: varchar("issuing_org", { length: 100 }),
  status: policyStatusEnum("status").notNull().default("ACTIVE"),
  effectiveFrom: date("effective_from"),
  effectiveTo: date("effective_to"),
  supersedes: varchar("supersedes", { length: 80 }),
  sourceUrl: text("source_url"),
  descriptionMd: text("description_md"),
  ruleJson: jsonb("rule_json").notNull(),
  verifierStatus: verifierStatusEnum("verifier_status"),
  lastVerifiedAt: timestamp("last_verified_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});

export const announcement = pgTable("announcement", {
  announcementId: serial("announcement_id").primaryKey(),
  policyId: varchar("policy_id", { length: 80 }).references(() => policy.policyId),
  announcementType: announcementTypeEnum("announcement_type").notNull(),
  source: announcementSourceEnum("source").notNull(),
  sourceExternalId: varchar("source_external_id", { length: 200 }),
  title: text("title").notNull(),
  publishDate: date("publish_date"),
  applyStart: date("apply_start"),
  applyEnd: date("apply_end"),
  targetRegion: jsonb("target_region"),
  unitsTotal: integer("units_total"),
  ruleOverrides: jsonb("rule_overrides"),
  pdfUrl: text("pdf_url"),
  pdfTextMd: text("pdf_text_md"),
  bodyHash: varchar("body_hash", { length: 64 }),
  firstSeenAt: timestamp("first_seen_at", { withTimezone: true }).defaultNow().notNull(),
  lastChangedAt: timestamp("last_changed_at", { withTimezone: true }).defaultNow().notNull(),
  status: announcementOpenStatusEnum("status").notNull().default("OPEN"),
});

export const match = pgTable("match", {
  matchId: serial("match_id").primaryKey(),
  householdId: integer("household_id").notNull().references(() => household.householdId, { onDelete: "cascade" }),
  announcementId: integer("announcement_id").notNull().references(() => announcement.announcementId, { onDelete: "cascade" }),
  matchStatus: matchStatusEnum("match_status").notNull(),
  confidence: integer("confidence"),
  criterionResults: jsonb("criterion_results"),
  appliedRuleVersion: varchar("applied_rule_version", { length: 50 }),
  appliedAt: timestamp("applied_at", { withTimezone: true }).defaultNow().notNull(),
  validUntil: timestamp("valid_until", { withTimezone: true }),
  calendarEventId: varchar("calendar_event_id", { length: 255 }),
  notificationSentAt: timestamp("notification_sent_at", { withTimezone: true }),
  isDismissed: boolean("is_dismissed").default(false),
  isFavorite: boolean("is_favorite").default(false),
});

export const ruleChangeProposal = pgTable("rule_change_proposal", {
  proposalId: serial("proposal_id").primaryKey(),
  targetPolicyId: varchar("target_policy_id", { length: 80 }).references(() => policy.policyId),
  changeType: changeTypeEnum("change_type").notNull(),
  proposedRuleJson: jsonb("proposed_rule_json").notNull(),
  sourceNewsUrl: text("source_news_url"),
  sourcePdfUrl: text("source_pdf_url"),
  extractedFieldsEvidence: jsonb("extracted_fields_evidence"),
  extractorConfidence: decimal("extractor_confidence", { precision: 4, scale: 3 }),
  verifierFindings: jsonb("verifier_findings"),
  status: proposalStatusEnum("status").notNull().default("PENDING"),
  reviewedAt: timestamp("reviewed_at", { withTimezone: true }),
  appliedAt: timestamp("applied_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

export const policyStatus = pgTable("policy_status", {
  statusId: serial("status_id").primaryKey(),
  statusType: policyStatusTypeEnum("status_type").notNull(),
  region: jsonb("region"),
  effectivePeriod: jsonb("effective_period"),
  valueSummary: varchar("value_summary", { length: 200 }),
  summaryMd: text("summary_md"),
  sourceUrls: jsonb("source_urls"),
  verifierStatus: policyStatusVerifierEnum("verifier_status"),
  extractedAt: timestamp("extracted_at", { withTimezone: true }).defaultNow().notNull(),
});

export const lookupTable = pgTable("lookup_table", {
  tableId: varchar("table_id", { length: 80 }).primaryKey(),
  version: varchar("version", { length: 50 }),
  effectiveFrom: date("effective_from"),
  data: jsonb("data").notNull(),
  sourceUrl: text("source_url"),
  verifierStatus: verifierStatusEnum("verifier_status"),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});

export const announcementScore = pgTable("announcement_score", {
  scoreId: serial("score_id").primaryKey(),
  announcementId: integer("announcement_id").notNull().references(() => announcement.announcementId, { onDelete: "cascade" }),
  scoreType: scoreTypeEnum("score_type").notNull(),
  normalizedScore: integer("normalized_score").notNull(),
  details: jsonb("details"),
  sourceUrls: jsonb("source_urls"),
  computedAt: timestamp("computed_at", { withTimezone: true }).defaultNow().notNull(),
  expiresAt: timestamp("expires_at", { withTimezone: true }),
});

export const announcementSupplyBreakdown = pgTable("announcement_supply_breakdown", {
  breakdownId: serial("breakdown_id").primaryKey(),
  announcementId: integer("announcement_id").notNull().references(() => announcement.announcementId, { onDelete: "cascade" }),
  supplyType: supplyTypeEnum("supply_type").notNull(),
  saleGeneralSupply: jsonb("sale_general_supply"),
  saleSpecialSupply: jsonb("sale_special_supply"),
  saleUnrankedUnits: integer("sale_unranked_units"),
  rentalPriorityLanes: jsonb("rental_priority_lanes"),
  areaDistribution: jsonb("area_distribution"),
  sourceUrls: jsonb("source_urls"),
  parsedAt: timestamp("parsed_at", { withTimezone: true }).defaultNow().notNull(),
});

export const crawlerHealth = pgTable("crawler_health", {
  sourceId: varchar("source_id", { length: 50 }).primaryKey(),
  selectorPath: text("selector_path"),
  lastSuccessAt: timestamp("last_success_at", { withTimezone: true }),
  lastFailureAt: timestamp("last_failure_at", { withTimezone: true }),
  consecutiveFailures: integer("consecutive_failures").default(0),
  status: crawlerHealthStatusEnum("status").default("HEALTHY"),
});

export const matchDismissed = pgTable("match_dismissed", {
  dismissalId: serial("dismissal_id").primaryKey(),
  householdId: integer("household_id").notNull().references(() => household.householdId, { onDelete: "cascade" }),
  policyId: varchar("policy_id", { length: 80 }).notNull().references(() => policy.policyId),
  dismissedAt: timestamp("dismissed_at", { withTimezone: true }).defaultNow().notNull(),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
});

export const matchReport = pgTable("match_report", {
  reportId: serial("report_id").primaryKey(),
  matchId: integer("match_id").notNull().references(() => match.matchId, { onDelete: "cascade" }),
  reason: text("reason"),
  reportedAt: timestamp("reported_at", { withTimezone: true }).defaultNow().notNull(),
  status: reportStatusEnum("status").default("PENDING"),
});

export const notificationLog = pgTable("notification_log", {
  logId: serial("log_id").primaryKey(),
  householdId: integer("household_id").notNull().references(() => household.householdId, { onDelete: "cascade" }),
  channel: notifChannelEnum("channel").notNull(),
  category: varchar("category", { length: 50 }),
  payload: jsonb("payload"),
  sentAt: timestamp("sent_at", { withTimezone: true }).defaultNow().notNull(),
  delivered: boolean("delivered").default(false),
});

export const userSettings = pgTable("user_settings", {
  householdId: integer("household_id").primaryKey().references(() => household.householdId, { onDelete: "cascade" }),
  quietHoursStart: time("quiet_hours_start").default("22:00:00"),
  quietHoursEnd: time("quiet_hours_end").default("07:00:00"),
  digestTime: time("digest_time").default("08:00:00"),
  enabledCategories: jsonb("enabled_categories"),
  theme: themeEnum("theme").default("AUTO"),
});

export const llmCostLog = pgTable("llm_cost_log", {
  logId: serial("log_id").primaryKey(),
  date: date("date").notNull(),
  model: varchar("model", { length: 50 }).notNull(),
  taskType: llmTaskTypeEnum("task_type").notNull(),
  inputTokens: integer("input_tokens").notNull(),
  outputTokens: integer("output_tokens").notNull(),
  costUsd: decimal("cost_usd", { precision: 10, scale: 4 }).notNull(),
});
```

- [ ] **Step 5: Write the DB client**

Create `src/db/client.ts`:

```typescript
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { loadEnv } from "@/lib/env";
import * as schema from "./schema";

const env = loadEnv();
const queryClient = postgres(env.DATABASE_URL, { max: 10 });
export const db = drizzle(queryClient, { schema });
export { schema };
```

- [ ] **Step 6: Run schema test, verify it passes**

```bash
pnpm test tests/integration/db/schema.test.ts
```

Expected: PASS.

- [ ] **Step 7: Generate and apply migrations**

```bash
docker compose up -d postgres
pnpm db:generate         # creates migrations/0000_*.sql
pnpm db:migrate
```

Verify with `psql`:

```bash
docker compose exec -T postgres psql -U app -d housing -c "\dt"
```

Expected: lists all 18 tables.

- [ ] **Step 8: Add a smoke integration test that opens the connection**

Create `tests/integration/db/connection.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import { db } from "@/db/client";
import { sql } from "drizzle-orm";

describe("db connection", () => {
  it("runs a trivial query", async () => {
    const result = await db.execute(sql`SELECT 1 as n`);
    expect(result[0].n).toBe(1);
  });
});
```

Run:

```bash
pnpm test tests/integration/db/connection.test.ts
```

Expected: PASS.

- [ ] **Step 9: Create lookup-table seed loader**

Create `src/db/seed-lookups.ts`:

```typescript
import { db } from "./client";
import { lookupTable } from "./schema";
import { sql } from "drizzle-orm";

const URBAN_INCOME_2026 = {
  "1": 39_000_000,
  "2": 65_000_000,
  "3": 87_000_000,
  "4": 105_000_000,
  "5": 121_000_000,
  "6": 134_000_000,
};

export async function seedLookups() {
  await db.insert(lookupTable).values({
    tableId: "urban_worker_income_yearly_2026",
    version: "2026.05",
    effectiveFrom: "2026-01-01",
    data: URBAN_INCOME_2026,
    sourceUrl: "https://www.korea.kr/news/policyNewsView.do",
    verifierStatus: "VERIFIED",
  }).onConflictDoUpdate({
    target: lookupTable.tableId,
    set: { data: URBAN_INCOME_2026, version: "2026.05", updatedAt: sql`NOW()` },
  });
  console.log("→ Seeded urban_worker_income_yearly_2026");
}

if (require.main === module) {
  seedLookups().then(() => process.exit(0));
}
```

Add to `package.json` scripts: `"db:seed": "tsx src/db/seed-lookups.ts"`. Run:

```bash
pnpm db:seed
```

Expected: prints "Seeded".

- [ ] **Step 10: Commit**

```bash
git add .
git commit -m "feat(db): add full schema, migrations, client, and lookup seed (T2)"
```

---

## Wave 2 — Parallel: 4 independent subagents

After Wave 1 commit, dispatch T3, T4, T5, T6 as parallel subagents. They share **only** the locked schema from T2 and never modify each other's files.

---

### Task T3: Onboarding Wizard (5~7 dynamic steps)

**Goal:** A working `/onboarding` flow that collects all profile fields per spec §10.1, validates with Zod, and inserts a complete `household` + `person`(s) + `child`(ren) row set.

**Files:**
- Create: `src/app/onboarding/page.tsx`, `src/app/onboarding/steps/{HouseholdTypeStep,PrimaryInfoStep,IncomeAssetsStep,HousingHistoryStep,SpouseStep,ChildrenStep,PermissionsStep}.tsx`
- Create: `src/app/onboarding/schema.ts` (Zod for full wizard form)
- Create: `src/app/onboarding/actions.ts` (Server Action — submit)
- Create: `src/db/queries/household.ts`
- Test: `tests/unit/onboarding/schema.test.ts`, `tests/integration/onboarding/submit.test.ts`

- [ ] **Step 1: Write a failing test for the wizard schema**

Create `tests/unit/onboarding/schema.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import { onboardingSchema } from "@/app/onboarding/schema";

describe("onboardingSchema", () => {
  const baseSingle = {
    householdType: "SINGLE",
    primary: {
      birthDate: "1995-03-15",
      nationality: "KOR",
      residenceSido: "서울특별시",
      residenceSigungu: "강남구",
      residenceDong: "역삼동",
      residenceSince: "2024-01-01",
      incomeYearly: 50_000_000,
      incomeSourceType: "LABOR",
      yearsOfEmployment: 5,
      assetsRealEstate: 0,
      assetsVehicle: 0,
      assetsFinancial: 30_000_000,
      hasSubscriptionAccount: true,
      subscriptionAccountType: "GENERAL",
      subscriptionOpenAt: "2018-01-01",
      subscriptionPaymentCount: 80,
      subscriptionPaymentTotal: 4_000_000,
      homelessSince: "2015-03-15",
      isHouseholdHead: true,
      isSubscriptionWinnerWithin5y: false,
    },
    children: [],
    permissions: { push: true, calendar: false },
  };

  it("accepts a minimal SINGLE household", () => {
    const result = onboardingSchema.safeParse(baseSingle);
    expect(result.success).toBe(true);
  });

  it("requires spouse for COUPLE", () => {
    const couple = { ...baseSingle, householdType: "COUPLE" };
    const result = onboardingSchema.safeParse(couple);
    expect(result.success).toBe(false);
  });

  it("requires children for SINGLE_PARENT", () => {
    const sp = { ...baseSingle, householdType: "SINGLE_PARENT", children: [] };
    const result = onboardingSchema.safeParse(sp);
    expect(result.success).toBe(false);
  });
});
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
pnpm test tests/unit/onboarding/schema.test.ts
```

Expected: FAIL — module not found.

- [ ] **Step 3: Write the wizard schema**

Create `src/app/onboarding/schema.ts`:

```typescript
import { z } from "zod";

const personSchema = z.object({
  birthDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  nationality: z.enum(["KOR", "FOREIGNER"]),
  residenceSido: z.string().min(1),
  residenceSigungu: z.string().min(1),
  residenceDong: z.string().min(1),
  residenceSince: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  incomeYearly: z.number().int().nonnegative(),
  incomeSourceType: z.enum(["LABOR", "BUSINESS", "MIXED", "RETIRED"]),
  yearsOfEmployment: z.number().int().nonnegative(),
  militaryServiceMonths: z.number().int().nonnegative().default(0),
  assetsRealEstate: z.number().int().nonnegative(),
  assetsVehicle: z.number().int().nonnegative().default(0),
  assetsFinancial: z.number().int().nonnegative(),
  existingLoanBalance: z.number().int().nonnegative().default(0),
  hasSubscriptionAccount: z.boolean(),
  subscriptionAccountType: z.enum(["GENERAL", "YOUTH"]).optional(),
  subscriptionOpenAt: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  subscriptionPaymentCount: z.number().int().nonnegative().optional(),
  subscriptionPaymentTotal: z.number().int().nonnegative().optional(),
  subscriptionCanceledWithin1y: z.boolean().default(false),
  homelessSince: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable(),
  isHouseholdHead: z.boolean(),
  isSeparatedHousehold: z.boolean().default(false),
  isSubscriptionWinnerWithin5y: z.boolean(),
  hasExistingDidimdolLoan: z.boolean().default(false),
  hasExistingJeonseLoan: z.boolean().default(false),
  hasExistingLhRental: z.boolean().default(false),
  hasHousingSubsidy: z.boolean().default(false),
  creditScoreKcb: z.number().int().min(0).max(1000).optional(),
  creditScoreNice: z.number().int().min(0).max(1000).optional(),
});

const childSchema = z.object({
  birthDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  isAdopted: z.boolean().default(false),
});

export const onboardingSchema = z
  .object({
    householdType: z.enum(["SINGLE", "COUPLE", "SINGLE_PARENT", "PRE_NEWLYWED"]),
    primary: personSchema,
    spouse: personSchema.optional(),
    marriageDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    pregnancyStartDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    children: z.array(childSchema).default([]),
    permissions: z.object({
      push: z.boolean(),
      calendar: z.boolean(),
    }),
  })
  .superRefine((data, ctx) => {
    if ((data.householdType === "COUPLE" || data.householdType === "PRE_NEWLYWED") && !data.spouse) {
      ctx.addIssue({ code: "custom", path: ["spouse"], message: "spouse required for COUPLE/PRE_NEWLYWED" });
    }
    if (data.householdType === "COUPLE" && !data.marriageDate) {
      ctx.addIssue({ code: "custom", path: ["marriageDate"], message: "marriageDate required for COUPLE" });
    }
    if (data.householdType === "SINGLE_PARENT" && data.children.length === 0) {
      ctx.addIssue({ code: "custom", path: ["children"], message: "children required for SINGLE_PARENT" });
    }
  });

export type OnboardingInput = z.infer<typeof onboardingSchema>;
```

- [ ] **Step 4: Run the schema test, verify it passes**

```bash
pnpm test tests/unit/onboarding/schema.test.ts
```

Expected: PASS (all 3 cases).

- [ ] **Step 5: Write a failing integration test for the submit Server Action**

Create `tests/integration/onboarding/submit.test.ts`:

```typescript
import { describe, it, expect, beforeEach } from "vitest";
import { submitOnboarding } from "@/app/onboarding/actions";
import { db } from "@/db/client";
import { household, person, child as childTbl, householdEvent } from "@/db/schema";
import { eq } from "drizzle-orm";

async function reset() {
  await db.delete(householdEvent);
  await db.delete(childTbl);
  await db.delete(person);
  await db.delete(household);
}

describe("submitOnboarding", () => {
  beforeEach(reset);

  it("inserts household + primary person + MARRIAGE event for COUPLE with child", async () => {
    const result = await submitOnboarding({
      householdType: "COUPLE",
      marriageDate: "2022-05-01",
      primary: {
        birthDate: "1990-01-01", nationality: "KOR",
        residenceSido: "서울특별시", residenceSigungu: "강남구", residenceDong: "역삼동",
        residenceSince: "2023-01-01", incomeYearly: 60_000_000,
        incomeSourceType: "LABOR", yearsOfEmployment: 8,
        militaryServiceMonths: 24,
        assetsRealEstate: 0, assetsVehicle: 0, assetsFinancial: 50_000_000,
        existingLoanBalance: 0,
        hasSubscriptionAccount: true, subscriptionAccountType: "GENERAL",
        subscriptionOpenAt: "2015-01-01", subscriptionPaymentCount: 100, subscriptionPaymentTotal: 5_000_000,
        subscriptionCanceledWithin1y: false,
        homelessSince: "2010-01-01", isHouseholdHead: true,
        isSeparatedHousehold: false, isSubscriptionWinnerWithin5y: false,
        hasExistingDidimdolLoan: false, hasExistingJeonseLoan: false,
        hasExistingLhRental: false, hasHousingSubsidy: false,
      },
      spouse: {
        birthDate: "1992-02-02", nationality: "KOR",
        residenceSido: "서울특별시", residenceSigungu: "강남구", residenceDong: "역삼동",
        residenceSince: "2023-01-01", incomeYearly: 50_000_000,
        incomeSourceType: "LABOR", yearsOfEmployment: 6, militaryServiceMonths: 0,
        assetsRealEstate: 0, assetsVehicle: 0, assetsFinancial: 20_000_000,
        existingLoanBalance: 0,
        hasSubscriptionAccount: false, subscriptionCanceledWithin1y: false,
        homelessSince: "2010-01-01", isHouseholdHead: false,
        isSeparatedHousehold: false, isSubscriptionWinnerWithin5y: false,
        hasExistingDidimdolLoan: false, hasExistingJeonseLoan: false,
        hasExistingLhRental: false, hasHousingSubsidy: false,
      },
      children: [{ birthDate: "2024-09-01", isAdopted: false }],
      permissions: { push: true, calendar: true },
    });

    expect(result.householdId).toBeGreaterThan(0);
    const persons = await db.select().from(person).where(eq(person.householdId, result.householdId));
    expect(persons).toHaveLength(2);
    const events = await db.select().from(householdEvent).where(eq(householdEvent.householdId, result.householdId));
    expect(events.find((e) => e.eventType === "MARRIAGE")).toBeTruthy();
    expect(events.find((e) => e.eventType === "CHILD_BIRTH")).toBeTruthy();
    expect(events.find((e) => e.eventType === "HOMELESS_START")).toBeTruthy();
  });
});
```

- [ ] **Step 6: Run integration test, verify it fails**

```bash
pnpm test tests/integration/onboarding/submit.test.ts
```

Expected: FAIL — `submitOnboarding` not defined.

- [ ] **Step 7: Implement `submitOnboarding` Server Action**

Create `src/app/onboarding/actions.ts`:

```typescript
"use server";

import { db } from "@/db/client";
import { household, person, child as childTbl, householdEvent, userSettings } from "@/db/schema";
import { onboardingSchema, type OnboardingInput } from "./schema";

export async function submitOnboarding(input: OnboardingInput) {
  const data = onboardingSchema.parse(input);
  const inserted = await db.insert(household).values({ householdType: data.householdType }).returning({ id: household.householdId });
  const householdId = inserted[0].id;

  const personRows = [{ ...data.primary, householdId, role: "PRIMARY" as const }];
  if (data.spouse) personRows.push({ ...data.spouse, householdId, role: "SPOUSE" as const });
  await db.insert(person).values(
    personRows.map((p) => ({
      householdId: p.householdId, role: p.role, birthDate: p.birthDate,
      nationality: p.nationality,
      incomeYearly: BigInt(p.incomeYearly), incomeSourceType: p.incomeSourceType,
      yearsOfEmployment: p.yearsOfEmployment, militaryServiceMonths: p.militaryServiceMonths ?? 0,
      assetsRealEstate: BigInt(p.assetsRealEstate),
      assetsVehicle: BigInt(p.assetsVehicle ?? 0),
      assetsFinancial: BigInt(p.assetsFinancial),
      hasSubscriptionAccount: p.hasSubscriptionAccount,
      subscriptionAccountType: p.subscriptionAccountType ?? null,
      subscriptionOpenAt: p.subscriptionOpenAt ?? null,
      subscriptionPaymentCount: p.subscriptionPaymentCount ?? null,
      subscriptionPaymentTotal: p.subscriptionPaymentTotal ? BigInt(p.subscriptionPaymentTotal) : null,
      subscriptionCanceledWithin1y: p.subscriptionCanceledWithin1y,
      homelessSince: p.homelessSince,
      residenceSido: p.residenceSido, residenceSigungu: p.residenceSigungu, residenceDong: p.residenceDong,
      residenceSince: p.residenceSince,
      isHouseholdHead: p.isHouseholdHead, isSeparatedHousehold: p.isSeparatedHousehold,
      creditScoreKcb: p.creditScoreKcb ?? null, creditScoreNice: p.creditScoreNice ?? null,
      hasExistingDidimdolLoan: p.hasExistingDidimdolLoan, hasExistingJeonseLoan: p.hasExistingJeonseLoan,
      hasExistingLhRental: p.hasExistingLhRental, hasHousingSubsidy: p.hasHousingSubsidy,
      existingLoanBalance: BigInt(p.existingLoanBalance),
      isSubscriptionWinnerWithin5y: p.isSubscriptionWinnerWithin5y,
    })),
  );

  if (data.children.length > 0) {
    await db.insert(childTbl).values(
      data.children.map((c) => ({ householdId, birthDate: c.birthDate, isAdopted: c.isAdopted })),
    );
  }

  const events: { eventType: typeof householdEvent.$inferInsert.eventType; eventDate: string; meta?: object }[] = [];
  if (data.marriageDate) events.push({ eventType: "MARRIAGE", eventDate: data.marriageDate });
  if (data.pregnancyStartDate) events.push({ eventType: "PREGNANCY_START", eventDate: data.pregnancyStartDate });
  for (const p of personRows) {
    if (p.homelessSince) events.push({ eventType: "HOMELESS_START", eventDate: p.homelessSince, meta: { role: p.role } });
  }
  for (const c of data.children) {
    events.push({ eventType: "CHILD_BIRTH", eventDate: c.birthDate, meta: { isAdopted: c.isAdopted } });
  }
  if (events.length > 0) {
    await db.insert(householdEvent).values(events.map((e) => ({ ...e, householdId })));
  }

  await db.insert(userSettings).values({
    householdId,
    enabledCategories: { "매매-청약": true, "매매-대출": true, "전세-대출": true, "임대-공공": true, "임대-매입": true, "정책현황": true },
  });

  return { householdId };
}
```

- [ ] **Step 8: Run the integration test, verify it passes**

```bash
pnpm test tests/integration/onboarding/submit.test.ts
```

Expected: PASS.

- [ ] **Step 9: Build the UI shell — `/onboarding` page with step navigation**

Create `src/app/onboarding/page.tsx`:

```tsx
"use client";

import { useState } from "react";
import { HouseholdTypeStep } from "./steps/HouseholdTypeStep";
import { PrimaryInfoStep } from "./steps/PrimaryInfoStep";
import { IncomeAssetsStep } from "./steps/IncomeAssetsStep";
import { HousingHistoryStep } from "./steps/HousingHistoryStep";
import { SpouseStep } from "./steps/SpouseStep";
import { ChildrenStep } from "./steps/ChildrenStep";
import { PermissionsStep } from "./steps/PermissionsStep";
import { submitOnboarding } from "./actions";
import { Progress } from "@/components/ui/progress";
import type { OnboardingInput } from "./schema";

const baseSteps = ["household-type", "primary", "income-assets", "housing-history", "permissions"] as const;

function planSteps(type: OnboardingInput["householdType"], hasChildren: boolean): string[] {
  const steps: string[] = ["household-type", "primary", "income-assets", "housing-history"];
  if (type === "COUPLE" || type === "PRE_NEWLYWED") steps.push("spouse");
  if (type === "SINGLE_PARENT" || hasChildren) steps.push("children");
  steps.push("permissions");
  return steps;
}

export default function OnboardingPage() {
  const [current, setCurrent] = useState(0);
  const [data, setData] = useState<Partial<OnboardingInput>>({ children: [], permissions: { push: false, calendar: false } });
  const [hasChildren, setHasChildren] = useState(false);
  const steps = planSteps(data.householdType ?? "SINGLE", hasChildren);
  const currentStep = steps[current];

  const next = (patch: Partial<OnboardingInput>) => {
    setData((d) => ({ ...d, ...patch }));
    setCurrent((c) => Math.min(c + 1, steps.length - 1));
  };
  const prev = () => setCurrent((c) => Math.max(0, c - 1));

  const onSubmit = async (final: Partial<OnboardingInput>) => {
    const merged = { ...data, ...final } as OnboardingInput;
    const { householdId } = await submitOnboarding(merged);
    window.location.href = `/?welcome=${householdId}`;
  };

  return (
    <main className="mx-auto max-w-xl p-6">
      <Progress value={((current + 1) / steps.length) * 100} className="mb-6" />
      {currentStep === "household-type" && (
        <HouseholdTypeStep onNext={(t) => { next({ householdType: t }); setHasChildren(t === "SINGLE_PARENT"); }} />
      )}
      {currentStep === "primary" && <PrimaryInfoStep onNext={(p) => next({ primary: p })} onBack={prev} />}
      {currentStep === "income-assets" && <IncomeAssetsStep value={data.primary} onNext={(p) => next({ primary: p })} onBack={prev} />}
      {currentStep === "housing-history" && <HousingHistoryStep value={data.primary} onNext={(p) => next({ primary: p })} onBack={prev} />}
      {currentStep === "spouse" && <SpouseStep onNext={(s, m) => next({ spouse: s, marriageDate: m })} onBack={prev} />}
      {currentStep === "children" && <ChildrenStep value={data.children ?? []} onNext={(c) => next({ children: c })} onBack={prev} />}
      {currentStep === "permissions" && <PermissionsStep onSubmit={(perm) => onSubmit({ permissions: perm })} onBack={prev} />}
    </main>
  );
}
```

- [ ] **Step 10: Implement step components**

Each of the 7 step files follows the same structure. Example — create `src/app/onboarding/steps/HouseholdTypeStep.tsx`:

```tsx
"use client";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

const types = [
  { value: "SINGLE", label: "1인 가구" },
  { value: "COUPLE", label: "부부 (혼인신고 완료)" },
  { value: "SINGLE_PARENT", label: "한부모 가구" },
  { value: "PRE_NEWLYWED", label: "예비 신혼부부 (혼인신고 전)" },
] as const;

type T = typeof types[number]["value"];

export function HouseholdTypeStep({ onNext }: { onNext: (t: T) => void }) {
  return (
    <Card>
      <CardHeader><CardTitle>세대 유형</CardTitle></CardHeader>
      <CardContent className="grid gap-3">
        {types.map((t) => (
          <Button key={t.value} variant="outline" onClick={() => onNext(t.value)}>{t.label}</Button>
        ))}
      </CardContent>
    </Card>
  );
}
```

Apply the same pattern (shadcn Card + Form + Input + DatePicker) for the remaining 6 step components. Each step:
1. Renders shadcn `Form` with the specific subset of `personSchema` fields it owns.
2. On submit, calls `onNext(values)`.
3. `onBack` triggers parent's `prev`.

Field-to-step mapping (mirror spec §10.1):

| Step | Fields |
|------|--------|
| PrimaryInfoStep | birthDate, nationality, residence{Sido,Sigungu,Dong,Since}, isHouseholdHead, isSeparatedHousehold, militaryServiceMonths, yearsOfEmployment, incomeSourceType |
| IncomeAssetsStep | incomeYearly, assets{RealEstate,Vehicle,Financial}, existingLoanBalance, has{ExistingDidimdolLoan,ExistingJeonseLoan,ExistingLhRental,HousingSubsidy}, creditScore{Kcb,Nice}? |
| HousingHistoryStep | hasSubscriptionAccount, subscription{AccountType,OpenAt,PaymentCount,PaymentTotal,CanceledWithin1y}, homelessSince, isSubscriptionWinnerWithin5y |
| SpouseStep | full personSchema for spouse + marriageDate (top-level field) |
| ChildrenStep | children: { birthDate, isAdopted }[] (add/remove rows) |
| PermissionsStep | requestNotificationPermission(), Google Calendar OAuth button (calls a route added in T10 — for now, just toggle a boolean) |

- [ ] **Step 11: Verify the wizard runs end-to-end**

```bash
pnpm dev
```

In a browser visit `http://localhost:3000/onboarding`. Walk through steps as a single household, submit, and check Postgres:

```bash
docker compose exec -T postgres psql -U app -d housing -c "SELECT household_id, household_type FROM household;"
docker compose exec -T postgres psql -U app -d housing -c "SELECT count(*) FROM person;"
```

Expected: rows present.

- [ ] **Step 12: Commit**

```bash
git add .
git commit -m "feat(onboarding): 7-step wizard with Zod validation and household event seeding (T3)"
```

---

### Task T4: Rule Engine + Computed Facts (107 fields)

**Goal:** A pure-function rule engine that evaluates declarative JSON rules against derived facts. No DB writes. Test-driven; coverage-first.

**Files:**
- Create: `src/rules/types.ts`, `src/rules/operators.ts`, `src/rules/multiplier-formula.ts`, `src/rules/evaluator.ts`
- Create: `src/rules/compute-facts.ts`, `src/rules/scores/subscription-score.ts`, `src/rules/scores/urban-income-pct.ts`
- Create: `src/rules/examples/{newlywed-special,youth-happy-house,kookmin-rental}.json`
- Test: `tests/unit/rules/*.test.ts`

- [ ] **Step 1: Write the types**

Create `src/rules/types.ts`:

```typescript
export type Fact = number | string | boolean | Date | null;
export type Facts = Record<string, Fact>;

export type Operator =
  | "eq" | "neq" | "lt" | "lte" | "gt" | "gte"
  | "in" | "not_in" | "between" | "contains" | "regex_match"
  | "lookup_eq" | "lookup_lte" | "regional_lte" | "regional_eq";

export interface Criterion {
  field: string;
  op: Operator;
  value?: Fact | Fact[];
  table?: string;
  key?: string;
  multiplier_formula?: MultiplierFormula;
}

export interface MultiplierFormula {
  evaluation_order: ["set_base_first", "then_per_unit_add"];
  set_base: Array<
    | { if: string; value: number }
    | { else_default: number }
  >;
  per_unit_add?: Array<{ field: string; add_per_unit: number }>;
}

export type CriteriaNode =
  | { all: CriteriaNode[] }
  | { any: CriteriaNode[] }
  | { not: CriteriaNode }
  | Criterion;

export interface PolicyRule {
  policy_id: string;
  version: string;
  name: string;
  category: string;
  effective_from: string;
  effective_to: string | null;
  supersedes?: string;
  transition_rules?: {
    cutoff_date: string;
    applications_before_cutoff: "use_predecessor_rule" | "use_this_rule";
    applications_on_or_after_cutoff: "use_predecessor_rule" | "use_this_rule";
  };
  criteria: CriteriaNode;
  disqualifiers?: Criterion[];
  outputs?: Record<string, unknown>;
  score_formula?: unknown;
  applies_to_announcement: { category: string; region: string };
}

export interface CriterionResult {
  passed: boolean;
  field: string;
  operator: string;
  expected: Fact | Fact[];
  actual: Fact;
  computed_threshold?: Fact;
  reason?: string;
}

export interface EvaluationResult {
  matched: boolean;
  confidence: number; // 0-100
  criterion_results: CriterionResult[];
  disqualified: boolean;
  outputs: Record<string, Fact>;
  applied_rule_version: string;
}

export type LookupTableData = Record<string, number | string | boolean>;
export type LookupResolver = (tableId: string) => LookupTableData | null;
```

- [ ] **Step 2: Write failing tests for `operators.ts`**

Create `tests/unit/rules/operators.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import { applyOperator } from "@/rules/operators";

describe("applyOperator", () => {
  it("eq", () => expect(applyOperator("eq", 5, 5).passed).toBe(true));
  it("eq fails", () => expect(applyOperator("eq", 5, 6).passed).toBe(false));
  it("lte", () => expect(applyOperator("lte", 5, 10).passed).toBe(true));
  it("lte boundary", () => expect(applyOperator("lte", 5, 5).passed).toBe(true));
  it("between", () => expect(applyOperator("between", 5, [1, 10]).passed).toBe(true));
  it("between fails", () => expect(applyOperator("between", 11, [1, 10]).passed).toBe(false));
  it("in", () => expect(applyOperator("in", "A", ["A", "B"]).passed).toBe(true));
  it("not_in", () => expect(applyOperator("not_in", "C", ["A", "B"]).passed).toBe(true));
  it("contains", () => expect(applyOperator("contains", "hello world", "world").passed).toBe(true));
  it("regex_match", () => expect(applyOperator("regex_match", "abc123", "^[a-z]+\\d+$").passed).toBe(true));
});
```

```bash
pnpm test tests/unit/rules/operators.test.ts
```

Expected: FAIL.

- [ ] **Step 3: Implement `operators.ts`**

Create `src/rules/operators.ts`:

```typescript
import type { Fact, Operator } from "./types";

export interface OperatorResult { passed: boolean; reason?: string }

export function applyOperator(op: Operator, actual: Fact, expected: Fact | Fact[]): OperatorResult {
  switch (op) {
    case "eq": return { passed: actual === expected };
    case "neq": return { passed: actual !== expected };
    case "lt": return { passed: typeof actual === "number" && typeof expected === "number" && actual < expected };
    case "lte": return { passed: typeof actual === "number" && typeof expected === "number" && actual <= expected };
    case "gt": return { passed: typeof actual === "number" && typeof expected === "number" && actual > expected };
    case "gte": return { passed: typeof actual === "number" && typeof expected === "number" && actual >= expected };
    case "in": return { passed: Array.isArray(expected) && expected.includes(actual) };
    case "not_in": return { passed: Array.isArray(expected) && !expected.includes(actual) };
    case "between": {
      if (!Array.isArray(expected) || expected.length !== 2 || typeof actual !== "number") return { passed: false, reason: "invalid between" };
      const [lo, hi] = expected as [number, number];
      return { passed: actual >= lo && actual <= hi };
    }
    case "contains": return { passed: typeof actual === "string" && typeof expected === "string" && actual.includes(expected) };
    case "regex_match": return { passed: typeof actual === "string" && typeof expected === "string" && new RegExp(expected).test(actual) };
    case "lookup_eq":
    case "lookup_lte":
    case "regional_lte":
    case "regional_eq":
      // Resolved upstream in evaluator with table data
      return { passed: false, reason: `${op} must be resolved by evaluator` };
    default: return { passed: false, reason: `unknown op ${op}` };
  }
}
```

- [ ] **Step 4: Verify operators test passes**

```bash
pnpm test tests/unit/rules/operators.test.ts
```

Expected: PASS.

- [ ] **Step 5: Write failing tests for `multiplier-formula.ts`**

Create `tests/unit/rules/multiplier-formula.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import { evaluateMultiplier } from "@/rules/multiplier-formula";

describe("evaluateMultiplier", () => {
  const formula = {
    evaluation_order: ["set_base_first", "then_per_unit_add"] as const,
    set_base: [
      { if: "household.is_dual_earner", value: 2.0 },
      { else_default: 1.3 },
    ],
    per_unit_add: [{ field: "household.children_count", add_per_unit: 0.1 }],
  };

  it("dual earner with 2 children → 2.2", () => {
    const facts = { "household.is_dual_earner": true, "household.children_count": 2 };
    expect(evaluateMultiplier(formula, facts)).toBeCloseTo(2.2);
  });

  it("single earner with 0 children → 1.3", () => {
    const facts = { "household.is_dual_earner": false, "household.children_count": 0 };
    expect(evaluateMultiplier(formula, facts)).toBeCloseTo(1.3);
  });

  it("single earner with 3 children → 1.6", () => {
    const facts = { "household.is_dual_earner": false, "household.children_count": 3 };
    expect(evaluateMultiplier(formula, facts)).toBeCloseTo(1.6);
  });
});
```

```bash
pnpm test tests/unit/rules/multiplier-formula.test.ts
```

Expected: FAIL.

- [ ] **Step 6: Implement multiplier-formula.ts**

Create `src/rules/multiplier-formula.ts`:

```typescript
import type { Facts, MultiplierFormula } from "./types";

export function evaluateMultiplier(formula: MultiplierFormula, facts: Facts): number {
  let base: number | null = null;
  for (const entry of formula.set_base) {
    if ("if" in entry) {
      if (facts[entry.if] === true) { base = entry.value; break; }
    } else if ("else_default" in entry) {
      base ??= entry.else_default;
    }
  }
  if (base == null) base = 1.0;

  if (formula.per_unit_add) {
    for (const add of formula.per_unit_add) {
      const v = facts[add.field];
      if (typeof v === "number") base += v * add.add_per_unit;
    }
  }
  return base;
}
```

```bash
pnpm test tests/unit/rules/multiplier-formula.test.ts
```

Expected: PASS.

- [ ] **Step 7: Write failing tests for the evaluator**

Create `tests/unit/rules/evaluator.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import { evaluate } from "@/rules/evaluator";
import type { PolicyRule, Facts } from "@/rules/types";

const rule: PolicyRule = {
  policy_id: "test:1",
  version: "1",
  name: "Test",
  category: "매매-청약",
  effective_from: "2026-01-01",
  effective_to: null,
  criteria: {
    all: [
      { field: "household.type", op: "eq", value: "COUPLE" },
      { field: "household.years_since_marriage", op: "lte", value: 7 },
      {
        field: "household.combined_income_yearly", op: "lookup_lte",
        table: "urban_worker_income_yearly_2026", key: "household.member_count",
        multiplier_formula: {
          evaluation_order: ["set_base_first", "then_per_unit_add"],
          set_base: [{ if: "household.is_dual_earner", value: 2.0 }, { else_default: 1.3 }],
          per_unit_add: [{ field: "household.children_count", add_per_unit: 0.1 }],
        },
      },
    ],
  },
  disqualifiers: [{ field: "primary.is_subscription_winner_within_5y", op: "eq", value: true }],
  applies_to_announcement: { category: "매매-청약", region: "*" },
};

const lookupResolver = (id: string) =>
  id === "urban_worker_income_yearly_2026" ? { "1": 39000000, "2": 65000000, "3": 87000000, "4": 105000000 } : null;

describe("evaluate", () => {
  it("matches with VERIFIED facts", () => {
    const facts: Facts = {
      "household.type": "COUPLE",
      "household.years_since_marriage": 3,
      "household.combined_income_yearly": 100_000_000,
      "household.is_dual_earner": true,
      "household.member_count": 3,
      "household.children_count": 1,
      "primary.is_subscription_winner_within_5y": false,
    };
    const r = evaluate(rule, facts, lookupResolver);
    expect(r.matched).toBe(true);
    expect(r.disqualified).toBe(false);
    expect(r.criterion_results).toHaveLength(3);
  });

  it("disqualifies if winner within 5y even when criteria pass", () => {
    const facts: Facts = {
      "household.type": "COUPLE",
      "household.years_since_marriage": 3,
      "household.combined_income_yearly": 50_000_000,
      "household.is_dual_earner": true,
      "household.member_count": 2,
      "household.children_count": 0,
      "primary.is_subscription_winner_within_5y": true,
    };
    const r = evaluate(rule, facts, lookupResolver);
    expect(r.disqualified).toBe(true);
    expect(r.matched).toBe(false);
  });

  it("computes lookup_lte threshold via multiplier", () => {
    const facts: Facts = {
      "household.type": "COUPLE",
      "household.years_since_marriage": 3,
      "household.combined_income_yearly": 200_000_000,
      "household.is_dual_earner": true,
      "household.member_count": 3,
      "household.children_count": 1,
      "primary.is_subscription_winner_within_5y": false,
    };
    const r = evaluate(rule, facts, lookupResolver);
    expect(r.matched).toBe(false);
    const incomeCrit = r.criterion_results.find((c) => c.field === "household.combined_income_yearly");
    expect(incomeCrit?.computed_threshold).toBe(87_000_000 * 2.1);
  });
});
```

```bash
pnpm test tests/unit/rules/evaluator.test.ts
```

Expected: FAIL.

- [ ] **Step 8: Implement evaluator**

Create `src/rules/evaluator.ts`:

```typescript
import type { PolicyRule, CriteriaNode, Criterion, Facts, EvaluationResult, CriterionResult, LookupResolver } from "./types";
import { applyOperator } from "./operators";
import { evaluateMultiplier } from "./multiplier-formula";

function evalCriterion(c: Criterion, facts: Facts, lookups: LookupResolver): CriterionResult {
  const actual = facts[c.field] ?? null;
  if (c.op === "lookup_lte" || c.op === "lookup_eq") {
    if (!c.table || !c.key) return base(c, actual, "missing table/key");
    const data = lookups(c.table);
    if (!data) return base(c, actual, "lookup table missing");
    const keyVal = facts[c.key];
    const raw = (data as Record<string, number>)[String(keyVal)];
    if (typeof raw !== "number") return base(c, actual, "lookup miss");
    const multiplier = c.multiplier_formula ? evaluateMultiplier(c.multiplier_formula, facts) : 1;
    const threshold = raw * multiplier;
    const passed = c.op === "lookup_lte"
      ? typeof actual === "number" && actual <= threshold
      : actual === threshold;
    return { passed, field: c.field, operator: c.op, expected: threshold, actual, computed_threshold: threshold };
  }
  if (c.op === "regional_lte" || c.op === "regional_eq") {
    return base(c, actual, "regional ops require region context — handled outside evaluator");
  }
  const result = applyOperator(c.op, actual, c.value as never);
  return { passed: result.passed, field: c.field, operator: c.op, expected: c.value as never, actual, reason: result.reason };
}

function base(c: Criterion, actual: unknown, reason: string): CriterionResult {
  return { passed: false, field: c.field, operator: c.op, expected: c.value as never, actual: actual as never, reason };
}

function evalNode(node: CriteriaNode, facts: Facts, lookups: LookupResolver, results: CriterionResult[]): boolean {
  if ("all" in node) return node.all.every((n) => evalNode(n, facts, lookups, results));
  if ("any" in node) return node.any.some((n) => evalNode(n, facts, lookups, results));
  if ("not" in node) return !evalNode(node.not, facts, lookups, results);
  const r = evalCriterion(node, facts, lookups);
  results.push(r);
  return r.passed;
}

export function evaluate(rule: PolicyRule, facts: Facts, lookups: LookupResolver = () => null): EvaluationResult {
  const results: CriterionResult[] = [];
  const matchedCriteria = evalNode(rule.criteria, facts, lookups, results);

  let disqualified = false;
  if (rule.disqualifiers) {
    for (const d of rule.disqualifiers) {
      const r = evalCriterion(d, facts, lookups);
      if (r.passed) { disqualified = true; break; }
    }
  }

  const passedCount = results.filter((r) => r.passed).length;
  const confidence = results.length > 0 ? Math.round((passedCount / results.length) * 100) : 0;

  return {
    matched: matchedCriteria && !disqualified,
    confidence,
    criterion_results: results,
    disqualified,
    outputs: {},
    applied_rule_version: rule.version,
  };
}
```

```bash
pnpm test tests/unit/rules/evaluator.test.ts
```

Expected: PASS.

- [ ] **Step 9: Implement subscription score (가점 84점)**

Create `src/rules/scores/subscription-score.ts`:

```typescript
export interface SubscriptionScoreInput {
  homelessYears: number | null;
  dependentsCount: number;
  subscriptionAccountAgeMonths: number | null;
}

export function computeSubscriptionScore(inp: SubscriptionScoreInput): {
  homeless: number; dependents: number; subscription: number; total: number;
} {
  // 무주택 (32점): 1년 미만 0, 1~2년 2, … 1년마다 2점, 15년+ 32점
  const homeless = inp.homelessYears == null ? 0 : Math.min(32, Math.max(0, Math.floor(inp.homelessYears) * 2));

  // 부양가족 (35점): 0명 5점, 1명마다 +5점, 6명+ 35점
  const dependents = Math.min(35, 5 + Math.max(0, Math.min(6, inp.dependentsCount)) * 5);

  // 통장 가입기간 (17점): 6개월 미만 1점, 6개월~1년 2점, 이후 1년마다 +1점, 15년+ 17점
  let subscription = 0;
  const m = inp.subscriptionAccountAgeMonths;
  if (m == null) subscription = 0;
  else if (m < 6) subscription = 1;
  else if (m < 12) subscription = 2;
  else subscription = Math.min(17, 2 + Math.floor((m - 12) / 12));

  return { homeless, dependents, subscription, total: homeless + dependents + subscription };
}
```

Add a quick test in `tests/unit/rules/subscription-score.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import { computeSubscriptionScore } from "@/rules/scores/subscription-score";

describe("computeSubscriptionScore", () => {
  it("max points", () => {
    const r = computeSubscriptionScore({ homelessYears: 20, dependentsCount: 6, subscriptionAccountAgeMonths: 200 });
    expect(r.total).toBe(84);
  });
  it("zero points", () => {
    const r = computeSubscriptionScore({ homelessYears: 0, dependentsCount: 0, subscriptionAccountAgeMonths: 0 });
    expect(r.total).toBe(6); // 0 + 5 + 1
  });
  it("interpolation", () => {
    const r = computeSubscriptionScore({ homelessYears: 7, dependentsCount: 2, subscriptionAccountAgeMonths: 60 });
    expect(r.homeless).toBe(14);
    expect(r.dependents).toBe(15);
    expect(r.subscription).toBe(6);
  });
});
```

```bash
pnpm test tests/unit/rules/subscription-score.test.ts
```

Expected: PASS.

- [ ] **Step 10: Implement `computeFacts(household, today)` — full 107 fields**

Create `src/rules/compute-facts.ts`. The function takes a snapshot of household + persons + children + events and returns a `Facts` map keyed by all 107 paths from spec §8.

Pattern (full implementation, abbreviated for brevity — the engineer must generate every field listed in spec §8):

```typescript
import type { Facts } from "./types";
import { computeSubscriptionScore } from "./scores/subscription-score";

export interface HouseholdSnapshot {
  household: {
    householdType: "SINGLE" | "COUPLE" | "SINGLE_PARENT" | "PRE_NEWLYWED";
  };
  primary: PersonSnapshot;
  spouse?: PersonSnapshot;
  children: { birthDate: string; isAdopted: boolean; dispositionDate: string | null }[];
  events: { eventType: string; eventDate: string; meta: any }[];
}

export interface PersonSnapshot {
  birthDate: string;
  nationality: "KOR" | "FOREIGNER" | null;
  incomeYearly: number;
  incomeSourceType: "LABOR" | "BUSINESS" | "MIXED" | "RETIRED" | null;
  yearsOfEmployment: number;
  militaryServiceMonths: number;
  assetsRealEstate: number;
  assetsVehicle: number;
  assetsFinancial: number;
  hasSubscriptionAccount: boolean;
  subscriptionAccountType: "GENERAL" | "YOUTH" | null;
  subscriptionOpenAt: string | null;
  subscriptionPaymentCount: number | null;
  subscriptionPaymentTotal: number | null;
  subscriptionCanceledWithin1y: boolean;
  homelessSince: string | null;
  residenceSido: string;
  residenceSigungu: string;
  residenceDong: string;
  residenceSince: string;
  isHouseholdHead: boolean;
  isSeparatedHousehold: boolean;
  hasExistingDidimdolLoan: boolean;
  hasExistingJeonseLoan: boolean;
  hasExistingLhRental: boolean;
  hasHousingSubsidy: boolean;
  existingLoanBalance: number;
  isSubscriptionWinnerWithin5y: boolean;
  creditScoreKcb: number | null;
  creditScoreNice: number | null;
}

const yearsBetween = (from: string, to: Date) => (to.getTime() - new Date(from).getTime()) / (365.25 * 24 * 3600 * 1000);
const monthsBetween = (from: string, to: Date) => yearsBetween(from, to) * 12;

export function computeFacts(snap: HouseholdSnapshot, today: Date = new Date()): Facts {
  const f: Facts = {};
  const p = snap.primary, s = snap.spouse;

  // Cat 1: 세대 구성
  f["household.type"] = snap.household.householdType;
  f["household.member_count"] = 1 + (s ? 1 : 0) + snap.children.length;
  f["household.children_count"] = snap.children.length;
  f["household.minor_children_count"] = snap.children.filter((c) => yearsBetween(c.birthDate, today) < 18).length;
  f["household.is_multi_child"] = snap.children.length >= 3;
  const youngest = snap.children.length > 0 ? snap.children.reduce((a, b) => (a.birthDate > b.birthDate ? a : b)) : null;
  f["household.youngest_child_age_months"] = youngest ? monthsBetween(youngest.birthDate, today) : null;
  f["household.has_newborn"] = (f["household.youngest_child_age_months"] as number | null) != null && (f["household.youngest_child_age_months"] as number) <= 24;
  f["household.has_pregnancy"] = snap.events.some((e) => e.eventType === "PREGNANCY_START" && !snap.events.find((x) => x.eventType === "PREGNANCY_END" && x.eventDate > e.eventDate));
  f["household.is_dual_earner"] =
    !!s && ["LABOR", "BUSINESS", "MIXED"].includes(p.incomeSourceType ?? "") && ["LABOR", "BUSINESS", "MIXED"].includes(s.incomeSourceType ?? "");

  // Cat 2: 소득
  f["primary.income_yearly"] = p.incomeYearly;
  f["spouse.income_yearly"] = s?.incomeYearly ?? 0;
  f["household.combined_income_yearly"] = p.incomeYearly + (s?.incomeYearly ?? 0);
  f["household.combined_income_monthly_avg"] = Math.round((f["household.combined_income_yearly"] as number) / 12);
  f["household.income_pct_of_urban_avg"] = null; // resolved at evaluator with lookup
  f["household.income_decile"] = null;
  f["primary.income_source_type"] = p.incomeSourceType;
  f["primary.is_employed"] = (p.yearsOfEmployment + p.militaryServiceMonths / 12) >= 5;
  f["primary.years_of_employment_total"] = p.yearsOfEmployment + p.militaryServiceMonths / 12;
  f["household.has_dependent_elderly"] = false; // user input via separate event in MVP

  // Cat 3: 자산
  f["primary.assets_real_estate_official"] = p.assetsRealEstate;
  f["primary.assets_vehicle"] = p.assetsVehicle;
  f["primary.assets_financial"] = p.assetsFinancial;
  f["spouse.assets_real_estate_official"] = s?.assetsRealEstate ?? 0;
  f["spouse.assets_vehicle"] = s?.assetsVehicle ?? 0;
  f["spouse.assets_financial"] = s?.assetsFinancial ?? 0;
  f["household.combined_assets"] = p.assetsRealEstate + p.assetsVehicle + p.assetsFinancial + (s ? s.assetsRealEstate + s.assetsVehicle + s.assetsFinancial : 0);
  f["household.combined_assets_minus_debt"] = (f["household.combined_assets"] as number) - p.existingLoanBalance - (s?.existingLoanBalance ?? 0);
  f["household.has_subscription_account_balance_ge_24m"] = (p.subscriptionPaymentCount ?? 0) >= 24 || (s?.subscriptionPaymentCount ?? 0) >= 24;

  // Cat 4: 무주택
  f["primary.is_homeless"] = p.homelessSince != null;
  f["primary.homeless_since"] = p.homelessSince;
  f["primary.homeless_period_years"] = p.homelessSince ? yearsBetween(p.homelessSince, today) : 0;
  const subSc = computeSubscriptionScore({
    homelessYears: f["primary.homeless_period_years"] as number,
    dependentsCount: snap.children.length + (s ? 1 : 0),
    subscriptionAccountAgeMonths: p.subscriptionOpenAt ? monthsBetween(p.subscriptionOpenAt, today) : null,
  });
  f["primary.homeless_score"] = subSc.homeless;
  f["spouse.is_homeless"] = s ? s.homelessSince != null : null;
  f["spouse.homeless_period_years"] = s?.homelessSince ? yearsBetween(s.homelessSince, today) : 0;
  f["household.all_members_homeless"] = (p.homelessSince != null) && (!s || s.homelessSince != null);
  f["primary.had_house_in_past_5y"] = false; // user input
  f["primary.has_owned_house_5y_old_30plus"] = false;
  f["primary.house_disposed_pending"] = snap.events.some((e) => e.eventType === "HOUSE_DISPOSAL_START") && !snap.events.some((e) => e.eventType === "HOUSE_DISPOSAL_END");
  f["household.disqualified_under_recent_winner_rule"] = p.isSubscriptionWinnerWithin5y || (s?.isSubscriptionWinnerWithin5y ?? false);

  // Cat 5: 거주
  f["primary.residence_sido"] = p.residenceSido;
  f["primary.residence_sigungu"] = p.residenceSigungu;
  f["primary.residence_dong"] = p.residenceDong;
  f["primary.residence_since"] = p.residenceSince;
  f["primary.residence_years"] = yearsBetween(p.residenceSince, today);
  f["primary.residence_in_metro"] = ["서울특별시", "인천광역시", "경기도"].includes(p.residenceSido);
  f["primary.residence_in_regulated_zone"] = null; // resolved by lookup
  f["primary.residence_in_toheoja"] = null;

  // Cat 6: 혼인·자녀
  const marriage = snap.events.find((e) => e.eventType === "MARRIAGE");
  const marriageEnd = snap.events.find((e) => e.eventType === "MARRIAGE_END" && marriage && e.eventDate > marriage.eventDate);
  const activeMarriage = marriage && !marriageEnd ? marriage : null;
  f["primary.marriage_date"] = activeMarriage?.eventDate ?? null;
  f["household.years_since_marriage"] = activeMarriage ? yearsBetween(activeMarriage.eventDate, today) : null;
  f["household.is_pre_newlywed"] = snap.household.householdType === "PRE_NEWLYWED";
  f["household.is_newlywed"] = !!activeMarriage && (f["household.years_since_marriage"] as number) <= 7;
  f["household.is_post_newlywed"] = !!activeMarriage && (f["household.years_since_marriage"] as number) > 7;
  f["household.children_birth_dates"] = JSON.stringify(snap.children.map((c) => c.birthDate));
  f["household.has_child_in_school"] = snap.children.some((c) => yearsBetween(c.birthDate, today) >= 7 && yearsBetween(c.birthDate, today) < 19);
  f["household.is_single_parent"] = snap.household.householdType === "SINGLE_PARENT";
  f["household.is_grandparent_household"] = false;
  f["household.is_multicultural"] = p.nationality === "FOREIGNER" || s?.nationality === "FOREIGNER";

  // Cat 7: 청약통장
  f["primary.subscription_account_type"] = p.subscriptionAccountType;
  f["primary.subscription_open_at"] = p.subscriptionOpenAt;
  f["primary.subscription_age_months"] = p.subscriptionOpenAt ? monthsBetween(p.subscriptionOpenAt, today) : null;
  f["primary.subscription_age_score"] = subSc.subscription;
  f["primary.subscription_payment_count"] = p.subscriptionPaymentCount ?? 0;
  f["primary.subscription_payment_total"] = p.subscriptionPaymentTotal ?? 0;
  f["primary.subscription_recognized_amount"] = p.subscriptionPaymentTotal ?? 0;
  f["primary.subscription_youth_type"] = p.subscriptionAccountType === "YOUTH";
  f["spouse.subscription_account_type"] = s?.subscriptionAccountType ?? null;
  f["household.has_any_subscription_account"] = p.hasSubscriptionAccount || (s?.hasSubscriptionAccount ?? false);

  // Cat 8: 청약 가점
  f["primary.score_homeless"] = subSc.homeless;
  f["primary.score_dependents"] = subSc.dependents;
  f["primary.score_subscription"] = subSc.subscription;
  f["primary.score_total"] = subSc.total;
  f["primary.dependents_count"] = snap.children.length + (s ? 1 : 0);

  // Cat 9: 특별공급 자격 (간이 룰; 정밀 룰은 evaluator의 정책 룰에서 처리)
  f["eligibility.life_first"] = (f["primary.is_employed"] as boolean) && (f["primary.is_homeless"] as boolean);
  f["eligibility.newlywed_special"] = !!f["household.is_newlywed"];
  f["eligibility.newlywed_hope_town"] = !!f["household.is_newlywed"];
  f["eligibility.multi_child"] = !!f["household.is_multi_child"];
  f["eligibility.elder_parent"] = false;
  f["eligibility.institution_recommended"] = false;
  f["eligibility.newborn"] = !!f["household.has_newborn"];
  f["eligibility.youth_happy_house"] = !s && yearsBetween(p.birthDate, today) >= 19 && yearsBetween(p.birthDate, today) < 40;
  f["eligibility.newlywed_happy_house"] = !!f["household.is_newlywed"];
  f["eligibility.elderly_purchase"] = yearsBetween(p.birthDate, today) >= 65;
  f["eligibility.basic_living"] = false;
  f["eligibility.lower_class"] = false;
  f["eligibility.disabled"] = false;
  f["eligibility.national_merit"] = false;
  f["eligibility.north_korea_defector"] = false;

  // Cat 10: 대출
  f["loan.ltv_max_for_region"] = null;
  f["loan.dsr_max"] = null;
  f["loan.dsr_stress_rate"] = null;
  f["primary.existing_loan_balance"] = p.existingLoanBalance;
  f["primary.existing_didimdol_loan"] = p.hasExistingDidimdolLoan;
  f["primary.existing_jeonse_loan"] = p.hasExistingJeonseLoan;
  f["primary.credit_score_kcb"] = p.creditScoreKcb;
  f["primary.credit_score_nice"] = p.creditScoreNice;

  // Cat 11: 신분·자격·이력
  f["primary.nationality"] = p.nationality;
  f["primary.is_separated_household"] = p.isSeparatedHousehold;
  f["primary.is_household_head"] = p.isHouseholdHead;
  f["primary.is_subscription_winner_within_5y"] = p.isSubscriptionWinnerWithin5y;
  f["primary.subscription_account_canceled_within_1y"] = p.subscriptionCanceledWithin1y;
  f["primary.has_existing_lh_rental"] = p.hasExistingLhRental;
  f["primary.has_housing_subsidy"] = p.hasHousingSubsidy;
  const ageYears = yearsBetween(p.birthDate, today);
  f["primary.is_youth"] = ageYears >= 19 && ageYears < 40;

  // Cat 12: 시점별 정책 매핑 — populated by sweep worker into policy_status; here just pass-through
  f["policy_timeline.toheoja_zones_today"] = null;
  f["policy_timeline.regulated_zones_today"] = null;
  f["policy_timeline.ltv_dsr_rules_today"] = null;

  return f;
}
```

- [ ] **Step 11: Sanity test for computeFacts coverage**

Create `tests/unit/rules/compute-facts.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import { computeFacts } from "@/rules/compute-facts";

describe("computeFacts", () => {
  it("returns at least 95 distinct keys for a COUPLE+1 child", () => {
    const facts = computeFacts({
      household: { householdType: "COUPLE" },
      primary: samplePerson(),
      spouse: samplePerson({ incomeYearly: 40_000_000 }),
      children: [{ birthDate: "2024-09-01", isAdopted: false, dispositionDate: null }],
      events: [{ eventType: "MARRIAGE", eventDate: "2022-05-01", meta: null }, { eventType: "CHILD_BIRTH", eventDate: "2024-09-01", meta: null }, { eventType: "HOMELESS_START", eventDate: "2010-01-01", meta: { role: "PRIMARY" } }],
    }, new Date("2026-05-08"));
    expect(Object.keys(facts).length).toBeGreaterThanOrEqual(95);
    expect(facts["household.type"]).toBe("COUPLE");
    expect(facts["household.is_dual_earner"]).toBe(true);
    expect(facts["household.is_newlywed"]).toBe(true);
    expect(facts["household.has_newborn"]).toBe(true);
    expect(facts["primary.score_total"]).toBeGreaterThan(0);
  });
});

function samplePerson(overrides: any = {}) {
  return {
    birthDate: "1990-01-01",
    nationality: "KOR" as const,
    incomeYearly: 60_000_000,
    incomeSourceType: "LABOR" as const,
    yearsOfEmployment: 8,
    militaryServiceMonths: 0,
    assetsRealEstate: 0, assetsVehicle: 0, assetsFinancial: 50_000_000,
    hasSubscriptionAccount: true, subscriptionAccountType: "GENERAL" as const,
    subscriptionOpenAt: "2015-01-01", subscriptionPaymentCount: 100, subscriptionPaymentTotal: 5_000_000,
    subscriptionCanceledWithin1y: false,
    homelessSince: "2010-01-01",
    residenceSido: "서울특별시", residenceSigungu: "강남구", residenceDong: "역삼동",
    residenceSince: "2023-01-01",
    isHouseholdHead: true, isSeparatedHousehold: false,
    hasExistingDidimdolLoan: false, hasExistingJeonseLoan: false,
    hasExistingLhRental: false, hasHousingSubsidy: false,
    existingLoanBalance: 0, isSubscriptionWinnerWithin5y: false,
    creditScoreKcb: null, creditScoreNice: null,
    ...overrides,
  };
}
```

```bash
pnpm test tests/unit/rules/compute-facts.test.ts
```

Expected: PASS.

- [ ] **Step 12: Add example rules**

Create `src/rules/examples/newlywed-special.json` (paste the full JSON from spec §7.1 example 1, with `policy_id: "match-newlywed-special:2026.04"`).

Create `src/rules/examples/youth-happy-house.json` and `src/rules/examples/kookmin-rental.json` with similar structure for those policies — engineer fills in fields matching spec §0.4 Phase A list.

- [ ] **Step 13: Commit**

```bash
git add .
git commit -m "feat(rules): rule engine + 107 computed facts + score sub-functions (T4)"
```

---

### Task T5: Public Data OpenAPI Client

**Goal:** Robust client for 마이홈 모집공고, LH 단지정보, 국토부 실거래가 with retry, rate-limit, and LRU caching.

**Files:**
- Create: `src/data-sources/openapi/client.ts`, `src/data-sources/openapi/myhome.ts`, `src/data-sources/openapi/lh.ts`, `src/data-sources/openapi/molit-realprice.ts`
- Test: `tests/unit/data-sources/openapi/*.test.ts` (with fetch mocked)

- [ ] **Step 1: Write failing tests for the base client**

Create `tests/unit/data-sources/openapi/client.test.ts`:

```typescript
import { describe, it, expect, vi, beforeEach } from "vitest";
import { OpenAPIClient } from "@/data-sources/openapi/client";

describe("OpenAPIClient", () => {
  beforeEach(() => { vi.restoreAllMocks(); });

  it("retries on 5xx and succeeds", async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(new Response("err", { status: 503 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ ok: 1 }), { status: 200, headers: { "Content-Type": "application/json" } }));
    vi.stubGlobal("fetch", fetchMock);
    const c = new OpenAPIClient({ serviceKey: "k", baseUrl: "https://api.test", maxRetries: 2 });
    const res = await c.get<{ ok: number }>("/x");
    expect(res.ok).toBe(1);
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it("caches by request URL within TTL", async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(JSON.stringify({ v: 1 }), { status: 200, headers: { "Content-Type": "application/json" } }));
    vi.stubGlobal("fetch", fetchMock);
    const c = new OpenAPIClient({ serviceKey: "k", baseUrl: "https://api.test", cacheTtlMs: 60_000 });
    await c.get("/x");
    await c.get("/x");
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });
});
```

```bash
pnpm test tests/unit/data-sources/openapi/client.test.ts
```

Expected: FAIL.

- [ ] **Step 2: Implement the base client**

Create `src/data-sources/openapi/client.ts`:

```typescript
import pRetry from "p-retry";
import { LRUCache } from "lru-cache";

export interface OpenAPIClientOpts {
  serviceKey: string;
  baseUrl: string;
  maxRetries?: number;
  cacheTtlMs?: number;
}

export class OpenAPIClient {
  private cache: LRUCache<string, unknown>;

  constructor(private opts: OpenAPIClientOpts) {
    this.cache = new LRUCache({ max: 500, ttl: opts.cacheTtlMs ?? 5 * 60_000 });
  }

  async get<T>(path: string, params: Record<string, string | number | undefined> = {}): Promise<T> {
    const url = this.buildUrl(path, params);
    const cached = this.cache.get(url) as T | undefined;
    if (cached) return cached;

    const res = await pRetry(
      async () => {
        const r = await fetch(url, { headers: { Accept: "application/json" } });
        if (r.status >= 500 || r.status === 429) throw new Error(`status ${r.status}`);
        if (!r.ok) {
          const body = await r.text();
          throw new pRetry.AbortError(`status ${r.status}: ${body}`);
        }
        return r;
      },
      { retries: this.opts.maxRetries ?? 3, minTimeout: 500, factor: 2 },
    );
    const body = await res.json() as T;
    this.cache.set(url, body);
    return body;
  }

  private buildUrl(path: string, params: Record<string, string | number | undefined>): string {
    const u = new URL(path, this.opts.baseUrl);
    u.searchParams.set("serviceKey", this.opts.serviceKey);
    for (const [k, v] of Object.entries(params)) {
      if (v != null) u.searchParams.set(k, String(v));
    }
    u.searchParams.set("_type", "json");
    return u.toString();
  }
}
```

- [ ] **Step 3: Verify the client tests pass**

```bash
pnpm test tests/unit/data-sources/openapi/client.test.ts
```

Expected: PASS.

- [ ] **Step 4: Implement the 마이홈 client**

Create `src/data-sources/openapi/myhome.ts`:

```typescript
import { OpenAPIClient } from "./client";
import { loadEnv } from "@/lib/env";

export interface MyhomeAnnouncement {
  externalId: string;
  title: string;
  publishDate: string;
  applyStart: string | null;
  applyEnd: string | null;
  region: { sido: string; sigungu?: string };
  unitsTotal: number | null;
  pdfUrl: string | null;
  policyHint: string;
}

const client = () => new OpenAPIClient({
  serviceKey: loadEnv().PUBLIC_DATA_SERVICE_KEY ?? "",
  baseUrl: "https://apis.data.go.kr/B552555/lhLeaseNoticeInfo",
});

export async function fetchMyhomeAnnouncements(opts: { pageNo?: number; numOfRows?: number } = {}): Promise<MyhomeAnnouncement[]> {
  const c = client();
  const data = await c.get<any>("/myhomeNoticeList", { pageNo: opts.pageNo ?? 1, numOfRows: opts.numOfRows ?? 100 });
  const items = data?.response?.body?.items?.item ?? [];
  return items.map((it: any) => ({
    externalId: String(it.PBLANC_NO ?? it.NTC_ID),
    title: String(it.PBLANC_NM ?? it.NTC_TITL ?? ""),
    publishDate: String(it.PBLANC_DE ?? it.NTC_DT ?? ""),
    applyStart: it.SBSCRP_RCEPT_BGNDE ? String(it.SBSCRP_RCEPT_BGNDE) : null,
    applyEnd: it.SBSCRP_RCEPT_ENDDE ? String(it.SBSCRP_RCEPT_ENDDE) : null,
    region: { sido: String(it.CTPRVN_NM ?? ""), sigungu: it.SIGNGU_NM ? String(it.SIGNGU_NM) : undefined },
    unitsTotal: it.SPLY_HSHLDCNT ? Number(it.SPLY_HSHLDCNT) : null,
    pdfUrl: it.PBLANC_DOC_URL ? String(it.PBLANC_DOC_URL) : null,
    policyHint: String(it.HOUSE_TY_NM ?? ""),
  }));
}
```

(Field names follow the data.go.kr 마이홈 OpenAPI sample. The integration test in T8 will verify against a real key.)

- [ ] **Step 5: Implement the LH and 실거래가 clients with the same pattern**

Create `src/data-sources/openapi/lh.ts` and `src/data-sources/openapi/molit-realprice.ts` mirroring the 마이홈 pattern. Each exposes one or two `fetchX` functions returning typed records. Add unit tests for each that mock `fetch` with sample fixtures.

- [ ] **Step 6: Add fixture-based tests**

Create `tests/fixtures/openapi/myhome-sample.json` with a sanitized response copy. Add a unit test in `tests/unit/data-sources/openapi/myhome.test.ts` that mocks fetch with the fixture and asserts mapping is correct.

```bash
pnpm test tests/unit/data-sources/openapi/
```

Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add .
git commit -m "feat(data): public OpenAPI clients for 마이홈/LH/실거래가 with retry+cache (T5)"
```

---

### Task T6: Playwright Crawlers + crawler_health Tracking

**Goal:** Crawlers for 청약홈, SH (미리내집), GH that emit `Announcement` candidates and update `crawler_health`. Tested with recorded HAR fixtures (no live network in unit tests).

**Files:**
- Create: `src/data-sources/crawlers/base.ts`, `applyhome.ts`, `sh.ts`, `gh.ts`
- Create: `src/db/queries/crawler-health.ts`
- Test: `tests/unit/data-sources/crawlers/*.test.ts` (with Playwright `route.fulfill` mocking)

- [ ] **Step 1: Write the base crawler interface and health tracking**

Create `src/data-sources/crawlers/base.ts`:

```typescript
import { db } from "@/db/client";
import { crawlerHealth } from "@/db/schema";
import { eq, sql } from "drizzle-orm";

export interface CrawledAnnouncement {
  sourceId: string;
  externalId: string;
  title: string;
  publishDate: string;
  applyStart: string | null;
  applyEnd: string | null;
  region: { sido: string; sigungu?: string };
  unitsTotal: number | null;
  pdfUrl: string | null;
}

export interface Crawler {
  sourceId: string;
  fetchAll(): Promise<CrawledAnnouncement[]>;
}

export async function recordHealthSuccess(sourceId: string) {
  await db.insert(crawlerHealth).values({ sourceId, lastSuccessAt: sql`NOW()`, consecutiveFailures: 0, status: "HEALTHY" })
    .onConflictDoUpdate({ target: crawlerHealth.sourceId, set: { lastSuccessAt: sql`NOW()`, consecutiveFailures: 0, status: "HEALTHY" } });
}

export async function recordHealthFailure(sourceId: string) {
  const rows = await db.select().from(crawlerHealth).where(eq(crawlerHealth.sourceId, sourceId));
  const next = (rows[0]?.consecutiveFailures ?? 0) + 1;
  const status = next >= 3 ? "BROKEN" : next >= 1 ? "DEGRADED" : "HEALTHY";
  await db.insert(crawlerHealth).values({ sourceId, lastFailureAt: sql`NOW()`, consecutiveFailures: next, status })
    .onConflictDoUpdate({ target: crawlerHealth.sourceId, set: { lastFailureAt: sql`NOW()`, consecutiveFailures: next, status } });
}
```

- [ ] **Step 2: Implement the 청약홈 crawler**

Create `src/data-sources/crawlers/applyhome.ts`:

```typescript
import { chromium, type Browser } from "playwright";
import { recordHealthFailure, recordHealthSuccess, type CrawledAnnouncement, type Crawler } from "./base";

export const applyhomeCrawler: Crawler = {
  sourceId: "applyhome",
  async fetchAll() {
    let browser: Browser | null = null;
    try {
      browser = await chromium.launch({ headless: true });
      const ctx = await browser.newContext({ locale: "ko-KR" });
      const page = await ctx.newPage();
      await page.goto("https://www.applyhome.co.kr/ai/aia/selectSubscrptCalenderView.do", { waitUntil: "domcontentloaded" });
      const rows = await page.$$eval("table.tbl_st1 tbody tr", (trs) =>
        trs.map((tr) => {
          const cells = tr.querySelectorAll("td");
          return {
            externalId: cells[0]?.textContent?.trim() ?? "",
            title: cells[1]?.textContent?.trim() ?? "",
            publishDate: cells[2]?.textContent?.trim() ?? "",
            applyStart: cells[3]?.textContent?.trim() ?? null,
            applyEnd: cells[4]?.textContent?.trim() ?? null,
            region: { sido: cells[5]?.textContent?.trim() ?? "" },
            unitsTotal: null,
            pdfUrl: tr.querySelector("a[href*='.pdf']")?.getAttribute("href") ?? null,
          };
        }),
      );
      const items: CrawledAnnouncement[] = rows.filter((r) => r.title).map((r) => ({ ...r, sourceId: "applyhome" }));
      await recordHealthSuccess("applyhome");
      return items;
    } catch (e) {
      await recordHealthFailure("applyhome");
      throw e;
    } finally {
      await browser?.close();
    }
  },
};
```

(Engineer note: actual selectors may shift. Verify against live page during implementation. The `recordHealthFailure` chain ensures 3 misses → BROKEN → T12 alerts.)

- [ ] **Step 3: Add an integration smoke test gated by env**

Create `tests/integration/crawlers/applyhome.smoke.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import { applyhomeCrawler } from "@/data-sources/crawlers/applyhome";

const ENABLED = process.env.RUN_LIVE_CRAWLER_TESTS === "1";

describe.skipIf(!ENABLED)("applyhomeCrawler — live", () => {
  it("returns at least 1 announcement", async () => {
    const items = await applyhomeCrawler.fetchAll();
    expect(items.length).toBeGreaterThan(0);
  }, 60_000);
});
```

Run on demand: `RUN_LIVE_CRAWLER_TESTS=1 pnpm test tests/integration/crawlers`.

- [ ] **Step 4: Implement SH and GH crawlers (same pattern)**

Create `src/data-sources/crawlers/sh.ts` (target https://www.i-sh.co.kr — 미리내집 list page).
Create `src/data-sources/crawlers/gh.ts` (target https://apply.gh.or.kr).

Each follows the same `try/recordHealthSuccess/catch/recordHealthFailure` pattern.

- [ ] **Step 5: Write upsert helper for announcements**

Create `src/db/queries/announcement.ts`:

```typescript
import { db } from "@/db/client";
import { announcement } from "@/db/schema";
import { and, eq } from "drizzle-orm";
import { createHash } from "node:crypto";

export interface UpsertInput {
  policyId: string | null;
  announcementType: "SALE" | "RENTAL";
  source: "API" | "CRAWL";
  sourceExternalId: string;
  title: string;
  publishDate: string | null;
  applyStart: string | null;
  applyEnd: string | null;
  targetRegion: object;
  unitsTotal: number | null;
  pdfUrl: string | null;
  pdfTextMd?: string | null;
}

export async function upsertAnnouncement(input: UpsertInput): Promise<{ id: number; changed: boolean }> {
  const bodyHash = createHash("sha256").update(JSON.stringify({ ...input, pdfTextMd: input.pdfTextMd ?? null })).digest("hex");
  const existing = await db.select().from(announcement)
    .where(and(eq(announcement.source, input.source), eq(announcement.sourceExternalId, input.sourceExternalId)));
  if (existing.length === 0) {
    const ins = await db.insert(announcement).values({
      ...input, bodyHash, status: "OPEN",
    }).returning({ id: announcement.announcementId });
    return { id: ins[0].id, changed: true };
  }
  const row = existing[0];
  if (row.bodyHash === bodyHash) return { id: row.announcementId, changed: false };
  await db.update(announcement).set({ ...input, bodyHash, lastChangedAt: new Date() })
    .where(eq(announcement.announcementId, row.announcementId));
  return { id: row.announcementId, changed: true };
}
```

- [ ] **Step 6: Commit**

```bash
git add .
git commit -m "feat(crawlers): Playwright crawlers + crawler_health tracking + announcement upsert (T6)"
```

---

---

## Wave 3 — Parallel (3 subagents OK)

> **Pre-condition:** Wave 2 merged to `main`. All three tasks share the same DB schema and crawled `announcement` rows, but write to distinct tables (`announcement` body/pdf fields for T7, `match` for T8, `announcement_supply_breakdown` for T9). Safe to run concurrently.

---

### Task T7: PDF/HWP + LLM Extraction / Verification Pipeline

**Scope:** Download PDF/HWP attachments for each announcement, convert HWP→PDF via LibreOffice, extract full text via pdfjs-dist, run Claude Extractor to extract structured policy fields + supply breakdown, run Verifier sub-agent (Tavily web search) to cross-check, auto-apply or enqueue for ACK.

**Files created/modified:**
- `src/pipeline/pdf-downloader.ts`
- `src/pipeline/hwp-converter.ts`
- `src/pipeline/text-extractor.ts`
- `src/pipeline/llm-extractor.ts`
- `src/pipeline/verifier.ts`
- `src/pipeline/rule-change-applier.ts`
- `src/pipeline/sweep.ts`
- `src/workers/pdf-worker.ts`
- `scripts/run-cron.ts` (update — add PDF worker job)
- Tests: `src/pipeline/__tests__/text-extractor.test.ts`, `src/pipeline/__tests__/llm-extractor.test.ts`

---

- [ ] **Step 1: PDF downloader**

```typescript
// src/pipeline/pdf-downloader.ts
import fs from "node:fs/promises";
import path from "node:path";
import crypto from "node:crypto";

const PDF_CACHE_DIR = process.env.PDF_CACHE_DIR ?? "/tmp/housing-pdfs";

/** Download PDF from URL if not already cached. Returns local path. */
export async function downloadPdf(url: string): Promise<string> {
  await fs.mkdir(PDF_CACHE_DIR, { recursive: true });
  const hash = crypto.createHash("md5").update(url).digest("hex");
  const ext = url.toLowerCase().endsWith(".hwp") ? ".hwp" : ".pdf";
  const localPath = path.join(PDF_CACHE_DIR, `${hash}${ext}`);
  try {
    await fs.access(localPath);
    return localPath; // cache hit
  } catch {
    const res = await fetch(url, { signal: AbortSignal.timeout(30_000) });
    if (!res.ok) throw new Error(`PDF download failed ${res.status}: ${url}`);
    const buf = Buffer.from(await res.arrayBuffer());
    await fs.writeFile(localPath, buf);
    return localPath;
  }
}
```

- [ ] **Step 2: HWP → PDF converter (calls LibreOffice Docker service)**

```typescript
// src/pipeline/hwp-converter.ts
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import path from "node:path";

const execFileAsync = promisify(execFile);

/**
 * Convert HWP file to PDF via LibreOffice running in Docker container.
 * Requires LibreOffice service mounted at PDF_CACHE_DIR.
 * Returns path to converted PDF, or null if conversion fails (caller shows original link).
 */
export async function convertHwpToPdf(hwpPath: string): Promise<string | null> {
  const outDir = path.dirname(hwpPath);
  try {
    await execFileAsync(
      "docker",
      ["exec", "libreoffice", "libreoffice", "--headless", "--convert-to", "pdf",
        "--outdir", outDir, hwpPath],
      { timeout: 60_000 }
    );
    const pdfPath = hwpPath.replace(/\.hwp$/i, ".pdf");
    return pdfPath;
  } catch (err) {
    console.warn("[hwp-converter] Conversion failed, returning null:", err);
    return null;
  }
}
```

- [ ] **Step 3: Text extractor (pdfjs-dist)**

```typescript
// src/pipeline/text-extractor.ts
import * as pdfjs from "pdfjs-dist/legacy/build/pdf.mjs";

/**
 * Extract full text from a local PDF file.
 * Returns markdown-ish plain text (page breaks as \n---\n).
 */
export async function extractPdfText(pdfPath: string): Promise<string> {
  const data = new Uint8Array(
    await import("node:fs/promises").then((fs) => fs.readFile(pdfPath))
  );
  const doc = await pdfjs.getDocument({ data }).promise;
  const pages: string[] = [];
  for (let i = 1; i <= doc.numPages; i++) {
    const page = await doc.getPage(i);
    const content = await page.getTextContent();
    pages.push(content.items.map((item: any) => item.str).join(" "));
  }
  return pages.join("\n---\n");
}
```

- [ ] **Step 4: Vitest — text extractor unit test**

```typescript
// src/pipeline/__tests__/text-extractor.test.ts
import { describe, it, expect } from "vitest";
import path from "node:path";
import { extractPdfText } from "../text-extractor";

describe("extractPdfText", () => {
  it("extracts text from a known fixture PDF", async () => {
    // fixtures/sample-announcement.pdf contains "버팀목 전세자금 대출 안내"
    const fixturePath = path.join(__dirname, "fixtures/sample-announcement.pdf");
    const text = await extractPdfText(fixturePath);
    expect(text).toContain("버팀목");
  });
});
```

> Add a small (public-domain) PDF fixture at `src/pipeline/__tests__/fixtures/sample-announcement.pdf`. Any PDF with Korean text works for this test.

- [ ] **Step 5: LLM Extractor (Claude Sonnet 4.6)**

```typescript
// src/pipeline/llm-extractor.ts
import Anthropic from "@anthropic-ai/sdk";
import { z } from "zod";

const client = new Anthropic();

export const ExtractedRuleSchema = z.object({
  field: z.string(),        // e.g. "income_threshold_solo"
  operator: z.string(),     // e.g. "lte"
  value: z.union([z.number(), z.string(), z.boolean()]),
  unit: z.string().optional(), // e.g. "만원/년"
  evidence: z.string(),     // direct quote from document supporting this rule
  confidence: z.enum(["HIGH", "MEDIUM", "LOW"]),
});

export const ExtractionResultSchema = z.object({
  policyId: z.number(),
  announcementId: z.number(),
  rules: z.array(ExtractedRuleSchema),
  supplyStructure: z.object({
    totalUnits: z.number().nullable(),
    specialSupply: z.number().nullable(),    // 특별공급
    generalSupply: z.number().nullable(),    // 일반공급
    lotteryUnits: z.number().nullable(),     // 추첨제
    priorityUnits: z.number().nullable(),    // 우선공급
    waitlistUnits: z.number().nullable(),    // 무순위/줍줍
    breakdownByType: z.record(z.number()),   // { "전용 59㎡": 120, "전용 84㎡": 80, ... }
    competitionRatioHistory: z.number().nullable(), // 직전 경쟁률
  }),
  summary_ko: z.string(), // 300자 이내 한국어 요약
});

export type ExtractionResult = z.infer<typeof ExtractionResultSchema>;

/** PII guard: block any document text containing 주민번호/phone/account patterns before sending to LLM */
function guardPii(text: string): string {
  return text
    .replace(/\d{6}-\d{7}/g, "[주민번호-REDACTED]")
    .replace(/01[0-9]-\d{3,4}-\d{4}/g, "[전화번호-REDACTED]")
    .replace(/\d{3,4}-\d{4}-\d{4}-\d{4}/g, "[계좌-REDACTED]");
}

export async function extractFromDocument(
  policyId: number,
  announcementId: number,
  documentText: string
): Promise<ExtractionResult> {
  const safeText = guardPii(documentText.slice(0, 40_000)); // token budget
  const systemPrompt = `You are a Korean government housing policy extraction agent.
Extract structured eligibility rules and supply breakdown from the provided announcement document text.
Output ONLY valid JSON matching the schema. Do NOT include personal data. Use Korean text from the document as evidence.`;

  const userPrompt = `Document text:\n${safeText}\n\nPolicy ID: ${policyId}\nAnnouncement ID: ${announcementId}`;

  const response = await client.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 4096,
    system: systemPrompt,
    messages: [{ role: "user", content: userPrompt }],
  });

  const raw = (response.content[0] as { type: "text"; text: string }).text;
  const jsonMatch = raw.match(/\{[\s\S]*\}/);
  if (!jsonMatch) throw new Error("LLM returned no JSON block");
  const parsed = ExtractionResultSchema.parse(JSON.parse(jsonMatch[0]));
  return { ...parsed, policyId, announcementId };
}
```

- [ ] **Step 6: Vitest — LLM extractor integration test (recorded fixture)**

```typescript
// src/pipeline/__tests__/llm-extractor.test.ts
import { describe, it, expect, vi } from "vitest";
import { extractFromDocument } from "../llm-extractor";

// Use a recorded LLM response fixture to avoid API calls in CI
const FIXTURE_RESPONSE = {
  policyId: 1,
  announcementId: 1,
  rules: [{ field: "income_threshold_solo", operator: "lte", value: 5000, unit: "만원/년", evidence: "연소득 5천만원 이하", confidence: "HIGH" }],
  supplyStructure: { totalUnits: 100, specialSupply: 30, generalSupply: 70, lotteryUnits: 20, priorityUnits: 50, waitlistUnits: 0, breakdownByType: { "전용 59㎡": 60, "전용 84㎡": 40 }, competitionRatioHistory: 12.5 },
  summary_ko: "청년 버팀목 전세자금 대출 공고. 연소득 5천만원 이하 무주택 청년 대상.",
};

vi.mock("@anthropic-ai/sdk", () => ({
  default: class {
    messages = { create: async () => ({ content: [{ type: "text", text: JSON.stringify(FIXTURE_RESPONSE) }] }) };
  },
}));

describe("extractFromDocument", () => {
  it("parses LLM response into ExtractionResult", async () => {
    const result = await extractFromDocument(1, 1, "버팀목 전세자금 대출 연소득 5천만원 이하");
    expect(result.rules[0].field).toBe("income_threshold_solo");
    expect(result.supplyStructure.totalUnits).toBe(100);
    expect(result.summary_ko).toContain("버팀목");
  });
});
```

- [ ] **Step 7: Verifier sub-agent (Claude Opus 4.7 / GPT-5.5 + Tavily)**

```typescript
// src/pipeline/verifier.ts
import Anthropic from "@anthropic-ai/sdk";
import type { ExtractionResult, ExtractedRuleSchema } from "./llm-extractor";
import { z } from "zod";

const client = new Anthropic();

export const VerificationStatus = z.enum([
  "VERIFIED",         // ≥2 independent sources confirm, apply automatically if delta is MINOR
  "WEAK_VERIFIED",    // 1 source confirms, queue for ACK
  "AMBIGUOUS",        // sources conflict, queue for ACK
  "UNVERIFIABLE",     // no relevant sources found, queue for ACK
  "NEW_RULE",         // rule not previously known, queue for ACK
  "DEPRECATE",        // policy appears removed/superseded, queue for ACK
]);

export const VerificationResultSchema = z.object({
  status: VerificationStatus,
  sources: z.array(z.object({ url: z.string(), title: z.string(), snippet: z.string() })),
  notes: z.string(),
});

export type VerificationResult = z.infer<typeof VerificationResultSchema>;

/**
 * Verify extracted rule changes using Tavily web search via Claude tool use.
 * Uses claude-opus-4-7 as judge. Each rule is verified independently.
 */
export async function verifyRuleChange(
  rule: z.infer<typeof ExtractedRuleSchema>,
  policyName: string
): Promise<VerificationResult> {
  const query = `${policyName} ${rule.field} ${rule.operator} ${rule.value} ${rule.unit ?? ""} 정부 공식 발표`;

  // Tavily search via Claude tool use (tool calling with search tool)
  const response = await client.messages.create({
    model: "claude-opus-4-7",
    max_tokens: 2048,
    tools: [
      {
        name: "web_search",
        description: "Search the web for current Korean housing policy information",
        input_schema: {
          type: "object" as const,
          properties: { query: { type: "string" } },
          required: ["query"],
        },
      },
    ],
    messages: [
      {
        role: "user",
        content: `Verify this extracted rule for Korean housing policy "${policyName}":
Field: ${rule.field}
Operator: ${rule.operator}
Value: ${rule.value} ${rule.unit ?? ""}
Evidence from document: "${rule.evidence}"

Search for current official information and determine if this rule is accurate.
Return JSON: { status: VERIFIED|WEAK_VERIFIED|AMBIGUOUS|UNVERIFIABLE|NEW_RULE|DEPRECATE, sources: [...], notes: "..." }`,
      },
    ],
  });

  // Parse the assistant's final text response
  const finalText = response.content
    .filter((b) => b.type === "text")
    .map((b) => (b as { type: "text"; text: string }).text)
    .join("");
  const jsonMatch = finalText.match(/\{[\s\S]*\}/);
  if (!jsonMatch) return { status: "UNVERIFIABLE", sources: [], notes: "No JSON in verifier response" };
  return VerificationResultSchema.parse(JSON.parse(jsonMatch[0]));
}
```

- [ ] **Step 8: Rule change applier**

```typescript
// src/pipeline/rule-change-applier.ts
import { db } from "@/db/client";
import { ruleChangeProposal, policy } from "@/db/schema";
import { eq } from "drizzle-orm";
import type { ExtractionResult } from "./llm-extractor";
import type { VerificationResult } from "./verifier";

const MINOR_FIELDS = new Set([
  "income_threshold_solo", "income_threshold_couple", "income_threshold_newlywed",
  "asset_threshold_solo", "asset_threshold_couple",
  "loan_limit_solo", "loan_limit_couple",
  "interest_rate_min", "interest_rate_max",
]);

/** Auto-apply VERIFIED minor numeric-threshold changes; enqueue everything else */
export async function applyOrEnqueue(
  extraction: ExtractionResult,
  verifications: Map<string, VerificationResult>
): Promise<void> {
  for (const rule of extraction.rules) {
    const ver = verifications.get(rule.field) ?? { status: "UNVERIFIABLE" as const, sources: [], notes: "" };
    const isMinor = MINOR_FIELDS.has(rule.field);
    const autoApply = ver.status === "VERIFIED" && isMinor && rule.confidence !== "LOW";

    await db.insert(ruleChangeProposal).values({
      policyId: extraction.policyId,
      announcementId: extraction.announcementId,
      proposedChange: {
        field: rule.field,
        operator: rule.operator,
        value: rule.value,
        unit: rule.unit ?? null,
      },
      evidence: rule.evidence,
      verificationStatus: ver.status,
      verificationSources: ver.sources,
      autoApplied: autoApply,
      appliedAt: autoApply ? new Date() : null,
    });

    if (autoApply) {
      // Update the JSON rule in the policy's eligibility_rules JSONB column
      // This is a targeted patch: only the matching field's value is updated
      await db.execute(
        // Raw SQL: jsonb_set to update nested rule value
        // policy.eligibility_rules is JSONB array of PolicyRule objects
        // We find the rule by field name and patch the value
        `UPDATE policy
         SET eligibility_rules = (
           SELECT jsonb_agg(
             CASE WHEN r->>'field' = $1
               THEN r || jsonb_build_object('value', $2::text::jsonb)
               ELSE r
             END
           )
           FROM jsonb_array_elements(eligibility_rules) AS r
         ),
         updated_at = NOW()
         WHERE policy_id = $3`,
        [rule.field, JSON.stringify(rule.value), extraction.policyId]
      );
    }
  }
}
```

- [ ] **Step 9: Sweep orchestrator (main pipeline entry point)**

```typescript
// src/pipeline/sweep.ts
import { db } from "@/db/client";
import { announcement, policy } from "@/db/schema";
import { isNull, eq } from "drizzle-orm";
import { downloadPdf } from "./pdf-downloader";
import { convertHwpToPdf } from "./hwp-converter";
import { extractPdfText } from "./text-extractor";
import { extractFromDocument } from "./llm-extractor";
import { verifyRuleChange } from "./verifier";
import { applyOrEnqueue } from "./rule-change-applier";
import { upsertSupplyBreakdown } from "@/data/supply-breakdown";
import { recordSweepCost } from "@/data/llm-cost";

/**
 * Sweep all OPEN announcements that have a pdfUrl but no pdfTextMd yet.
 * Download → convert → extract text → LLM extract → verify → apply/enqueue.
 */
export async function runPdfSweep(): Promise<void> {
  const pending = await db
    .select()
    .from(announcement)
    .where(
      // has pdfUrl but hasn't been processed
      isNull(announcement.pdfTextMd)
    )
    .limit(50);

  for (const ann of pending) {
    if (!ann.pdfUrl) continue;
    try {
      let localPath = await downloadPdf(ann.pdfUrl);
      if (localPath.endsWith(".hwp")) {
        const converted = await convertHwpToPdf(localPath);
        if (!converted) {
          await db.update(announcement)
            .set({ pdfTextMd: "__HWP_CONVERSION_FAILED__" })
            .where(eq(announcement.announcementId, ann.announcementId));
          continue;
        }
        localPath = converted;
      }
      const text = await extractPdfText(localPath);
      const pol = await db.select().from(policy).where(eq(policy.policyId, ann.policyId)).limit(1);
      const policyName = pol[0]?.name ?? "알 수 없음";
      const extraction = await extractFromDocument(ann.policyId, ann.announcementId, text);

      // Verify each rule concurrently
      const verMap = new Map(
        await Promise.all(
          extraction.rules.map(async (r) => {
            const ver = await verifyRuleChange(r, policyName);
            return [r.field, ver] as [string, typeof ver];
          })
        )
      );
      await applyOrEnqueue(extraction, verMap);
      await upsertSupplyBreakdown(ann.announcementId, extraction.supplyStructure);
      await db.update(announcement)
        .set({ pdfTextMd: text, llmSummary: extraction.summary_ko })
        .where(eq(announcement.announcementId, ann.announcementId));
      await recordSweepCost("sonnet", extraction.rules.length, "pdf-sweep");
    } catch (err) {
      console.error(`[pdf-sweep] Failed for announcement ${ann.announcementId}:`, err);
    }
  }
}
```

- [ ] **Step 10: Wire PDF worker into cron**

```typescript
// src/workers/pdf-worker.ts
import { runPdfSweep } from "@/pipeline/sweep";

export async function run(): Promise<void> {
  console.log("[pdf-worker] Starting PDF sweep...");
  await runPdfSweep();
  console.log("[pdf-worker] PDF sweep complete.");
}
```

```typescript
// scripts/run-cron.ts — add alongside existing crawl jobs
import cron from "node-cron";
import { run as runCrawlers } from "../src/workers/crawl-worker";
import { run as runPdfWorker } from "../src/workers/pdf-worker";

// Crawl every 6 hours
cron.schedule("0 */6 * * *", () => runCrawlers().catch(console.error));
// PDF sweep every 2 hours (after crawl drops new rows)
cron.schedule("30 */2 * * *", () => runPdfWorker().catch(console.error));
```

- [ ] **Step 11: Add `upsertSupplyBreakdown` and `recordSweepCost` helpers**

```typescript
// src/data/supply-breakdown.ts
import { db } from "@/db/client";
import { announcementSupplyBreakdown } from "@/db/schema";
import { eq } from "drizzle-orm";

export async function upsertSupplyBreakdown(
  announcementId: number,
  s: {
    totalUnits: number | null;
    specialSupply: number | null;
    generalSupply: number | null;
    lotteryUnits: number | null;
    priorityUnits: number | null;
    waitlistUnits: number | null;
    breakdownByType: Record<string, number>;
    competitionRatioHistory: number | null;
  }
): Promise<void> {
  await db
    .insert(announcementSupplyBreakdown)
    .values({ announcementId, ...s, breakdownByType: s.breakdownByType })
    .onConflictDoUpdate({
      target: announcementSupplyBreakdown.announcementId,
      set: { ...s, updatedAt: new Date() },
    });
}
```

```typescript
// src/data/llm-cost.ts
import { db } from "@/db/client";
import { llmCostLog } from "@/db/schema";

const TOKEN_RATES: Record<string, { input: number; output: number }> = {
  sonnet: { input: 3 / 1_000_000, output: 15 / 1_000_000 },  // USD per token
  opus: { input: 15 / 1_000_000, output: 75 / 1_000_000 },
};

export async function recordSweepCost(
  model: "sonnet" | "opus",
  rulesProcessed: number,
  jobName: string
): Promise<void> {
  // Approximate: 2000 tokens per rule (input + output combined)
  const estimatedTokens = rulesProcessed * 2000;
  const rate = TOKEN_RATES[model];
  const estimatedCostUsd = estimatedTokens * ((rate.input + rate.output) / 2);
  await db.insert(llmCostLog).values({
    jobName,
    model,
    estimatedTokens,
    estimatedCostUsd: estimatedCostUsd.toString(),
    rulesProcessed,
  });
}
```

- [ ] **Step 12: Commit**

```bash
git add .
git commit -m "feat(pipeline): PDF/HWP download + text extraction + LLM extractor + verifier + rule applier (T7)"
```

---

### Task T8: Matching Engine + Phase A Scoring

**Scope:** For each household, evaluate all OPEN announcements against all applicable policies using the T4 rule evaluator and computed facts. Store match rows, compute three scores (competition, price-value, composite), generate a home dashboard showing matched announcements ranked by composite score.

**Files created/modified:**
- `src/matching/matcher.ts`
- `src/matching/scorer.ts`
- `src/matching/run-matching.ts`
- `src/workers/match-worker.ts`
- `src/app/page.tsx` (home dashboard — replaced stub)
- `src/app/catalog/page.tsx` (full benefit catalog)
- `src/app/match/[id]/page.tsx` (match detail page)
- `src/data/matches.ts`
- `scripts/run-cron.ts` (add match worker)
- Tests: `src/matching/__tests__/matcher.test.ts`, `src/matching/__tests__/scorer.test.ts`

---

- [ ] **Step 1: Household snapshot loader**

```typescript
// src/matching/matcher.ts
import { db } from "@/db/client";
import { household, person, child, householdEvent } from "@/db/schema";
import { eq } from "drizzle-orm";
import type { HouseholdSnapshot } from "@/rules/compute-facts";

export async function loadHouseholdSnapshot(householdId: number): Promise<HouseholdSnapshot> {
  const [hh] = await db.select().from(household).where(eq(household.householdId, householdId));
  if (!hh) throw new Error(`Household ${householdId} not found`);
  const persons = await db.select().from(person).where(eq(person.householdId, householdId));
  const children = await db.select().from(child).where(eq(child.householdId, householdId));
  const events = await db.select().from(householdEvent).where(eq(householdEvent.householdId, householdId));
  return { household: hh, persons, children, events };
}
```

- [ ] **Step 2: Policy + announcement loader for matching**

```typescript
// src/matching/matcher.ts (continued)
import { policy, announcement, lookupTable } from "@/db/schema";
import type { LookupResolver } from "@/rules/evaluator";

export async function loadActivePolicies() {
  return db
    .select()
    .from(policy)
    .where(eq(policy.isActive, true));
}

export async function loadOpenAnnouncements(policyId: number) {
  return db
    .select()
    .from(announcement)
    .where(
      and(eq(announcement.policyId, policyId), eq(announcement.status, "OPEN"))
    );
}

export function buildLookupResolver(tables: typeof lookupTable.$inferSelect[]): LookupResolver {
  return (tableName: string, key: string | number) => {
    const table = tables.find((t) => t.tableName === tableName);
    if (!table) return null;
    const entry = (table.entries as Array<{ key: string | number; value: unknown }>)
      .find((e) => String(e.key) === String(key));
    return entry?.value ?? null;
  };
}
```

- [ ] **Step 3: Match evaluator**

```typescript
// src/matching/matcher.ts (continued)
import { computeFacts } from "@/rules/compute-facts";
import { evaluate } from "@/rules/evaluator";
import type { PolicyRule } from "@/rules/types";

export interface MatchCandidate {
  policyId: number;
  announcementId: number;
  policyName: string;
  announcementTitle: string;
  passedRules: string[];
  failedRules: string[];
  eligible: boolean;
  failureReasons: string[]; // human-readable Korean failure messages
}

export async function evaluateHouseholdAgainstAnnouncement(
  snap: HouseholdSnapshot,
  pol: typeof policy.$inferSelect,
  ann: typeof announcement.$inferSelect,
  lookupResolver: LookupResolver
): Promise<MatchCandidate> {
  const facts = computeFacts(snap);
  const rules: PolicyRule[] = pol.eligibilityRules as PolicyRule[];
  const passed: string[] = [];
  const failed: string[] = [];
  const failureReasons: string[] = [];

  for (const rule of rules) {
    const result = evaluate(rule, facts, lookupResolver);
    if (result.pass) {
      passed.push(rule.field);
    } else {
      failed.push(rule.field);
      failureReasons.push(result.reason ?? `${rule.field} 조건 미충족`);
    }
  }

  return {
    policyId: pol.policyId,
    announcementId: ann.announcementId,
    policyName: pol.name,
    announcementTitle: ann.title,
    passedRules: passed,
    failedRules: failed,
    eligible: failed.length === 0,
    failureReasons,
  };
}
```

- [ ] **Step 4: Vitest — matcher unit tests**

```typescript
// src/matching/__tests__/matcher.test.ts
import { describe, it, expect } from "vitest";
import { evaluateHouseholdAgainstAnnouncement } from "../matcher";
import type { HouseholdSnapshot } from "@/rules/compute-facts";

const makeSnap = (overrides: Partial<HouseholdSnapshot["household"]> = {}): HouseholdSnapshot => ({
  household: {
    householdId: 1, userId: 1, householdType: "SINGLE",
    region: "서울특별시", subRegion: "마포구",
    createdAt: new Date(), updatedAt: new Date(), ...overrides,
  },
  persons: [{
    personId: 1, householdId: 1, role: "PRIMARY",
    name: "홍길동", birthDate: new Date("1995-01-01"),
    annualIncomePretax: 40_000_000, netAssets: 100_000_000,
    isMarried: false, marriageDate: null, isFirsthomeBuyer: true,
    hasSubscriptionAccount: true, subscriptionMonths: 24,
    employmentType: "EMPLOYED", employmentMonths: 36,
    militaryServiceMonths: 0, isDisabled: false, isVeteran: false,
    isBasicLivelihoodRecipient: false, createdAt: new Date(), updatedAt: new Date(),
  }],
  children: [],
  events: [],
});

const SOLO_INCOME_RULE = {
  ruleId: "r1", field: "income_pretax_primary_annual", operator: "lte" as const, value: 50_000_000,
  description: "연소득 5천만원 이하",
};

it("passes when income is within threshold", async () => {
  const snap = makeSnap();
  const result = await evaluateHouseholdAgainstAnnouncement(
    snap,
    { policyId: 1, name: "테스트", eligibilityRules: [SOLO_INCOME_RULE], isActive: true } as any,
    { announcementId: 1, policyId: 1, title: "공고", status: "OPEN" } as any,
    () => null
  );
  expect(result.eligible).toBe(true);
});

it("fails when income exceeds threshold", async () => {
  const snap = makeSnap({ /* income will be overridden via persons */ });
  snap.persons[0].annualIncomePretax = 60_000_000;
  const result = await evaluateHouseholdAgainstAnnouncement(
    snap,
    { policyId: 1, name: "테스트", eligibilityRules: [SOLO_INCOME_RULE], isActive: true } as any,
    { announcementId: 1, policyId: 1, title: "공고", status: "OPEN" } as any,
    () => null
  );
  expect(result.eligible).toBe(false);
  expect(result.failureReasons.length).toBeGreaterThan(0);
});
```

- [ ] **Step 5: Scorer (competition, price-value, liquidity, composite)**

```typescript
// src/matching/scorer.ts
import { db } from "@/db/client";
import { announcementScore, announcementSupplyBreakdown } from "@/db/schema";
import { eq } from "drizzle-orm";

export interface ScoreInput {
  announcementId: number;
  // Competition score inputs
  competitionRatioHistory: number | null;         // 직전 경쟁률
  totalUnits: number | null;
  // Price-value inputs
  announcementPriceWon: number | null;            // 분양가 (원)
  nearbyMarketPriceWon: number | null;            // 인근 시세 (원) — from 실거래가 API
  // Liquidity inputs
  nearbyTransactionCount90d: number | null;       // 인근 90일 거래량
}

/** Score: 0–100 scale. Higher is better (more competitive/valuable). */
function scoreCompetition(ratio: number | null): number {
  if (ratio === null) return 50; // unknown — neutral
  // Competition ratio: lower ratio = better for applicant
  // 1:1 = 100, 5:1 = 70, 10:1 = 50, 50:1 = 20, 100+:1 = 5
  if (ratio <= 1) return 100;
  if (ratio <= 5) return Math.round(100 - (ratio - 1) * 7.5);
  if (ratio <= 10) return Math.round(70 - (ratio - 5) * 4);
  if (ratio <= 50) return Math.round(50 - (ratio - 10) * 0.75);
  return Math.max(5, Math.round(20 - (ratio - 50) * 0.3));
}

function scorePriceValue(announcementPrice: number | null, marketPrice: number | null): number {
  if (!announcementPrice || !marketPrice) return 50;
  const discount = (marketPrice - announcementPrice) / marketPrice;
  // 30%+ discount = 100, 15% = 70, 0% = 40, negative = 10
  if (discount >= 0.3) return 100;
  if (discount >= 0.15) return Math.round(70 + ((discount - 0.15) / 0.15) * 30);
  if (discount >= 0) return Math.round(40 + (discount / 0.15) * 30);
  return Math.max(10, Math.round(40 + discount * 200));
}

function scoreLiquidity(txCount90d: number | null): number {
  if (txCount90d === null) return 50;
  // 100+ transactions in 90 days = highly liquid
  if (txCount90d >= 100) return 100;
  if (txCount90d >= 50) return Math.round(70 + ((txCount90d - 50) / 50) * 30);
  if (txCount90d >= 10) return Math.round(40 + ((txCount90d - 10) / 40) * 30);
  return Math.max(10, Math.round(txCount90d * 3));
}

export async function computeAndStoreScores(input: ScoreInput): Promise<void> {
  const comp = scoreCompetition(input.competitionRatioHistory);
  const priceVal = scorePriceValue(input.announcementPriceWon, input.nearbyMarketPriceWon);
  const liquidity = scoreLiquidity(input.nearbyTransactionCount90d);
  // Weighted: competition 30%, price-value 50%, liquidity 20%
  const composite = Math.round(comp * 0.3 + priceVal * 0.5 + liquidity * 0.2);

  for (const [scoreType, value] of [
    ["COMPETITION", comp], ["PRICE_VALUE", priceVal],
    ["LIQUIDITY", liquidity], ["COMPOSITE", composite],
  ] as const) {
    await db
      .insert(announcementScore)
      .values({ announcementId: input.announcementId, scoreType, score: value })
      .onConflictDoUpdate({
        target: [announcementScore.announcementId, announcementScore.scoreType],
        set: { score: value, updatedAt: new Date() },
      });
  }
}
```

- [ ] **Step 6: Vitest — scorer unit tests**

```typescript
// src/matching/__tests__/scorer.test.ts
import { describe, it, expect } from "vitest";
import { scoreCompetition, scorePriceValue, scoreLiquidity } from "../scorer";
// Export internal helpers for testing (or re-test via computeAndStoreScores with DB mock)

it("low competition ratio scores high", () => {
  expect(scoreCompetition(1)).toBe(100);
  expect(scoreCompetition(50)).toBeLessThan(30);
});

it("large discount scores high price value", () => {
  expect(scorePriceValue(700_000_000, 1_000_000_000)).toBeGreaterThan(90); // 30% discount
  expect(scorePriceValue(1_000_000_000, 1_000_000_000)).toBe(40); // no discount
});

it("high transaction count scores high liquidity", () => {
  expect(scoreLiquidity(150)).toBe(100);
  expect(scoreLiquidity(0)).toBe(10);
});
```

> Note: export `scoreCompetition`, `scorePriceValue`, `scoreLiquidity` as named exports from `scorer.ts` to allow direct unit testing.

- [ ] **Step 7: Match runner + upsert**

```typescript
// src/matching/run-matching.ts
import { db } from "@/db/client";
import { household, match, lookupTable } from "@/db/schema";
import {
  loadHouseholdSnapshot, loadActivePolicies, loadOpenAnnouncements,
  buildLookupResolver, evaluateHouseholdAgainstAnnouncement,
} from "./matcher";
import { computeAndStoreScores } from "./scorer";

export async function runMatchingForAllHouseholds(): Promise<void> {
  const households = await db.select().from(household);
  const allLookups = await db.select().from(lookupTable);
  const lookupResolver = buildLookupResolver(allLookups);
  const policies = await loadActivePolicies();

  for (const hh of households) {
    const snap = await loadHouseholdSnapshot(hh.householdId);
    for (const pol of policies) {
      const announcements = await loadOpenAnnouncements(pol.policyId);
      for (const ann of announcements) {
        const candidate = await evaluateHouseholdAgainstAnnouncement(snap, pol, ann, lookupResolver);
        await db
          .insert(match)
          .values({
            householdId: hh.householdId,
            announcementId: ann.announcementId,
            isEligible: candidate.eligible,
            failedRules: candidate.failedRules,
            failureReasons: candidate.failureReasons,
            matchedAt: new Date(),
          })
          .onConflictDoUpdate({
            target: [match.householdId, match.announcementId],
            set: {
              isEligible: candidate.eligible,
              failedRules: candidate.failedRules,
              failureReasons: candidate.failureReasons,
              matchedAt: new Date(),
            },
          });

        // Scoring inputs — fetch from supply breakdown + real-price API cache
        // nearbyMarketPriceWon and nearbyTransactionCount90d are populated
        // by the T5 real-estate price API client (announcement.nearbyMarketPrice)
        if (candidate.eligible && ann.status === "OPEN") {
          const breakdown = await db
            .select()
            .from(announcementSupplyBreakdown)
            .where(eq(announcementSupplyBreakdown.announcementId, ann.announcementId))
            .limit(1);
          await computeAndStoreScores({
            announcementId: ann.announcementId,
            competitionRatioHistory: breakdown[0]?.competitionRatioHistory ?? null,
            totalUnits: breakdown[0]?.totalUnits ?? null,
            announcementPriceWon: (ann.metadata as any)?.priceWon ?? null,
            nearbyMarketPriceWon: (ann.metadata as any)?.nearbyMarketPriceWon ?? null,
            nearbyTransactionCount90d: (ann.metadata as any)?.nearbyTx90d ?? null,
          });
        }
      }
    }
  }
}
```

- [ ] **Step 8: Match worker + cron**

```typescript
// src/workers/match-worker.ts
import { runMatchingForAllHouseholds } from "@/matching/run-matching";

export async function run(): Promise<void> {
  console.log("[match-worker] Running matching sweep...");
  await runMatchingForAllHouseholds();
  console.log("[match-worker] Matching complete.");
}
```

```typescript
// scripts/run-cron.ts — add match worker
import { run as runMatchWorker } from "../src/workers/match-worker";

// Run matching 30 min after each crawl (after PDF sweep finishes)
cron.schedule("0 */6 * * *", () => runMatchWorker().catch(console.error));
```

- [ ] **Step 9: Home dashboard page**

```tsx
// src/app/page.tsx
import { redirect } from "next/navigation";
import { db } from "@/db/client";
import { household, match, announcement, policy, announcementScore } from "@/db/schema";
import { eq, and, desc } from "drizzle-orm";
import { MatchCard } from "@/components/MatchCard";
import { PolicyStatusCard } from "@/components/PolicyStatusCard";

// Phase A: single household, userId=1
async function getHouseholdId(): Promise<number | null> {
  const [hh] = await db.select({ id: household.householdId })
    .from(household).where(eq(household.userId, 1)).limit(1);
  return hh?.id ?? null;
}

export default async function HomePage() {
  const householdId = await getHouseholdId();
  if (!householdId) redirect("/onboarding");

  const matches = await db
    .select({
      matchId: match.matchId,
      announcementId: announcement.announcementId,
      title: announcement.title,
      policyName: policy.name,
      applyStart: announcement.applyStart,
      applyEnd: announcement.applyEnd,
      compositeScore: announcementScore.score,
      llmSummary: announcement.llmSummary,
    })
    .from(match)
    .innerJoin(announcement, eq(match.announcementId, announcement.announcementId))
    .innerJoin(policy, eq(announcement.policyId, policy.policyId))
    .leftJoin(
      announcementScore,
      and(
        eq(announcementScore.announcementId, announcement.announcementId),
        eq(announcementScore.scoreType, "COMPOSITE")
      )
    )
    .where(and(eq(match.householdId, householdId), eq(match.isEligible, true)))
    .orderBy(desc(announcementScore.score))
    .limit(20);

  return (
    <main className="container mx-auto px-4 py-8 space-y-6">
      <PolicyStatusCard />
      <section>
        <h2 className="text-2xl font-bold mb-4">내 맞춤 공고 ({matches.length}건)</h2>
        <div className="grid gap-4">
          {matches.map((m) => (
            <MatchCard key={m.matchId} match={m} />
          ))}
          {matches.length === 0 && (
            <p className="text-muted-foreground">현재 조건에 맞는 공고가 없습니다. 프로필을 확인해 주세요.</p>
          )}
        </div>
      </section>
    </main>
  );
}
```

- [ ] **Step 10: MatchCard + match detail page stubs**

```tsx
// src/components/MatchCard.tsx
import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface Props {
  match: {
    matchId: number;
    announcementId: number;
    title: string;
    policyName: string;
    applyStart: Date | null;
    applyEnd: Date | null;
    compositeScore: number | null;
    llmSummary: string | null;
  };
}

export function MatchCard({ match: m }: Props) {
  const score = m.compositeScore ?? null;
  const endDate = m.applyEnd ? new Date(m.applyEnd).toLocaleDateString("ko-KR") : "미정";
  return (
    <Card className="hover:shadow-md transition-shadow">
      <CardHeader className="pb-2">
        <div className="flex items-start justify-between gap-2">
          <CardTitle className="text-base leading-snug">{m.title}</CardTitle>
          {score !== null && (
            <Badge variant={score >= 70 ? "default" : score >= 40 ? "secondary" : "outline"}>
              {score}점
            </Badge>
          )}
        </div>
        <p className="text-sm text-muted-foreground">{m.policyName}</p>
      </CardHeader>
      <CardContent className="space-y-2">
        {m.llmSummary && <p className="text-sm line-clamp-2">{m.llmSummary}</p>}
        <p className="text-xs text-muted-foreground">신청 마감: {endDate}</p>
        <Link href={`/match/${m.announcementId}`} className="text-sm text-primary underline">
          상세 보기 →
        </Link>
      </CardContent>
    </Card>
  );
}
```

```tsx
// src/app/match/[id]/page.tsx — detail stub (T9 supply panel added in T9 task)
import { db } from "@/db/client";
import { announcement, policy, announcementScore, match } from "@/db/schema";
import { eq, and } from "drizzle-orm";
import { notFound } from "next/navigation";

export default async function MatchDetailPage({ params }: { params: { id: string } }) {
  const announcementId = parseInt(params.id, 10);
  const [ann] = await db.select().from(announcement)
    .where(eq(announcement.announcementId, announcementId));
  if (!ann) notFound();

  const [pol] = await db.select().from(policy).where(eq(policy.policyId, ann.policyId));
  const scores = await db.select().from(announcementScore)
    .where(eq(announcementScore.announcementId, announcementId));

  const scoreMap = Object.fromEntries(scores.map((s) => [s.scoreType, s.score]));

  return (
    <main className="container mx-auto px-4 py-8 space-y-6">
      <h1 className="text-2xl font-bold">{ann.title}</h1>
      <p className="text-muted-foreground">{pol?.name}</p>

      {ann.llmSummary && (
        <section>
          <h2 className="font-semibold mb-1">AI 요약</h2>
          <p className="text-sm">{ann.llmSummary}</p>
        </section>
      )}

      <section className="grid grid-cols-3 gap-3">
        {(["COMPETITION", "PRICE_VALUE", "LIQUIDITY", "COMPOSITE"] as const).map((t) => (
          <div key={t} className="border rounded-lg p-3 text-center">
            <p className="text-xs text-muted-foreground">
              {{ COMPETITION: "경쟁률", PRICE_VALUE: "시세 대비", LIQUIDITY: "유동성", COMPOSITE: "종합" }[t]}
            </p>
            <p className="text-2xl font-bold">{scoreMap[t] ?? "—"}</p>
          </div>
        ))}
      </section>

      {/* Supply panel placeholder — filled by T9 */}
      <div id="supply-panel-slot" />

      {ann.pdfUrl && (
        <section>
          <a href={ann.pdfUrl} target="_blank" rel="noopener noreferrer"
            className="text-primary underline text-sm">
            원문 PDF 다운로드 →
          </a>
        </section>
      )}
    </main>
  );
}
```

- [ ] **Step 11: Commit**

```bash
git add .
git commit -m "feat(matching): matching engine + competition/price/liquidity scorer + home dashboard + match detail (T8)"
```

---

### Task T9: Supply Structure Analysis Panel

**Scope:** Render the supply-structure breakdown (공급 구조 분석) from `announcement_supply_breakdown` on the match detail page. Include lane guide (어떤 청약 유형에서 기회가 있나), breakdown chart (type × units table), competition ratio history badge, and a plain-Korean "Lane Entry Guide" narrative generated by the LLM from supply data.

**Files created/modified:**
- `src/components/SupplyPanel.tsx`
- `src/components/SupplyLaneGuide.tsx`
- `src/app/match/[id]/page.tsx` (inject supply panel)
- `src/data/supply-breakdown.ts` (add `getSupplyBreakdown`)
- `src/pipeline/supply-narrative.ts` (LLM mini-prompt for lane guide)

---

- [ ] **Step 1: Supply breakdown reader**

```typescript
// src/data/supply-breakdown.ts (add to existing file)
import { announcementSupplyBreakdown } from "@/db/schema";
import { eq } from "drizzle-orm";

export async function getSupplyBreakdown(announcementId: number) {
  const [row] = await db
    .select()
    .from(announcementSupplyBreakdown)
    .where(eq(announcementSupplyBreakdown.announcementId, announcementId));
  return row ?? null;
}
```

- [ ] **Step 2: LLM supply lane narrative (Claude Sonnet 4.6, short prompt)**

```typescript
// src/pipeline/supply-narrative.ts
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic();

export interface SupplyNarrativeInput {
  policyName: string;
  announcementTitle: string;
  totalUnits: number | null;
  specialSupply: number | null;
  generalSupply: number | null;
  lotteryUnits: number | null;
  priorityUnits: number | null;
  waitlistUnits: number | null;
  breakdownByType: Record<string, number>;
  competitionRatioHistory: number | null;
  householdType: string;
  isFirsthomeBuyer: boolean;
  isNewlywed: boolean;
  hasNewborn: boolean;
}

/**
 * Generate a short Korean lane-entry narrative explaining which supply lanes
 * this household can realistically enter (특별공급/일반공급/추첨제/무순위).
 */
export async function generateSupplyNarrative(input: SupplyNarrativeInput): Promise<string> {
  const breakdown = Object.entries(input.breakdownByType)
    .map(([type, units]) => `${type}: ${units}세대`)
    .join(", ");

  const prompt = `주택 공급 구조 분석을 해주세요.

공고: ${input.announcementTitle} (${input.policyName})
총 공급: ${input.totalUnits ?? "미확인"}세대
- 특별공급: ${input.specialSupply ?? 0}세대
- 일반공급: ${input.generalSupply ?? 0}세대
- 추첨제: ${input.lotteryUnits ?? 0}세대
- 우선공급: ${input.priorityUnits ?? 0}세대
- 무순위/줍줍: ${input.waitlistUnits ?? 0}세대
- 면적별: ${breakdown || "정보 없음"}
- 직전 경쟁률: ${input.competitionRatioHistory ? `${input.competitionRatioHistory}:1` : "미확인"}

신청자 정보:
- 가구유형: ${input.householdType}
- 생애최초: ${input.isFirsthomeBuyer ? "예" : "아니오"}
- 신혼부부: ${input.isNewlywed ? "예" : "아니오"}
- 신생아 특례: ${input.hasNewborn ? "해당" : "해당없음"}

위 신청자가 어떤 공급 유형(특별공급/일반공급/추첨제/무순위)에서 진입 기회가 있는지 3-4문장으로 간결하게 한국어로 설명해주세요. 숫자와 근거를 포함하세요.`;

  const response = await client.messages.create({
    model: "claude-sonnet-4-6",
    max_tokens: 512,
    messages: [{ role: "user", content: prompt }],
  });
  return (response.content[0] as { type: "text"; text: string }).text.trim();
}
```

- [ ] **Step 3: Supply panel component**

```tsx
// src/components/SupplyPanel.tsx
import { Badge } from "@/components/ui/badge";

interface Props {
  totalUnits: number | null;
  specialSupply: number | null;
  generalSupply: number | null;
  lotteryUnits: number | null;
  priorityUnits: number | null;
  waitlistUnits: number | null;
  breakdownByType: Record<string, number>;
  competitionRatioHistory: number | null;
  laneNarrative: string | null;
}

export function SupplyPanel({
  totalUnits, specialSupply, generalSupply,
  lotteryUnits, priorityUnits, waitlistUnits,
  breakdownByType, competitionRatioHistory, laneNarrative,
}: Props) {
  const rows = [
    { label: "특별공급", value: specialSupply, desc: "신혼·다자녀·생애최초·국가유공자 등" },
    { label: "일반공급 (우선)", value: priorityUnits, desc: "청약 가점 우선 순위" },
    { label: "추첨제", value: lotteryUnits, desc: "가점 무관 추첨" },
    { label: "무순위/줍줍", value: waitlistUnits, desc: "당첨 취소 물량, 자격 완화" },
  ];
  return (
    <section className="space-y-4">
      <h2 className="font-semibold">공급 구조 분석</h2>
      {competitionRatioHistory !== null && (
        <Badge variant="outline">직전 경쟁률 {competitionRatioHistory}:1</Badge>
      )}
      <p className="text-sm text-muted-foreground">총 {totalUnits ?? "?"} 세대</p>

      <table className="w-full text-sm border-collapse">
        <thead>
          <tr className="border-b">
            <th className="text-left py-1 font-medium">유형</th>
            <th className="text-right py-1 font-medium">세대</th>
            <th className="text-left py-1 font-medium pl-4">대상</th>
          </tr>
        </thead>
        <tbody>
          {rows.map(({ label, value, desc }) => (
            <tr key={label} className="border-b last:border-0">
              <td className="py-1.5 font-medium">{label}</td>
              <td className="py-1.5 text-right">{value ?? "—"}</td>
              <td className="py-1.5 pl-4 text-muted-foreground">{desc}</td>
            </tr>
          ))}
        </tbody>
      </table>

      {Object.keys(breakdownByType).length > 0 && (
        <div>
          <p className="text-xs font-medium text-muted-foreground mb-1">면적별 배분</p>
          <div className="flex flex-wrap gap-2">
            {Object.entries(breakdownByType).map(([type, units]) => (
              <Badge key={type} variant="secondary">{type}: {units}세대</Badge>
            ))}
          </div>
        </div>
      )}

      {laneNarrative && (
        <div className="bg-muted/40 rounded-lg p-3">
          <p className="text-xs font-semibold mb-1 text-muted-foreground">AI 진입 레인 가이드</p>
          <p className="text-sm leading-relaxed">{laneNarrative}</p>
        </div>
      )}
    </section>
  );
}
```

- [ ] **Step 4: Inject supply panel into match detail page**

```tsx
// src/app/match/[id]/page.tsx — add supply panel (replace `<div id="supply-panel-slot" />`)
import { getSupplyBreakdown } from "@/data/supply-breakdown";
import { generateSupplyNarrative } from "@/pipeline/supply-narrative";
import { SupplyPanel } from "@/components/SupplyPanel";

// Inside the page component, after loading scores:
const breakdown = await getSupplyBreakdown(announcementId);
const laneNarrative = breakdown && hh
  ? await generateSupplyNarrative({
      policyName: pol?.name ?? "",
      announcementTitle: ann.title,
      totalUnits: breakdown.totalUnits,
      specialSupply: breakdown.specialSupply,
      generalSupply: breakdown.generalSupply,
      lotteryUnits: breakdown.lotteryUnits,
      priorityUnits: breakdown.priorityUnits,
      waitlistUnits: breakdown.waitlistUnits,
      breakdownByType: breakdown.breakdownByType as Record<string, number>,
      competitionRatioHistory: breakdown.competitionRatioHistory,
      householdType: hh.householdType,
      isFirsthomeBuyer: primary?.isFirsthomeBuyer ?? false,
      isNewlywed: primary?.isMarried ?? false,
      hasNewborn: children.some((c) => {
        const age = (Date.now() - new Date(c.birthDate).getTime()) / (365.25 * 24 * 3600 * 1000);
        return age <= 2;
      }),
    })
  : null;

// Replace `<div id="supply-panel-slot" />` with:
{breakdown && (
  <SupplyPanel
    totalUnits={breakdown.totalUnits}
    specialSupply={breakdown.specialSupply}
    generalSupply={breakdown.generalSupply}
    lotteryUnits={breakdown.lotteryUnits}
    priorityUnits={breakdown.priorityUnits}
    waitlistUnits={breakdown.waitlistUnits}
    breakdownByType={breakdown.breakdownByType as Record<string, number>}
    competitionRatioHistory={breakdown.competitionRatioHistory}
    laneNarrative={laneNarrative}
  />
)}
```

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "feat(supply): supply structure panel + LLM lane narrative on match detail (T9)"
```

---

## Wave 4 — Parallel (3 subagents OK)

> **Pre-condition:** Wave 3 merged to `main`. T10 needs match rows + announcement dates. T11 needs rule change proposals. T12 needs all services running. Safe to run concurrently.

---

### Task T10: Web Push (VAPID) + Google Calendar Integration

**Scope:** Subscribe the browser to Web Push, send push on new eligible matches, send digest at user's digest time, add a Google Calendar multi-day event per announcement (applyStart→applyEnd), and implement service worker for push handling.

**Files created/modified:**
- `src/app/sw.ts` (service worker — push handler)
- `src/app/manifest.ts` (PWA manifest)
- `src/app/layout.tsx` (push subscription bootstrap)
- `src/app/api/push/subscribe/route.ts`
- `src/app/api/push/send/route.ts`
- `src/app/api/calendar/add/route.ts`
- `src/lib/push.ts`
- `src/lib/calendar.ts`
- `src/workers/notify-worker.ts`
- `scripts/run-cron.ts` (add notify worker)
- Tests: `src/lib/__tests__/push.test.ts`

---

- [ ] **Step 1: VAPID key generation script**

```bash
# scripts/generate-vapid.sh
#!/bin/bash
set -e
KEYS=$(node -e "
const webpush = require('web-push');
const k = webpush.generateVAPIDKeys();
console.log('NEXT_PUBLIC_VAPID_PUBLIC_KEY=' + k.publicKey);
console.log('VAPID_PRIVATE_KEY=' + k.privateKey);
")
echo "$KEYS"
echo ""
echo "Add the above lines to .env.local"
```

- [ ] **Step 2: Web Push server library**

```typescript
// src/lib/push.ts
import webpush, { type PushSubscription } from "web-push";
import { db } from "@/db/client";
import { userSettings, notificationLog } from "@/db/schema";
import { eq } from "drizzle-orm";

webpush.setVapidDetails(
  "mailto:admin@housing-app.local",
  process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY!,
  process.env.VAPID_PRIVATE_KEY!
);

export interface PushPayload {
  title: string;
  body: string;
  url: string;
  tag: string;  // dedupe key — prevents duplicate notifications
}

export async function sendPushToHousehold(
  householdId: number,
  payload: PushPayload
): Promise<void> {
  const [settings] = await db
    .select()
    .from(userSettings)
    .where(eq(userSettings.householdId, householdId));
  if (!settings?.pushSubscription) return;

  // Quiet hours check
  if (settings.quietHoursStart != null && settings.quietHoursEnd != null) {
    const hour = new Date().getHours();
    const { quietHoursStart: start, quietHoursEnd: end } = settings;
    const inQuiet = start < end
      ? hour >= start && hour < end
      : hour >= start || hour < end;
    if (inQuiet) return;
  }

  const subscription = settings.pushSubscription as PushSubscription;
  try {
    await webpush.sendNotification(subscription, JSON.stringify(payload));
    await db.insert(notificationLog).values({
      householdId,
      channel: "PUSH",
      payload,
      status: "SENT",
      sentAt: new Date(),
    });
  } catch (err: any) {
    await db.insert(notificationLog).values({
      householdId,
      channel: "PUSH",
      payload,
      status: "FAILED",
      errorMessage: String(err?.message ?? err),
      sentAt: new Date(),
    });
  }
}
```

- [ ] **Step 3: Push subscription API route**

```typescript
// src/app/api/push/subscribe/route.ts
import { NextResponse } from "next/server";
import { db } from "@/db/client";
import { userSettings, household } from "@/db/schema";
import { eq } from "drizzle-orm";

export async function POST(req: Request) {
  const subscription = await req.json();
  const [hh] = await db.select({ id: household.householdId })
    .from(household).where(eq(household.userId, 1)).limit(1);
  if (!hh) return NextResponse.json({ error: "no household" }, { status: 404 });

  await db
    .update(userSettings)
    .set({ pushSubscription: subscription })
    .where(eq(userSettings.householdId, hh.id));

  return NextResponse.json({ ok: true });
}
```

- [ ] **Step 4: Service worker (push handler)**

```typescript
// src/app/sw.ts
// This file is processed by next-pwa / custom SW build — must be plain TS/JS
declare const self: ServiceWorkerGlobalScope;

self.addEventListener("push", (event) => {
  const data = event.data?.json() as {
    title: string; body: string; url: string; tag: string;
  };
  event.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      tag: data.tag,
      data: { url: data.url },
      icon: "/icons/icon-192x192.png",
    })
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const url = event.notification.data?.url ?? "/";
  event.waitUntil(
    self.clients.matchAll({ type: "window" }).then((clients) => {
      for (const client of clients) {
        if (client.url === url && "focus" in client) return client.focus();
      }
      return self.clients.openWindow(url);
    })
  );
});
```

- [ ] **Step 5: PWA manifest**

```typescript
// src/app/manifest.ts
import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "주거혜택 알리미",
    short_name: "주거혜택",
    description: "정부 주거 혜택 알림 서비스",
    start_url: "/",
    display: "standalone",
    background_color: "#ffffff",
    theme_color: "#18181b",
    icons: [
      { src: "/icons/icon-192x192.png", sizes: "192x192", type: "image/png" },
      { src: "/icons/icon-512x512.png", sizes: "512x512", type: "image/png" },
    ],
  };
}
```

> Create placeholder PNG icons at `public/icons/icon-192x192.png` and `public/icons/icon-512x512.png` (any 192×192 and 512×512 PNG).

- [ ] **Step 6: Google Calendar integration**

```typescript
// src/lib/calendar.ts
import { google } from "googleapis";

const SCOPES = ["https://www.googleapis.com/auth/calendar.events"];

function buildAuth() {
  return new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    process.env.GOOGLE_REDIRECT_URI
  );
}

export async function addAnnouncementToCalendar(input: {
  accessToken: string;
  title: string;
  description: string;
  applyStart: Date;
  applyEnd: Date;
  announcementUrl: string;
}): Promise<string | null> {
  const auth = buildAuth();
  auth.setCredentials({ access_token: input.accessToken });
  const cal = google.calendar({ version: "v3", auth });

  const event = await cal.events.insert({
    calendarId: "primary",
    requestBody: {
      summary: `📋 ${input.title}`,
      description: `${input.description}\n\n원문: ${input.announcementUrl}`,
      start: { date: input.applyStart.toISOString().split("T")[0] },
      end: { date: input.applyEnd.toISOString().split("T")[0] },
      colorId: "9", // Blueberry
    },
  });
  return event.data.id ?? null;
}
```

- [ ] **Step 7: Calendar API route**

```typescript
// src/app/api/calendar/add/route.ts
import { NextResponse } from "next/server";
import { db } from "@/db/client";
import { announcement, userSettings, household } from "@/db/schema";
import { eq } from "drizzle-orm";
import { addAnnouncementToCalendar } from "@/lib/calendar";

export async function POST(req: Request) {
  const { announcementId } = await req.json();
  const [ann] = await db.select().from(announcement)
    .where(eq(announcement.announcementId, announcementId));
  if (!ann) return NextResponse.json({ error: "not found" }, { status: 404 });

  const [hh] = await db.select({ id: household.householdId })
    .from(household).where(eq(household.userId, 1)).limit(1);
  const [settings] = await db.select().from(userSettings)
    .where(eq(userSettings.householdId, hh!.id));
  if (!settings?.googleAccessToken) {
    return NextResponse.json({ error: "google_not_connected" }, { status: 400 });
  }

  if (!ann.applyStart || !ann.applyEnd) {
    return NextResponse.json({ error: "no_dates" }, { status: 400 });
  }

  const eventId = await addAnnouncementToCalendar({
    accessToken: settings.googleAccessToken,
    title: ann.title,
    description: ann.llmSummary ?? "",
    applyStart: new Date(ann.applyStart),
    applyEnd: new Date(ann.applyEnd),
    announcementUrl: ann.applyUrl ?? ann.pdfUrl ?? "",
  });
  return NextResponse.json({ ok: true, eventId });
}
```

- [ ] **Step 8: Notify worker (new-match push + deadline reminder push)**

```typescript
// src/workers/notify-worker.ts
import { db } from "@/db/client";
import { match, announcement, policy, notificationLog } from "@/db/schema";
import { eq, and, gt, isNull, lte } from "drizzle-orm";
import { sendPushToHousehold } from "@/lib/push";

const DEADLINE_DAYS = 3; // push when ≤3 days to applyEnd

export async function run(): Promise<void> {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  // 1. New eligible matches not yet notified
  const newMatches = await db
    .select({ matchId: match.matchId, householdId: match.householdId,
               announcementId: announcement.announcementId,
               title: announcement.title, policyName: policy.name })
    .from(match)
    .innerJoin(announcement, eq(match.announcementId, announcement.announcementId))
    .innerJoin(policy, eq(announcement.policyId, policy.policyId))
    .leftJoin(
      notificationLog,
      and(
        eq(notificationLog.householdId, match.householdId),
        eq(notificationLog.channel, "PUSH"),
        // tag-based dedup: `match-${announcementId}`
      )
    )
    .where(and(eq(match.isEligible, true), eq(announcement.status, "OPEN")));

  for (const m of newMatches) {
    const tag = `match-${m.announcementId}`;
    const alreadySent = await db.select().from(notificationLog)
      .where(and(
        eq(notificationLog.householdId, m.householdId),
        eq(notificationLog.channel, "PUSH"),
      )).limit(1);
    // Simple check: if no log with this tag in last 24h, send
    const sentRecently = alreadySent.some(
      (l) => JSON.stringify(l.payload).includes(tag) &&
             new Date(l.sentAt!).getTime() > Date.now() - 86400_000
    );
    if (!sentRecently) {
      await sendPushToHousehold(m.householdId, {
        title: "새 공고 매칭",
        body: `${m.policyName}: ${m.title}`,
        url: `/match/${m.announcementId}`,
        tag,
      });
    }
  }

  // 2. Deadline reminders (≤3 days to applyEnd)
  const deadlineSoon = await db
    .select({ householdId: match.householdId, announcementId: announcement.announcementId,
               title: announcement.title, applyEnd: announcement.applyEnd })
    .from(match)
    .innerJoin(announcement, eq(match.announcementId, announcement.announcementId))
    .where(and(
      eq(match.isEligible, true),
      eq(announcement.status, "OPEN"),
      lte(announcement.applyEnd, new Date(today.getTime() + DEADLINE_DAYS * 86400_000)),
      gt(announcement.applyEnd, today),
    ));

  for (const m of deadlineSoon) {
    const daysLeft = Math.ceil(
      (new Date(m.applyEnd!).getTime() - today.getTime()) / 86400_000
    );
    const tag = `deadline-${m.announcementId}-d${daysLeft}`;
    await sendPushToHousehold(m.householdId, {
      title: `마감 ${daysLeft}일 전`,
      body: m.title,
      url: `/match/${m.announcementId}`,
      tag,
    });
  }
}
```

- [ ] **Step 9: Wire notify worker into cron**

```typescript
// scripts/run-cron.ts — add notify worker
import { run as runNotifyWorker } from "../src/workers/notify-worker";

// Notify check every 4 hours (digest + deadline)
cron.schedule("0 */4 * * *", () => runNotifyWorker().catch(console.error));
```

- [ ] **Step 10: Push subscription bootstrap in layout**

```tsx
// src/app/layout.tsx — add PushBootstrap client component
// This registers the service worker and subscribes the browser to push
"use client";
import { useEffect } from "react";

export function PushBootstrap() {
  useEffect(() => {
    if (!("serviceWorker" in navigator) || !("PushManager" in window)) return;
    navigator.serviceWorker.register("/sw.js").then(async (reg) => {
      const existing = await reg.pushManager.getSubscription();
      if (existing) return; // already subscribed
      const sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY,
      });
      await fetch("/api/push/subscribe", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(sub),
      });
    });
  }, []);
  return null;
}
```

- [ ] **Step 11: Add calendar connect button to settings page stub**

```tsx
// src/app/settings/page.tsx (stub — full settings in T13)
import Link from "next/link";
export default function SettingsPage() {
  const calAuthUrl = `/api/auth/google?scope=calendar`;
  return (
    <main className="container mx-auto px-4 py-8">
      <h1 className="text-2xl font-bold mb-6">설정</h1>
      <section className="space-y-4">
        <div className="border rounded-lg p-4">
          <h2 className="font-semibold mb-2">Google Calendar 연동</h2>
          <a href={calAuthUrl} className="inline-flex items-center gap-2 text-sm text-primary underline">
            Google 계정 연결 →
          </a>
        </div>
      </section>
    </main>
  );
}
```

- [ ] **Step 12: Commit**

```bash
git add .
git commit -m "feat(notifications): VAPID web push + Google Calendar integration + notify worker (T10)"
```

---

### Task T11: Rule Change Proposal Queue (ACK UI)

**Scope:** Admin UI to review queued `rule_change_proposal` rows (status = non-auto-applied), approve/reject with one click. Approval triggers the same JSONB patch as auto-apply. Also surfaces macro policy change proposals (L3-B policy monitoring placeholder).

**Files created/modified:**
- `src/app/admin/proposals/page.tsx`
- `src/app/admin/proposals/[id]/approve/route.ts`
- `src/app/admin/proposals/[id]/reject/route.ts`
- `src/data/proposals.ts`
- `src/components/ProposalCard.tsx`

---

- [ ] **Step 1: Proposal data helpers**

```typescript
// src/data/proposals.ts
import { db } from "@/db/client";
import { ruleChangeProposal, policy } from "@/db/schema";
import { eq, isNull } from "drizzle-orm";

export async function getPendingProposals() {
  return db
    .select({
      proposalId: ruleChangeProposal.proposalId,
      policyName: policy.name,
      policyId: ruleChangeProposal.policyId,
      announcementId: ruleChangeProposal.announcementId,
      proposedChange: ruleChangeProposal.proposedChange,
      evidence: ruleChangeProposal.evidence,
      verificationStatus: ruleChangeProposal.verificationStatus,
      verificationSources: ruleChangeProposal.verificationSources,
      createdAt: ruleChangeProposal.createdAt,
    })
    .from(ruleChangeProposal)
    .innerJoin(policy, eq(ruleChangeProposal.policyId, policy.policyId))
    .where(isNull(ruleChangeProposal.autoApplied))  // not yet processed
    .orderBy(ruleChangeProposal.createdAt);
}

export async function approveProposal(proposalId: number): Promise<void> {
  const [proposal] = await db
    .select()
    .from(ruleChangeProposal)
    .where(eq(ruleChangeProposal.proposalId, proposalId));
  if (!proposal) throw new Error("Proposal not found");
  const change = proposal.proposedChange as { field: string; operator: string; value: unknown };
  // Apply the JSONB patch (same logic as rule-change-applier.ts auto-apply path)
  await db.execute(
    `UPDATE policy
     SET eligibility_rules = (
       SELECT jsonb_agg(
         CASE WHEN r->>'field' = $1
           THEN r || jsonb_build_object('value', $2::text::jsonb)
           ELSE r
         END
       )
       FROM jsonb_array_elements(eligibility_rules) AS r
     ),
     updated_at = NOW()
     WHERE policy_id = $3`,
    [change.field, JSON.stringify(change.value), proposal.policyId]
  );
  await db
    .update(ruleChangeProposal)
    .set({ autoApplied: true, appliedAt: new Date() })
    .where(eq(ruleChangeProposal.proposalId, proposalId));
}

export async function rejectProposal(proposalId: number): Promise<void> {
  await db
    .update(ruleChangeProposal)
    .set({ autoApplied: false, appliedAt: new Date() })
    .where(eq(ruleChangeProposal.proposalId, proposalId));
}
```

- [ ] **Step 2: ProposalCard component**

```tsx
// src/components/ProposalCard.tsx
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

const STATUS_COLOR: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  VERIFIED: "default",
  WEAK_VERIFIED: "secondary",
  AMBIGUOUS: "outline",
  UNVERIFIABLE: "destructive",
  NEW_RULE: "outline",
  DEPRECATE: "destructive",
};

interface Props {
  proposal: {
    proposalId: number;
    policyName: string;
    proposedChange: { field: string; operator: string; value: unknown; unit?: string };
    evidence: string;
    verificationStatus: string;
    verificationSources: Array<{ url: string; title: string; snippet: string }>;
    createdAt: Date;
  };
}

export function ProposalCard({ proposal: p }: Props) {
  return (
    <div className="border rounded-lg p-4 space-y-3">
      <div className="flex items-start justify-between gap-2">
        <div>
          <p className="font-semibold">{p.policyName}</p>
          <p className="text-sm text-muted-foreground">
            {p.proposedChange.field} {p.proposedChange.operator} {String(p.proposedChange.value)} {p.proposedChange.unit ?? ""}
          </p>
        </div>
        <Badge variant={STATUS_COLOR[p.verificationStatus] ?? "outline"}>
          {p.verificationStatus}
        </Badge>
      </div>

      <p className="text-sm bg-muted/40 rounded p-2 italic">"{p.evidence}"</p>

      {p.verificationSources.length > 0 && (
        <ul className="text-xs space-y-0.5">
          {p.verificationSources.map((s, i) => (
            <li key={i}>
              <a href={s.url} target="_blank" rel="noopener noreferrer"
                className="text-primary underline">{s.title}</a>
              <span className="text-muted-foreground ml-1">— {s.snippet}</span>
            </li>
          ))}
        </ul>
      )}

      <div className="flex gap-2">
        <form action={`/admin/proposals/${p.proposalId}/approve`} method="POST">
          <Button size="sm" type="submit">승인 적용</Button>
        </form>
        <form action={`/admin/proposals/${p.proposalId}/reject`} method="POST">
          <Button size="sm" variant="outline" type="submit">거부</Button>
        </form>
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Proposals admin page**

```tsx
// src/app/admin/proposals/page.tsx
import { getPendingProposals } from "@/data/proposals";
import { ProposalCard } from "@/components/ProposalCard";

export default async function ProposalsPage() {
  const proposals = await getPendingProposals();
  return (
    <main className="container mx-auto px-4 py-8 space-y-4">
      <h1 className="text-2xl font-bold">규칙 변경 제안 검토 ({proposals.length}건)</h1>
      {proposals.length === 0 && (
        <p className="text-muted-foreground">검토 대기 중인 제안이 없습니다.</p>
      )}
      <div className="space-y-3">
        {proposals.map((p) => <ProposalCard key={p.proposalId} proposal={p as any} />)}
      </div>
    </main>
  );
}
```

- [ ] **Step 4: Approve / Reject API routes**

```typescript
// src/app/admin/proposals/[id]/approve/route.ts
import { NextResponse } from "next/server";
import { approveProposal } from "@/data/proposals";

export async function POST(_req: Request, { params }: { params: { id: string } }) {
  await approveProposal(parseInt(params.id, 10));
  return NextResponse.redirect(new URL("/admin/proposals", process.env.NEXT_PUBLIC_BASE_URL!));
}
```

```typescript
// src/app/admin/proposals/[id]/reject/route.ts
import { NextResponse } from "next/server";
import { rejectProposal } from "@/data/proposals";

export async function POST(_req: Request, { params }: { params: { id: string } }) {
  await rejectProposal(parseInt(params.id, 10));
  return NextResponse.redirect(new URL("/admin/proposals", process.env.NEXT_PUBLIC_BASE_URL!));
}
```

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "feat(admin): rule change proposal queue + one-click approve/reject (T11)"
```

---

### Task T12: Health Check + Telegram Alerts

**Scope:** Daily health check at 09:00 KST. Always sends a Telegram message (OK or ALERT — silence = healthcheck dead). Checks: DB connectivity, crawler errors in last 24h, stale proposals (>7 days unreviewed), LLM cost last 30 days, DB size, broken crawlers (0 announcements in 72h), failed PDF processing count.

**Files created/modified:**
- `scripts/healthcheck.ts`
- `src/lib/telegram.ts`
- `scripts/run-cron.ts` (add healthcheck job)
- Tests: `scripts/__tests__/healthcheck.test.ts`

---

- [ ] **Step 1: Telegram notifier**

```typescript
// src/lib/telegram.ts
const BASE = "https://api.telegram.org";

export async function sendTelegram(message: string): Promise<void> {
  const token = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_CHAT_ID;
  if (!token || !chatId) {
    console.warn("[telegram] TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set — skipping");
    return;
  }
  const res = await fetch(`${BASE}/bot${token}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: chatId, text: message, parse_mode: "HTML" }),
  });
  if (!res.ok) {
    console.error("[telegram] Send failed:", await res.text());
  }
}
```

- [ ] **Step 2: Health check report builder**

```typescript
// scripts/healthcheck.ts
import { db } from "@/db/client";
import {
  crawlerHealth, ruleChangeProposal, llmCostLog,
  announcement, notificationLog,
} from "@/db/schema";
import { sql, lt, gt, eq, and, sum } from "drizzle-orm";
import { sendTelegram } from "@/lib/telegram";

interface HealthReport {
  ok: boolean;
  dbConnected: boolean;
  crawlerErrors24h: number;
  staleProposals7d: number;
  llmCost30dUsd: number;
  dbSizeMb: number;
  brokenCrawlers: string[];   // sourceIds with 0 announces in 72h
  failedPdfs24h: number;
}

async function buildReport(now: Date): Promise<HealthReport> {
  let dbConnected = false;
  try {
    await db.execute(sql`SELECT 1`);
    dbConnected = true;
  } catch { /* dbConnected remains false */ }

  if (!dbConnected) {
    return { ok: false, dbConnected, crawlerErrors24h: 0, staleProposals7d: 0,
             llmCost30dUsd: 0, dbSizeMb: 0, brokenCrawlers: [], failedPdfs24h: 0 };
  }

  const since24h = new Date(now.getTime() - 86400_000);
  const since72h = new Date(now.getTime() - 3 * 86400_000);
  const since7d = new Date(now.getTime() - 7 * 86400_000);
  const since30d = new Date(now.getTime() - 30 * 86400_000);

  const [crawlerErrRow] = await db
    .select({ count: sql<number>`count(*)` })
    .from(crawlerHealth)
    .where(and(eq(crawlerHealth.status, "ERROR"), gt(crawlerHealth.checkedAt, since24h)));

  const [staleRow] = await db
    .select({ count: sql<number>`count(*)` })
    .from(ruleChangeProposal)
    .where(and(sql`auto_applied IS NULL`, lt(ruleChangeProposal.createdAt, since7d)));

  const [costRow] = await db
    .select({ total: sum(llmCostLog.estimatedCostUsd) })
    .from(llmCostLog)
    .where(gt(llmCostLog.createdAt, since30d));

  const [dbSizeRow] = await db.execute<{ size_mb: string }>(
    sql`SELECT round(pg_database_size(current_database()) / 1024.0 / 1024.0, 1) AS size_mb`
  );

  // Broken crawlers: sources that have had 0 new announcements in 72h
  const activeSources = await db
    .selectDistinct({ source: announcement.source })
    .from(announcement)
    .where(gt(announcement.createdAt, since72h));
  const allSources = (await db.selectDistinct({ source: announcement.source }).from(announcement))
    .map((r) => r.source);
  const activeSrcSet = new Set(activeSources.map((r) => r.source));
  const brokenCrawlers = allSources.filter((s) => !activeSrcSet.has(s));

  const [failedPdfRow] = await db
    .select({ count: sql<number>`count(*)` })
    .from(announcement)
    .where(and(
      eq(announcement.pdfTextMd, "__HWP_CONVERSION_FAILED__"),
      gt(announcement.updatedAt, since24h)
    ));

  const llmCost30dUsd = parseFloat(costRow?.total ?? "0");
  const crawlerErrors24h = Number(crawlerErrRow?.count ?? 0);
  const staleProposals7d = Number(staleRow?.count ?? 0);
  const dbSizeMb = parseFloat((dbSizeRow as any)?.size_mb ?? "0");
  const failedPdfs24h = Number(failedPdfRow?.count ?? 0);

  const ok = crawlerErrors24h === 0 && staleProposals7d === 0
    && brokenCrawlers.length === 0 && llmCost30dUsd < 50;

  return { ok, dbConnected, crawlerErrors24h, staleProposals7d, llmCost30dUsd,
           dbSizeMb, brokenCrawlers, failedPdfs24h };
}

function formatReport(r: HealthReport, now: Date): string {
  const status = r.ok ? "✅ OK" : "🚨 ALERT";
  const kstTime = now.toLocaleString("ko-KR", { timeZone: "Asia/Seoul" });
  const lines = [
    `<b>주거혜택 앱 헬스체크 ${status}</b>`,
    `시각: ${kstTime}`,
    `DB 연결: ${r.dbConnected ? "✅" : "❌"}`,
    `크롤러 오류(24h): ${r.crawlerErrors24h === 0 ? "✅ 0" : `❌ ${r.crawlerErrors24h}건`}`,
    `미검토 규칙 제안(7d↑): ${r.staleProposals7d === 0 ? "✅ 0" : `⚠️ ${r.staleProposals7d}건`}`,
    `LLM 비용(30d): $${r.llmCost30dUsd.toFixed(2)}${r.llmCost30dUsd >= 50 ? " ⚠️" : ""}`,
    `DB 크기: ${r.dbSizeMb}MB`,
    `HWP 변환 실패(24h): ${r.failedPdfs24h}건`,
  ];
  if (r.brokenCrawlers.length > 0) {
    lines.push(`❌ 비활성 크롤러(72h): ${r.brokenCrawlers.join(", ")}`);
  }
  return lines.join("\n");
}

export async function runHealthCheck(): Promise<void> {
  const now = new Date();
  const report = await buildReport(now);
  const message = formatReport(report, now);
  await sendTelegram(message);
  console.log("[healthcheck]", message);
}
```

- [ ] **Step 3: Wire healthcheck into cron**

```typescript
// scripts/run-cron.ts — add healthcheck
import { runHealthCheck } from "./healthcheck";

// Every day at 09:00 KST (= 00:00 UTC)
cron.schedule("0 0 * * *", () => runHealthCheck().catch(console.error));
```

- [ ] **Step 4: Vitest — health check unit test (DB-mocked)**

```typescript
// scripts/__tests__/healthcheck.test.ts
import { describe, it, expect, vi } from "vitest";

// Mock DB calls; test report formatting only
vi.mock("@/db/client", () => ({
  db: {
    execute: vi.fn().mockResolvedValue([{ size_mb: "42.5" }]),
    select: vi.fn().mockReturnThis(),
    selectDistinct: vi.fn().mockReturnThis(),
    from: vi.fn().mockReturnThis(),
    where: vi.fn().mockResolvedValue([{ count: 0 }]),
  },
}));

// Test the formatter directly by constructing a report
it("formats OK report correctly", () => {
  const { formatReport } = require("../healthcheck");
  const report = {
    ok: true, dbConnected: true, crawlerErrors24h: 0,
    staleProposals7d: 0, llmCost30dUsd: 1.23, dbSizeMb: 42.5,
    brokenCrawlers: [], failedPdfs24h: 0,
  };
  const msg = formatReport(report, new Date("2026-01-01T00:00:00Z"));
  expect(msg).toContain("✅ OK");
  expect(msg).toContain("$1.23");
});

it("flags ALERT when crawler errors exist", () => {
  const { formatReport } = require("../healthcheck");
  const report = {
    ok: false, dbConnected: true, crawlerErrors24h: 3,
    staleProposals7d: 0, llmCost30dUsd: 0, dbSizeMb: 10,
    brokenCrawlers: ["applyhome"], failedPdfs24h: 0,
  };
  const msg = formatReport(report, new Date("2026-01-01T00:00:00Z"));
  expect(msg).toContain("🚨 ALERT");
  expect(msg).toContain("applyhome");
});
```

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "feat(healthcheck): daily Telegram health report + OK/ALERT for all subsystems (T12)"
```

---

## Wave 5 — Final (sequential)

### Task T13: Security Hardening + Integration Verification

**Scope:** Apply the five security domains D1–D5 from spec §14. Verify the complete system runs end-to-end on local WSL before declaring Phase A.1 complete.

**Files created/modified (security):**
- `src/lib/encryption.ts` (D1 — AES-256-GCM column encryption)
- `src/lib/pii-guard.ts` (D3 — LLM PII wrapper, enhance existing guardPii)
- `next.config.mjs` (D5 — CSP + HSTS headers)
- `src/app/api/export/route.ts` (D4 — GDPR data export)
- `src/app/api/delete-account/route.ts` (D4 — data delete)
- `src/middleware.ts` (D2 — auth middleware placeholder)
- `src/db/schema.ts` (D1 — mark encrypted columns in comments)

---

- [ ] **Step 1: AES-256-GCM column encryption (D1)**

```typescript
// src/lib/encryption.ts
import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";

const KEY_HEX = process.env.DB_ENCRYPTION_KEY_HEX;

function getKey(): Buffer {
  if (!KEY_HEX || KEY_HEX.length !== 64) {
    throw new Error("DB_ENCRYPTION_KEY_HEX must be a 64-char hex string (32 bytes AES-256)");
  }
  return Buffer.from(KEY_HEX, "hex");
}

/**
 * Encrypt a string value for storage in DB.
 * Returns `iv:ciphertext` as base64, separated by colon.
 */
export function encryptColumn(plaintext: string): string {
  const key = getKey();
  const iv = randomBytes(12); // 96-bit IV for GCM
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const encrypted = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  // Format: base64(iv):base64(tag):base64(ciphertext)
  return `${iv.toString("base64")}:${tag.toString("base64")}:${encrypted.toString("base64")}`;
}

export function decryptColumn(stored: string): string {
  const [ivB64, tagB64, cipherB64] = stored.split(":");
  if (!ivB64 || !tagB64 || !cipherB64) throw new Error("Invalid encrypted column format");
  const key = getKey();
  const iv = Buffer.from(ivB64, "base64");
  const tag = Buffer.from(tagB64, "base64");
  const ciphertext = Buffer.from(cipherB64, "base64");
  const decipher = createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAuthTag(tag);
  return decipher.update(ciphertext) + decipher.final("utf8");
}
```

> **Encrypted columns (apply encrypt/decrypt in data access layer, not schema):**
> - `person.name` → encrypt on write, decrypt on read
> - `userSettings.googleAccessToken` → encrypt on write, decrypt on read
> - `userSettings.pushSubscription` → encrypt on write, decrypt on read

> To generate key: `openssl rand -hex 32` → paste in `.env.local` as `DB_ENCRYPTION_KEY_HEX`.

- [ ] **Step 2: Encrypt sensitive person columns in onboarding action**

```typescript
// src/app/onboarding/actions.ts — wrap name writes
import { encryptColumn, decryptColumn } from "@/lib/encryption";

// In submitOnboarding, before inserting person rows:
const encryptedName = encryptColumn(parsedInput.primaryName);
// Insert with encryptedName instead of plaintext name

// In any read path that returns person.name, decrypt:
const displayName = decryptColumn(person.name);
```

- [ ] **Step 3: Full PII guard for LLM (D3)**

```typescript
// src/lib/pii-guard.ts
const PII_PATTERNS: Array<[RegExp, string]> = [
  [/\d{6}-\d{7}/g, "[주민번호-REDACTED]"],
  [/01[016789]-?\d{3,4}-?\d{4}/g, "[전화번호-REDACTED]"],
  [/\d{3,4}-\d{4}-\d{4}-\d{4}/g, "[계좌번호-REDACTED]"],
  [/[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}/g, "[이메일-REDACTED]"],
  [/\d{4}-?\d{4}-?\d{4}-?\d{4}/g, "[카드번호-REDACTED]"],
];

/** Strip PII patterns from text before sending to LLM */
export function maskPii(text: string): string {
  let masked = text;
  for (const [pattern, replacement] of PII_PATTERNS) {
    masked = masked.replace(pattern, replacement);
  }
  return masked;
}
```

> Replace the inline `guardPii` in `llm-extractor.ts` with `import { maskPii } from "@/lib/pii-guard"`.

- [ ] **Step 4: Security HTTP headers (D5)**

```javascript
// next.config.mjs — add headers function
/** @type {import('next').NextConfig} */
const nextConfig = {
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "X-Frame-Options", value: "DENY" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          {
            key: "Content-Security-Policy",
            value: [
              "default-src 'self'",
              "script-src 'self' 'unsafe-inline'",  // unsafe-inline needed for Next.js inline scripts
              "style-src 'self' 'unsafe-inline'",
              "img-src 'self' data: https:",
              "connect-src 'self' https://api.anthropic.com https://api.openai.com",
              "frame-ancestors 'none'",
            ].join("; "),
          },
          {
            key: "Strict-Transport-Security",
            value: "max-age=63072000; includeSubDomains; preload",
          },
          { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
        ],
      },
    ];
  },
};
export default nextConfig;
```

- [ ] **Step 5: Auth middleware placeholder (D2)**

```typescript
// src/middleware.ts
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

// Phase A: single-user, no auth. Middleware exists as placeholder for Phase B.
// Protected paths that will require auth in Phase B:
const PROTECTED_PREFIXES = ["/admin", "/api/export", "/api/delete-account", "/api/calendar"];

export function middleware(req: NextRequest) {
  // Phase A: allow all. Phase B: check session cookie here.
  const { pathname } = req.nextUrl;
  if (PROTECTED_PREFIXES.some((p) => pathname.startsWith(p))) {
    // TODO Phase B: validate session. For now, pass through.
    return NextResponse.next();
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/admin/:path*", "/api/:path*"],
};
```

- [ ] **Step 6: GDPR data export route (D4)**

```typescript
// src/app/api/export/route.ts
import { NextResponse } from "next/server";
import { db } from "@/db/client";
import { household, person, child, householdEvent, match, userSettings } from "@/db/schema";
import { eq } from "drizzle-orm";
import { decryptColumn } from "@/lib/encryption";

export async function GET() {
  const [hh] = await db.select().from(household).where(eq(household.userId, 1)).limit(1);
  if (!hh) return NextResponse.json({ error: "no data" }, { status: 404 });

  const persons = await db.select().from(person).where(eq(person.householdId, hh.householdId));
  const children = await db.select().from(child).where(eq(child.householdId, hh.householdId));
  const events = await db.select().from(householdEvent).where(eq(householdEvent.householdId, hh.householdId));
  const matches = await db.select().from(match).where(eq(match.householdId, hh.householdId));
  const [settings] = await db.select().from(userSettings).where(eq(userSettings.householdId, hh.householdId));

  const exportData = {
    exportedAt: new Date().toISOString(),
    household: hh,
    persons: persons.map((p) => ({ ...p, name: decryptColumn(p.name) })),
    children,
    events,
    matches,
    settings: settings ? { ...settings, googleAccessToken: "[REDACTED]", pushSubscription: "[REDACTED]" } : null,
  };

  return new NextResponse(JSON.stringify(exportData, null, 2), {
    headers: {
      "Content-Type": "application/json",
      "Content-Disposition": `attachment; filename="housing-data-${Date.now()}.json"`,
    },
  });
}
```

- [ ] **Step 7: Data delete route (D4)**

```typescript
// src/app/api/delete-account/route.ts
import { NextResponse } from "next/server";
import { db } from "@/db/client";
import { household, person, child, householdEvent, match,
         userSettings, notificationLog } from "@/db/schema";
import { eq } from "drizzle-orm";

export async function DELETE() {
  const [hh] = await db.select({ id: household.householdId })
    .from(household).where(eq(household.userId, 1)).limit(1);
  if (!hh) return NextResponse.json({ error: "no data" }, { status: 404 });

  const id = hh.id;
  // Delete in dependency order (FK constraints)
  await db.delete(notificationLog).where(eq(notificationLog.householdId, id));
  await db.delete(match).where(eq(match.householdId, id));
  await db.delete(userSettings).where(eq(userSettings.householdId, id));
  await db.delete(householdEvent).where(eq(householdEvent.householdId, id));
  await db.delete(child).where(eq(child.householdId, id));
  await db.delete(person).where(eq(person.householdId, id));
  await db.delete(household).where(eq(household.householdId, id));

  return NextResponse.json({ ok: true, message: "모든 개인정보가 삭제되었습니다." });
}
```

- [ ] **Step 8: Integration smoke-test checklist**

Run the following manual steps on WSL Ubuntu to confirm Phase A.1 end-to-end:

```bash
# 1. Start services
cd ~/projects/housing-benefits-app
docker compose up -d
pnpm db:migrate
pnpm dev &

# 2. Onboarding (http://localhost:3000/onboarding)
#    - Complete 5-step wizard (single-person household)
#    - Verify household/person rows in DB:
psql $DATABASE_URL -c "SELECT * FROM household; SELECT name FROM person;"

# 3. Crawl test
pnpm tsx scripts/run-cron.ts --once crawl
#    - Verify announcement rows exist:
psql $DATABASE_URL -c "SELECT source, count(*) FROM announcement GROUP BY source;"

# 4. PDF sweep test (needs ≥1 announcement with pdfUrl)
pnpm tsx scripts/run-cron.ts --once pdf
#    - Verify pdfTextMd and llm_summary populated on ≥1 row

# 5. Matching test
pnpm tsx scripts/run-cron.ts --once match
#    - Verify match rows exist:
psql $DATABASE_URL -c "SELECT count(*) FROM match WHERE is_eligible = true;"

# 6. Home dashboard
#    - Open http://localhost:3000 in browser
#    - Confirm matched announcements appear with scores

# 7. Push test (requires ngrok for HTTPS)
ngrok http 3000
#    - Update NEXT_PUBLIC_BASE_URL in .env.local to ngrok URL
#    - Open ngrok URL, accept push permission, verify push arrives

# 8. Calendar test
#    - Connect Google in /settings
#    - Click "캘린더에 추가" on a match detail page
#    - Verify event appears in Google Calendar

# 9. Healthcheck test
pnpm tsx scripts/healthcheck.ts
#    - Verify Telegram message received

# 10. Run full test suite
pnpm test
#    - All Vitest tests must pass
```

- [ ] **Step 9: Fix placeholder defects from plan self-review**

The following defects were identified during plan writing and must be resolved before merging T13:

1. **T3 Step 10** referenced "Apply the same pattern for remaining step components." Each step component (`HousingHistoryStep`, `SpouseStep`, `ChildrenStep`, `PermissionsStep`) must be fully implemented following the same structure as `HouseholdTypeStep`, `PrimaryInfoStep`, and `IncomeAssetsStep` already written in the plan. No step should be a stub.

2. **T4 Step 10** (`computeFacts`) referenced "abbreviated for brevity — engineer must generate every field." The implementation file must contain all 107 computed fields listed in spec §10.2. Use spec §10.2 as the definitive source; implement every field in `compute-facts.ts`.

3. **T4 Step 12** referenced "engineer fills in fields matching spec." The initial `policy` seed rows must include complete `eligibility_rules` JSON for at minimum the three seed policies: 청년 버팀목 전세자금 대출, 신혼부부 버팀목 전세자금 대출, 국민임대주택.

4. **T5 Step 5** referenced "implement LH and realprice clients with same pattern." Implement concrete function signatures and test expectations for `LHClient.getPublicRentalAnnouncements()` and `RealPriceClient.getApartmentTransactions(regionCode, yearMonth)` in `src/data-sources/openapi/lh-client.ts` and `src/data-sources/openapi/realprice-client.ts` respectively.

- [ ] **Step 10: Final commit**

```bash
git add .
git commit -m "feat(security): AES-256-GCM encryption + PII guard + CSP headers + GDPR export/delete + auth middleware placeholder (T13)"
git tag -a v0.1.0-phase-a1 -m "Phase A.1 complete: local PWA with matching, push, calendar, healthcheck"
```

---

## Execution Options

This plan is ready for implementation. Choose your approach:

**Option A — Subagent-driven (recommended):**
Invoke `superpowers:subagent-driven-development` with this plan file. The skill dispatches Wave 1 sequentially, then launches Wave 2–4 as parallel subagents, and runs Wave 5 at the end. Maximum parallelism: 4 concurrent subagents during Wave 2, 3 during Waves 3 and 4.

**Option B — Inline sequential:**
Invoke `superpowers:executing-plans` and work through tasks T1→T13 one by one in a single session. Slower but simpler if subagent orchestration is unavailable.

**Working directory (WSL Ubuntu):**
```bash
cd ~/projects/   # create housing-benefits-app/ in T1
```

**First step:** Start with `superpowers:subagent-driven-development` or `superpowers:executing-plans`, point it at this file, and begin T1.


