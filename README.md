# NEPSE Trade Journal

A trading journal and analysis workspace for Nepal Stock Exchange (NEPSE) traders.
Plan trades, record executions and results, keep a daily journal, track your
portfolio, and review analytics, market breadth and VCP (volatility contraction
pattern) setups.

- **Backend:** Ruby on Rails 8 (API mode), PostgreSQL, Devise + JWT, ActionCable
- **Frontend:** React 19 + TypeScript + Vite, Tailwind CSS, React Query, Zustand, Recharts (in `frontend/`)

See [PROJECT_DOCUMENTATION.md](./PROJECT_DOCUMENTATION.md) for the full feature list
and [PROGRESS.md](./PROGRESS.md) for the build log.

---

## Prerequisites

| Tool       | Version            | Notes                                                       |
| ---------- | ------------------ | ----------------------------------------------------------- |
| Ruby       | 3.2.0              | Pinned in `.ruby-version`. Use rbenv/asdf, **not** macOS system Ruby (2.6). |
| Bundler    | 2.x                | `gem install bundler`                                       |
| PostgreSQL | 14+                | Must be running locally (`pg_isready` should say "accepting connections"). |
| Node.js    | 20+                | With npm.                                                   |

With rbenv, make sure the shims are on your `PATH` so `ruby -v` prints 3.2.0 in the
project folder:

```bash
eval "$(rbenv init -)"
ruby -v   # => ruby 3.2.0
```

## Running locally

You need two terminals: one for the Rails API and one for the React frontend.

### 1. Backend (Rails API on port 3000)

```bash
bundle install
bin/rails db:prepare     # creates the database, runs migrations and seeds
bin/rails server         # http://localhost:3000
```

`db:prepare` seeds a starter list of 20 NEPSE stocks (from
`db/seeds/nepse_stocks.json`) and the default trading strategies. Then pull today's
prices for them (see [Getting the latest stock prices](#getting-the-latest-stock-prices)):

```bash
bin/rails nepse:sync_market
```

> The market sync only updates stocks that already exist in the database. It does not
> add new ones. To track more stocks, add them to `db/seeds/nepse_stocks.json` and run
> `bin/rails nepse:seed_stocks`.

Health check: `curl http://localhost:3000/up` should return a green page.

### 2. Frontend (Vite on port 5173)

```bash
cd frontend
npm install
npm run dev              # http://localhost:5173
```

Vite proxies `/api` and `/cable` to `http://localhost:3000`, so no extra config is
needed. Open **http://localhost:5173** and you land on `/dashboard`.

### Login in development

There is no login screen yet. In development and test, the API automatically signs
requests in as a local demo user (created on first request) when no JWT is sent, so
you can use the app straight away.

### Checking the app

| Page              | URL                    | What to check                                   |
| ----------------- | ---------------------- | ----------------------------------------------- |
| Dashboard         | `/dashboard`           | KPI cards and recent trades                     |
| Market overview   | `/market`              | NEPSE index trend, breadth, sectors             |
| VCP screener      | `/screener`            | Setup scores, breakout watch list               |
| Stock analysis    | `/screener/NABIL`      | Candles, moving averages, levels, VCP breakdown |
| Stocks explorer   | `/stocks`              | All stocks with price, change %, fundamentals   |
| New trade         | `/trade/new`           | Plan → Execute → Result wizard                  |
| Trades            | `/trades`              | Filters, trade detail, CSV export               |
| Portfolio         | `/portfolio`           | Holdings, P&L, sector allocation                |
| Analytics         | `/analytics`           | Equity curve, strategy and mistake breakdowns   |
| Journal           | `/journal`             | Daily entries, calendar, weekly review PDF      |
| Settings          | `/settings`            | Preferences, export/import, backups             |

Quick API checks:

```bash
curl http://localhost:3000/api/v1/stocks | head -c 500
curl "http://localhost:3000/api/v1/stocks/current_prices?symbols=NABIL,NICA"
curl http://localhost:3000/api/v1/market/overview | head -c 500
```

### Running the tests

```bash
bundle exec rspec          # backend specs
cd frontend && npm test    # frontend (Vitest)
cd frontend && npm run lint
cd frontend && npm run build
```

---

## Getting the latest stock prices

Prices are stored in the database (`stocks` for the latest snapshot,
`stock_daily_prices` for daily history) and the app reads from there. **They only
change when a sync runs**, so refresh them before you look.

### Option 1: Rake tasks (recommended)

```bash
# Latest market table for all listed stocks from Sharesansar
# (LTP, open/high/low/close, change %, volume, turnover, 52-week range)
bin/rails nepse:sync_market

# Company fundamentals from Merolagani (EPS, P/E, book value, P/B, market cap).
# Slower: one request per stock.
bin/rails nepse:sync_fundamentals

# Both of the above in one go
bin/rails nepse:sync_stock_basics

# Per-symbol last traded price from the free NEPSE API (LTP only)
bin/rails nepse:fetch_prices
```

### Option 2: API

```bash
# Refresh selected symbols from the live per-symbol API, then return them
curl "http://localhost:3000/api/v1/stocks/current_prices?symbols=NABIL,NICA&refresh=true"

# Run the daily price import for every active stock
curl -X POST http://localhost:3000/api/v1/data_imports/sync_daily_prices
```

### Option 3: In the app

- **`/stocks`** lists every stock with its stored price, change % and fundamentals.
- The **refresh button in the header** makes the API re-fetch the last traded price
  from the per-symbol API. It fetches the stocks on screen (for example, your portfolio
  holdings), or up to 200 stocks if none are being tracked. Expect it to be slow.
- During market hours (Sun–Thu, 11:00–15:00 Nepal time) the frontend subscribes to
  the `StockPricesChannel` WebSocket and polls `/stocks/current_prices` every 30
  seconds if the socket drops. Outside market hours it stops fetching.

> **Current limitation:** the "Sync Daily Prices" button on `/stocks` calls an
> endpoint that does not exist yet, and the WebSocket only broadcasts after a trade
> result is saved. Use the rake tasks above to get fresh prices for now.

### Importing prices from CSV

```bash
bin/rails "nepse:import_csv[path/to/prices.csv,prices]"
bin/rails "nepse:import_csv[path/to/financials.csv,financials]"
```

### Scheduled sync

`config/recurring.yml` schedules `FetchNepseDailyPricesJob` daily at 10:15 UTC
(4:00 PM Nepal time). It only runs when a Solid Queue worker is running. That is set
up in production, but not in the default local setup, so run the rake tasks by hand
during development.

---

## Configuration

All environment variables are optional in development.

| Variable                       | Purpose                                                    |
| ------------------------------ | ---------------------------------------------------------- |
| `JWT_SECRET`                   | Secret for signing API tokens. **Set this in production.** |
| `NEPSE_FREE_API_TEMPLATE`      | Per-symbol price API URL, with `%{symbol}` placeholder.    |
| `NEPSE_FREE_API_KEY`           | API key for that price API, if it needs one.               |
| `NEPSE_FREE_API_KEY_HEADER`    | Header name for the key (default `X-API-Key`).             |
| `YONEPSE_BASE_URL`             | Base URL for the Yonepse market data provider.             |
| `NEPSE_HISTORICAL_BASE_URL`    | Base URL for historical price data.                        |
| `DEFAULT_MARKET_DATA_PROVIDER` | Market data provider for ingestion jobs.                   |
| `VITE_API_BASE_URL`            | Frontend API base URL (default `/api/v1` via Vite proxy).  |
| `VITE_CABLE_URL`               | Frontend WebSocket URL (default derived from the API URL). |

## Project layout

```
app/
  controllers/api/v1/   REST API (stocks, trades, journal, analytics, market, screener, data)
  channels/             ActionCable StockPricesChannel
  services/nepse/       Stock list, price and fundamentals sync (Sharesansar, Merolagani, APIs)
  services/indicators/  Moving averages and other indicators
  services/vcp/         VCP detection
  services/scanner/     Screener engine
  services/market_context/  Market regime, sector and liquidity analysis
  jobs/                 Price sync, indicators, analytics, backups
lib/tasks/              nepse:* rake tasks
frontend/src/
  pages/                Route pages
  hooks/useStockPrices.ts   Live price WebSocket + polling
  stores/               Zustand stores
docs/superpowers/       Design specs and implementation plans
```

## Deployment

The app ships with a `Dockerfile` and Kamal config (`config/deploy.yml`). Secrets are
read from `.kamal/secrets`, which is kept out of version control.
