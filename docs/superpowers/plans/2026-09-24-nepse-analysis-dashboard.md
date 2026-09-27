# NEPSE Analysis Dashboard Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver usable market overview, VCP watchlist, breakout watch, stock detail, and filters backed by persisted Rails market data.

**Architecture:** Focused Ruby analysis classes generate the existing frontend API contract; thin controllers expose three GET endpoints. Existing pages and shared components are routed into PlatformLayout, with interaction and error-state fixes.

**Tech Stack:** Rails 8, PostgreSQL, RSpec, React 19, TypeScript, React Query, Tailwind, Recharts, Vitest, Testing Library.

---

### Task 1: Market overview

**Files:** `spec/requests/api/v1/market_overview_spec.rb`, `app/models/market_index/overview.rb`, `app/controllers/api/v1/market_controller.rb`, `config/routes.rb`.

- [ ] Write request specs for no index data, dated index + stock history, sector breadth, and nonfabricated values.
- [ ] Run `bundle exec rspec spec/requests/api/v1/market_overview_spec.rb` and confirm expected failures.
- [ ] Implement snapshot/overview using persisted index and stock daily prices; expose endpoint.
- [ ] Re-run targeted specs until passing.

### Task 2: VCP analysis and endpoints

**Files:** `spec/requests/api/v1/screener_spec.rb`, `app/models/stock/setup_analysis.rb`, `app/models/stock/setup_screener.rb`, `app/controllers/api/v1/screener_controller.rb`, `config/routes.rb`.

- [ ] Write failing specs for derived score/pivot, filterable attributes, neutral states, sparse history, symbol detail, and 404.
- [ ] Run `bundle exec rspec spec/requests/api/v1/screener_spec.rb` and confirm expected failures.
- [ ] Calculate setup analysis from observed prices and indicators, share it between list and detail, and expose endpoints.
- [ ] Re-run targeted specs until passing.

### Task 3: React integration

**Files:** `frontend/src/pages/ScreenerPage.test.tsx`, `frontend/src/pages/MarketOverviewPage.test.tsx`, `frontend/src/pages/StockAnalysisPage.test.tsx`, `frontend/src/pages/ScreenerPage.tsx`, `frontend/src/pages/StockAnalysisPage.tsx`, `frontend/src/App.tsx`, `frontend/src/layouts/PlatformLayout.tsx`.

- [ ] Write interaction tests for filtering both tabs, near-pivot selection, accessible detail navigation, and sparse state.
- [ ] Run `npm test -- src/pages/ScreenerPage.test.tsx src/pages/StockAnalysisPage.test.tsx` in `frontend/` and confirm failure.
- [ ] Wire routes/nav and refine current responsive components using existing design tokens.
- [ ] Run `npm test`, `npm run build`, and `npm run lint` in `frontend/`.

### Task 4: Final verification

- [ ] Run `bundle exec rspec spec/requests/api/v1/market_overview_spec.rb spec/requests/api/v1/screener_spec.rb` and `bin/rails zeitwerk:check`.
- [ ] Review diff/status and report test outcomes and any environment blockers.
