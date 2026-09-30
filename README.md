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
bin/rails db:prepare     # creates the databases, runs migrations and seeds
bin/dev                  # http://localhost:3000
```

`bin/dev` starts the Rails server together with the Solid Queue worker, which runs
background jobs and the scheduled price sync. Plain `bin/rails server` also works,
but jobs will queue up without running. Development uses three local databases:
`nepse_trade_journal_development`, plus `_queue` (jobs) and `_cable` (WebSocket
messages), all created by `db:prepare`.

`db:prepare` seeds a starter list of 20 NEPSE stocks (from
`db/seeds/nepse_stocks.json`) and the default trading strategies. Then pull today's
prices for them (see [Getting the latest stock prices](#getting-the-latest-stock-prices)):

```bash
bin/rails nepse:sync_market
```

Then load the reference data: every listed security with its real name, sector and
type, NEPSE and sector index history, dividends and fundamentals (about an hour,
mostly waiting on Merolagani). See [Stock data sources](#stock-data-sources).

```bash
bin/rails nepse:data:all
```

VCP and price-action analysis need months of daily history, which the market sync
does not provide. Load about a year of it once (this takes roughly 30–45 minutes
for all stocks, because the source answers slowly):

```bash
bin/rails "nepse:backfill_history[365]"             # all active stocks
bin/rails "nepse:backfill_history[365,NABIL NICA]"  # or just a few symbols
```

The backfill reads adjusted daily bars from Merolagani's chart endpoint, replaces
stored rows in that range, and recalculates moving averages afterwards.

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
| Watchlist         | `/watchlist`           | Tracked setups, entry zones, alerts             |
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
`stock_daily_prices` for daily history) and the app reads from there.

**While `bin/dev` is running, prices update automatically.** Every 5 minutes during
market hours (Mon–Fri, 11:00–15:15 Nepal time) `SyncMarketPricesJob` pulls the
Sharesansar market table for all listed stocks and pushes the new prices to open
browsers over the WebSocket. At 4:00 PM Nepal time it records the closing prices.
If Sharesansar is down at that point, it falls back to the per-symbol price API.

You can also sync by hand:

### Option 1: Rake tasks

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
# Sync the full market table now and push it to open browsers
curl -X POST http://localhost:3000/api/v1/data_imports/sync_market

# Refresh selected symbols from the live per-symbol API, then return them
curl "http://localhost:3000/api/v1/stocks/current_prices?symbols=NABIL,NICA&refresh=true"

# Run the daily price import for every active stock
curl -X POST http://localhost:3000/api/v1/data_imports/sync_daily_prices
```

### Option 3: In the app

- **`/stocks`** lists every stock with its price, change % and fundamentals, and shows
  when the prices were last updated. It flags them as "May be out of date" if they are
  older than a normal weekend. **Sync Latest Prices** pulls the market table right away.
- The **refresh button in the header** makes the API re-fetch the last traded price
  from the per-symbol API. It fetches the stocks on screen (for example, your portfolio
  holdings), or up to 200 stocks if none are being tracked. Expect it to be slow.
- During market hours (Mon–Fri, 11:00–15:00 Nepal time) the frontend subscribes to
  the `StockPricesChannel` WebSocket and polls `/stocks/current_prices` every 30
  seconds if the socket drops. Outside market hours it stops fetching.

### Importing prices from CSV

```bash
bin/rails "nepse:import_csv[path/to/prices.csv,prices]"
bin/rails "nepse:import_csv[path/to/financials.csv,financials]"
```

### Scheduled sync

The schedule lives in `config/recurring.yml` and runs whenever a Solid Queue worker
is running (`bin/dev`, or `bin/jobs` on its own). Market holidays are not modelled
yet, so on a holiday the job simply re-reads the previous session's prices.

---

## Stock data sources

All sources are free and need no account. For each field the first source that has
a value wins, and the source and time are stored in the record's `field_sources`.

| Data | 1st source | Fallback |
| ---- | ---------- | -------- |
| Listed securities: name, sector, type, listed/delisted | Chukul company list | — |
| Live and daily prices | Sharesansar market table | per-symbol price API |
| Daily price history (1 year) | Merolagani chart data | — |
| NEPSE and 12 sector index history | Chukul | Merolagani |
| EPS, P/E, P/B, book value, net profit, paid-up capital, ROE, ROA, distributable profit per share | Chukul stock details | Merolagani company page |
| Shares outstanding, 52-week range | Merolagani company page | Chukul |
| Cash dividend and bonus history, book-close and AGM dates | Chukul | Merolagani |

Notes:
- `distributable_profit_per_share` is what Chukul labels "DPS". It can be negative
  and is **not** the dividend paid; dividends are in `stock_dividends`.
- Promoter shares and debentures publish no fundamentals and are skipped by the
  fundamentals sync. Mutual funds get shares outstanding only (their pages show NAV).
- NEPSE's official API needs a token and NepseAlpha blocks automated requests, so
  neither is used. Chukul's API is undocumented; requests are rate-limited.

| Command | What it does |
| ------- | ------------ |
| `bin/rails nepse:data:universe` | Add and correct listed securities |
| `bin/rails "nepse:data:indices[365]"` | Index history for the last N days |
| `bin/rails nepse:data:dividends` | Dividend and bonus history |
| `bin/rails "nepse:data:fundamentals[NABIL NICA]"` | Fundamentals (all securities if no symbols; ~5s each) |
| `bin/rails nepse:data:all` | Everything above, then a report |
| `bin/rails nepse:data:report` | How complete the data is, per field |

Schedule (with `bin/dev`): securities, dividends and index history daily at 4:30 PM
Nepal time; fundamentals on Saturday morning.

## Watchlist and entry zones

Track a stock toward an entry using a VCP or price-action setup.

1. **Add a stock.** On `/screener`, use **Track** on any row, or on a stock's page
   (`/screener/NABIL`) use **Add to watchlist**. Pick a setup:
   - **VCP breakout:** zone from the pivot to 3% above it; the setup fails below the
     low of the last contraction.
   - **Pullback to support:** zone from the nearest support to 2% above it; the setup
     fails 3% below support.

   The target is the nearest resistance at least 1R above the zone, or 2R when there
   is none. Every level can be edited before adding. The dialog warns when the
   pattern does not qualify as a VCP. A qualified VCP has 2-4 contractions, the first
   8-35% deep, each at most 80% as deep as the one before, the last at most 10%, a
   base of at least 15 trading days, lower average daily volume in the last
   contraction than the first, and a score of 60+. Swings are measured with a
   threshold of twice the stock's median daily range (3-8%).
2. **Watch it.** `/watchlist` shows each setup's price against its zone on a price
   ladder, the levels, risk:reward, and a snapshot of the analysis from the day it was
   added. The stock's chart on `/screener/SYMBOL` shows the zone, invalidation and
   target lines.
3. **Get alerts.** After every price sync (every 5 minutes in market hours) each setup
   is checked, and an alert is raised when it moves into a new state:
   - **Breakout confirmed / Breakout, low volume:** a VCP crossed into its zone from
     below, on at least / under 1.5x its 50-day average volume.
   - **Entered zone:** a pullback setup reached its zone.
   - **Extended:** price ran above the zone.
   - **Invalidated:** price hit the invalidation level. The setup stays invalidated
     until you choose **Reset setup**.

   Alerts appear on `/watchlist` and as a count next to **Watchlist** in the sidebar.
4. **Check the entry.** Each card has an **Entry checklist**: qualified VCP (or an
   uptrend for pullbacks), closed above the pivot / inside the zone, volume at least
   1.5x average at the close, market regime not weak, sector index beating NEPSE over
   20 sessions, risk:reward at least 2R, and price not above the zone. Each rule shows
   met, not met, waiting or not applicable. These are rule checks, not advice.
5. **End-of-day verdict.** After the 4 PM close sync each setup is judged on the close
   and full-day volume: **Close confirmed**, **Close, low volume**, **Failed at close**
   (reached the zone but closed below it) or **Held zone at close** (pullbacks).
6. **Plan the trade.** **Create plan** opens `/trade/new?watchlist=ID` with the entry,
   stop, target and a thesis filled in, plus position sizing from your account size
   and risk per trade. Saving creates a trade plan and marks the setup **Planned**.

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
| `NEPSE_TRADING_DAYS`           | Trading weekdays, 0 = Sunday (default `1,2,3,4,5`, Mon–Fri). |
| `VITE_NEPSE_TRADING_DAYS`      | Same setting for the frontend's market-open badge.         |

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
