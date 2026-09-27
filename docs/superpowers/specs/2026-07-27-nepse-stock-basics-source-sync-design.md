# NEPSE Stock Basics Source Sync Design

## Summary

Replace the current mixed fetch logic with a source-oriented sync pipeline for NEPSE stock basics. Use Sharesansar as the primary source for daily market table data and Merolagani company detail pages as the primary source for company fundamentals and metadata. Persist normalized values into `stocks`, `stock_daily_prices`, and `stock_company_financials` without adding a runtime dependency on third-party GitHub wrappers.

## Goals

- Sync stock basics like `ltp`, `open`, `high`, `low`, `close`, `volume`, `turnover`, `52w high`, `52w low`, `listed_shares`, `market_cap`, `eps`, `pe_ratio`, `book_value`, and `pb_ratio`
- Run the sync one source at a time with clear source-specific logging and failure reporting
- Keep the change aligned with the current Rails service structure and schema
- Avoid overwriting valid stored values with missing or invalid scraped values
- Respect current schema constraints where some financial columns default to `0.0` and cannot represent `nil`

## Non-Goals

- Adding paid APIs or broker integrations
- Building a generic market data abstraction for unrelated markets
- Depending on unofficial GitHub wrappers in production runtime
- Refactoring unrelated stock, trade, or frontend code

## Source Strategy

### Primary Sources

- `Sharesansar /today-share-price`
  - Primary for daily market table fields
  - Expected fields: `symbol`, `open`, `high`, `low`, `close`, `ltp`, `volume`, `turnover`, `previous_close`, `change_amount`, `change_percent`, `52w high`, `52w low`
- `Merolagani /CompanyDetail.aspx?symbol=...`
  - Primary for company-level metadata and fundamentals
  - Expected fields: `sector`, `listed_shares`, `market_cap`, `eps`, `pe_ratio`, `book_value`, `pb_ratio`

### Fallback Position

- Keep the local stock master seed/import flow as a bootstrap fallback for symbol/name coverage
- Do not use GitHub projects or wrappers as runtime dependencies
- If a source is partially missing a field, preserve the current stored value and compute a derived value only when safe

## Proposed Components

### `Nepse::Source::SharesansarMarketClient`

Responsibilities:

- Fetch the daily market table HTML
- Parse rows into normalized hashes
- Return source-specific errors when the page shape is missing or invalid

Normalized output shape:

```ruby
{
  symbol: "ADBL",
  open_price: 304.0,
  high_price: 329.0,
  low_price: 304.0,
  close_price: 322.0,
  last_price: 322.0,
  previous_close: 320.0,
  change_amount: 2.0,
  change_percent: 0.62,
  volume: 84_053,
  turnover: 27_182_336.20,
  total_trades: 317,
  high_52w: 344.90,
  low_52w: 285.20,
  traded_on: Date.current,
  fetched_at: Time.current
}
```

### `Nepse::Source::MerolaganiCompanyClient`

Responsibilities:

- Fetch the company detail page for a symbol
- Parse company metadata and fundamental values into normalized hashes
- Continue to work per symbol so partial failures do not stop the full fundamentals run

Normalized output shape:

```ruby
{
  symbol: "ADBL",
  sector: "Commercial Banks",
  listed_shares: 184_000_000,
  market_cap: 59_248_000_000.0,
  eps: 27.14,
  pe_ratio: 11.86,
  book_value: 198.41,
  pb_ratio: 1.62,
  reported_on: Date.current,
  fiscal_year: "latest",
  quarter: "Annual"
}
```

### `Nepse::StockBasicsSyncService`

Responsibilities:

- Orchestrate the stock basics sync in explicit steps
- Use source clients for parsing and fetching
- Apply conservative upserts into existing tables
- Collect counts for processed, updated, skipped, and failed symbols per source

Public flow:

1. ensure master stocks exist
2. sync market table from Sharesansar
3. sync fundamentals from Merolagani
4. recalculate derived values where needed
5. return a structured result summary

## Data Flow

### Step 1: Ensure Master Stocks

Use the existing master stock seeder/importer to ensure `Stock` rows exist for tradable symbols before any scrape step runs. This remains the bootstrap source for `symbol`, `name`, `sector`, and `security_type` where live sources are incomplete.

If the master stock seed/import does not cover a live market symbol, the sync should record the symbol as rejected and continue rather than creating placeholder stocks with invented `name` or `sector` values.

### Step 2: Sync Daily Market Data

For each normalized market row from Sharesansar:

- find existing `Stock` by `symbol`
- update `stocks.last_price`
- update `stocks.change_percent`
- update `stocks.volume`
- overwrite `stocks.high_52w` when the parsed source value is valid and positive
- overwrite `stocks.low_52w` when the parsed source value is valid and positive
- update `stocks.last_updated`
- persist `StockDailyPrice` for `traded_on`

Write rules:

- never replace valid numeric values with `nil`
- skip rows with missing or invalid `symbol`
- skip rows with no usable `last_price` or `close_price`
- reject rows for symbols that do not already exist in `stocks` after the master seed step

### Step 3: Sync Company Fundamentals

For each active stock:

- fetch Merolagani company detail page by symbol
- parse company metadata and fundamentals
- update `stocks.listed_shares` when valid and positive
- update `stocks.market_cap` from source when valid and positive
- update `stocks.sector` only when present
- upsert one mutable latest `StockCompanyFinancial` snapshot using a stable period placeholder until a better fiscal-period source is available

Initial period strategy:

- `fiscal_year: "latest"`
- `quarter: "Annual"`

This avoids inventing fake year/quarter values while preserving one current fundamentals snapshot per stock. It intentionally does not preserve historical report rows in the first implementation.

### Step 4: Derived Values

If `market_cap` is missing from the source but `listed_shares` and `last_price` are available, compute it as `listed_shares * last_price`.

Keep model-level derived accessors like `current_pe_ratio` and `current_pb_ratio`, but update the read path so API payloads prefer persisted source values from the latest financial snapshot when those values are present and positive.

## Persistence Rules

### `stocks`

Persist and update:

- `symbol`
- `name` only when blank and source provides a usable value
- `sector`
- `security_type`
- `last_price`
- `change_percent`
- `volume`
- `listed_shares`
- `market_cap`
- `high_52w`
- `low_52w`
- `last_updated`

### `stock_daily_prices`

Upsert by `stock_id` + `traded_on`:

- `open_price`
- `high_price`
- `low_price`
- `close_price`
- `previous_close`
- `change_amount` only as an input if needed, knowing the model currently recomputes it before save
- `change_percent` only as an input if needed, knowing the model currently recomputes it before save
- `volume`
- `turnover`
- `total_trades`

Because `StockDailyPrice` currently recalculates `change_amount` and `change_percent` from `previous_close` and `close_price`, the stored values should be treated as model-derived values, not guaranteed source-exact values.

### `stock_company_financials`

Upsert by `stock_id` + `fiscal_year` + `quarter`:

- `reported_on`
- `eps` when parsed and positive
- `pe_ratio` when parsed and positive
- `book_value` when parsed and positive
- `pb_ratio` when parsed and positive

Current schema note:

- `stock_company_financials` numeric fields are non-null with `0.0` defaults
- the first implementation therefore treats `0.0` as "unknown or unavailable" for fields the source does not provide
- truly nullable unknown fundamentals would require a later schema change and are out of scope for the first pass

Fields like `roe`, `net_profit`, and `paid_up_capital` remain unchanged unless a validated source is added for them.

## Failure Handling

### Market Step

- If Sharesansar fetch or parse fails completely, mark the market step failed and stop that step
- Return a source-specific error message such as `sharesansar_market_parse_failed`

### Fundamentals Step

- If a single Merolagani company page fails, record the symbol in failures and continue
- If many pages fail, return both aggregate counts and failed symbols for inspection
- Add a small delay between requests to reduce the chance of blocking
- Abort the fundamentals step early when failure rate crosses a threshold, for example after 20 attempts with more than 50% failures, and return a source-level error indicating likely parser breakage or blocking

### Data Safety

- Missing scraped fields do not erase populated database fields
- Invalid numeric parsing results are ignored rather than stored as zero unless zero is explicitly meaningful

## Logging and Result Shape

Return a structured result from the sync service similar to:

```ruby
{
  success: true,
  market: {
    source: "Sharesansar",
    processed: 240,
    updated: 240,
    failed: 0
  },
  fundamentals: {
    source: "Merolagani",
    processed: 220,
    updated: 205,
    failed: 15,
    failed_symbols: ["ABC", "XYZ"]
  }
}
```

Rake output should print step-by-step progress by source rather than a single mixed summary.

## Rake Task Changes

Prefer explicit tasks over one ambiguous task:

- `nepse:seed_stocks`
- `nepse:sync_market`
- `nepse:sync_fundamentals`
- `nepse:sync_stock_basics`

`nepse:sync_stock_basics` should run the steps in order and print a final combined summary.

## Testing Strategy

Add focused tests for:

- Sharesansar row parsing into normalized market hashes
- Merolagani detail page parsing into normalized fundamentals hashes
- sync service persistence into `stocks`
- sync service persistence into `stock_daily_prices`
- sync service persistence into `stock_company_financials`
- partial failure behavior where one company page fails and the run continues
- rejection behavior for unknown symbols not present after the seed step
- overwrite behavior for valid source `high_52w` and `low_52w` values
- early abort behavior when fundamentals scraping crosses the failure-rate cutoff
- API/read-path behavior that prefers persisted positive `pe_ratio` and `pb_ratio` values from the latest financial snapshot
- conservative update behavior where missing fields do not overwrite existing data

## Migration Impact

No schema change is required for the first implementation, but the current `stock_company_financials` defaults mean missing fundamentals are represented as `0.0` rather than `nil`. A later schema cleanup can improve this if needed.

## Risks

- HTML structure changes on Sharesansar or Merolagani can break parsing
- Company detail pages may not always expose clear fiscal period metadata
- Repeated per-symbol requests can be slow for the fundamentals step
- Current financial schema cannot distinguish missing values from true zero values

## Mitigations

- Isolate source parsing into dedicated clients so source breakage is localized
- Keep parsing tests with captured fixture HTML
- Log source-specific failures clearly
- Use conservative persistence rules so partial scrape failures do not degrade existing stored data
- Stop early on high failure rates so a broken parser does not hammer the source across all symbols

## Implementation Recommendation

Implement this as a minimal refactor of the current NEPSE services:

- extract parsing/fetch logic from `WebScraperService` into dedicated source clients
- add one orchestrator service for stock basics sync
- update rake tasks to call the orchestrator in clear sequential steps
- keep existing models and schema intact for the first pass, while explicitly handling current defaults and validations
