# Trend indicators and crossovers, from first principles

Used by the **Indicator Scanner** (`/scanner`). The settings (EMA 9/21/50, HMA 55, ALMA 21
with offset 0.85 and sigma 6, Aroon 25) were chosen from a test on NEPSE, 2020–2026
([research](research/indicator-turning-points-2020-2026.md)). Set the same in TradingView
to compare values.

## The idea

A single day's price is noisy. Averaging several days smooths the noise so the direction
shows, but every average **lags**: it reacts after the move. Each indicator below is a
different trade-off between **smooth** (fewer false signals) and **fast** (earlier signals).

**Analogy:** judging which way a ship is turning from its wake. A long wake (slow average)
is steady but shows the turn late; a short wake (fast average) shows it early but wobbles.

## EMA: exponential moving average (9, 21, 50)

- **What:** an average that weights recent days more. Today's EMA = close × k + yesterday's
  EMA × (1 − k), with k = 2 ÷ (period + 1). In a 9-day EMA, today counts about 20%.
- **Periods:** 9 ≈ two weeks (very short term), 21 ≈ a month (short term), 50 ≈ 2½ months
  (medium term).
- **On a steady rise** an EMA lags about (period − 1) ÷ 2 days behind the price.

## EMA crossovers

- **9 crosses above 21:** recent prices now average higher than the past month's: short-term
  momentum turned up. Early and frequent, with many false starts in sideways markets.
- **21 crosses above 50:** the same at a slower timescale. Not on the scanner: on NEPSE it
  came about 21 sessions after bottoms, with half the rise gone, and won no more often than
  a random entry.
- **Stack 9 > 21 > 50:** every timeframe agrees on an uptrend. A state, not an event.
- **Analogy:** three runners. When the sprinter (9) passes the middle-distance runner (21),
  the pace picked up recently; when all three line up fastest-first, the pack is accelerating.
- **Weakness:** in sideways markets the lines tangle and cross back and forth (whipsaws).

## HMA: Hull moving average (55)

- **What:** Alan Hull's near-zero-lag average: WMA(2 × WMA(n/2) − WMA(n), √n). Doubling the
  short average and subtracting the long one overshoots in the direction of recent change,
  which cancels the lag; the final WMA smooths it.
- **Signal:** the HMA's direction turning from down to up.
- **Analogy:** a driver looking where the road is going, not at the road under the car.
- **Why 55:** at 21 (TradingView's default) it flipped so often on NEPSE that its signals were
  barely better than random. At 55 it caught 87% of bottoms about 8 sessions in, and was the
  best of 18 settings tested (47% of signals reached +10% before −7%, against 42% for a
  random entry; 52% on strong volume).
- **Weakness:** fast settings flip on one strong day; 55 trades some speed for fewer flips.

## ALMA: Arnaud Legoux moving average (21, offset 0.85, sigma 6)

- **What:** a weighted average whose weights follow a bell curve centred near the recent end
  of the window (offset 0.85); sigma sets its width.
- **Why:** smooth like a long average, responsive like a short one, with less overshoot than
  the HMA.
- **Signal:** the close crossing above the ALMA.
- **Analogy:** a camera focused sharply on the recent past, with the distant past softly
  blurred rather than cut off.
- **Why 21:** at 9 the close crossed it about 37,000 times in seven years against ~2,500 real
  rises: almost all noise. 21 fires less and did slightly better.

## Aroon (25)

- **What:** it measures time, not price. Aroon Up = 100 × (25 − days since the highest high) ÷
  25; Aroon Down the same for the lowest low.
- **Meaning:** Up near 100 means new highs keep coming (a fresh uptrend). Up crossing above
  Down means highs became more recent than lows: a possible new uptrend. Both low: no trend.
- **Aroon Up ≥ 70:** a new 25-session high within the last 7 sessions.
- **Analogy:** a scoreboard of who scored most recently. If the buyers scored the last goal (a
  new high) recently and the sellers haven't for ages, the buyers have the momentum.

## Using them together

EMA crosses say the trend turned; HMA and ALMA say it earlier with less lag; Aroon says
whether new highs are happening at all. Traders often require two to agree (for example a
9/21 cross plus Aroon Up ≥ 70) to filter out whipsaws.

**Volume** confirms a signal: on NEPSE, signals that began on a day with 1.5× the 50-session
average volume did 3–7 points better for every setting tested, so the scanner requires it by
default.

## What they did on NEPSE

The scanner page shows each signal's track record since January 2020 (archived prices plus
the regular history): the return 5, 10 and 20 sessions after each signal began, against all
stock-days, also for signals on 1.5× volume and year by year. On 13 November 2026, 20
sessions after a signal began:

| Signal | Avg return | Went up | On 1.5× volume | Went up |
|---|---|---|---|---|
| All stock-days (baseline) | +2.06% | 47.5% | | |
| HMA 55 turned up | +2.60% | 49.0% | **+4.20%** | **54.2%** |
| Aroon Up crossed above Down | +2.03% | 46.1% | +3.91% | 51.6% |
| Aroon Up ≥ 70 | +2.36% | 46.2% | +3.40% | 49.5% |
| EMA 9 > 21 > 50 | +2.31% | 46.5% | +2.90% | 46.4% |
| EMA 9 crossed above 21 | +2.13% | 47.4% | +2.85% | 48.8% |
| Close crossed above ALMA 21 | +1.61% | 46.9% | +2.06% | 48.4% |

- **Volume matters most:** every signal did better on a 1.5× volume day.
- **The year matters more than the signal:** in 2020–21 and 2024 nearly everything rose; in
  the 2022 fall HMA 55, the 9/21 cross and Aroon still averaged +1.8% to +3.6% while the
  average stock-day lost 0.9%; in 2026, a sideways market, every signal did worse than the
  baseline (about −3% against −1%).
- **NEPSE's phase matters too** (its 20-day average against the 50-day, shown in a banner on
  the scanner): signals that began in a NEPSE uptrend did best (HMA 55 +7.3% against +2.5%
  for all stock-days), while in downtrends every signal did worse than the average
  stock-day (HMA 55 +0.8% against +1.8%).
- **The crossover levels** (entry at the signal, stop under EMA 21, target 2× the risk) still
  lost money after costs for every signal (profit factor 0.68–0.98), so use the board's
  setups for entries and these signals as a shortlist.

These numbers include every stock-day; the [research](research/indicator-turning-points-2020-2026.md)
looked at liquid stocks only, with a +10% / −7% test, and reached the same ranking. The page
updates them every night.
