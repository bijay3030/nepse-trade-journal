# Hamroshare Stock Sync And Frontend Refresh Design

## Summary

Make Hamroshare the single primary source for NEPSE stock list data, daily market snapshot data, and core fundamentals shown in the app. Replace the current split-source stock basics flow with Hamroshare-backed sync clients, add a canonical backend refresh endpoint for stock basics, and wire the `/stocks` page to support explicit refresh plus lightweight live price updates without repeated reload behavior.

## Goals

- Use Hamroshare as the primary source for listed stocks and core stock metrics
- Keep the app updated with daily real data directly visible in the app
- Show `ltp`, `% change`, `market_cap`, `eps`, `pe_ratio`, `book_value`, `pb_ratio`, `52w high`, `52w low`, and range insight derived from those values
- Fix the frontend refresh flow so `/stocks` triggers the correct backend sync path
- Keep live price updates lightweight and separate from fundamentals refresh
- Make Hamroshare authoritative for the active listed-stock universe shown by `/api/v1/stocks`

## Non-Goals

- Rebuilding the app around true tick-by-tick market streaming
- Adding paid APIs or authenticated broker feeds
- Guaranteeing every advanced financial field is available from Hamroshare if the source does not expose it
- Refactoring unrelated trading, journal, or analytics code

## Source Strategy

### Primary Source

- `https://hamroshare.com.np/nepse/stocks`
  - primary source for the full listed stock table and daily market snapshot rows
- `https://hamroshare.com.np/company/:symbol`
  - primary source for per-stock company detail and core fundamentals

### Supported Core Fields

Expected from Hamroshare list and company pages:

- `symbol`
- `name`
- `sector`
- `last_price`
- `change_percent`
- `open_price`
- `high_price`
- `low_price`
- `previous_close`
- `volume`
- `turnover`
- `market_cap`
- `paid_up_capital`
- `listed_shares` when present
- `high_52w`
- `low_52w`
- `eps`
- `pe_ratio`
- `book_value`
- `pb_ratio`

### Unsupported Or Optional Fields

Fields such as `roe`, `net_profit`, `reserve_and_surplus`, and `npl_ratio` should only be updated if Hamroshare exposes them clearly and consistently. Otherwise they remain unchanged in persistence and blank or existing in API output.

## Proposed Components

### `Nepse::Source::HamroshareStocksClient`

Responsibilities:

- fetch the Hamroshare listed-stocks page
- parse all listed stock rows into normalized hashes
- provide full market/list coverage from one page

Normalized output shape:

```ruby
{
  symbol: "NABIL",
  name: "Nabil Bank Limited",
  sector: "Commercial Banks",
  last_price: 558.0,
  change_percent: -0.36,
  market_cap: 148_810_000_000.0,
  paid_up_capital: 27_056_996_352.0,
  listed_shares: nil,
  high_52w: 563.0,
  fetched_at: Time.current
}
```

If `listed_on` is parsed from Hamroshare, treat it as parse-only metadata in the first implementation. Do not include it in the required normalized contract or persistence rules until the schema has a clear destination for it.

### `Nepse::Source::HamroshareCompanyClient`

Responsibilities:

- fetch `https://hamroshare.com.np/company/:symbol`
- parse market detail values and core fundamentals for one stock
- return per-symbol failures without stopping the full sync

Normalized output shape:

```ruby
{
  symbol: "NABIL",
  last_price: 558.0,
  change_percent: -0.36,
  open_price: 560.0,
  high_price: 560.0,
  low_price: 554.0,
  previous_close: 560.0,
  volume: 61_500,
  turnover: 34_200_000.0,
  market_cap: 148_810_000_000.0,
  paid_up_capital: 27_056_996_352.0,
  listed_shares: nil,
  high_52w: 563.0,
  low_52w: 471.0,
  eps: 33.02,
  pe_ratio: 16.80,
  book_value: 243.30,
  pb_ratio: 2.30,
  fiscal_year: "082/083",
  quarter: "Q3",
  reported_on: Date.current,
  fetched_at: Time.current
}
```

### `Nepse::StockBasicsSyncService`

Responsibilities:

- become Hamroshare-first and canonical for stock basics sync
- sync master list and market snapshot from the Hamroshare list page
- enrich per symbol from Hamroshare company pages
- persist to `stocks`, `stock_daily_prices`, and `stock_company_financials`
- return a structured sync result suitable for API and task output

Public flow:

1. fetch and persist master/list rows from Hamroshare stocks page
2. update `stocks` current snapshot from the same page
3. fetch per-stock Hamroshare company details
4. update `stocks` enriched values
5. persist latest daily price rows
6. persist financial snapshot rows

## Stock Master Authority Rules

Hamroshare becomes the authority for which NEPSE-listed stocks are active in the app.

Rules:

- if a symbol exists on Hamroshare and not locally, create a new `Stock`
- if a symbol exists locally and also appears on Hamroshare, update its master attributes from Hamroshare
- if a symbol exists locally but no longer appears on Hamroshare, mark `is_active = false` instead of deleting it
- if a company name or sector changes on Hamroshare, update the local record on sync
- if Hamroshare presents what appears to be a symbol change, treat it as a new symbol creation plus old-symbol deactivation unless there is a separately verified reconciliation rule

Required fields for stock creation:

- `symbol`
- `name`
- `sector`

If Hamroshare does not expose a usable `security_type`, preserve the current local value or set a conservative default only when the app already does so consistently.

This ensures `Stock.active` remains aligned with the live listed-stock universe and prevents successful syncs from leaving the app stale.

## Persistence Rules

### `stocks`

Update:

- `symbol`
- `name`
- `sector`
- `last_price`
- `change_percent`
- `volume`
- `listed_shares`
- `market_cap`
- `high_52w`
- `low_52w`
- `last_updated`

If `security_type` is not derivable from Hamroshare, keep the current stored value or bootstrap seed value.

If Hamroshare exposes paid-up capital reliably, also update `stocks.paid_up_value` so stock-level snapshots and stock detail output stay aligned with the latest company metrics.

### `stock_daily_prices`

Upsert one row per `stock_id + traded_on` with:

- `open_price`
- `high_price`
- `low_price`
- `close_price`
- `previous_close`
- `change_amount`
- `change_percent`
- `volume`
- `turnover`
- `total_trades` only if Hamroshare exposes it reliably

### `stock_company_financials`

Upsert latest financial snapshot with:

- `reported_on`
- `fiscal_year`
- `quarter`
- `eps`
- `pe_ratio`
- `book_value`
- `pb_ratio`
- `paid_up_capital`

If quarter or fiscal-year text is missing, fall back to the current latest-snapshot convention instead of inventing fake period history.

## Missing Data Semantics

Current schema and serializers use `0.0` defaults for many financial fields, which makes missing data look like a real numeric value. The implementation for this design must change API semantics even if the database defaults remain unchanged in the first pass.

API rule:

- when a financial field is missing, unsupported, or only present as a placeholder, serializers should emit `null` rather than `0.0`

This applies at minimum to:

- `eps`
- `pe_ratio`
- `book_value`
- `pb_ratio`
- optional advanced fields like `roe`, `net_profit`, `reserve_and_surplus`, and `npl_ratio`

Model rule:

- stock-level helper methods used by API serializers should treat `0.0` as "unknown" for source-populated fundamentals unless a real positive value is present

This preserves truthful frontend display even before any later schema cleanup.

## Conservative Data Rules

- missing Hamroshare fields must not erase good stored values
- unsupported fields remain unchanged rather than backfilled with guesses
- invalid placeholders like `-`, `--`, `NA`, and blank strings must be ignored
- `market_cap` may be recomputed from `listed_shares * last_price` only when source `market_cap` is missing and both inputs are valid

## Frontend Refresh Design

### Canonical Backend Refresh Endpoint

Add a new API endpoint:

- `POST /api/v1/data_imports/sync_stock_basics`

Behavior:

- triggers the canonical Hamroshare stock basics sync service
- returns structured sync status and counts

Expected response shape:

```json
{
  "success": true,
  "market": {
    "updated": 240,
    "failed": 0
  },
  "fundamentals": {
    "updated": 220,
    "failed": 20,
    "failed_symbols": ["ABC"]
  },
  "synced_at": "2026-07-27T12:00:00Z"
}
```

### `/stocks` Page Refresh Behavior

Current broken behavior:

- frontend posts to `/data_imports/fetch_prices`, which does not exist

New behavior:

- `StocksPage` refresh button calls `POST /api/v1/data_imports/sync_stock_basics`
- after success, the page refetches stock list data in place without route reload
- if a stock detail modal is open, the page also refetches in place:
  - `/stocks/:symbol/historical_prices`
  - `/stocks/:symbol/financials`

The page must preserve current client state while doing this:

- current search query
- selected filters
- sort order
- current view mode
- open stock modal and selected tab when practical

This is an explicit manual refresh, not an automatic full sync on page mount.

## Live Update Design

### Scope

Live-ish updates should only update lightweight market fields, not fundamentals.

Use the existing `useStockPrices()` hook for:

- `last_price`
- `change_percent`
- `volume`
- `last_updated`

Do not use it to re-fetch or merge fundamentals.

Source decision for live overlay:

- the short-term implementation may continue using the existing `NepsePriceService` path for `/stocks/current_prices`
- the persisted Hamroshare snapshot remains the source of truth for stock pages after each explicit or scheduled sync
- if live overlay values differ from persisted Hamroshare values, the overlay wins only in-memory for the active session until the next canonical stock-basics sync

This split is intentional in the first pass to avoid blocking frontend live updates on a larger Hamroshare intraday polling redesign.

### `/stocks` Data Flow

1. load the full stock snapshot once from `GET /api/v1/stocks`
2. subscribe to `current_prices` through the existing price hook during market hours
3. merge live price fields into the rendered stock list in memory
4. keep fundamentals from the latest persisted snapshot until the next manual or scheduled sync

### Market Detail Refresh

If the user has a stock detail modal open, live price fields can update in the modal from the same hook, but historical and financial tabs should remain snapshot-based unless refreshed explicitly.

If the existing current-prices endpoint remains capped for performance, the stock page should subscribe only to the symbols currently rendered or selected rather than forcing all active stocks through the live overlay path.

## Derived Metrics For API And UI

Add serializer-level derived fields:

- `percent_below_52w_high`
- `percent_above_52w_low`

These should be computed once in backend serializers so the frontend does not duplicate financial math.

The frontend can continue showing the 52-week range bar, but should also display these explicit percentages in the stock overview and/or detail modal.

Additional derived copy may include a human-readable summary like:

- `"90% up the 52-week range"`

but the numeric percentage fields are the required API contract.

## Failure Handling

### List Page Failure

- if the Hamroshare listed-stocks page fails, stop the sync entirely
- return source-level error information

### Company Page Failure

- if one company page fails, continue syncing the rest
- return `failed_symbols` and failure counts
- keep market/list snapshot data even when some fundamentals fail

### Frontend Refresh Failure

- if `sync_stock_basics` fails, keep the current `/stocks` data rendered
- show a visible error toast or inline error state instead of leaving the user with a spinner loop

## Scheduling

Production scheduling should eventually use the same canonical Hamroshare stock basics sync job, not only the current daily-price path. This design intentionally aligns manual refresh, rake tasks, and future cron scheduling around one source and one orchestrator.

## Testing Strategy

Add or update tests for:

- Hamroshare list page parsing
- Hamroshare company page parsing
- Hamroshare-backed stock basics sync persistence
- `POST /api/v1/data_imports/sync_stock_basics`
- serializer output for `percent_below_52w_high` and `percent_above_52w_low`
- `/stocks` refresh button calling the correct endpoint
- frontend stock list merging lightweight live price updates without replacing persisted fundamentals
- frontend stock detail refresh behavior when modal is open

## Risks

- Hamroshare HTML structure changes can break both list and company parsing
- per-symbol company-page scraping may be slower than the current mixed source path
- not every advanced fundamental field may exist on Hamroshare for every stock

## Mitigations

- isolate Hamroshare parsing in dedicated clients
- preserve stored values on missing or unparsable source fields
- keep explicit error reporting and failed-symbol output
- treat unsupported fields as blank or unchanged rather than fake data
- keep live updates limited to lightweight price fields for stability

## Implementation Recommendation

Implement this as a focused source consolidation and refresh-wiring change:

- replace the current stock basics source mix with Hamroshare clients
- add one canonical `sync_stock_basics` API endpoint
- wire `/stocks` manual refresh to that endpoint
- use `useStockPrices()` only for lightweight live price overlays
- expose range-percentage metrics from serializers
