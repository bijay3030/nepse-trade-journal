# NEPSE Analysis Dashboard Design

The dashboard derives all market and setup data from persisted market-index history, daily stock prices, and daily indicators. Missing observations are represented as empty or unavailable values rather than fabricated prices. The existing PlatformLayout, UI components, Tailwind tokens, Recharts, and responsive patterns remain the visual foundation.

## Data and API

- `GET /api/v1/market/overview` supplies the latest dated NEPSE index trend, regime, turnover, stock breadth, and per-sector summaries. Snapshot dates must agree with the available index and stock sessions; the view reports the date explicitly.
- `GET /api/v1/screener` supplies one row per eligible active equity with price history, including its calculated pivot and distance, score, liquidity, trend, neutral setup state, sector, and market regime.
- `GET /api/v1/screener/:symbol` supplies dated candles with available moving averages, support/resistance, price-action structure, VCP contraction sequence and score breakdown, plus market/sector context. Unknown symbols return 404; insufficient history produces neutral/empty analysis without invented signals.

Calculations belong in focused analysis objects; controllers serialize responses without implementing algorithms. The screener and detail endpoints use the same stock analysis to keep classifications consistent. Pivots come from observed highs; breakdown components reflect actual observed price/volume structure. Never produce trading advice labels.

## Frontend

Mount the existing market overview, VCP screener, and stock analysis pages in the platform route tree and navigation. Retain the existing Stocks explorer and trade-journal dashboard. Watchlist and breakout tabs share active filters; breakout watch includes only stocks at/near a calculated pivot, ordered by distance. Rows navigate by an accessible symbol link. The stock detail page uses existing charts/cards for close, volume, averages, levels, contractions, score, structure, and context. On narrow viewports, controls wrap and tables scroll horizontally.

## Errors and verification

Loading, empty datasets, missing analysis, and request errors display existing components with retry where useful. Rails request/calculation specs verify response shape, dates, derived values, sparse data, and 404s. Vitest interaction tests verify filters, breakout selection, navigation, and neutral labels; build and lint checks ensure integration.
