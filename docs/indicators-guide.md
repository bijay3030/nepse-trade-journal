# Trend indicators and crossovers, from first principles

Used by the **Indicator Scanner** (`/scanner`). All settings are TradingView's defaults so
values match its charts.

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
- **21 crosses above 50:** the same at a slower, more meaningful timescale.
- **Stack 9 > 21 > 50:** every timeframe agrees on an uptrend. A state, not an event.
- **Analogy:** three runners. When the sprinter (9) passes the middle-distance runner (21),
  the pace picked up recently; when all three line up fastest-first, the pack is accelerating.
- **Weakness:** in sideways markets the lines tangle and cross back and forth (whipsaws).

## HMA: Hull moving average (21)

- **What:** Alan Hull's near-zero-lag average: WMA(2 × WMA(n/2) − WMA(n), √n). Doubling the
  short average and subtracting the long one overshoots in the direction of recent change,
  which cancels the lag; the final WMA smooths it.
- **Signal:** the HMA's direction turning from down to up.
- **Analogy:** a driver looking where the road is going, not at the road under the car.
- **Weakness:** so fast that one strong day can flip it.

## ALMA: Arnaud Legoux moving average (9, offset 0.85, sigma 6)

- **What:** a weighted average whose weights follow a bell curve centred near the recent end
  of the window (offset 0.85); sigma sets its width.
- **Why:** smooth like a long average, responsive like a short one, with less overshoot than
  the HMA.
- **Signal:** the close crossing above the ALMA.
- **Analogy:** a camera focused sharply on the recent past, with the distant past softly
  blurred rather than cut off.

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

## What they did on NEPSE

The scanner page shows each signal's track record on our history (about a year, ending at
the latest session): the return 5, 10 and 20 sessions after each signal began, against all
stock-days. In the year to November 2026, a mostly sideways market, **every bullish signal
did worse than the average stock-day**: for example, 20 sessions after a 9/21 cross the
average was −2.8% with 27% of cases up, against −0.1% and 42% for all stock-days. Crossovers
tended to come after a short rise that then faded. Trend-following signals usually do better
in trending markets; the page updates these numbers every night, so you can see if that
changes.
