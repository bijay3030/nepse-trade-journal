# NEPSE Stock Basics Source Sync Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current mixed NEPSE stock basics fetch flow with a source-oriented sync that uses Sharesansar market data and Merolagani fundamentals, then persists normalized data into the existing tables.

**Architecture:** Extract source-specific parsing and fetch logic into dedicated NEPSE source clients, add one orchestrator service to run seed -> market sync -> fundamentals sync, and update rake tasks to call the new flow. Keep the current schema and models, but implement conservative writes that respect current validations and defaults.

**Tech Stack:** Ruby on Rails, RSpec, HTTParty, Nokogiri, ActiveRecord, rake

---

## File Map

- Create: `app/services/nepse/source/sharesansar_market_client.rb`
  - Fetch and parse Sharesansar daily market table into normalized market rows.
- Create: `app/services/nepse/source/merolagani_company_client.rb`
  - Fetch and parse Merolagani company detail pages into normalized fundamentals hashes.
- Create: `app/services/nepse/stock_basics_sync_service.rb`
  - Orchestrate seed, market sync, fundamentals sync, result aggregation, and failure thresholds.
- Modify: `app/services/nepse/web_scraper_service.rb`
  - Reuse the new clients or narrow this file to compatibility wrappers for existing call sites.
- Modify: `app/services/nepse/master_importer_service.rb`
  - Keep this as the canonical bootstrap path for master stock records.
- Modify: `app/services/nepse/stock_master_seeder.rb`
  - Reduce duplicate responsibility or delegate to the canonical importer if needed.
- Modify: `app/models/stock.rb`
  - Prefer persisted positive `pe_ratio` and `pb_ratio` values from the latest financial snapshot in read helpers.
- Modify: `lib/tasks/nepse.rake`
  - Replace ambiguous scrape tasks with explicit stock basics sync tasks and step-by-step output.
- Modify: `lib/tasks/nepse_data.rake`
  - Remove duplicate task responsibility and align task naming with the canonical sync flow.
- Add/Modify tests:
  - `spec/services/nepse/source/sharesansar_market_client_spec.rb`
  - `spec/services/nepse/source/merolagani_company_client_spec.rb`
- `spec/services/nepse/stock_basics_sync_service_spec.rb`
- `spec/services/nepse/web_scraper_service_spec.rb`
- `spec/models/stock_spec.rb`

### Task 1: Add Sharesansar Market Client

**Files:**
- Create: `app/services/nepse/source/sharesansar_market_client.rb`
- Test: `spec/services/nepse/source/sharesansar_market_client_spec.rb`

- [ ] **Step 1: Write the failing parsing spec**

Cover:
- parsing one valid Sharesansar row into normalized attributes
- rejecting rows without a usable symbol or last price
- returning a structured error when the table is missing

- [ ] **Step 2: Run the client spec to verify it fails**

Run: `bundle exec rspec spec/services/nepse/source/sharesansar_market_client_spec.rb`

- [ ] **Step 3: Write the minimal client implementation**

Implement:
- an HTTP fetch method with user agent and timeout
- a parser that maps the known table columns into normalized hashes
- numeric cleanup helpers scoped to this client or a tiny shared internal helper if duplication is obvious

- [ ] **Step 4: Run the client spec to verify it passes**

Run: `bundle exec rspec spec/services/nepse/source/sharesansar_market_client_spec.rb`

### Task 2: Add Merolagani Company Client

**Files:**
- Create: `app/services/nepse/source/merolagani_company_client.rb`
- Test: `spec/services/nepse/source/merolagani_company_client_spec.rb`

- [ ] **Step 1: Write the failing parsing spec**

Cover:
- parsing valid fundamentals from a company detail response
- returning partial data without blowing away absent fields
- returning a structured error when the page shape is missing

- [ ] **Step 2: Run the client spec to verify it fails**

Run: `bundle exec rspec spec/services/nepse/source/merolagani_company_client_spec.rb`

- [ ] **Step 3: Write the minimal client implementation**

Implement:
- per-symbol fetch
- extraction of `sector`, `listed_shares`, `market_cap`, `eps`, `pe_ratio`, `book_value`, and `pb_ratio`
- normalized result shape with a stable placeholder period of `fiscal_year: "latest"` and `quarter: "Annual"`

- [ ] **Step 4: Run the client spec to verify it passes**

Run: `bundle exec rspec spec/services/nepse/source/merolagani_company_client_spec.rb`

### Task 3: Add Stock Basics Sync Service

**Files:**
- Create: `app/services/nepse/stock_basics_sync_service.rb`
- Modify: `app/services/nepse/master_importer_service.rb`
- Modify: `app/services/nepse/stock_master_seeder.rb`
- Test: `spec/services/nepse/stock_basics_sync_service_spec.rb`

- [ ] **Step 1: Write the failing sync service spec**

Cover:
- running the canonical master seed step via `Nepse::MasterImporterService.call` before sync
- persisting market data into `stocks` and `stock_daily_prices`
- persisting fundamentals into `stocks` and `stock_company_financials`
- computing `market_cap` from `listed_shares * last_price` when source `market_cap` is missing
- rejecting symbols missing from the seeded master list
- continuing after single-symbol fundamentals failures
- aborting fundamentals when failure rate crosses the configured threshold
- preserving existing stored values when fundamentals fields are missing or unparsable
- overwriting `high_52w` and `low_52w` from valid source values

- [ ] **Step 2: Run the sync service spec to verify it fails**

Run: `bundle exec rspec spec/services/nepse/stock_basics_sync_service_spec.rb`

- [ ] **Step 3: Write the minimal sync implementation**

Implement:
- seed step via `Nepse::MasterImporterService.call` as the single bootstrap path
- market step that loads Sharesansar rows and updates existing stocks only
- daily price upsert using existing `StockDailyPrice` semantics
- fundamentals step that updates stocks and one mutable latest `StockCompanyFinancial` snapshot
- market cap fallback via `Stock#recalculate_market_cap!` when source `market_cap` is absent but `listed_shares` and `last_price` are present
- small delay between fundamentals requests to preserve current throttling behavior
- aggregated result payload with per-step counts and failed symbols

- [ ] **Step 4: Run the sync service spec to verify it passes**

Run: `bundle exec rspec spec/services/nepse/stock_basics_sync_service_spec.rb`

### Task 4: Update Stock Read Helpers and Compatibility Paths

**Files:**
- Modify: `app/models/stock.rb`
- Modify: `app/services/nepse/web_scraper_service.rb`
- Test: `spec/models/stock_spec.rb`
- Test: `spec/services/nepse/web_scraper_service_spec.rb`

- [ ] **Step 1: Write the failing stock model expectations**

Cover:
- preferring persisted positive `pe_ratio` and `pb_ratio` values from the latest financial record
- falling back to derived values when persisted ratios are absent or zero

- [ ] **Step 2: Run the stock model spec to verify it fails**

Run: `bundle exec rspec spec/models/stock_spec.rb`

- [ ] **Step 3: Write the minimal implementation**

Implement:
- `Stock#current_pe_ratio` and `Stock#current_pb_ratio` preference for persisted positive values
- `WebScraperService` wrappers that delegate to the new source clients or to the new sync service without duplicating parsing logic

- [ ] **Step 4: Run the stock model spec to verify it passes**

Run: `bundle exec rspec spec/models/stock_spec.rb`

- [ ] **Step 5: Run the web scraper compatibility spec**

Run: `bundle exec rspec spec/services/nepse/web_scraper_service_spec.rb`

### Task 5: Update Rake Tasks and End-to-End Verification

**Files:**
- Modify: `lib/tasks/nepse.rake`
- Modify: `lib/tasks/nepse_data.rake`
- Test: `spec/services/nepse/stock_basics_sync_service_spec.rb`

- [ ] **Step 1: Write the failing task-level expectation if needed**

If task-level specs are too heavy, skip adding a new rake spec and verify through service tests plus a direct rake invocation.

- [ ] **Step 2: Write the minimal task updates**

Implement:
- one canonical `nepse:seed_stocks` path that calls `Nepse::MasterImporterService.call`
- `nepse:sync_market`
- `nepse:sync_fundamentals`
- `nepse:sync_stock_basics`
- compatibility decision for `nepse:scrape_market`, `nepse:scrape_fundamentals`, and `nepse:scrape_all`: either delegate to the new flow or remove duplicate behavior cleanly
- step-by-step output by source

- [ ] **Step 3: Run the targeted service and model specs**

Run:
- `bundle exec rspec spec/services/nepse/source/sharesansar_market_client_spec.rb`
- `bundle exec rspec spec/services/nepse/source/merolagani_company_client_spec.rb`
- `bundle exec rspec spec/services/nepse/stock_basics_sync_service_spec.rb`
- `bundle exec rspec spec/services/nepse/web_scraper_service_spec.rb`
- `bundle exec rspec spec/models/stock_spec.rb`

- [ ] **Step 4: Run a direct rake smoke check**

Run: `bundle exec rake -T nepse`

Expected:
- new tasks are listed
- task names match the spec

- [ ] **Step 5: Run the full focused verification batch**

Run: `bundle exec rspec spec/services/nepse spec/models/stock_spec.rb`

Expected:
- all targeted specs pass

## Notes for Execution

- Keep changes minimal and avoid schema changes in the first pass.
- Use fixture HTML or stubbed response bodies in specs instead of live network calls.
- Treat `0.0` in `stock_company_financials` as "unknown for now" because of current schema defaults.
- Do not invent placeholder stocks for unknown symbols discovered in market rows.
- Prefer adapting the existing `WebScraperService` as a compatibility layer rather than deleting it outright.
- Consolidate bootstrap seeding on `Nepse::MasterImporterService.call` so task behavior is deterministic.
