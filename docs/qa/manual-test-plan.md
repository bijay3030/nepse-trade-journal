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
| C5 | **Market Heatmap** card | Sectors as blocks, largest market cap top-left (Commercial Banks); each stock a tile sized by market cap; dark header per larger sector with its market-cap weighted change |
| C6 | Tile colours | Red for falling, grey for within ±0.25%, green for rising, darker for bigger moves; legend below matches |
| C7 | Small tiles | Show colour only; no clipped labels like "UPP…" |
| C8 | Click a tile (e.g. NABIL) | Opens `/screener/NABIL` |
| C9 | Footer and subtitle | "281 stocks · 20 without market cap not shown" (numbers vary); "prices as of" time of the last price sync |
| C10 | Market hours | Colours update within about a minute of each 5-minute price sync without reloading |
| C11 | Phone width | Taller layout (portrait), no horizontal scroll |

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

## H2. End-of-day verdict *(after the 4 PM close)*

| # | Steps | Expected |
| - | ----- | -------- |
| H2.1 | A VCP setup closes inside its zone on ≥ 1.5× average volume | **Close confirmed** alert; checklist "Closed above the pivot" and "Volume" show ✓ |
| H2.2 | Closes above the pivot on lighter volume | **Close, low volume** alert; volume check ✗ |
| H2.3 | Reached the zone intraday but closed below it | **Failed at close** alert |
| H2.4 | A pullback setup closes inside its zone | **Held zone at close** alert |
| H2.5 | Run the close check twice for the same session | Only one verdict/alert |

To force it outside the schedule (after the close only): `bin/rails runner 'SyncMarketPricesJob.perform_now(true)'`.

## H3. Entry checklist — `/watchlist`

| # | Steps | Expected |
| - | ----- | -------- |
| H3.1 | Open a VCP card | Seven checks with ✓ met, ✗ not met, dashed circle waiting, grey not applicable; badge "N of 7 met" |
| H3.2 | Card added before 4 PM today | Close and volume checks show "Judged after the 4 PM close" |
| H3.3 | Unqualified VCP | "Qualified VCP" ✗ lists the rules not met (e.g. "2-4 contractions") |
| H3.4 | Pullback card | Pattern check is "Price-action trend is up"; volume check greyed as not applicable; badge "N of 6 met" |
| H3.5 | Stock in a sector without an index (e.g. Mutual Fund) | Sector check not applicable |
| H3.6 | Edit levels so target is below 2R | "Risk:reward at least 2R" turns ✗ |
| H3.7 | All applicable checks met | Green "All conditions met" badge |

## H4. VCP detection

| # | Steps | Expected |
| - | ----- | -------- |
| H4.1 | `/screener` → sort/filter by VCP score | Few stocks qualify (3 on 2026-09-30 in a weak market); contraction sequences are short (2-4 steps) and shrinking |
| H4.2 | Track dialog for a stock with a long noisy pattern | "Not a qualified VCP yet" warning |

## H5. Entry readiness — `/screener` and `/screener/SYMBOL`

Run `bin/rails nepse:data:setups` once (about a minute) if no snapshot exists yet.

| # | Steps | Expected |
| - | ----- | -------- |
| H5.1 | Open `/screener` | Opens on **Entry zone now**: cards with a readiness gauge, "In entry zone", setup type, close, zone, invalidation, trend x/7, RS (5 stocks on 2026-09-28: KBL, PCBL, SHIVM, SANIMA, BHCL) |
| H5.2 | Read the line above the cards | States the criteria: in zone, 5 of 7 trend rules, readiness 60+, and the close date |
| H5.3 | **All setups** tab | New "Entry readiness" column: score and zone badge per row; loads in under a second |
| H5.4 | Dashboard | Still shows the All setups table (not the entry board) |
| H5.5 | Click a symbol, e.g. KBL | **Entry readiness** card: gauge, zone ladder with the current step outlined, score breakdown (e.g. 31/35, 14/30, 3/15, 20/20), 8 trend-template rules with ✓/✗ and numbers |
| H5.6 | **Price & Trend** chart | Candles with volume, 50/200-day lines, shaded entry zone, Target / Pivot / Invalidation lines with price labels, T1, T2… markers; drag to pan, scroll to zoom |
| H5.7 | Track the stock, then reopen its page | Chart subtitle says "(from your watchlist levels)" and an "Added" marker appears |
| H5.8 | Search the page for "buy" or "sell" | Not found anywhere (neutral wording) |
| H5.9 | Run the command twice for the same close | Snapshots are replaced, not duplicated |
| H5.10 | `/screener/NABIL` → **Price & Trend** | Caption "RS vs NEPSE: +x% over 20 sessions, +y% over 60 sessions · last RS new high <date> (before price)"; green = beating NEPSE, orange = lagging |
| H5.11 | Same chart, lower pane | Blue RS line labelled "RS vs NEPSE" starting at 100, same time axis as the candles (pan/zoom together); blue dots on RS new highs, green where RS got there before price; legend entries for both |
| H5.12 | Entry readiness card | "Readiness, last 60 sessions" sparkline with a dashed 60 line and dots on entry-zone sessions; caption "58 on 2026-07-01 → 63 now · … sessions met the entry-zone criteria" |
| H5.13 | `/screener` → **Entry zone now** | A small sparkline under each gauge showing whether readiness has been rising or fading (green rising, amber falling) |

## H6. Broker flow — `/screener/SYMBOL`

Run `bin/rails "nepse:data:floorsheet[120]"` once (about 7 minutes) if no floorsheet is stored.

| # | Steps | Expected |
| - | ----- | -------- |
| H6.1 | Open `/screener/KBL` → **Broker flow** | Accumulation badge, flow score (e.g. +18.03), four boxes: top buyers / sellers % of volume for 20 and 5 sessions |
| H6.2 | Bar chart | One green (top buyers' net) and one red (top sellers' net) bar per session for the last 20 sessions; tooltip shows shares |
| H6.3 | Tables | Top net buyers and sellers with broker number, name, net shares, % of volume, average price paid / received |
| H6.4 | A thinly traded stock | Amber "Thin trading" note; state shown as neutral |
| H6.5 | A stock with fewer than 5 sessions of data | "Not enough floorsheet data yet (n of 5 sessions)" |
| H6.6 | **Entry readiness** card | Score breakdown has a **Broker flow** row out of 15; weights are 30/25/15/15/15 |
| H6.7 | `/screener` All setups | Readiness column shows an Accumulation / Distribution badge where applicable; Entry zone cards mention the flow |
| H6.8 | `bin/rails "nepse:data:floorsheet[5]"` twice | Second run imports nothing (already stored) |
| H6.9 | Compare with market data | For a session, total floorsheet quantity equals the stored market volume (checked: 13,178,128 on 2026-09-28) |

## H7. Backtest — `/backtest`

Run `bin/rails "nepse:data:setup_history[120]"` (about 25 minutes, once) and `bin/rails nepse:data:backtest`.

| # | Steps | Expected |
| - | ----- | -------- |
| H7.1 | Sidebar → **Backtest** | Page with the period, sessions, stocks and snapshot count |
| H7.2 | **Entry zone now: simulated trades** | Six stat tiles (closed trades, win rate, avg return with wins/losses, avg R, profit factor, avg holding), exit-reason badges, trade table newest first |
| H7.3 | Fewer than 30 closed trades | Amber "too few to judge" note |
| H7.4 | Click a symbol in the trade table | Opens its analysis page |
| H7.5 | Switch 5 / 10 / 20 sessions | All five charts and tables update; the "All snapshots" line changes |
| H7.6 | Charts | Blue avg return and green vs-NEPSE bars per group; table with samples, avg, win rate, vs NEPSE; groups under 30 samples greyed and marked "small sample" |
| H7.7 | No backtest yet (fresh database) | "No backtest yet." with the two commands |
| H7.8 | Look-ahead check | `bin/rails runner 'Setups::SnapshotBuilder.call(as_of: Date.new(2026,9,28))'` changes no Sep 28 snapshot values |
| H7.9 | Session check | No snapshot dates on weekends or holidays (only NEPSE index sessions) |

## H8. Setup types

| # | Steps | Expected |
| - | ----- | -------- |
| H8.1 | Track dialog on any stock | Four setup cards: VCP breakout, Pullback to support, Pullback to a rising average, Flat-base breakout, each with its rule |
| H8.2 | Choose **Flat-base breakout** on a stock near its 52-week high | Pattern line such as "31-session base, 8% deep"; zone starts at the base high |
| H8.3 | Choose **Pullback to a rising average** on a downtrending stock | Red "Not an uptrend above a rising 50-day average …"; levels empty |
| H8.4 | Watchlist card for a flat-base setup | Checklist pattern row "Flat base near the 52-week high"; volume check applies (breakout) |
| H8.5 | Watchlist card for an MA pullback | Checklist close row "Closed inside the entry zone"; volume check not applicable |
| H8.6 | **Create plan** for each type | Default strategy: breakouts → Turtle Breakout, pullbacks → Support Bounce |
| H8.7 | `/backtest` | "By setup type" chart for stocks inside their zone; trade stats per setup type |
| H8.8 | Stock page for a stock whose best setup is a flat base | Chart subtitle names "the flat-base breakout setup found on …" |

## H9. Corporate actions

| # | Steps | Expected |
| - | ----- | -------- |
| H9.1 | `/screener/NABIL` → **Corporate actions** | Upcoming book close (date, days, FY, bonus/cash, AGM); amber with the price-adjustment note when a bonus is due; dividend history table |
| H9.2 | Stock with nothing due | "No book close announced in the next 45 days." |
| H9.3 | `/screener` All setups and **Entry zone now** | Amber "Book close Oct 2 · 10% bonus" badge on stocks with a bonus book close due |
| H9.4 | Watchlist card for a stock with a book close due | Badge next to the status; checklist rule "No bonus book close in the next 10 days" ✗ for a bonus within 10 days, ✓ with a note for cash-only |
| H9.5 | Daily job 5 days before a bonus book close | One "Book close soon" alert (not repeated next day) |
| H9.6 | Daily job on/after a bonus book close | Levels divided by (1 + bonus%), note "Levels adjusted for a 10% bonus (book close …)" on the card, one "Levels adjusted" alert; no separate "book close soon" alert that same day |
| H9.7 | A stock whose bonus book close was 1-10 days ago | Its chart shows no fake drop after the daily job (history re-fetched) |
| H9.8 | Broker flow tables at a medium window width | Tables stack, columns don't overlap |

## H10. Liquidity and circuit guards

| # | Steps | Expected |
| - | ----- | -------- |
| H10.1 | `/screener` → **Entry zone now** | Criteria line mentions "average turnover NPR 2.0M+ a day, and a daily move under ±14.5% (not at the ±15% circuit)"; no card shows a guard badge |
| H10.2 | Same tab after a session where a qualifying chart was thin or hit a circuit | **Held back by guards (n)** list under the cards: symbol, readiness, badge, "NPR 1.2M a day" or "+9.96% on the day"; the stock is not a card above |
| H10.3 | `/screener` → **All setups**, a thin stock (e.g. sort by turnover) | Amber "Thin volume" badge next to its zone badge |
| H10.4 | `/screener/SYMBOL` for a thin stock | Readiness card: "Thin volume" badge, turnover "NPR x.xM/day", note "…Kept off the Entry zone now board."; no "Meets entry-zone criteria" |
| H10.5 | `/screener/NABIL` | Turnover about "NPR 34M/day", no guard badge |
| H10.6 | `/watchlist`, expand a card's checklist | Rules "Average turnover at least NPR 2.0M a day (20 sessions)" and "Not at the ±15% daily limit" with today's change; a stock up 14.5%+ intraday shows ✗ "at the upper circuit, few sellers; wait for another session" |
| H10.7 | `/backtest` | Trades summary hint includes "n held back by guards" when any; **By tradability guard** chart compares "Passed guards" with each guard |
| H10.8 | Terminal: `NEPSE_MIN_TURNOVER=5000000 bin/rails nepse:data:setups` | More stocks flagged thin (about 100 vs 47 at 2M); reset by running it again without the variable |

## H11. Daily digest — `/digest`, dashboard, settings

| # | Steps | Expected |
| - | ----- | -------- |
| H11.1 | Terminal: `bin/rails nepse:data:digest` | "Built N digests" (one per user with the digest on) |
| H11.2 | `/dashboard` | "Daily digest · <day>" card at the top with a headline (e.g. "NEPSE -0.91%"), counts, a **New** badge until opened, and **Open digest** |
| H11.3 | Sidebar → **Daily Digest** | Market summary (index, change, regime, breadth, best/weakest sectors, no "Corporate Debentures"), Entry zone changes (Joined / Left with reason / Held back), Watchlist status (verdicts, alerts, book closes within 10 days) |
| H11.4 | Stock symbols in the digest | Link to `/screener/SYMBOL` |
| H11.5 | Reopen `/dashboard` after viewing the digest | **New** badge gone |
| H11.6 | Settings → Daily Digest → untick **Market summary**, run H11.1 again, reopen `/digest` | Market section missing; the other two remain |
| H11.7 | Settings → untick **Build a daily digest** | Section switches greyed out; H11.1 skips you |
| H11.8 | After a few sessions | The **Session** dropdown lists earlier digests, "(new)" on unread ones |
| H11.9 | Search the digest for "buy" or "sell" | Not found |

## H12. Telegram messages

Needs a bot token (README → Telegram messages) and `bin/dev` restarted with it.

| # | Steps | Expected |
| - | ----- | -------- |
| H12.1 | Without a token: Settings → **Telegram** | "Telegram isn't set up on the server yet…" with setup steps |
| H12.2 | With a token: **Connect Telegram** | Your bot's @name, an 8-character code with **Copy code**, and an "open it from here" link |
| H12.3 | In Telegram, send the code to the bot (lower case works too) | Bot replies "Connected to NEPSE Trade Journal (your email)"; Settings shows "Connected as @you" within a few seconds |
| H12.3b | Send the bot just `/start` | Bot explains how to get and send the code; nothing is linked |
| H12.4 | **Send test message** | "Test message sent." and the message arrives |
| H12.5 | Send a code older than 30 minutes, or a made-up one | Bot replies the code isn't valid or has expired |
| H12.6 | During market hours, a tracked stock moves into its zone | One message: "🟢 SYMBOL is in its entry zone" with price, zone, stop, target, R:R, setup, readiness, trend, RS and any warnings |
| H12.7 | The same stock leaves and re-enters the zone that day | No second message |
| H12.8 | After the nightly job (or `bin/rails runner 'TelegramBoardJob.perform_now'`) on a day with new board stocks | One "📋 New on Entry zone now" message listing them; running it again sends nothing |
| H12.9 | Untick a switch, repeat H12.6 or H12.8 | No message of that kind |
| H12.10 | Send `/stop` to the bot | Bot replies "Disconnected"; Settings shows **Connect Telegram** again within a minute |
| H12.11 | Read the messages | No "buy"/"sell" wording; ends with "Rule checks, not a recommendation." |

## H13. Positions — `/watchlist` and `/positions`

| # | Steps | Expected |
| - | ----- | -------- |
| H13.1 | Watchlist card → **Mark as bought** | Dialog with price (latest), quantity, date (today, Nepal time); preview of stop, target, risk/share, reward:risk; **Record buy** disabled until a whole quantity is entered |
| H13.2 | Stock whose invalidation is more than 8% below the price | Stop shows 8% below the price, with a note saying why |
| H13.3 | Enter 100 shares, **Record buy** | "Recorded: 100 … Position now 100 shares at an average …", stop/target and "sellable from <date> (T+2)"; **View positions** link |
| H13.4 | Back on the watchlist | Card shows **Holding**, a **View position** button, no entry checklist; no "entered zone" alerts for it any more |
| H13.5 | `/positions` (sidebar **Positions**) | Summary (open positions, market value, unrealized P&L, risk if every stop is hit) and a card per position: shares at average, held days, P&L ₹ and %, R, stop and target with % distance, risk at stop, opened date, "Sellable from" badge until T+2 |
| H13.6 | **Add a buy** at a different price | Same position; quantity adds up and the average is weighted; the stop is kept |
| H13.7 | **Edit stop / target**, save | New values shown; R still measured from the first stop |
| H13.8 | **Fills** → remove the newer buy | Quantity and average go back |
| H13.9 | Remove the last fill (confirm) | Position disappears; the watchlist card returns to Watching/In zone |
| H13.10 | Buy dated Thursday | Sellable from the following Monday (weekend skipped; holidays not counted) |

## H14. Position size and costs

| # | Steps | Expected |
| - | ----- | -------- |
| H14.1 | Watchlist with no capital set | Cards say "Set your trading capital to see a position size" (link to Settings) |
| H14.2 | Settings → **Capital & Risk**: capital 500000, risk 1%, Save | "Each trade is sized so hitting its stop loses at most Rs 5,000, including fees." then "Saved." |
| H14.3 | Back on the watchlist | Each tracked card shows "Size: N shares at P = Rs … + Rs … fees · loss at stop …: Rs … (…% of capital) · break-even … · at target +Rs … (…R)"; N is a multiple of 10 and the loss is at most Rs 5,000 |
| H14.4 | Card whose price is below its zone | Sized at the zone low |
| H14.5 | Very small capital (e.g. 20000) | "Size: Your risk budget is smaller than the loss on one 10-share lot at this stop." |
| H14.6 | **Mark as bought** | "Suggested for your risk (Rs 5,000.00): N shares" with **Use N**; typing a quantity shows fees, total cost, break-even and loss at stop after fees |
| H14.7 | `/positions` | Each card adds Cost incl. fees, Net if sold now and Break-even; the summary shows Net if all sold now |
| H14.8 | Check a fee by hand: buy Rs 1,00,000 | Commission Rs 330 (0.33%) + SEBON Rs 15 = Rs 345 |

## H15. Intraday volume pace *(market hours)*

| # | Steps | Expected |
| - | ----- | -------- |
| H15.1 | During the session, open `/screener/NABIL` | "Volume today: N so far · projected M by the close = R× the 50-day average of A (estimated pace…)"; after 5 recorded sessions the note says "pace learned from the last N sessions" |
| H15.2 | Before 11:15 | "too early in the session to project" |
| H15.3 | A tracked VCP/flat-base stock breaks its pivot mid-session | Alert says "on a projected R× its 50-day average volume (N so far by h:mm)"; confirmed when R ≥ 1.5 even if the volume so far is below the average |
| H15.4 | Breakout in the first 15 minutes | "It's too early in the session to judge volume; the close will confirm or reject it." |
| H15.5 | Breakout at the upper circuit | Message ends "It's at the upper circuit, so volume understates demand." |
| H15.6 | Terminal after a few sessions: `bin/rails runner 'p Nepse::VolumeProfile.build'` | `source: "learned"` once 5 sessions exist, points rising to 1.0 at minute 240 |

## H16. Extension and breakout age

| # | Steps | Expected |
| - | ----- | -------- |
| H16.1 | `/screener` → All setups | Some rows show "Extended N ADR" or "Big move N ADR" (amber) and breakout setups "Breakout day N" ("Stale breakout · day N" from 5) |
| H16.2 | **Entry zone now** | No card is "Extended"; extended charts that met the rules appear under "Held back by guards" |
| H16.3 | `/screener/SYMBOL` readiness card | The same badges; an extended stock has the note "4+ ADR above the 50-day average…" |
| H16.4 | `/watchlist`, a card's checklist | Rule "Not stretched: under 4 ADR above the 50-day, today's move under 1 ADR" with "N ADR above the 50-day; today ±N ADR (ADR N%)" |
| H16.5 | `/backtest` | Charts "By extension from the 50-day", "By the day's move" and "By breakout age"; the guard chart includes "Extended" |

## H17. Market direction

| # | Steps | Expected |
| - | ----- | -------- |
| H17.1 | `/market` | Card "Market: Uptrend · N distribution days in the last 25 sessions · index -X% from its high · last follow-through D Mon" and the threshold explanation |
| H17.2 | `/screener` → Entry zone now | The same card in compact form above the criteria |
| H17.3 | Terminal: `bin/rails runner 'p Setups::MarketDirection.call'` | `state`, `distribution_days`, `size_factor` (1.0 / 0.5 / 0.25) |
| H17.4 | When the state is under pressure or correction: a watchlist card's size line | Adds "Market correction: a cautious size at 25% of your risk would be N shares" |
| H17.5 | Same, in the buy dialog | The cautious line has "Use N", which fills the quantity |
| H17.6 | `/backtest` | Chart "By market direction" |

## H18. Base count and volume signatures

| # | Steps | Expected |
| - | ----- | -------- |
| H18.1 | `/screener` → All setups | Badges "Base N" ("Base N+" when the history starts near the low), "Pocket pivot" / "Pocket pivot Nd ago", "U/D vol N", "Volume dry-up" |
| H18.2 | A 3rd-or-later base | Amber "Base 3 · late stage"; not on Entry zone now, listed under "Held back by guards" |
| H18.3 | `/screener/SYMBOL` readiness card | The same badges, with explanations on hover |
| H18.4 | `/backtest` | Charts by base count, pocket pivot, up/down volume and volume dry-up; the guard chart includes "late_stage_base" |

## H19. Heads-up alerts and secondary setups *(market hours for H19.1–H19.3)*

| # | Steps | Expected |
| - | ----- | -------- |
| H19.1 | A tracked VCP stock rises to within 3% of its pivot | Alert "Approaching zone": "SYMBOL is 2.4% below its 500.00 pivot at 488.00."; Telegram 🟡 message with that line |
| H19.2 | It stays near, then falls 5%+ away and comes back | No repeat while near; one new alert on the return |
| H19.3 | A tracked stock in an uptrend dips to its rising 21-day average on light volume | Alert "Pullback to 21-day" with the EMA value and projected volume; at most once that day |
| H19.4 | Add to watchlist dialog | Six setup types, including 3-weeks-tight and Undercut and rally, with what the pattern found |
| H19.5 | `/screener` → All setups | Some rows show the new setup labels; none of them on Entry zone now |
| H19.6 | `/backtest` | The setup-type chart lists the new types once snapshots are rebuilt |

## H20. Sell-rule alerts *(market hours for H20.1–H20.3)*

| # | Steps | Expected |
| - | ----- | -------- |
| H20.1 | An open position's price falls to its stop | "Position alerts" on /watchlist: "Stop hit … Selling at the stop: -Rs N after costs." (+ "settle (T+2) … from D" if bought in the last 2 sessions); Telegram "🔴 hit your stop"; no repeat on the next sync |
| H20.2 | Price reaches +1R while the stop is below break-even | "Up 1R" with **Move stop to break-even (N)**; clicking it updates the stop; the button disappears |
| H20.3 | Price 20%+ above the average / at the target | "+20% zone" / "Target reached" |
| H20.4 | After the end-of-day sync, a position that closed under its 50-day on heavy volume | "50-day break" with the volume multiple |
| H20.5 | A position held 15+ sessions under +0.5R | "Time stop" after the close |
| H20.6 | Menu badge on Watchlist | Counts unread watchlist and position alerts; "Mark all read" clears each panel |

## H21. Portfolio heat and concentration

| # | Steps | Expected |
| - | ----- | -------- |
| H21.1 | Settings → Capital & Risk | Fourth field "Max per sector (% of capital)", default 30; saves |
| H21.2 | `/positions` with open positions | "Portfolio heat" bar with the limit marker, "X% of capital at risk · limit 6%", room, cash/invested, per-position chips |
| H21.3 | A sector worth more than 30% of capital | "Sector exposure" shows it in red with "Over your 30% sector limit" |
| H21.4 | Position alerts | Panel on /positions (not /watchlist); latest alert on each card; Positions menu badge counts unread |
| H21.5 | Buy dialog / watchlist size line when the buy would exceed the limit | "This buy takes open risk to N% of capital (limit 6%, now M%). K shares would stay within it" + "Use K" (dialog) |
| H21.6 | Entry zone now while over/near the limit | Note "Your open risk is N% of capital (limit 6%)…" with a link to Positions |

## H22. Close and review

| # | Steps | Expected |
| - | ----- | -------- |
| H22.1 | `/positions` → a card → **Record a sell**, part of the shares | "Recorded: sold N … M shares left", realized gain / CGT / net; card shows the smaller quantity |
| H22.2 | Sell shares bought in the last 2 sessions | Dialog notes only N have settled; after saving, "… hadn't settled (T+2) on D" |
| H22.3 | Sell the rest | Position moves to **Closed**; its watchlist item is archived |
| H22.4 | **Closed** tab | Net after fees and tax, R, MAE/MFE, days; stats strip (win rate, net, expectancy, average R, plan followed) |
| H22.5 | **Review this trade** → choose "Partly", a tag, a lesson → Save | Review shown on the card; stats "Plan followed" counts it |
| H22.6 | Remove the closing sell from Fills | Position reopens under Open |
| H22.7 | A lot held over 365 days | CGT at 7.5% on that lot's gain |

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
