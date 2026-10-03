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
| Market overview   | `/market`              | NEPSE index trend, breadth, heatmap, sectors    |
| Daily digest      | `/digest`              | End-of-day summary; card on the dashboard       |
| Positions         | `/positions`           | Bought stocks vs stop and target, live P&L in R |
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
curl http://localhost:3000/api/v1/market/heatmap | head -c 500
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
| Floorsheet (every trade with buyer and seller broker), broker names | Chukul | — |

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
| `bin/rails "nepse:data:floorsheet[120]"` | Floorsheet for recent sessions not stored yet (~3s each) |
| `bin/rails nepse:data:setups` | Rebuild entry-readiness snapshots (indicators first) |
| `bin/rails nepse:data:report` | How complete the data is, per field |

Schedule (with `bin/dev`): securities, dividends, index history, broker names and the
day's floorsheet daily at 4:30 PM Nepal time; entry readiness at 4:45 PM; fundamentals
on Saturday morning. The floorsheet is stored as daily totals per stock and broker
(~13k rows a day).

## Entry readiness (every stock)

After each close (4:45 PM Nepal time, or `bin/rails nepse:data:setups`) every equity
with enough history gets a snapshot:

- **Trend template:** seven moving-average and 52-week rules for a stage-2 uptrend
  (price above the 150- and 200-day averages, 150 above 200, 200 rising for a month,
  50 above 150 and 200, price above the 50-day, 30%+ above the 52-week low, within
  25% of the 52-week high) plus relative strength 70+.
- **RS rating (1-99):** weighted 3/6/9/12-month performance ranked against all stocks.
- **Best setup and zone:** four setup types are tried, and the one whose zone the
  price is in (or closest to) is kept, with whether the price is too early, in the
  entry zone, extended or failed:

  | Setup | Zone | Fails |
  | ----- | ---- | ----- |
  | VCP breakout | pivot to +3% | below the last contraction's low |
  | Pullback to support | nearest support to +2% (quality +20 for a bullish candle at support) | 3% below support |
  | Pullback to a rising average | rising 20-day average (or 50-day if price is under the 20-day) to +2%, in an uptrend above a rising 50-day | 4% below the average |
  | Flat-base breakout | base high (15-60 sessions, at most 15% deep, within 5% of the 52-week high) to +3% | base low, at most 8% below the pivot |

  Breakout setups (VCP, flat base) need volume to confirm and alert on a break
  above the pivot; pullback setups are judged by holding their zone.
- **Broker flow:** from the daily NEPSE floorsheet (every trade with its buying and
  selling broker). Over 20 sessions, the net shares bought by the 5 largest net buyers
  and sold by the 5 largest net sellers, as % of volume; the flow score is the
  difference. +10 or more is **accumulation**, -10 or less **distribution**, otherwise
  neutral. Stocks with under NPR 20M turnover in the window stay neutral (thin trading).
- **Entry readiness (0-100):** trend template 30 + setup quality 25 + market regime 15 +
  sector index vs NEPSE 15 + broker flow 15.

A stock is listed under **Entry zone now** when the price is inside the zone, at least
5 of 7 trend rules pass and readiness is 60+, **and it passes the tradability guards**
(`Setups::Guards`, measured point in time in the nightly snapshot):

| Guard | Rule | Why |
| ----- | ---- | --- |
| Thin volume | Average daily turnover over the last 20 NEPSE sessions under NPR 2M (`NEPSE_MIN_TURNOVER`); sessions the stock didn't trade count as 0 | A small order moves the price; fills are poor |
| At upper circuit | Closed +9.5% or more (NEPSE's daily limit is ±10%) | Few sellers, the next open often gaps; wait for another session |
| At lower circuit | Closed -9.5% or less | Few buyers; stops and exits may not fill |

A stock that fails a guard keeps its readiness and zone, shows a badge in the screener
and on its readiness card, and is listed under **Held back by guards** below the board.
The watchlist entry checklist has matching rules: average turnover (from the nightly
snapshot) and "not at the ±10% daily limit" (from today's live change, so it also warns
during the session). The backtest doesn't trade held-back signals. Where to see it:

- `/screener`, **Entry zone now** tab (default), plus a readiness column on **All setups**
- `/screener/SYMBOL`: a **Broker flow** card (state, flow score, 5- and 20-session
  figures, daily net shares of the top buyers and sellers, top brokers with names and
  average prices), the **Entry readiness** card and a candlestick chart with volume,
  50/200-day averages, the entry-zone band, invalidation / target / pivot lines and
  contraction markers (your watchlist levels when you track the stock)
- **RS line vs NEPSE** (lower pane of that chart): the close divided by the NEPSE
  index, 100 at the first point; rising means the stock is beating the market. Dots
  mark RS new highs (above the prior 252 sessions, or all history when shorter);
  green dots are new RS highs made while price was still below its own high (RS
  leading price). A caption above the chart gives the RS change over 20 and 60
  sessions and the last RS new high.
- **Readiness history**: a 60-session sparkline on the Entry readiness card (dashed
  line at 60, dots on sessions that met the entry-zone criteria) and a small one under
  each gauge on **Entry zone now**, scaled to that stock's range so the trend shows

These are rule checks on stored data, not recommendations; the app never labels
anything buy or sell.

## Corporate actions (book closes and bonus shares)

A bonus issue lowers the share price mechanically on the book close (a 10% bonus
divides it by 1.10). Without handling it, levels and charts would read that as a
breakdown. Using the stored dividend data (Chukul, with book-close and AGM dates):

- **Upcoming book closes** (next 45 days) show on the stock page's **Corporate
  actions** card with the dividend history, and as a badge on watchlist cards, the
  Entry zone board and the screener (bonus book closes are highlighted).
- **Entry checklist:** "No bonus book close in the next 10 days" fails when one is
  due; cash-only book closes pass with a note.
- **Watchlist:** a "Book close soon" alert 5 days ahead; after a bonus book close the
  item's zone, invalidation, stop, target and pivot are divided by (1 + bonus%) and a
  "Levels adjusted" alert is sent (once per book close; bonuses before the item was
  added are ignored).
- **Price history:** 1-10 days after a bonus book close the stock's bonus-adjusted
  history is re-fetched from Merolagani and its indicators recalculated, so charts,
  moving averages and patterns don't see a fake drop.

These run in the daily 4:30 PM job. Right-share issues aren't covered yet (no free source found).

## Backtest

`/backtest` shows how the app's signals would have played out, using snapshots
rebuilt for past sessions from only the data available on each day (no look-ahead;
an as-of rebuild of the latest session matches the nightly build exactly).

- **Simulated trades** for every "Entry zone now" signal, one open trade per stock:
  enter at the next session's open; exit at the invalidation stop, the target (a gap
  through either exits at that day's open; both on one day counts as the stop), or at
  the close after 20 sessions. Net of 0.8% round-trip costs. Win rate, average
  return, average R, profit factor, holding time and exit reasons.
- **Forward returns** after 5, 10 and 20 sessions, with the excess over NEPSE, by
  readiness band, entry-zone flag, broker flow, zone state and trend-template rules,
  with sample sizes (groups under 30 samples are marked).

```bash
bin/rails "nepse:data:setup_history[120]"   # past snapshots, ~12s a session (once)
bin/rails nepse:data:backtest               # run and save; also runs nightly at 4:45 PM
```

Only NEPSE index sessions count; stray price rows on other dates are ignored. Caveats
(short, mostly weak-market period; overlapping daily samples; today's listings only;
idealised fills) are listed on the page.

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

## Positions

After you buy on TMS, record it in the app so it can track the trade:

- **Watchlist card → Mark as bought:** price (defaults to the latest), quantity and date.
  The stop and target come from the setup; the stop is capped at **8% below your entry**
  when the setup's invalidation is further away. The dialog previews risk per share,
  reward:risk and what the buy loses if the stop is hit. The card then shows
  **Holding**, and entry alerts and end-of-day verdicts stop for it.
- **`/positions`:** each open position with quantity, average price (weighted across
  buys), live P&L in rupees, % and **R** (the move in units of the risk at entry), stop
  and target with the distance to each, risk at the stop, days held and the **T+2
  sellable date**. Edit the stop/target/notes, **Add a buy** (adds to the same
  position), or remove a mistaken fill (removing the last one returns the stock to your
  watchlist).

Figures are before fees and tax; NEPSE costs, a position-size calculator and sell-rule
alerts (stop, target, time stop and more, also on Telegram) come next. Manual test steps
are in `docs/qa/manual-test-plan.md` section H13.

## Daily digest

After the nightly snapshots (4:45 PM Nepal time, Mon-Fri), `BuildDailyDigestsJob` builds
one digest per user for that session (`Digests::Builder`), with three sections each user
can switch on or off in **Settings → Daily Digest** (saved to the account):

- **Market summary:** NEPSE close and change, regime, breadth, best and weakest sectors
- **Entry zone changes:** stocks that joined or left **Entry zone now** since the previous
  session, and charts held back by the liquidity/circuit guards
- **Watchlist status:** today's end-of-day verdicts, alerts raised during the session and
  book closes due within 10 days

Read it at `/digest` (pick an earlier session from the dropdown; opening one marks it
read) or in the card at the top of the dashboard. Build it by hand with
`bin/rails nepse:data:digest`. It is in-app only; nothing is emailed.

## Telegram messages

Each user can link their own Telegram chat (**Settings → Telegram**) and get:

- **Watchlist stock enters its zone:** during market hours, within about 5 minutes of a
  tracked stock moving into its entry zone (for breakout setups, breaking out into it),
  with price, zone, stop, target, R:R, setup, readiness, trend rules, RS and warnings
  (thin volume, circuit, bonus book close within 10 days)
- **New on Entry zone now:** after the close, one message listing the stocks that newly
  met every entry-zone rule (top 10 by readiness) with the same levels and context

At most one message per stock per day for each kind. Both can be switched off in Settings.

Setup (once):

1. In Telegram, message **@BotFather**, send `/newbot`, and copy the bot token.
2. Start the Rails server with the token, e.g. add `export TELEGRAM_BOT_TOKEN=...` to your
   shell profile (or `bin/rails credentials:edit` → `telegram: { bot_token: ... }`), then
   restart `bin/dev`. Keep the token secret; don't commit it.
3. In the app: **Settings → Telegram → Connect Telegram**. It shows your bot's @name and
   an 8-character code. In Telegram (phone or computer), open the bot and **send it the
   code as a message**. The page shows "Connected" within a few seconds. **Send test
   message** checks it. (The "open it from here" link can carry the code with Start, but
   Telegram often drops it, e.g. for forwarded links, so sending the code is the reliable way.)

The app reads the bot's messages every minute (no public URL or webhook needed); send
`/stop` to the bot to disconnect. Without a token, Telegram stays off.

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
| `NEPSE_MIN_TURNOVER`           | Liquidity guard: min average daily turnover in NPR (default `2000000`). |
| `TELEGRAM_BOT_TOKEN`           | Telegram bot token from @BotFather; enables Telegram messages. |

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
