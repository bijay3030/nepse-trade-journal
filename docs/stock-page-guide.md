# The single-stock page, from first principles

Open any stock at `/screener/SYMBOL` (for example `/screener/NABIL`). This guide walks
through every part of that page: what it measures, why it matters, and how to read it.
Each part has an everyday analogy and a worked example with **NABIL's real figures**
(snapshot of 2 October 2026; live price on 12 October).

> Rule checks on stored data, not advice. The page never says "buy" or "sell".

---

## 0. The idea behind the whole page

A share price moves because people buy and sell it. Before buying, a swing trader wants
answers to four questions:

| Question | Where on the page |
| -------- | ----------------- |
| **Is the stock healthy?** Is it in an uptrend, not a downtrend? | Chart, moving averages, trend template |
| **Is it a leader?** Is it doing better than the market? | RS rating, RS line |
| **Is there a low-risk entry now?** A place to buy where being wrong costs little? | Setup, entry zone, stop, target |
| **Who is buying, and what could hurt?** | Volume, broker flow, guards, book closes, EPS |

**Analogy: catching a train.** Health is whether the train is moving in the direction you
want to go (trend). Leadership is whether it's the express or the local (RS). The entry
zone is the platform window when the doors are open: board then, not while the train is
already speeding away (extended). The stop is the next station where you get off if it
turns out to be the wrong train. The target is your destination.

---

## 1. Header: price, change, setup state

**What:** the latest price, today's % change, and the setup state (for example "Too early"
or "In entry zone").

**First principles:** a price is just the last trade. It tells you nothing alone; the rest
of the page compares it with the stock's own history, the market and the plan.

**NABIL:** live **537.10** on 12 October. Its last nightly snapshot (2 October, close
528.70) said **Too early**: the close was just under its zone. The live price now sits
inside the zone (section 6). That's why the board, built on closes, changes once a day,
while the "Live …" line moves during the session.

---

## 2. The chart

### Candles

**What:** each candle is one trading day. The body runs from the open to the close (green
when it closed up, red when down); the thin wicks reach the day's high and low.

**First principles:** a candle is a one-day summary of a fight between buyers and sellers.
A long lower wick means sellers pushed the price down but buyers pushed it back up: buyers
won the day. A close near the high means buyers were in control at the end.

**Analogy:** a candle is a day's weather report: where it started, the extremes, and where
it ended.

### Volume bars

**What:** shares traded each day.

**First principles:** price tells you **what** happened; volume tells you **how many people
agreed**. A breakout on 3× normal volume means many buyers; the same move on thin volume
could be one person's order.

**Analogy:** a crowd at a shop. A queue out the door (high volume) is a stronger signal
than one customer.

### Moving averages (50-day, 200-day lines)

**What:** the average closing price of the last 50 or 200 sessions, redrawn every day.

**First principles:** averages smooth daily noise, so you can see the direction. Price
above a **rising** average means buyers have been paying more and more over that period.
The 50-day is about 2½ months (the medium-term mood); the 200-day is about a year (the
long-term mood).

**Analogy:** your average speed on a journey. One slow traffic light (a red day) doesn't
change it much; a long hill does.

**NABIL:** 50-day **526.12**, 150-day **509.47**, 200-day **500.54**. The close (528.70) is
above all three, and they're stacked in the right order (50 > 150 > 200): an orderly uptrend.

### Zone band, stop, target, pivot, contraction markers

The shaded **band** is the entry zone, the red line is the stop (invalidation), the green
line is the target, and a pivot line appears for breakout setups. Section 6 explains how
they're set. If you track the stock, the chart shows **your** levels.

---

## 3. RS line vs NEPSE (lower pane)

**What:** the stock's price divided by the NEPSE index, starting at 100. It rises when the
stock beats the market and falls when it lags, even if both are going up.

**First principles:** in a rising market most stocks rise. What matters is which ones rise
**more**: those have extra buyers beyond the general tide. Strong stocks tend to stay strong
for a while (momentum).

**Analogy:** a runner in a race. Whether everyone is speeding up doesn't matter. The RS line
shows whether **this** runner is pulling ahead of the pack.

- **Dots** mark new RS highs. **Green dots** are new RS highs while the price is still below
  its own high: the stock is beating the market before its price breaks out, a classic early
  sign of a leader.
- The caption gives the RS change over 20 and 60 sessions.

**NABIL:** RS **+6.1%** over 60 sessions, **−0.45%** over the last 20. The last RS new high
was on **10 September**, and it **led the price** (green dot). So NABIL has beaten the
market over three months but paused recently.

**RS rating (1–99)** in the readiness card is the same idea as a single number: NABIL's
3/6/9/12-month performance ranked against every stock. **RS 80** means it beat 80% of
NEPSE stocks.

---

## 4. Volume today *(market hours)*

**What:** today's volume so far, the projected full-day volume, and how that compares with
the 50-day average.

**First principles:** at 11:30, a stock has only traded for 30 minutes. Comparing that with
a full day's average would make every morning breakout look weak. The app learns NEPSE's
normal pattern (busy open, calmer afterwards) and projects the day's total from it.

**Analogy:** a restaurant at 12:15. If it has already served half its usual daily lunches,
today is going to be busy, even though the day isn't over.

**Example:** "Volume today: 35,000 so far · projected 100,000 by the close = 2.0× the
50-day average". A breakout alert needs 1.5× or more.

---

## 5. Entry readiness card

### The score (0–100)

**What:** how many conditions for an entry are in place, from five parts:

| Part | Max | What it measures | NABIL |
| ---- | --- | ---------------- | ----- |
| Trend template | 30 | how many uptrend rules pass | **26** |
| Setup quality | 25 | how clean the setup pattern is | **20** |
| Market | 15 | overall market regime | **3** (market rated weak) |
| Sector | 15 | the sector index vs NEPSE over 20 sessions | **14** (banks +2.74 pts ahead) |
| Broker flow | 15 | accumulation vs distribution | **9** (neutral, +3.21) |
| **Total** | 100 | | **72** |

**Analogy:** a pre-flight checklist. Each item adds confidence; a missing item isn't a
crash, but the pilot notices.

The board needs **60+**. NABIL's 72 clears it; what kept it off the board on 2 October
was its zone state (too early), not the score.

### Trend template: 8 rules for a "stage 2" uptrend

**First principles:** stocks move through stages: basing (sideways), advancing (stage 2),
topping, and declining. Big gains happen in stage 2. These rules (from Mark Minervini) check
that a stock is in it.

| Rule | NABIL | Passed |
| ---- | ----- | ------ |
| Price above the 150- and 200-day | 528.70 vs 509.47 / 500.54 | ✅ |
| 150-day above the 200-day | 509.47 vs 500.54 | ✅ |
| 200-day rising for a month | 495.71 → 500.54 | ✅ |
| 50-day above the 150 and 200 | 526.12 | ✅ |
| Price above the 50-day | 528.70 vs 526.12 | ✅ |
| 30%+ above the 52-week low | only 14.5% above 461.90 | ❌ |
| Within 25% of the 52-week high | 4.7% below 553.33 | ✅ |
| RS rating 70+ | RS 80 | ✅ |

**Analogy:** a staircase. Higher floors (averages) are stacked above lower ones, and you're
standing near the top floor, not in the basement.

NABIL fails one rule: it hasn't climbed far from its yearly low (a slow, steady stock rather
than a big mover). Seven price rules: 6 pass (the board needs 5+).

### Zone state

- **Too early:** price is below the entry zone (the doors aren't open yet).
- **In entry zone:** the price is in the zone now.
- **Extended:** price ran above the zone (the train has left; chasing it raises your risk).
- **Failed:** price fell to the invalidation level (wrong train).

### Readiness history (sparkline)

The last 60 sessions of the score, with a dashed line at 60 and dots on days that met every
board rule. A rising line means conditions are building; a falling one means they're fading.

### Guards and badges

Guards (thin volume, circuit, extended, late-stage base) keep a stock off the board even if
everything else passes. Badges add context (section 8). **NABIL has no guards.**

---

## 6. Setup and levels: where to enter, where you're wrong, where to take profit

**First principles:** you can't know whether a trade will work. You **can** decide in advance
how much you lose if it doesn't. A good entry is a price close to a level where, if broken,
the idea is clearly wrong. That keeps the loss small while the possible gain stays large.

**Analogy:** a stop is a smoke alarm you install before the fire, not after.

The app tries six setup types and keeps the most actionable. NABIL's is **pullback to a
rising average**: in an uptrend, buyers often step in when the price dips back to its rising
20- or 50-day average.

| Level | NABIL | How it's set |
| ----- | ----- | ------------ |
| Entry zone | **529.47 – 540.06** | the rising average, to 2% above it |
| Invalidation (stop) | **508.29** | 4% below the average: a real break of the trend |
| Target | **553.33** | the nearest resistance: here the 52-week high |

**The reward-to-risk lesson (R:R):** compare what you'd lose at the stop with what you'd
gain at the target.

- Buying at the bottom of the zone, **529.47**: risk 529.47 − 508.29 = **21.18**, reward
  553.33 − 529.47 = **23.86** → about **1.1R**.
- Buying at the live price, **537.10**: risk **28.81**, reward **16.23** → about **0.56R**.

The entry checklist asks for **2R or more**, so NABIL's checklist would **fail** this rule even
though the price is in the zone. With a target this close (the old high), each trade risks
more than it can make. The rules suggest either waiting for a better price or for a breakout
above 553.33 that opens a higher target. That's why the app checks R:R, not just the zone.

**R** is that risk unit. A trade that gains 2× its risk is "+2R". Thinking in R lets you
compare trades of any size.

---

## 7. VCP section

**What:** a **volatility contraction pattern** (Mark Minervini) is a base where each pullback
is smaller than the one before (for example 20% → 12% → 6%), usually on drying volume, then a
breakout above the pivot (the base's high).

**First principles:** each smaller pullback means fewer sellers are left; holders who wanted
out have sold. When supply dries up, a modest wave of buying can push the price up quickly.

**Analogy:** squeezing a sponge. Each squeeze gets less water out. When it's nearly dry,
there's little left to resist the next push.

A qualified VCP needs 2–4 contractions, the first 8–35% deep, each at most 80% of the one
before, the last at most 10%, a base of 15+ sessions, falling volume, and a score of 60+.

**NABIL:** **not a VCP**: one contraction of 5.12% (score 65, pivot 553.33). Its setup is the
pullback in section 6 instead.

---

## 8. Price action, extension and other badges

### Support and resistance

**First principles:** prices remember. Where buyers stepped in before (**support**), they
often step in again; where sellers appeared before (**resistance**), they often sell again.

**Analogy:** a floor and a ceiling in a room. The price bounces between them until one gives.

**NABIL:** trend **sideways** (confidence 0.65), support at **501.97 / 485.18 / 464.81**,
resistance at **528.38 / 548.29**.

### Extension, measured in ADR

**First principles:** "far above the average" depends on how much a stock normally moves. A
5% gap is huge for a sleepy bank and normal for a volatile hydropower stock. **ADR** (average
daily range) is the stock's usual daily high-to-low move, so distances are measured in the
stock's own units.

**Analogy:** a rubber band. Stretch it too far from its anchor (the 50-day) and it tends to
snap back.

**NABIL:** ADR **1.3%**, only **0.38 ADR** above its 50-day (not stretched; 4+ would be
"Extended"); today's move **0.03 ADR** (a quiet day).

### Other badges

| Badge | First principle | NABIL |
| ----- | --------------- | ----- |
| Base N | each new base after a rally is more widely noticed and fails more often | none (no base since its low) |
| U/D vol | volume on up days ÷ down days: >1.2 buyers more eager, <0.8 sellers | **1.02**: balanced |
| Pocket pivot | an up day on more volume than any recent down day: quiet buying | none |
| Volume dry-up | very quiet days in a base: sellers exhausted | 0 days |
| EPS +N% YoY | earnings growth is what keeps institutions buying | **+33.5%** (Q4 082/083, Chukul): strong |

---

## 9. Broker flow card

**What:** from the daily floorsheet (every trade with its buying and selling broker), the
brokers that bought and sold the most shares over 20 sessions. The **flow score** is (top 5
net buyers' share of volume) − (top 5 net sellers' share). +10 or more is
**accumulation**, −10 or less **distribution**.

**First principles:** large investors build positions over weeks through a few brokers. If a
handful of brokers keep absorbing what many others sell, someone big may be accumulating.

**Analogy:** watching a warehouse. If a few trucks keep carrying boxes **in** while many small
vans carry boxes out, someone is stocking up.

**Caveat:** a broker trades for many clients, so this is a hint, not proof of who's buying.
Thin stocks (under NPR 20M turnover in the window) stay neutral.

**NABIL:** **neutral**, score **+3.21**. Top net buyers: R.B.B. Securities **+81,845** shares,
Mega Stock Markets **+50,663**. Top sellers: Sharepro **−35,159**, Siprabi **−34,870**. Some
buying, but not concentrated enough to call it accumulation.

---

## 10. Corporate actions

**What:** upcoming book closes (dividends, bonus shares) and dividend history.

**First principles:** a bonus issue doesn't create value. After a 10% bonus you own 110
shares worth what 100 were, so the price drops by ÷1.10. Without adjusting, every chart and
stop would read that drop as a crash.

**Analogy:** cutting a pizza into more slices. More slices, same pizza.

**NABIL:** no book close coming up. Its 5% bonus book close on 30 September is an example:
the price was adjusted from 566 to 539.05, the app re-fetched the adjusted history and
recalculated the averages, so the chart shows no fake drop.

---

## 11. Putting it together: reading NABIL in two minutes

1. **Healthy?** Mostly yes: 6 of 7 price rules, averages stacked and rising. Weak point: not
   far above its yearly low.
2. **Leader?** Yes, moderately: RS 80, RS line up 6.1% over 60 sessions, though flat lately.
3. **Low-risk entry now?** The price is in its pullback zone, **but** the target (the 52-week
   high, 553.33) is so close that R:R is about 0.6–1.1R. The checklist's 2R rule fails.
4. **Who's buying, what could hurt?** Broker flow neutral; earnings growth strong (+33.5%);
   no guards, no book close.

**What the rules say:** the trend and the leadership are fine, but the trade's arithmetic
isn't. Following the rules means waiting for a better entry or a breakout above 553.33. The
decision is yours; the page makes the trade-off visible.

---

## 12. A 10-minute practice routine

Pick one board stock a day and, on its page:

1. Read the four questions (section 0) and write one line for each.
2. Work out the R:R yourself from the levels (section 6) before looking at the checklist.
3. Look at the RS line: is it making new highs (green dots)?
4. Check the broker flow and the EPS badge.
5. Write your decision (track / skip / wait) and why. Compare with what happened a week later.

After a few weeks you'll read a page in a minute, and you'll know why each number is there.
