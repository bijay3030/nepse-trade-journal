# Do the scanner's indicators catch NEPSE trend changes? (2020–2026)

A study of every 15% trend change in 292 listed NEPSE companies from January 2020 to
13 November 2026 (about 1,750 sessions each, daily prices from Merolagani's adjusted
history), and how 18 indicator settings did at those turns. Run on 15 November 2026.

Rule checks on past data, not advice. Read the caveats at the end.

## Method

1. **Turning points.** For each stock, a *bottom* is the lowest close before the price
   rises 15% or more, and a *top* is the highest close before it falls 15% or more
   (a zigzag on closing prices). That found **2,473 rises and 2,525 falls**.
2. **Catching a turn.** For each rise (bottom → top), the first bullish signal of a
   setting inside the rise: was there one, how many sessions after the bottom, and how
   much of the rise was still ahead. Falls are scored the same way with bearish signals.
3. **Trading a signal.** Every time a signal began on a liquid stock (average turnover
   NPR 2M+ a day): within 40 sessions, did the price reach **+10% before −7%** (a win)?
   For bearish signals ("warnings"): **−10% before +7%** (right).
4. **Baseline.** The same test on a random liquid stock-day. A signal is only useful if it
   beats this.
5. **Scenarios.** Results split by year, by NEPSE's trend (above/below a rising/falling
   200-day average), by the signal day's volume, by the stock's own 200-day average and by
   its 3-month strength against NEPSE.

`*` marks the scanner's current settings (TradingView defaults).

## 1. Catching bottoms and tops

| Setting | Bottoms caught | Sessions after bottom | Rise still ahead | Tops caught | Sessions after top | Fall still ahead |
|---|---|---|---|---|---|---|
| ALMA 9 * | 99.6% | 1 | 89% | 99.7% | 2 | 83% |
| HMA 9 | 98.9% | 2 | 87% | 99.1% | 2 | 79% |
| ALMA 21 | 98.5% | 2 | 83% | 98.5% | 3 | 74% |
| HMA 21 * | 95.9% | 4 | 82% | 97.3% | 4 | 70% |
| ALMA 50 | 94.3% | 5 | 75% | 90.4% | 7 | 63% |
| Aroon 14 | 92.5% | 7 | 75% | 93.2% | 10 | 60% |
| EMA 5/20 | 91.1% | 7 | 68% | 91.0% | 10 | 56% |
| HMA 55 | 87.3% | 8 | 69% | 83.6% | 11 | 58% |
| EMA 9/21 * | 86.0% | 10 | 66% | 86.9% | 13 | 53% |
| Aroon 25 Up ≥ 70 * | 84.7% | 13 | 66% | 88.6% | 8 | 64% |
| Aroon 25 * | 83.6% | 13 | 69% | 84.7% | 17 | 51% |
| 9/21 + Aroon 25 ≥ 70 | 83.6% | 13 | 63% | 87.4% | 8 | 64% |
| EMA 10/30 | 79.6% | 13 | 62% | 82.2% | 16 | 49% |
| 21/50 + HMA 21 up | 73.8% | 17 | 62% | 80.3% | 4 | 71% |
| EMA stack 9>21>50 * | 69.5% | 19 | 60% | 74.4% | 14 | 54% |
| Aroon 50 | 60.7% | 24 | 65% | 61.0% | 32 | 38% |
| EMA 20/50 | 58.4% | 21 | 56% | 61.9% | 25 | 41% |
| EMA 21/50 * | 57.3% | 21 | 56% | 61.1% | 25 | 41% |

**The trade-off:** fast settings (ALMA 9, HMA 9/21) are at almost every turn within 1–4
sessions with most of the move ahead, but they fire constantly (ALMA 9 began 36,855 times
on liquid stocks against ~2,500 real rises), so most of their signals are noise. Slow
settings (EMA 21/50, Aroon 50) miss about 40% of turns and arrive 3–5 weeks late, with only
about half of the move left.

## 2. Trading the signals (+10% before −7% within 40 sessions)

| Setting | Signals | Won | Lost | | Setting | Signals | Won | Lost |
|---|---|---|---|---|---|---|---|---|
| **Random stock-day (baseline)** | 83,903 | **41.7%** | **47.8%** | | | | | |
| HMA 55 | 5,424 | **47.0%** | **42.2%** | | ALMA 50 | 13,784 | 43.9% | 44.4% |
| 9/21 + Aroon 25 ≥ 70 | 5,813 | 46.4% | 46.5% | | HMA 21 * | 12,900 | 43.4% | 45.5% |
| Aroon 25 Up ≥ 70 * | 6,292 | 46.1% | 45.7% | | ALMA 21 | 22,426 | 43.2% | 45.9% |
| EMA 9/21 * | 5,211 | 45.0% | 45.0% | | ALMA 9 * | 36,855 | 43.1% | 46.3% |
| EMA 5/20 | 7,131 | 44.9% | 44.2% | | HMA 9 | 24,900 | 43.0% | 46.7% |
| EMA stack 9>21>50 * | 3,855 | 44.9% | 47.7% | | EMA 21/50 * | 2,308 | 42.5% | 50.0% |
| Aroon 25 * | 4,931 | 44.9% | 43.7% | | EMA 20/50 | 2,346 | 41.9% | 50.1% |
| Aroon 14 | 8,503 | 44.7% | 43.8% | | Aroon 50 | 2,707 | 41.9% | 48.7% |
| EMA 10/30 | 4,151 | 44.7% | 45.5% | | | | | |
| 21/50 + HMA 21 up | 7,754 | 44.5% | 48.7% | | | | | |

**Over seven years, most signals beat a random entry, but only by 2–5 points.**
HMA 55 is the best balance (47% won vs 42% lost); the slow EMA 20/50 and 21/50 crosses are
no better than random.

### By year: the market decides

Won % (+10% before −7%):

| Setting | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 | 2026 |
|---|---|---|---|---|---|---|---|
| **Random stock-day** | **64.4** | **49.6** | **28.9** | **33.1** | **52.8** | **39.7** | **28.8** |
| EMA 5/20 | 71.2 | 54.5 | 47.6 | 35.0 | 52.0 | 42.0 | 31.0 |
| EMA 9/21 * | 66.8 | 53.8 | 52.9 | 36.7 | 51.8 | 42.4 | 28.6 |
| EMA 21/50 * | 51.3 | 42.0 | 26.4 | 46.0 | 60.8 | 41.8 | 34.7 |
| HMA 21 * | 68.7 | 53.7 | 32.8 | 32.1 | 54.0 | 40.3 | 32.3 |
| HMA 55 | 65.6 | 62.6 | 47.9 | 36.6 | 55.7 | 45.2 | 30.2 |
| ALMA 9 * | 66.6 | 52.3 | 30.9 | 31.0 | 53.0 | 41.6 | 32.3 |
| Aroon 25 * | 60.2 | 53.3 | 43.2 | 39.4 | 57.5 | 45.6 | 27.3 |
| Aroon 25 Up ≥ 70 * | 63.1 | 52.0 | 44.3 | 47.5 | 55.1 | 40.3 | 28.9 |
| 9/21 + Aroon 25 ≥ 70 | 63.4 | 52.4 | 43.8 | 49.2 | 55.4 | 38.6 | 29.0 |

- **2020–21 (bull run) and 2024:** nearly everything worked, because the market rose.
- **2022–23 (bear market):** random buys mostly failed (29–33% won), but **EMA 9/21,
  HMA 55, Aroon ≥ 70 and the 9/21 + Aroon combination still won 44–53%**: crosses after a
  decline caught the bounces. This is where the signals added the most.
- **2026 (sideways):** nothing beat random, which is what the scanner's one-year track
  record showed. Our earlier conclusion was right for this year, not for every year.

## 3. Scenarios: what made a bullish signal better

Won % for bullish signals (signals in brackets):

| Setting | Volume ≥ 1.5× avg | Volume < 1.5× | Above own 200-day | Below own 200-day | Beating NEPSE (3m) | Lagging NEPSE (3m) |
|---|---|---|---|---|---|---|
| EMA 9/21 * | 45.8 (1,934) | 44.5 (3,228) | 41.9 | 45.7 | 44.7 | 45.2 |
| HMA 21 * | **47.8** (3,319) | 41.4 (9,395) | 42.4 | 39.8 | 43.6 | 42.4 |
| HMA 55 | **51.7** (1,985) | 44.3 (3,439) | 46.6 | 44.0 | 46.0 | 47.9 |
| ALMA 9 * | **48.2** (6,839) | 41.8 (29,239) | 42.2 | 39.6 | 42.5 | 43.2 |
| Aroon 25 Up ≥ 70 * | 47.6 (3,433) | 43.4 (2,744) | 43.8 | 44.0 | 46.5 | 44.8 |
| 9/21 + Aroon 25 ≥ 70 | 47.4 (3,422) | 43.9 (2,280) | 43.9 | 44.3 | 46.8 | 45.0 |

- **Volume is the most useful filter:** a signal on a day with 1.5× the 50-day average
  volume won 3–7 points more, for every setting. HMA 55 with volume won 51.7%.
- **The stock's own trend and its strength against NEPSE didn't help these crossover
  signals** (often slightly worse). Those filters belong to the board's setups, not here.

### NEPSE's trend

Won % by NEPSE's position against its 200-day average on the signal day:

| | NEPSE above a rising 200-day | Mixed | NEPSE below a falling 200-day |
|---|---|---|---|
| Random stock-day | 34.6 | 48.2 | 40.5 |
| EMA 9/21 * | 37.5 | 47.6 | **49.3** |
| HMA 55 | **43.9** | 49.0 | 45.2 |
| Aroon 25 Up ≥ 70 * | 39.7 | 50.1 | 46.4 |

The 200-day average turns late, so "NEPSE above a rising 200-day" mostly marked the late
part of rallies (2021's peak, 2025), when buying anything did badly. The year table is a
clearer guide. Signals helped most against the baseline when NEPSE was falling, by catching
rebounds.

## 4. Bearish crossovers as exit warnings

Right % (−10% before +7%) is about 30% for almost every setting, against **30.2%** for a
random day. **Bearish crossovers barely predicted falls**: about 55% of the time the price
rose 7% first. As exit rules they would mostly have sold too early; stop-losses and the
app's sell rules are better exits.

## Conclusions

1. **Settings are compatible with NEPSE** and, over seven years, most bullish signals beat
   a random entry by **2–5 points**. They are weak signals, not useless ones.
2. **The market year matters far more than the setting.** In rising years everything works;
   in falling years the better signals still catch rebounds; in the 2026 sideways market
   nothing works.
3. **Best balance: HMA 55** (catches 87% of bottoms 8 sessions in, 69% of the rise still
   ahead; 47% won vs 42% lost, 51.7% with volume). **Aroon 25 Up ≥ 70** and **EMA 9/21 +
   Aroon 25 ≥ 70** come next. **EMA 21/50 and EMA 20/50 are the weakest** (late and no
   better than random).
4. **Require volume:** 1.5× the 50-day average on the signal day adds 3–7 points.
5. **Don't use bearish crosses as sell signals** on NEPSE.

## Possible changes to the app

- *Done (15 Nov 2026):* the scanner uses **HMA 55** and **ALMA 21**, dropped the EMA 21/50
  cross, has a **"volume ≥ 1.5×" filter** (on by default, also for Telegram alerts), and
  shows the **track record since 2020** by year (prices in `stock_price_archives`, ~35 MB).
- *Done (15 Nov 2026):* a **market-phase banner** on the scanner, using NEPSE's 20-day
  against its 50-day average (faster than the 200-day). Measured since 2020: in uptrends
  every signal except ALMA beat the average stock-day (HMA 55 +7.3% vs +2.5% over 20
  sessions); in sideways phases they were close to it (HMA 55 +2.8% vs +1.6%); in
  downtrends every signal did worse (HMA 55 +0.8% vs +1.8%).

## Caveats

- **Survivorship:** only companies listed today; delisted or merged ones are missing.
- **Before costs:** the +10%/−7% test ignores commission, SEBON and DP (about 0.8% a round
  trip).
- **Entries at the signal-day close**, which isn't always achievable on NEPSE (circuits,
  thin books).
- **Overlapping samples:** a stock can give several signals in one swing; samples aren't
  independent.
- **One swing size (15%) and one test (+10/−7 in 40 sessions)**; other choices shift the
  numbers, though the comparisons with the baseline held across settings.
- **Adjusted prices** from Merolagani (bonus/rights adjusted); a few adjustment errors are
  possible.
