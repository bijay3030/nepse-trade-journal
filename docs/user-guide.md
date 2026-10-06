# NEPSE Trade Journal: user guide

What every feature is, why it exists, how it works, how to use it, how to check it
works (QA), and how to use it all for **paper trading** before risking real money.

The app checks rules against stored market data. It never says "buy" or "sell", and
nothing in it is investment advice. Every decision, and every order on TMS, is yours.

**Contents**

1. [Running the app](#1-running-the-app)
2. [Paper trading: set up a separate account](#2-paper-trading-set-up-a-separate-account)
3. [How a trade flows through the app](#3-how-a-trade-flows-through-the-app)
4. [Features](#4-features)
   - [4.1 Market data and the daily schedule](#41-market-data-and-the-daily-schedule)
   - [4.2 Market Overview and market direction](#42-market-overview-and-market-direction)
   - [4.3 Screener and entry readiness](#43-screener-and-entry-readiness)
   - [4.4 Entry zone now (the board) and guards](#44-entry-zone-now-the-board-and-guards)
   - [4.5 Badges: stretch, breakout age, base count, volume, EPS](#45-badges-stretch-breakout-age-base-count-volume-eps)
   - [4.6 Stock page](#46-stock-page)
   - [4.7 Watchlist and setups](#47-watchlist-and-setups)
   - [4.8 Watchlist alerts](#48-watchlist-alerts)
   - [4.9 Entry checklist](#49-entry-checklist)
   - [4.10 Position size, costs, cautious size, heat warning](#410-position-size-costs-cautious-size-heat-warning)
   - [4.11 Positions: recording buys](#411-positions-recording-buys)
   - [4.12 Sell-rule alerts](#412-sell-rule-alerts)
   - [4.13 Portfolio heat and sector exposure](#413-portfolio-heat-and-sector-exposure)
   - [4.14 Selling, closing, after-tax results and reviews](#414-selling-closing-after-tax-results-and-reviews)
   - [4.15 Corporate actions (book closes, bonus shares)](#415-corporate-actions-book-closes-bonus-shares)
   - [4.16 Backtest](#416-backtest)
   - [4.17 Daily digest](#417-daily-digest)
   - [4.18 Telegram](#418-telegram)
   - [4.19 Settings](#419-settings)
   - [4.20 Older pages](#420-older-pages)
5. [Paper-trading routine](#5-paper-trading-routine)
6. [Limitations to keep in mind](#6-limitations-to-keep-in-mind)

---

## 1. Running the app

Two terminal tabs in the project folder:

```bash
bin/dev
```

```bash
npm --prefix frontend run dev
```

Open **http://localhost:5173**. `bin/dev` runs the API (port 3000) **and** the background
jobs (price sync, nightly snapshots, alerts). If `bin/dev` isn't running, nothing updates.

**Market hours** (Nepal time): Monday–Friday, 11:00–15:00. Features marked
*(market hours)* below can only be checked then; outside those hours the app shows the
last close.

---

## 2. Paper trading: set up a separate account

**Why a separate account:** positions, watchlist, alerts, settings and closed-trade
statistics all belong to an account. Paper trades kept in their own account never mix
with real ones, and you can compare the two later.

Locally the app signs you in as the first account (`trader@nepse.com`) unless you log in.

1. Create the paper account (you'll type a password; it isn't shown):
   ```bash
   bin/rails 'users:create[paper@local.test]'
   ```
2. Start the frontend with the login page on (stop the other frontend first):
   ```bash
   VITE_REQUIRE_LOGIN=true npm --prefix frontend run dev
   ```
3. Open http://localhost:5173, log in as `paper@local.test`.
4. **Settings → Capital & Risk:** enter the capital you'd really trade with (for example
   Rs 5,00,000), risk per trade 1%, max open risk 6%, max per sector 30%. Save.
5. Optional: **Settings → Telegram** to get alerts on your phone (section 4.18). Each
   account links its own chat.

Use this account for everything in this guide. **Sign out** (Account menu) and log in as
`trader@nepse.com` when you want your real account.

**Paper-trading rules that keep results honest:**

- Record a buy only at a price you **could actually have got**: the live price when the
  alert came, or the next session's open. Never a better price from hindsight.
- Use the **suggested quantity** (10-share lots), not "whatever feels right".
- When a sell rule fires (stop, target, time stop), act on it the way you would with
  real money, and record the sell at the real price at that moment.
- Write the **review** for every closed trade.
- Don't delete losing trades.

---

## 3. How a trade flows through the app

```
Market data (prices every 5 min, floorsheet + indicators nightly)
   │
   ▼
Nightly snapshot of every stock ── trend template, RS, setups, zones, readiness, guards
   │
   ├─▶ Screener / Entry zone now board ── which charts meet every rule today
   │
   ▼
Watchlist (you track a setup) ── live alerts: approaching, breakout/entered zone, extended, failed
   │                              entry checklist, position size, heat warning
   ▼
Mark as bought (position) ── live P&L, R, T+2, sell-rule alerts, portfolio heat
   │
   ▼
Record a sell ── after-tax result, R, MAE/MFE ── review ── closed-trade statistics
   │
   ▼
Backtest + daily digest + Telegram ── is the process working?
```

---

## 4. Features

Each feature below has: **Why** (the problem it solves), **How it works**, **Use it**,
**QA** (steps and expected results) and, where useful, **Paper trading** (how to use it
in practice).

### 4.1 Market data and the daily schedule

**Why:** every rule in the app is only as good as its data. NEPSE has no official free
API, so the app collects from public sources on a schedule.

**How it works:**

| When (Nepal time) | What |
| ----------------- | ---- |
| Every 5 min, Mon–Fri 11:00–15:15 | Live prices for all stocks; watchlist and position alerts checked after each sync |
| Every minute | Telegram messages to the bot (linking, `/stop`) |
| 4:00 PM Mon–Fri | Closing prices; end-of-day verdicts for watchlist setups; close-based sell rules |
| 4:30 PM Mon–Fri | Securities list, dividends and book closes, index history, bonus adjustments, floorsheet |
| 4:45 PM Mon–Fri | Indicators, then every stock's snapshot (section 4.3), then the backtest, daily digest and Telegram "new on the board" |
| Saturday 9:45 AM | Fundamentals (EPS, P/E, growth rate…), about an hour |
| 9:30 PM daily | Housekeeping (finished jobs; on the hosted version, trimming old history) |

The header shows whether the market is open or closed.

**QA:**

1. During market hours, open `/stocks`. Prices change within about 5 minutes.
2. After 4:45 PM on a trading day, `/screener` shows today's date in the board heading.
3. Terminal check of what's stored:
   ```bash
   bin/rails runner 'p StockDailyPrice.maximum(:traded_on), StockSetupSnapshot.maximum(:traded_on)'
   ```
   Both show the latest trading day.

### 4.2 Market Overview and market direction

**Why:** most stocks follow the market. Buying breakouts in a falling market fails more
often, so you want to know the market's state before looking at single stocks.

**How it works:**

- **Overview:** NEPSE close and change, regime (strong / neutral / weak from the index
  trend and breadth), advancers and decliners, % of stocks above their 50- and 200-day
  averages, sector table.
- **Market direction** (`Setups::MarketDirection`), the method William O'Neil (IBD) uses:
  - A **distribution day** is the index closing down 0.5%+ on higher turnover than the
    day before (institutions selling). It counts for 25 sessions or until the index
    rallies 5% above it.
  - **Uptrend → Under pressure** at 4 distribution days; **Correction** at 6, or after a
    10% fall from the high.
  - A correction ends with a **follow-through day**: from day 4 of a rally attempt, the
    index gains 1.5%+ on higher turnover.
  - Thresholds are scaled up from IBD's US ones because NEPSE moves about twice as much.
- In our backtest the state **did not predict** later returns well (one correction in
  the data), so it doesn't change the board. It does add a **cautious size** suggestion
  (section 4.10).

**Use it:** check `/market` before the session. Under pressure or in a correction, be
more selective and consider the cautious size.

**QA:**

1. `/market`: a card reads "Market: Uptrend · N distribution days in the last 25 sessions
   · index −X% from its high · last follow-through D Mon".
2. The same card, compact, sits above **Entry zone now** on `/screener`.
3. Terminal:
   ```bash
   bin/rails runner 'p Setups::MarketDirection.call.slice(:state, :distribution_days, :size_factor)'
   ```

### 4.3 Screener and entry readiness

**Why:** NEPSE has 250+ stocks. Checking each chart by hand every night is impossible;
the screener applies the same rules to all of them, without bias.

**How it works:** after each close, every stock with 60+ sessions of history gets a
**snapshot**:

- **Trend template** (Mark Minervini's stage-2 rules): price above the 150- and 200-day
  averages, 150 above 200, 200 rising for a month, 50 above 150 and 200, price above the
  50-day, 30%+ above the 52-week low, within 25% of the 52-week high, plus RS 70+.
- **RS rating (1–99):** 3/6/9/12-month performance ranked against every stock (99 =
  strongest). Leaders tend to keep leading.
- **Setup and zone:** six setup types are tried and the most actionable kept:

  | Setup | Entry zone | Fails at |
  | ----- | ---------- | -------- |
  | VCP breakout | pivot to +3% | last contraction's low |
  | Flat-base breakout | base high to +3% | base low (max 8%) |
  | 3-weeks-tight | pattern high to +3% | pattern low (max 8%) |
  | Pullback to a rising average | rising 20- or 50-day to +2% | 4% under it |
  | Pullback to support (RS 70+ only) | support to +2% | 3% under support |
  | Undercut and rally | reclaimed low to +3% | just under the dip (max 8%) |

  Each gets a **zone state**: too early, in zone, extended (above the zone) or failed.
- **Broker flow** from the floorsheet: over 20 sessions, whether a few brokers are
  absorbing what many sell (**accumulation**) or unloading (**distribution**).
- **Entry readiness (0–100):** trend 30 + setup quality 25 + market 15 + sector vs NEPSE
  15 + broker flow 15.

**Use it:** `/screener` → **All setups** to browse everything; sort and filter by
readiness, setup, sector; **Track** adds a stock to your watchlist.

**QA:**

1. `/screener` → **All setups**: every row has a readiness score, zone state, setup type.
2. Filter by a sector: only that sector's stocks remain.
3. Open a stock with readiness 60+: its readiness card (section 4.6) shows the same score
   and a breakdown that adds up to it.

### 4.4 Entry zone now (the board) and guards

**Why:** a short list of charts that meet **every** rule today, so you look at 3–15
stocks instead of 250. Guards remove charts that look right but are hard to trade.

**How it works:** a stock is on the board when the price is **in its zone**, **5+ of 7
trend rules** pass, readiness is **60+**, the setup is a VCP, flat-base or rising-average
pullback, **and it passes every guard**:

| Guard | Rule | Why |
| ----- | ---- | --- |
| Thin volume | average turnover under NPR 2M a day | your order moves the price; poor fills |
| Upper / lower circuit | closed within 0.5% of the ±15% daily limit | few sellers/buyers; next open gaps |
| Extended | 4+ ADR above the 50-day average | stretched stocks usually pulled back first (−4.6% in 10 sessions in our data) |
| Late-stage base | 3rd base or later since the low | later bases failed more (20-session results −1.6% / −3.1% / −4.2%) |

Charts that meet every rule except a guard are listed under **Held back by guards**. In
our backtest (Apr–Oct 2026) the board's simulated trades won 64.5% with a profit factor
of 1.65. That's one short, mostly falling period: encouraging, not proof.

**Use it:** each evening after 4:45 PM, look at the board. For each stock, open its page
and decide whether to track it.

**QA:**

1. `/screener` opens on **Entry zone now**. Each card: readiness gauge with a small
   history line, setup, zone, stop, target, badges.
2. The explanation above the board lists the rules and setup types.
3. If any are held back, they appear under **Held back by guards** with the guard named.
4. No card shows an "Extended" or "Base 3 · late stage" badge (those are held back).
5. If your open risk is near or over your limit, a note appears above the board (4.13).

**Paper trading:** treat the board as your shortlist. Don't paper trade stocks that
aren't on it until you have results for the board itself.

### 4.5 Badges: stretch, breakout age, base count, volume, EPS

**Why:** extra context traders use (Minervini, O'Neil, Morales/Kacher). Each was measured
in the backtest; only the ones that helped hold anything back (section 4.4). The rest
are information.

| Badge | Meaning | Effect |
| ----- | ------- | ------ |
| **Extended N ADR** (amber) | price is N average daily ranges above the 50-day | guard at 4+ |
| **Big move N ADR** (amber) | today already moved more than an average day | information |
| **Breakout day N** / **Stale breakout · day N** | sessions since the price first closed above the pivot | information |
| **Base N** / **Base N+** / **Base 3 · late stage** | which base since the stock's low ("+" = history starts near the low, count may be higher) | guard at 3+ |
| **Pocket pivot** | an up day on more volume than any down day in the 10 before | information (didn't help in our data) |
| **U/D vol N** | volume on up days ÷ down days over 50 sessions (shown at 1.2+ or under 0.8) | information |
| **Volume dry-up** | 2+ of the last 10 sessions on under half the usual volume | information |
| **EPS +N% YoY** (green at 25%+, red if falling) | latest quarterly EPS growth | information |

Hover over any badge for its explanation.

**QA:**

1. `/screener` → All setups: several rows show these badges; hover shows a tooltip.
2. A stock with "Base 3 · late stage" is not on the board.
3. `/backtest` has a chart for each (by extension, day move, breakout age, base count,
   pocket pivot, up/down volume, dry-up).

### 4.6 Stock page

**Why:** everything about one stock in one place before you commit.

**How it works / what's on it** (`/screener/SYMBOL`, e.g. `/screener/NABIL`):

- **Candlestick chart:** volume, 50/200-day averages, entry-zone band, invalidation,
  target and pivot lines, VCP contraction markers (your own levels if you track it).
- **RS line vs NEPSE** (lower pane): rising = beating the market; dots mark RS new highs
  (green when RS leads price, a sign of strength).
- **Entry readiness card:** score, breakdown, 60-session history, guards and badges.
- **Volume today** *(market hours)*: volume so far and the projected full-day volume
  compared with the 50-day average. NEPSE trades most volume early, so the app learns the
  normal intraday pattern instead of judging an 11:30 breakout on half a day.
- **Broker flow card:** state, score, top buyers and sellers with names and average prices.
- **Corporate actions:** upcoming book close, dividend history.
- **EPS growth line.**

**QA:**

1. `/screener/NABIL` loads the chart with lines and the RS pane.
2. The readiness card's breakdown adds up to the score.
3. *(market hours)* "Volume today: N so far · projected M by the close = R× the 50-day
   average"; before 11:15 it says it's too early to project.
4. Broker flow card lists top buyers and sellers with broker names.

### 4.7 Watchlist and setups

**Why:** good entries come from waiting for a stock to reach its zone, not chasing it.
The watchlist holds the plan (zone, stop, target) and watches it for you.

**How it works:** **Track** (screener) or **Add to watchlist** (stock page) opens a dialog
with the six setup types and suggested levels (all editable). The target is the nearest
resistance at least 1R above the zone, or 2R. Each card shows a price ladder (price
against zone, stop, target), risk:reward, the analysis from the day you added it, the
entry checklist (4.9) and the position size (4.10).

**Use it:** track the board's stocks with the setup the board shows. Adjust levels only
for a clear reason (and write it in the notes).

**QA:**

1. `/screener` → **Track** on a board stock → the dialog shows six setup types; switching
   type changes the suggested levels and the pattern summary.
2. Add it: it appears on `/watchlist` with the ladder, levels and R:R.
3. Edit the zone or stop and save: the ladder updates.
4. **Archive** and the archived tab: the item moves there; restoring brings it back.

### 4.8 Watchlist alerts

**Why:** you can't watch charts all day. Alerts tell you when a tracked setup needs
attention, in the app and on Telegram.

**How it works** (checked after every 5-minute price sync):

| Alert | When |
| ----- | ---- |
| **Approaching zone** 🟡 | within 3% below the pivot/zone; again only after moving 5% away |
| **Pullback to 21-day** 🟡 | within 1.5% of a rising 21-day average, after being 3%+ above it, on lighter projected volume; once a day |
| **Breakout confirmed** | a breakout setup crosses into its zone on **projected** volume ≥ 1.5× average |
| **Breakout, low volume** | crossed in on less; "too early to judge" in the first 15 minutes; notes when at the upper circuit |
| **Entered zone** | a pullback setup reaches its zone |
| **Extended** | price ran above the zone (buying = chasing) |
| **Invalidated** | price hit the invalidation level; stays so until **Reset setup** |
| **Close confirmed / Close, low volume / Failed at close / Held zone at close** | after 4 PM, the setup judged on the close and full-day volume |
| **Book close soon / Levels adjusted** | bonus book close in 5 days; levels divided after a bonus |

The sidebar shows a count of unread alerts next to **Watchlist**.

**QA** *(market hours for most)*:

1. Track a stock trading 2–3% below its zone; when it comes within 3% you get
   "Approaching zone" once; no repeat on the next sync.
2. When a tracked breakout crosses its pivot, the alert names the projected volume
   ("on a projected 2.37x … (18,000 so far by 2:00)").
3. After 4 PM: each tracked setup that touched its zone gets an end-of-day verdict.
4. **Mark all read** clears the count.

**Paper trading:** an alert is your signal to **look**, not to buy. Open the stock,
check the checklist (4.9), then decide.

### 4.9 Entry checklist

**Why:** a fixed pre-entry checklist stops impulse buys. Each rule is something
experienced breakout traders check.

**How it works:** each watchlist card lists rules with **met / not met / waiting / n/a**:
qualified VCP (or uptrend for pullbacks); closed above the pivot / in the zone; volume
1.5× at the close; market not weak; sector beating NEPSE over 20 sessions; risk:reward
at least 2R; not above the zone; **not stretched** (under 4 ADR above the 50-day,
today's move under 1 ADR); average turnover; not at the ±15% limit; no bonus book close
in 10 days.

**Use it:** only consider an entry when everything applicable is met. Write down why if
you take one that isn't.

**QA:**

1. A card's checklist shows each rule with a status and detail (e.g. "1.5 ADR above the
   50-day; today +0.6 ADR (ADR 2.0%)").
2. A stock with a bonus book close within 10 days fails that rule.
3. Edit the target below 2R: the risk:reward rule fails.

### 4.10 Position size, costs, cautious size, heat warning

**Why:** how much you buy matters more than what you buy. Fixed-risk sizing keeps any
single loss small; NEPSE fees are large enough to change results.

**How it works:**

- **Size** = the shares (in 10-share lots) where hitting the stop loses at most
  **capital × risk %**, counting fees: commission by SEBON slabs (0.36% up to Rs 50,000 …
  0.243% above 1 crore), SEBON 0.015% each way, DP Rs 25 on sells.
- **Cautious size:** when the market is under pressure (50% of usual risk) or in a
  correction (25%), a smaller size is shown **alongside**; nothing changes on its own.
- **Heat warning:** if the buy would take your total open risk to 80%+ of your limit, it
  says so and suggests the size that fits ("Use N" in the buy dialog). Never blocks.

**QA** (needs capital in Settings):

1. A watchlist card shows "Size: N shares at P = Rs … + Rs … fees · loss at stop … ·
   break-even … · at target …".
2. Change risk per trade from 1% to 0.5% in Settings: the size roughly halves.
3. With positions using most of your heat, the size line warns "This buy takes open risk
   to X% of capital (limit 6%…)".

### 4.11 Positions: recording buys

**Why:** the app can only watch trades it knows about. TMS has no stop-loss orders, so
the app's alerts are your stop.

**How it works:** **Mark as bought** on a watchlist card (or **Add a buy** on a position):
price, quantity, date. Stop and target come from the setup; the stop is capped at **8%
below entry**. The position shows live P&L (Rs, %, **R** = gain in units of your initial
risk), stop and target distance, risk at the stop, cost with fees, net if sold now,
break-even, days held and the **T+2 sellable date** (you can't sell shares until two
trading days after buying).

**QA:**

1. Watchlist card → **Mark as bought**: price defaults to the latest, **Use N** fills the
   suggested quantity, preview shows fees, total, break-even, loss at stop.
2. Save: the card shows **Holding**; `/positions` lists it with all the figures and
   "Sellable from DATE".
3. **Edit stop / target** saves; **Fills** lists the buys; removing the only fill removes
   the position and returns the stock to the watchlist.

**Paper trading:** record the buy at the price you could really have got (section 2
rules), with the suggested quantity.

### 4.12 Sell-rule alerts

**Why:** most losses come from not selling. These are the sell rules from O'Neil and
Minervini, applied to every open position automatically.

| Alert | When | Checked |
| ----- | ---- | ------- |
| **Stop hit** | price ≤ your stop (shows the loss after costs; notes T+2 if unsettled) | every 5 min |
| **Target reached** | price ≥ target | every 5 min |
| **Up 1R** | +1R while the stop is below break-even; button **Move stop to break-even** | every 5 min |
| **+20% zone** | 20%+ above your average (where many take some profit) | every 5 min |
| **50-day break** | close below the 50-day on above-average volume | after the close |
| **Climax run** | a huge up day (3+ ADR) on the heaviest volume in 50 sessions, 25%+ above the 50-day | after the close |
| **Time stop** | 15+ sessions held and still under +0.5R | after the close |

Each fires once per rule (a new stop level can fire again). They show on `/positions`,
on each position card (latest alert), in the Positions sidebar badge, and on Telegram.

**QA:**

1. *(market hours)* Set a test position's stop just under the current price: within 5
   minutes "Stop hit … Selling at the stop: −Rs N after costs" appears once.
2. *(market hours)* When a position reaches +1R, "Up 1R" appears with **Move stop to
   break-even (P)**; clicking it updates the stop and the button disappears.
3. After a close, a position held 15+ sessions under 0.5R gets "Time stop".

**Paper trading:** when a sell alert fires, decide immediately and record what you'd do.
Ignoring a stop on paper builds the habit you're trying to avoid.

### 4.13 Portfolio heat and sector exposure

**Why:** several trades can fail together (a market drop, sector news). **Heat** is how
much you'd lose if every stop hit at once; keeping it capped limits the worst day.

**How it works:** `/positions` shows a **heat bar**: open risk as % of capital against
**max open risk** (6% default), green / amber from 80% of the limit / red over it, with
each position's share and cash vs invested. **Sector exposure** shows each sector's
value as % of capital, red over **max per sector** (30% default).

**QA:**

1. With two or more positions, the heat bar shows "X% of capital at risk · limit 6%"
   and chips per position.
2. Lower max open risk in Settings below your current heat: the bar turns red, the board
   shows a note, and size lines warn.
3. A sector above 30% of capital shows in red with the warning.

### 4.14 Selling, closing, after-tax results and reviews

**Why:** your real result is after fees and tax. Reviews turn trades into lessons; the
stats show whether your process works.

**How it works:**

- **Record a sell** (price, quantity, date). Partial sells reduce the position; selling
  everything closes it and archives its watchlist item. Selling unsettled shares (T+2) is
  recorded with a warning.
- **Tax:** sells are matched to your earliest buys first (FIFO); capital gains tax is
  **10%** on shares held up to 365 days, **7.5%** beyond, only on a net gain.
- **Closed** tab: net P&L after fees and tax, R, days held, **MAE/MFE** (the worst and
  best price while you held it: did the stop have room? did you leave money on the table?),
  and a stats strip: win rate, net P&L, expectancy per trade, average R, plan followed %.
- **Review:** "Did you follow the plan?" (yes / partly / no), mistake tags (chased the
  entry, moved the stop down, sold too early, held past the stop, oversized, ignored the
  market) and a lesson.

**QA:**

1. A position → **Record a sell** with part of the shares: "Recorded … M shares left",
   with realized gain, tax and net.
2. Sell the rest: the position moves to **Closed** with net after tax, R, MAE/MFE.
3. **Review this trade** → choose, tag, write a lesson → Save: shown on the card; the
   stats' "Plan followed" counts it.
4. Fills → remove the closing sell: the position reopens.

### 4.15 Corporate actions (book closes, bonus shares)

**Why:** a bonus issue drops the price mechanically (10% bonus = price ÷ 1.10). Without
handling, stops would trigger falsely and charts would show a fake breakdown.

**How it works:** upcoming book closes (45 days) show on the stock page and as badges; the
checklist fails within 10 days of a bonus book close; 5 days before, a "Book close soon"
alert; after it, the watchlist levels are divided by (1 + bonus%) with a "Levels adjusted"
alert, and the price history and indicators are re-fetched and recalculated.

**QA:**

1. A stock with an announced bonus shows a highlighted book-close badge on the board,
   screener and its watchlist card.
2. After its book close, the item's levels are lower by the bonus ratio and an alert
   says so.

### 4.16 Backtest

**Why:** before trusting rules with money, see how they would have done on past data.
Every rule change in this app was measured here first.

**How it works:** `/backtest` rebuilds what the app would have shown on each past session
(using only data available that day), then reports:

- **Simulated trades** on every board signal: buy at the next open, sell at the stop,
  target or after 20 sessions, minus 0.8% costs: win rate, average return, R, profit
  factor, exit reasons, by setup type.
- **Forward returns** 5, 10, 20 sessions later, versus NEPSE, by readiness, zone state,
  broker flow, guards, extension, market direction, base count, volume signals.

It re-runs every night. Groups with under 30 samples are flagged.

**QA:**

1. `/backtest` loads with the period, trade stats and charts; switching 5/10/20 sessions
   changes the charts.
2. The trades list shows entries, exits and reasons.

**Paper trading:** after 20+ paper trades, compare your win rate and average R with the
backtest's. Much worse usually means execution (late entries, ignored stops), not rules.

### 4.17 Daily digest

**Why:** one evening summary instead of checking every page.

**How it works:** after the nightly snapshot, a digest per account: market summary,
stocks that joined or left the board (and held back ones), watchlist verdicts, alerts and
book closes due. Sections can be switched off in **Settings → Daily Digest**.

**QA:**

1. After 4:45 PM, `/digest` shows today's digest; the dashboard shows a card.
2. Switch a section off in Settings: the next digest leaves it out.
3. Build one by hand:
   ```bash
   bin/rails nepse:data:digest
   ```

### 4.18 Telegram

**Why:** alerts reach your phone during market hours, when you aren't looking at the app.

**How it works:** you create your own bot once, the app polls it every minute (no public
URL needed). Messages: watchlist zone entries and breakouts, approaching / 21-day
pullback (🟡), every position sell-rule alert, and after the close the stocks new on the
board. At most one zone message per stock per day.

**Set up:**

1. In Telegram, message **@BotFather**, send `/newbot`, copy the token.
2. Start the API with it:
   ```bash
   TELEGRAM_BOT_TOKEN='paste-token-here' bin/dev
   ```
3. **Settings → Telegram → Connect Telegram**: send the 8-character code to your bot as a
   message. "Connected" appears within seconds. **Send test message** checks it.

**QA:**

1. Test message arrives.
2. *(market hours)* A watchlist alert or a position alert arrives within ~5 minutes of
   showing in the app.
3. Send `/stop` to the bot: Settings shows disconnected.

### 4.19 Settings

- **Capital & Risk:** trading capital, risk per trade %, max open risk %, max per sector %.
- **Daily Digest:** sections on/off.
- **Telegram:** connect, test, which messages to receive.

**QA:** change each value, reload the page: it's kept (saved to your account).

### 4.20 Older pages

**Dashboard, Stocks, New Trade, Trades, Portfolio, Journal, Analytics** come from the
first version of the app. Several keep their data **in your browser only** (lost if you
clear site data, not shared between browsers, not used by alerts). `/stocks` (price list)
and the dashboard's digest card use server data.

For paper trading, use **Watchlist → Positions → Closed** (sections 4.7–4.14), which are
saved on the server and feed the alerts and statistics.

---

## 5. Paper-trading routine

A routine that uses each feature for what it's for. Times are Nepal time.

**Evening, after 4:45 PM (15–20 minutes)**

1. `/digest`: what changed today.
2. `/market`: market direction. In a correction, plan on the cautious size.
3. `/screener` → **Entry zone now**: open each stock's page; look at the chart, RS line,
   broker flow, badges.
4. **Track** the ones you'd be willing to buy. Check each card's checklist and size.
5. `/positions`: read sell alerts from the close (50-day break, climax, time stop) and
   decide what you'd do tomorrow.

**During the session (alerts do the watching)**

1. When an alert arrives (app or Telegram), open the stock. For a breakout, check the
   projected volume in the alert.
2. If the checklist passes and the heat warning allows it, record **Mark as bought** at
   the live price with the suggested quantity.
3. For sell alerts, record the sell at the live price if you'd sell, or move the stop
   (e.g. to break-even after +1R).

**After each closed trade:** write the review within a day.

**Every Saturday (30 minutes)**

1. `/positions` → **Closed**: stats strip. Win rate, average R, expectancy, plan followed.
2. Read the mistake tags. One habit to fix next week.
3. `/backtest`: compare your numbers with the rules' numbers.

**When to consider real money** (your decision; these are only checkpoints):

- 20–30 closed paper trades, so the numbers mean something;
- positive expectancy after fees and tax;
- plan followed on most trades (80%+);
- you acted on every stop alert;
- results not far from the backtest's.

Then start real trading with a smaller risk per trade (e.g. 0.5%) in your real account.

---

## 6. Limitations to keep in mind

- **Short history:** about a year of prices and six months of snapshots, mostly a falling
  market. Backtest numbers are encouraging, not proof.
- **Base counts** start at the lowest point in the stored year ("Base N+" when that's
  the start of the data).
- **EPS growth** is Chukul's figure for now; past quarters couldn't be backfilled, so it
  isn't in the backtest yet (about a year of weekly syncs is needed).
- **Prices are delayed** up to 5 minutes; TMS fills can differ.
- **Holidays** aren't known, so T+2 dates can be a day early around holidays.
- **Right shares** aren't handled (only bonus shares and cash dividends).
- **Broker flow** comes from public floorsheets; brokers trade for many clients, so it's a
  hint, not who is buying.
- The detailed test plan with every check is in
  [docs/qa/manual-test-plan.md](qa/manual-test-plan.md).
