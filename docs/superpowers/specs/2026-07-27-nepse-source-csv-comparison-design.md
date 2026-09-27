# NEPSE Source CSV Comparison Design

## Summary

Export full active NEPSE securities data into CSV from multiple free sources, normalize the overlapping fields, and compare coverage, completeness, consistency, and scrape practicality. Use the resulting comparison to decide which source should become the app's primary daily market-data and fundamentals source.

## Goals

- collect CSV exports for the full active NEPSE universe from relevant free sources
- compare the sources using a normalized shared schema
- identify which source is best for market fields
- assess whether Hamroshare fundamentals coverage is sufficient for the app's stock basics needs
- produce a comparison artifact that supports selecting the app's primary source and fallback source

## Non-Goals

- immediately replacing the app's production sync pipeline
- scraping every possible advanced company detail from every site
- building a permanent end-user feature around the CSV comparison files

## Source Set

### Included Sources

1. `Hamroshare`
   - list page: `https://hamroshare.com.np/nepse/stocks`
   - company pages: `https://hamroshare.com.np/company/:symbol`
   - role: primary candidate for combined market + fundamentals coverage

2. `Sharesansar`
   - market table: `https://www.sharesansar.com/today-share-price`
   - role: primary market-table comparison source

3. `Merolagani`
   - live market table: `https://merolagani.com/LatestMarket.aspx`
   - role: secondary market snapshot comparison source

### Excluded From Main Comparison

- current `NepsePriceService` external JSON source
  - useful only as a price-only reference
  - not suitable for full-universe listing/fundamentals comparison

## Universe Scope

The comparison should include the full active NEPSE securities universe available from the selected sources, including:

- common shares
- promoter shares
- mutual funds
- debentures
- preference shares
- other listed security types if present in source tables

The comparison output should not assume the universe is only common-equity stocks.

## Comparison Scope Separation

The workflow must explicitly separate two different universes:

1. `listed-universe comparison`
   - compares which securities appear in each source's exported dataset
   - useful for coverage and symbol-overlap analysis

2. `trading-snapshot comparison`
   - compares only the rows that are actually present in all relevant market snapshots for the same trading session
   - useful for `ltp`, `change_percent`, `open`, `high`, `low`, `volume`, and related market-field consistency

This distinction is required because market pages may represent only traded or currently displayed rows rather than the full listed universe.

## Export Strategy

### Two-Stage Export

#### Stage 1: Full-Universe Table Exports

Export all rows directly exposed by the chosen source pages from:

- Hamroshare listed-stocks page
- Sharesansar today-share-price page
- Merolagani latest-market page

This stage provides the fastest broad comparison for overlapping market fields, but the summary must classify each export as either:

- `listed-universe oriented`
- `trading-snapshot oriented`

#### Stage 2: Hamroshare Per-Symbol Enrichment

For the symbols discovered in the Hamroshare list export:

- fetch company detail page per symbol
- extract core fundamentals and company-detail fields
- write them into a separate enrichment CSV

Only Hamroshare needs this second-stage fundamentals pass for the initial comparison because it is the strongest candidate for a unified source.

This stage is not a cross-source fundamentals comparison. It is a sufficiency check for whether Hamroshare alone can cover the fundamentals needed by the app.

## Output Files

Required CSV files:

- `hamroshare_list.csv`
- `hamroshare_company_details.csv`
- `sharesansar_market.csv`
- `merolagani_market.csv`
- `source_comparison.csv`
- `source_comparison_summary.csv`

Optional debug artifacts:

- `unmatched_symbols.csv`
- `parse_failures.csv`

## CSV Schemas

### `hamroshare_list.csv`

Columns:

- `symbol`
- `name`
- `sector`
- `ltp`
- `change_percent`
- `market_cap`
- `paid_up_capital`
- `listed_shares`
- `listed_on_raw`
- `high_52w`
- `source`
- `scraped_at`

### `hamroshare_company_details.csv`

Columns:

- `symbol`
- `name`
- `sector`
- `ltp`
- `change_percent`
- `open_price`
- `high_price`
- `low_price`
- `previous_close`
- `volume`
- `turnover`
- `market_cap`
- `paid_up_capital`
- `listed_shares`
- `high_52w`
- `low_52w`
- `eps`
- `pe_ratio`
- `book_value`
- `pb_ratio`
- `fiscal_year_raw`
- `quarter_raw`
- `source`
- `scraped_at`

### Canonical Hamroshare Merge Rule

When the Hamroshare list export and Hamroshare company-detail export both contain the same field:

- company-detail values win for:
  - `ltp`
  - `change_percent`
- company-detail values win for:
  - `open_price`
  - `high_price`
  - `low_price`
  - `previous_close`
  - `volume`
  - `turnover`
  - `low_52w`
  - `eps`
  - `pe_ratio`
  - `book_value`
  - `pb_ratio`
- list-page values remain canonical for broad-universe list metadata unless detail pages clearly provide better values:
  - `symbol`
  - `name`
  - `sector`
  - `market_cap`
  - `paid_up_capital`
  - `listed_shares`
  - `high_52w`

If a field exists in both and conflicts materially, record both raw values in debug output and mark the merged field as coming from the chosen precedence rule.

### `sharesansar_market.csv`

Columns:

- `symbol`
- `name`
- `open_price`
- `high_price`
- `low_price`
- `close_price`
- `ltp`
- `previous_close`
- `change_amount`
- `change_percent`
- `vwap`
- `volume`
- `turnover`
- `transactions`
- `high_52w`
- `low_52w`
- `source`
- `as_of_date`
- `scraped_at`

### `merolagani_market.csv`

Columns:

- `symbol`
- `name`
- `ltp`
- `change_percent`
- `open_price`
- `high_price`
- `low_price`
- `previous_close`
- `volume`
- `source`
- `as_of_timestamp`
- `scraped_at`

### `source_comparison.csv`

One row per `symbol + source`, or one wide merged row per symbol. Prefer a wide merged row for easier manual review.

Columns:

- `symbol`
- `security_name_hamroshare`
- `security_name_sharesansar`
- `security_name_merolagani`
- `sector_hamroshare`
- `ltp_hamroshare`
- `ltp_sharesansar`
- `ltp_merolagani`
- `change_percent_hamroshare`
- `change_percent_sharesansar`
- `change_percent_merolagani`
- `market_cap_hamroshare`
- `paid_up_capital_hamroshare`
- `listed_shares_hamroshare`
- `high_52w_hamroshare`
- `high_52w_sharesansar`
- `low_52w_hamroshare`
- `low_52w_sharesansar`
- `eps_hamroshare`
- `pe_ratio_hamroshare`
- `book_value_hamroshare`
- `pb_ratio_hamroshare`
- `present_in_hamroshare`
- `present_in_sharesansar`
- `present_in_merolagani`
- `comparison_scraped_at`

The Hamroshare columns in this merged CSV must refer to the canonical merged Hamroshare record produced from `hamroshare_list.csv` plus `hamroshare_company_details.csv` according to the precedence rules above.

### `source_comparison_summary.csv`

One row per source plus per-field summary rows.

Columns:

- `source`
- `category`
- `metric`
- `value`
- `rationale`

Examples:

- `hamroshare, coverage, symbols_present, 545, list page exposes 545 active rows`
- `sharesansar, completeness_raw, ltp_non_null, 520, market table had 520 populated ltps`
- `merolagani, completeness_raw, market_cap_non_null, 0, market cap not present on latest-market table`
- `cross_source, consistency, conflicting_ltp_symbols, 12, excluding time-misaligned rows`

## Normalization Rules

- trim and uppercase `symbol`
- preserve original source symbol alongside normalized symbol in source-specific CSVs
- apply known alias mapping when symbols differ by source formatting or instrument suffix conventions
- preserve raw company names, but also compare normalized names case-insensitively
- convert formatted Nepali market units into numeric base values using explicit rules:
  - `K` = thousand
  - `L` = lakh
  - `Cr` = crore
  - `Arb` = arab
- strip `Rs`, commas, spaces, `%`, and surrounding punctuation before parsing
- preserve both raw and parsed values in source-specific exports when parsing is non-trivial
- preserve raw text fields in source-specific CSVs when parsing confidence is uncertain
- represent missing values as blank CSV cells, not zero-filled placeholders

If symbol aliasing cannot be resolved confidently, keep the row unmatched and record it in `unmatched_symbols.csv` rather than forcing a bad join.

If the app's existing stock master can help classify security types or normalize symbols, it may be used as a reference table, but raw source symbols remain the first comparison key.

## Time Alignment Rules

Cross-source market-field comparisons are valid only when all compared rows belong to the same trading date.

Rules:

- record source-visible market timestamp or as-of date whenever available
- record local `scraped_at` for every export
- treat `ltp`, `change_percent`, `open`, `high`, `low`, `volume`, and turnover comparisons as `same-session` only when source dates match and scrape times are within an acceptable window
- when time alignment is weak, report the difference as `time-misaligned` rather than a hard data conflict

Initial acceptable scrape window:

- all market exports should be collected in one run, back-to-back
- maximum acceptable scrape-time delta between market-source exports is `15 minutes`
- if one source exposes only a trading date and another exposes a timestamp, comparisons remain valid only when both belong to the same trading date and the local `scraped_at` timestamps stay within the `15 minute` window

The summary must distinguish:

- `true conflicting values`
- `time-misaligned values`

## Comparison Metrics

### Coverage

- total symbols exported per source
- total active symbols overlapping across sources
- symbols unique to one source

### Completeness

Per source, count non-null values for:

- `ltp`
- `change_percent`
- `market_cap`
- `listed_shares`
- `high_52w`
- `low_52w`
- `eps`
- `pe_ratio`
- `book_value`
- `pb_ratio`

Completeness must be reported in two ways:

1. `raw completeness`
   - across the whole exported universe

2. `applicable completeness`
   - only for security types where the field is meaningfully applicable

Examples:

- `eps`, `pe_ratio`, `book_value`, and `pb_ratio` should not penalize a source for debentures or mutual funds if those metrics are not applicable
- market fields should be compared only across rows present in the trading snapshot universe

### Consistency

For overlapping symbols, count conflicting values for:

- `ltp`
- `change_percent`
- `high_52w`
- `low_52w`

Use a small numeric tolerance where needed for floating-point or source-format differences.

Consistency should only be computed on time-aligned overlapping rows in the trading-snapshot comparison set.

### Practicality

Record operational observations:

- whether the source provides a single full-universe table or requires per-symbol requests
- whether HTML is noisy or scrape-fragile
- whether the source clearly separates security types
- whether timestamps and as-of dates are visible

These observations should be recorded in a structured summary file, not only in prose.

## Expected Source Roles

### Hamroshare

- expected primary candidate for combined stock list + market snapshot + core fundamentals
- requires per-symbol company-page scraping for fundamentals
- fundamentals verdict is based on Hamroshare sufficiency, not cross-source superiority testing

### Sharesansar

- expected fallback/reference source for daily market-table fields
- not expected to win for fundamentals

### Merolagani

- expected secondary market snapshot reference
- not expected to win for fundamentals

## Implementation Shape

Use a dedicated export/comparison workflow instead of mixing this into the production stock sync path.

Suggested responsibilities:

- source-specific export services write raw normalized CSVs
- comparison service merges rows by symbol and computes summary metrics
- one rake task or command runs the full comparison workflow end to end

## Failure Handling

- if one source export fails, preserve the successful CSVs from other sources
- write parse failures into `parse_failures.csv`
- if a per-symbol Hamroshare company page fails, continue remaining symbols and record the failure
- do not stop the whole comparison because a small subset of detail pages fail

If a market page appears to omit parts of the listed universe, do not classify that source as broadly incomplete for fundamentals or stock-master coverage without labeling it as a snapshot-only source in the summary.

## Testing Strategy

Add focused tests for:

- unit conversion parsing like `K`, `L`, `Cr`, `Arb`
- source-specific row extraction for each source
- CSV writer output shape
- comparison merge behavior by symbol
- summary metric calculations
- time-alignment classification
- applicability-aware completeness calculations by security type

## Decision Output

The end of this workflow should produce a decision-ready summary answering:

- which source has the best full-universe stock coverage
- which source has the best daily market-field coverage
- whether Hamroshare alone is sufficient for the app's stock basics fundamentals needs
- which source should be the app's primary source and which should be fallback/reference only

The decision output must explicitly separate:

- listed-universe coverage decision
- trading-snapshot market-fields decision
- Hamroshare fundamentals sufficiency decision

`source_comparison_summary.csv` should therefore include structured rows for:

- `coverage`
- `completeness_raw`
- `completeness_applicable`
- `consistency`
- `time_alignment`
- `practicality`
- `decision`

Decision rows should include a short rationale in addition to the chosen value.

## Implementation Recommendation

Implement the CSV comparison as a one-off but maintainable internal tool:

- export full-universe rows from Hamroshare, Sharesansar, and Merolagani
- enrich Hamroshare with per-symbol company details
- merge and summarize into comparison CSVs
- use the results to choose the production source strategy for the app
