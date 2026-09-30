# Manual test plan

Covers the features added on `feature/live-stock-prices`, `feature/watchlist-entry-zones`
and `feature/free-data-sync`. Numbers in examples come from data on 2026-09-30 and will
move as prices update; the rules behind them do not.

## Setup

```bash
bin/rails db:prepare
bin/rails nepse:data:all      # first time only, about an hour
bin/dev                       # API + job worker on :3000
cd frontend && npm run dev    # app on :5173
```

Open http://localhost:5173. A first-time tour may appear; click through it.

Market hours are **Mon–Fri, 11:00–15:00 Nepal time**. Tests marked *(market hours)*
only behave as described then, and only while the backend runs with `bin/dev`.

---

## A. Stock prices — `/stocks`

| # | Steps | Expected |
| - | ----- | -------- |
| A1 | Click **Sync Latest Prices** | Green "Updated N stocks…", and "Prices as of … (x min ago)" refreshes |
| A2 | Look at the **Market Cap** card | A short value such as "NPR 3.83 Trillion", not a long string of digits |
| A3 | Look at the **Unchanged** card | A number above 0 |
| A4 | Stop the Rails server, click **Sync Latest Prices** | A red error message; no silent failure |
| A5 | Leave the page open *(market hours)* | Prices change without reloading within ~5 minutes |
| A6 | Check data older than a weekend | Amber "May be out of date" next to "Prices as of" |

## B. Market status (header)

| # | Steps | Expected |
| - | ----- | -------- |
| B1 | Open the app at the weekend or outside 11:00–15:00 | **Market Closed**, "Next open in … (Mon-Fri, 11:00-15:00 NPT)" |
| B2 | On Friday after 15:00 | Next open is Monday 11:00, not Sunday |
| B3 | *(market hours)* | **Market Open**, connection shows **Live** or **Polling** |

## C. Market overview — `/market`

| # | Steps | Expected |
| - | ----- | -------- |
| C1 | Open the page | A date is shown; it is the latest day that has **stock** prices |
| C2 | Before the day's stock sync has run *(e.g. early in market hours)* | Still shows the previous session with breadth figures, not today with 0 stocks |
| C3 | Look at the regime | One of strong / neutral / weak, derived from real index history |
| C4 | Index chart | About 90 recent sessions of the NEPSE index |

## D. Screener — `/screener`

| # | Steps | Expected |
| - | ----- | -------- |
| D1 | Open the page | Tabs **All setups** and **Breakout Watch** (a spinner first; the page analyses every stock) |
| D2 | Scroll the table right; click **Track** on a row far down the list | The dialog opens centred on screen (it used to open off-screen) |

## E. Track dialog (add to watchlist)

Open it from **Track** on `/screener`, or **Track** next to the name on `/screener/ADBL`.

| # | Steps | Expected (ADBL at 308.00) |
| - | ----- | -------- |
| E1 | Dialog opens with **VCP breakout** selected | Zone 302.4–311.47 (pivot + 3%), invalidation 290 (last contraction low), stop 290, target 315.98; grey box shows VCP score, contractions, trend, market, "Target from resistance", data date |
| E2 | Read the grey box | For ADBL, an orange "Not a qualified VCP yet (score 65 …)" warning |
| E3 | Click **Pullback to support** | Zone 301.2–307.22 (support + 2%), invalidation 292.16 (support − 3%); VCP score, contractions and warning disappear |
| E4 | Watch **Risk:reward** while switching | ~1.1R for VCP, ~1.63R for pullback |
| E5 | Click **VCP breakout** again | The VCP levels return |
| E6 | Set **Invalidation** above **Zone low**, click **Add to watchlist** | Red "Invalidation price must be below the entry zone" |
| E7 | Fix the levels, add a note, click **Add to watchlist** | "ADBL is on your watchlist." stays visible; the button behind becomes **On watchlist** |
| E8 | Press **Esc** or click outside the dialog | It closes |
| E9 | Try a stock/setup with no suggestion | Red "No … found … Enter the levels yourself below."; fields empty; **Add** disabled until a zone low is typed |

## F. Chart — `/screener/ADBL` (after adding ADBL)

| # | Steps | Expected |
| - | ----- | -------- |
| F1 | Look at **Price & Trend** | Subtitle lists your zone, invalidation and target |
| F2 | Chart | Green band for the entry zone, red **Invalidation** line, green **Target** line, grey **Added** marker |

## G. Watchlist — `/watchlist`

| # | Steps | Expected |
| - | ----- | -------- |
| G1 | Open the page | Card with symbol, status badge, setup type, price and change %, price position line, price ladder, levels, risk:reward, snapshot, notes |
| G2 | Compare the price with the zone | Status and "In zone / Below zone / Above zone" match; distance text correct (e.g. "2.51% below the zone") |
| G3 | **Edit levels** → change zone low → **Save levels** | Values update; no alert is raised |
| G4 | **Edit levels** with invalid ordering | Red error explaining which level is wrong |
| G5 | **Archive** | Card moves to the **Archived** tab |
| G6 | **Archived** tab → **Restore** | Card returns to **Active** |
| G7 | **Remove** → confirm | Card and its alerts are deleted |
| G8 | Empty watchlist | "Nothing tracked yet." with a link to the screener |

## H. Alerts *(market hours)*

Add a stock whose price is just below its zone, then wait for the price to cross it.

| # | Steps | Expected |
| - | ----- | -------- |
| H1 | Price crosses into a VCP zone from below | **Breakout confirmed** (volume ≥ 1.5× 50-day average) or **Breakout, low volume** |
| H2 | Price rises above the zone high | **Extended** alert; status **Extended** |
| H3 | Price falls to the invalidation level | **Invalidated** alert; status stays **Invalidated** even if the price recovers; **Reset setup** appears |
| H4 | Same state for several syncs | No repeated alerts |
| H5 | Sidebar | Red count next to **Watchlist**; **Mark all read** clears it |

## I. Plan from setup

| # | Steps | Expected |
| - | ----- | -------- |
| I1 | **Create plan** on a watchlist card | Form pre-filled with entry = zone low, stop, target, strategy (VCP → Turtle Breakout, pullback → Support Bounce) and a thesis |
| I2 | Account size 500000, risk 1% | Suggested quantity = 5000 ÷ (entry − stop), e.g. 192 shares for 556/530 |
| I3 | **Save plan** | "Plan #N saved for …"; the card shows **Plan #N saved** and status **Planned** |
| I4 | Open `/trade/new?watchlist=<same id>` again | "A plan (#N) already exists for this setup." |
| I5 | Check the plan | http://localhost:3000/api/v1/trade_plans lists it (there is no page for plans yet) |

## J. Reference data (terminal)

| # | Steps | Expected |
| - | ----- | -------- |
| J1 | `bin/rails nepse:data:report` | Coverage per field; compare before and after `nepse:data:all` |
| J2 | `bin/rails nepse:data:universe` | Adds missing securities, corrects names/sectors, lists deactivated ones |
| J3 | `bin/rails "nepse:data:fundamentals[NABIL]"` then open http://localhost:3000/api/v1/stocks/NABIL/financials | EPS 28.36, FY 082/083, Q4, ROE, ROA, `field_sources` showing `chukul` |
| J4 | `/stocks` sector filter | Clean sector names (no "s", no "Development Bank Limited" duplicate) |
| J5 | `/stocks` type filter | Equity, Mutual Fund, Promoter Share, Debenture |

## Known limitations (not bugs)

- `/trades` does not show plans saved from the watchlist.
- Mutual funds have no fundamentals (their pages show NAV); promoter shares and
  debentures have none at all.
- No NEPSE holiday calendar; on a holiday the app treats the market as open.
- Alerts appear only inside the app, and only while `bin/dev` is running.
- `/screener` is slow to load because it analyses every stock on each request.
