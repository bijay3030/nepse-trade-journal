# NEPSE Trade Journal - Project Documentation

## 1. Project Overview
NEPSE Trade Journal is a full-stack trading workspace for Nepal stock market participants to plan trades, execute them, review outcomes, and improve decision quality over time.

It combines:
- Structured trade lifecycle tracking (`Plan -> Execute -> Result`)
- Journal-based behavioral feedback loops
- Portfolio and market monitoring
- Analytics for performance and discipline trends

## 2. Core Value Proposition
The product brings value in three layers:

- Execution quality: Enforces process before and after each trade so decisions are less emotional and more repeatable.
- Learning loop: Captures mistakes, mood, and lessons, then turns them into measurable patterns.
- Performance clarity: Centralized dashboard for P&L, win rate, expectancy, and portfolio behavior.

## 3. High-Level Architecture

### Backend
- Framework: Ruby on Rails (API mode)
- Auth: Devise + JWT
- DB: PostgreSQL
- Async jobs: ActiveJob (Sidekiq-ready)
- Real-time: ActionCable
- Serialization: ActiveModelSerializers

### Frontend
- Framework: React + TypeScript + Vite
- Data fetching: React Query
- Styling: Tailwind CSS
- State: Zustand (live market prices)
- Charts: Recharts
- Forms: React Hook Form
- PWA: `vite-plugin-pwa`

## 4. Implemented Features

### 4.1 Authentication & API Security
- JWT-based login/logout flow with Devise.
- API base controller validates token and resolves current user context.
- CORS configured for local frontend development.

Backend routes:
- `POST /login`
- `DELETE /logout`

### 4.2 Stock & Market Data
- Stock listing, filtering by sector, search, and symbol detail.
- Live/near-live price updates via WebSocket with polling fallback.
- Current prices endpoint supports optional refresh and symbol subset.

Backend routes:
- `GET /api/v1/stocks`
- `GET /api/v1/stocks/:id`
- `GET /api/v1/stocks/sectors`
- `GET /api/v1/stocks/current_prices`

Realtime endpoint:
- `GET /cable` (ActionCable, `StockPricesChannel`)

### 4.3 Trade Lifecycle Management
- Trade Plan creation and retrieval.
- Trade Execution creation linked to plan.
- Trade Result creation linked to execution.
- Automatic portfolio holding updates on execution/result.
- Soft delete and restore capability for plans.

Backend routes:
- `GET /api/v1/trade_plans`
- `POST /api/v1/trade_plans`
- `GET /api/v1/trade_plans/:id`
- `DELETE /api/v1/trade_plans/:id`
- `POST /api/v1/trade_plans/:trade_plan_id/trade_execution`
- `POST /api/v1/trade_executions/:trade_execution_id/trade_result`

Frontend pages:
- `/trade/new`
- `/trades`

### 4.4 Portfolio Management
- Portfolio value summary (total value, invested, total/day P&L).
- Holdings view with sorting, row expansion, quick buy/sell actions.
- Sector allocation chart with filter interaction.
- Cash position card and add-funds mock action.
- Local data resilience (safe localStorage parsing/fallback).

Frontend page:
- `/portfolio`

### 4.5 Analytics Dashboard
- KPI cards for performance indicators.
- Equity curve visualization.
- Strategy performance breakdown.
- Mistake frequency and emotional correlation charts.
- Date-range filtering.

Backend routes:
- `GET /api/v1/analytics/dashboard`
- `GET /api/v1/analytics/trade_statistics`

Frontend page:
- `/analytics`

### 4.6 Trading Journal
- Daily entry form with:
  - date,
  - market commentary,
  - emotional state,
  - discipline score,
  - plan vs taken trades,
  - lessons and next-day plan.
- List/calendar experiences with heatmap-like P&L coloring.
- Weekly review generation and PDF export.
- Basic insight detection (best day, emotion/P&L correlation, discipline trend).

Backend routes:
- `GET /api/v1/daily_journals`
- `POST /api/v1/daily_journals`
- `GET /api/v1/daily_journals/:id`
- `GET /api/v1/daily_journals/:daily_journal_id/version_history`
- `POST /api/v1/daily_journals/:daily_journal_id/versions/:id/restore`

Frontend page:
- `/journal`

### 4.7 Settings & Data Controls
- Profile, trading preferences, notification, display settings.
- Data export/import actions (frontend local + backend APIs).
- Delete-account mock workflow.
- Form validation with React Hook Form.

Frontend page:
- `/settings`

Backend data management routes:
- `GET /api/v1/data_management/trades_export_csv`
- `GET /api/v1/data_management/journal_export_markdown`
- `GET /api/v1/data_management/analytics_export_report`
- `GET /api/v1/data_management/full_backup`
- `GET /api/v1/data_management/import_template`
- `POST /api/v1/data_management/import_preview`
- `POST /api/v1/data_management/import_commit`
- `GET /api/v1/data_management/deleted_trades`
- `POST /api/v1/data_management/restore_trade/:id`
- `GET /api/v1/data_management/audit_logs`

### 4.8 UX, Mobile & PWA
- Responsive layout with desktop sidebar and mobile bottom nav.
- Pull-to-refresh support for mobile list pages.
- Route-based code splitting and lazy loading.
- PWA manifest/service worker via Vite PWA plugin.
- Onboarding/sample data seeding for first launch.

Frontend routes:
- `/dashboard`
- `/trade/new`
- `/portfolio`
- `/trades`
- `/analytics`
- `/journal`
- `/help`
- `/settings`

## 5. Data Model Summary
Core entities:
- User
- Stock
- TradingStrategy
- TradePlan
- TradeExecution
- TradeResult
- Portfolio
- Holding
- DailyJournal
- DailyJournalVersion
- AuditLog

Supporting concerns:
- `SoftDeletable` for recoverable deletes
- `Auditable` for create/update tracking

## 6. How Features Are Implemented (Design Notes)

- Trade lifecycle integrity:
  - Each stage is normalized into its own model and API endpoint.
  - Associations enforce sequence (`plan -> execution -> result`).

- Analytics computation:
  - Derived metrics are computed server-side from completed trades.
  - Frontend visualizes aggregated data with chart components.

- Live pricing:
  - Primary path: ActionCable broadcast stream.
  - Fallback path: periodic polling (`/stocks/current_prices`).
  - Zustand store handles cross-page shared price state.

- Reliability and auditability:
  - Soft delete prevents accidental hard loss.
  - Audit logs capture critical entity changes.

- Frontend resilience:
  - React Query handles loading/cache/retry behavior.
  - Portfolio local cache parsing hardened to avoid route crashes on malformed browser data.

## 7. Business and User Outcomes

### For active traders
- Better process discipline through structured pre/post-trade recording.
- Faster feedback on what strategies and behaviors work.
- Cleaner visibility into portfolio risk and performance.

### For coaching/mentoring use cases
- Objective historical record for reviewing decisions.
- Behavioral evidence (emotion/discipline) paired with P&L outcomes.
- Easier weekly/monthly review conversations.

### For product/team
- Strong modular foundation for future broker integrations and automation.
- Clear API boundaries for scaling frontend/mobile clients.
- Extendable analytics and data export/import surface for premium features.

## 8. Current Boundaries / Known Gaps
- Some frontend modules still use local or mock data fallback when backend data is unavailable.
- Full automated test coverage and CI workflow are in progress.
- Some actions are intentionally mock placeholders (e.g., add funds, billing upgrade).

## 9. Suggested Next Milestones
1. Complete automated test suite (Rails RSpec + Vitest + E2E).
2. Finish full backend integration for all frontend flows currently mocked.
3. Add role-based permissions and production-grade observability.
4. Add broker statement import presets and scheduled analytics reports.

---
Last updated: 2026-03-15
