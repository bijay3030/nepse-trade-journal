# NEPSE Source CSV Comparison Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an internal workflow that exports full active NEPSE source data to CSV, normalizes and compares it, and produces decision-ready summary files for choosing the app's primary stock-data source.

**Architecture:** Add source-specific export clients/services for Hamroshare list data, Hamroshare company details, and Merolagani market rows, then add a comparison service that normalizes symbols/units, merges rows, computes coverage/completeness/consistency metrics, and writes the final CSV artifacts. Reuse the existing Sharesansar client where possible and keep this workflow separate from the app's production sync path.

**Tech Stack:** Ruby on Rails, RSpec, CSV, HTTParty, Nokogiri, rake

---

## File Map

- Create: `app/services/nepse/source/hamroshare_stocks_client.rb`
  - Fetch and parse the Hamroshare listed-stocks page into normalized rows.
- Create: `app/services/nepse/source/hamroshare_company_client.rb`
  - Fetch and parse Hamroshare company pages into normalized detail/fundamentals hashes.
- Create: `app/services/nepse/source/merolagani_market_client.rb`
  - Fetch and parse Merolagani latest-market rows into normalized market hashes.
- Create: `app/services/nepse/source_csv_export_service.rb`
  - Run stage-1/2 exports and write the source-specific CSV files.
- Create: `app/services/nepse/source_comparison_service.rb`
  - Merge source CSV rows by symbol, apply precedence/time-alignment rules, and compute summary metrics.
- Create: `app/services/nepse/security_type_classifier.rb`
  - Classify securities for applicability-aware completeness using source hints and optional stock-master reference data.
- Create: `lib/nepse/csv_number_parser.rb`
  - Parse units like `K`, `L`, `Cr`, `Arb`, strips `Rs`, commas, `%`, and preserves raw values where needed.
- Modify: `app/services/nepse/source/sharesansar_market_client.rb`
  - Reuse for CSV export with any small additions needed for `name`, `as_of_date`, or raw values.
- Modify: `lib/tasks/nepse.rake`
  - Add one canonical task to run the full comparison workflow and write artifacts.
- Add specs:
  - `spec/services/nepse/source/hamroshare_stocks_client_spec.rb`
  - `spec/services/nepse/source/hamroshare_company_client_spec.rb`
  - `spec/services/nepse/source/merolagani_market_client_spec.rb`
- `spec/services/nepse/source_csv_export_service_spec.rb`
- `spec/services/nepse/source_comparison_service_spec.rb`
- `spec/services/nepse/security_type_classifier_spec.rb`
- `spec/lib/nepse/csv_number_parser_spec.rb`
- `spec/tasks/nepse_source_comparison_rake_spec.rb`

### Task 1: Add Shared CSV Number Parsing

**Files:**
- Create: `lib/nepse/csv_number_parser.rb`
- Test: `spec/lib/nepse/csv_number_parser_spec.rb`

- [ ] **Step 1: Write the failing parser spec**

Cover:
- parsing `K`, `L`, `Cr`, and `Arb`
- stripping `Rs`, commas, spaces, and `%`
- preserving blanks/placeholders like `-`, `--`, `NA` as nil
- keeping raw strings available when needed by callers
- parsing formatted values consistently for both source CSVs and comparison metrics

- [ ] **Step 2: Run the parser spec to verify it fails**

Run: `bundle exec rspec spec/lib/nepse/csv_number_parser_spec.rb`

- [ ] **Step 3: Write the minimal parser implementation**

Implement:
- decimal-safe numeric conversion
- explicit unit multipliers
- helper methods for numeric, integer, and percent-like values

- [ ] **Step 4: Run the parser spec to verify it passes**

Run: `bundle exec rspec spec/lib/nepse/csv_number_parser_spec.rb`

### Task 2: Add Hamroshare List Client

**Files:**
- Create: `app/services/nepse/source/hamroshare_stocks_client.rb`
- Test: `spec/services/nepse/source/hamroshare_stocks_client_spec.rb`
- Support: `lib/nepse/csv_number_parser.rb`

- [ ] **Step 1: Write the failing list-client spec**

Cover:
- parsing active stock rows from the Hamroshare listed-stocks page
- extracting `symbol`, `name`, `sector`, `ltp`, `% change`, `market_cap`, `paid_up_capital`, `listed_shares`, `high_52w`
- preserving raw values like `source_symbol`, `ltp_raw`, `market_cap_raw`, `listed_shares_raw`, and `listed_on_raw`
- returning a structured error when the list table is missing

- [ ] **Step 2: Run the list-client spec to verify it fails**

Run: `bundle exec rspec spec/services/nepse/source/hamroshare_stocks_client_spec.rb`

- [ ] **Step 3: Write the minimal client implementation**

Implement:
- HTTP fetch with user agent and timeout
- table parser returning normalized list rows
- clear success/error result shape

- [ ] **Step 4: Run the list-client spec to verify it passes**

Run: `bundle exec rspec spec/services/nepse/source/hamroshare_stocks_client_spec.rb`

### Task 3: Add Hamroshare Company Client

**Files:**
- Create: `app/services/nepse/source/hamroshare_company_client.rb`
- Test: `spec/services/nepse/source/hamroshare_company_client_spec.rb`
- Support: `lib/nepse/csv_number_parser.rb`

- [ ] **Step 1: Write the failing company-client spec**

Cover:
- parsing one company page into normalized detail/fundamentals values
- extracting `open`, `high`, `low`, `previous_close`, `volume`, `turnover`, `high_52w`, `low_52w`, `eps`, `pe_ratio`, `book_value`, `pb_ratio`, `paid_up_capital`
- parsing `fiscal_year_raw` and `quarter_raw`
- preserving raw symbol and raw financial text values where parsing is non-trivial
- returning a structured error when expected sections are missing

- [ ] **Step 2: Run the company-client spec to verify it fails**

Run: `bundle exec rspec spec/services/nepse/source/hamroshare_company_client_spec.rb`

- [ ] **Step 3: Write the minimal client implementation**

Implement:
- per-symbol fetch
- company-page parser
- normalized output shape for CSV export and later canonical Hamroshare merge

- [ ] **Step 4: Run the company-client spec to verify it passes**

Run: `bundle exec rspec spec/services/nepse/source/hamroshare_company_client_spec.rb`

### Task 4: Add Merolagani Market Client

**Files:**
- Create: `app/services/nepse/source/merolagani_market_client.rb`
- Test: `spec/services/nepse/source/merolagani_market_client_spec.rb`
- Support: `lib/nepse/csv_number_parser.rb`

- [ ] **Step 1: Write the failing Merolagani market-client spec**

Cover:
- parsing latest-market rows into normalized fields
- extracting `symbol`, `name`, `ltp`, `% change`, `open`, `high`, `low`, `previous_close`, `volume`, and source timestamp
- preserving `source_symbol` and raw text values for non-trivial parsed fields
- returning a structured error when the market table is missing

- [ ] **Step 2: Run the market-client spec to verify it fails**

Run: `bundle exec rspec spec/services/nepse/source/merolagani_market_client_spec.rb`

- [ ] **Step 3: Write the minimal client implementation**

Implement:
- HTTP fetch
- live-market parser
- source timestamp extraction

- [ ] **Step 4: Run the market-client spec to verify it passes**

Run: `bundle exec rspec spec/services/nepse/source/merolagani_market_client_spec.rb`

### Task 5: Add Source CSV Export Service

**Files:**
- Create: `app/services/nepse/source_csv_export_service.rb`
- Modify: `app/services/nepse/source/sharesansar_market_client.rb` only if small export helpers are needed
- Test: `spec/services/nepse/source_csv_export_service_spec.rb`

- [ ] **Step 1: Write the failing export-service spec**

Cover:
- exporting `hamroshare_list.csv`
- exporting `hamroshare_company_details.csv` with continued processing on per-symbol failure
- exporting `sharesansar_market.csv`
- exporting `merolagani_market.csv`
- writing `parse_failures.csv` when detail pages fail
- preserving the required raw-symbol/raw-value columns in each source-specific CSV
- explicitly labeling each stage-1 export in metadata/summary input as `listed-universe oriented` or `trading-snapshot oriented`

- [ ] **Step 2: Run the export-service spec to verify it fails**

Run: `bundle exec rspec spec/services/nepse/source_csv_export_service_spec.rb`

- [ ] **Step 3: Write the minimal export-service implementation**

Implement:
- output directory handling
- CSV headers per spec
- stage-1 exports for all source tables
- stage-2 Hamroshare per-symbol enrichment
- parse failure recording
- source-specific raw-value columns required for later debugging and reconciliation

- [ ] **Step 4: Run the export-service spec to verify it passes**

Run: `bundle exec rspec spec/services/nepse/source_csv_export_service_spec.rb`

### Task 6: Add Source Comparison Service

**Files:**
- Create: `app/services/nepse/source_comparison_service.rb`
- Create: `app/services/nepse/security_type_classifier.rb`
- Test: `spec/services/nepse/source_comparison_service_spec.rb`
- Test: `spec/services/nepse/security_type_classifier_spec.rb`

- [ ] **Step 1: Write the failing comparison-service spec**

Cover:
- canonical Hamroshare merge precedence between list and company-detail exports
- canonical Hamroshare precedence for duplicated `ltp` and `change_percent`
- preserving conflicting raw Hamroshare list/detail values plus provenance when they differ materially
- listed-universe coverage summary
- trading-snapshot overlap comparison
- time-alignment classification with `15 minute` window
- applicability-aware completeness metrics by security type
- symbol alias/unmatched handling
- writing `source_comparison.csv`, `source_comparison_summary.csv`, `unmatched_symbols.csv`, and a merge-conflict artifact if needed
- summary rows for `practicality` and final `decision` categories with rationale

- [ ] **Step 2: Write the failing security-type classifier spec**

Cover:
- classifying common shares, promoter shares, mutual funds, debentures, preference shares, and unknowns
- using source hints first and optional local stock-master reference only as a fallback aid

- [ ] **Step 3: Run the comparison and classifier specs to verify they fail**

Run:
- `bundle exec rspec spec/services/nepse/source_comparison_service_spec.rb`
- `bundle exec rspec spec/services/nepse/security_type_classifier_spec.rb`

- [ ] **Step 4: Write the minimal comparison implementation**

Implement:
- symbol normalization and alias hook
- raw symbol preservation through merge flow
- security type classification for applicability-aware completeness
- canonical merged Hamroshare record
- coverage/completeness/consistency/time-alignment summary rows
- structured summary CSV with `source`, `category`, `metric`, `value`, `rationale`
- practicality summary rows identifying each source as `listed-universe oriented` or `trading-snapshot oriented`
- decision rows with short rationale for source role recommendation
- conflict artifact or conflict columns that preserve list/detail raw values and winning precedence

- [ ] **Step 5: Run the comparison and classifier specs to verify they pass**

Run:
- `bundle exec rspec spec/services/nepse/source_comparison_service_spec.rb`
- `bundle exec rspec spec/services/nepse/security_type_classifier_spec.rb`

### Task 7: Add Rake Task and End-to-End Verification

**Files:**
- Modify: `lib/tasks/nepse.rake`
- Test: `spec/tasks/nepse_source_comparison_rake_spec.rb`

- [ ] **Step 1: Write the failing rake-task spec**

Cover:
- task runs export stage then comparison stage
- task accepts or uses a predictable output directory
- task surfaces failures cleanly without hiding partial output artifacts

- [ ] **Step 2: Run the rake-task spec to verify it fails**

Run: `bundle exec rspec spec/tasks/nepse_source_comparison_rake_spec.rb`

- [ ] **Step 3: Write the minimal task implementation**

Implement:
- one canonical task such as `nepse:compare_sources_csv`
- source-specific progress output
- final artifact location output
- task wiring that exercises export then comparison end to end

- [ ] **Step 4: Run the targeted verification batch**

Run:
- `bundle exec rspec spec/lib/nepse/csv_number_parser_spec.rb`
- `bundle exec rspec spec/services/nepse/source/hamroshare_stocks_client_spec.rb`
- `bundle exec rspec spec/services/nepse/source/hamroshare_company_client_spec.rb`
- `bundle exec rspec spec/services/nepse/source/merolagani_market_client_spec.rb`
- `bundle exec rspec spec/services/nepse/source_csv_export_service_spec.rb`
- `bundle exec rspec spec/services/nepse/source_comparison_service_spec.rb`
- `bundle exec rspec spec/services/nepse/security_type_classifier_spec.rb`
- `bundle exec rspec spec/tasks/nepse_source_comparison_rake_spec.rb`

- [ ] **Step 5: Run the task listing smoke check**

Run: `bundle exec rake -T nepse`

Expected:
- new comparison task is listed

- [ ] **Step 6: Run an end-to-end artifact smoke check**

Run: `bundle exec rake nepse:compare_sources_csv`

Expected:
- command completes without crashing
- output directory is printed
- expected CSV artifacts are created, including comparison summary output

## Notes for Execution

- Keep this workflow separate from production stock sync code paths.
- Prefer fixtures or stubbed HTML in specs; do not rely on live network calls in tests.
- Do not overbuild symbol aliasing. Start with uppercase/trimmed symbols plus a small explicit alias hook only if specs require it.
- Preserve raw values in source-specific CSVs where parsing or unit conversion could otherwise hide ambiguity.
- Use `Stock` or existing master data only as a fallback helper for security-type classification, not as the primary comparison join key.
- Treat Sharesansar and Merolagani as market comparison sources, not true full-fundamentals candidates.
