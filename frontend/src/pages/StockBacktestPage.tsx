import axios from "axios"
import { format, parseISO } from "date-fns"
import { History } from "lucide-react"
import { useMemo, useState, type FormEvent, type ReactNode } from "react"
import { Link, useNavigate, useParams } from "react-router-dom"

import { Button, Card, CardBody, LoadingSpinner } from "../components/ui"
import { useEquitySymbols, useStockBacktest } from "../features/lab/api"
import { TradesChart } from "../features/lab/TradesChart"
import type { StockBacktest, StockBacktestStrategy, StockBacktestTrade } from "../features/lab/types"
import { cn } from "../lib/cn"

const money = (v: number | null | undefined) => (v == null ? "—" : v.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 }))
const pct = (v: number | null | undefined, digits = 1) => (v == null ? "—" : `${v > 0 ? "+" : ""}${v.toFixed(digits)}%`)
const tone = (v: number | null | undefined) => (v == null ? "text-slate" : v > 0 ? "text-pine" : v < 0 ? "text-ember" : "text-slate")
const pfTone = (pf: number | null | undefined) => (pf == null ? "text-slate" : pf >= 1.3 ? "text-pine" : pf < 1 ? "text-ember" : "text-ink")
const day = (iso: string | null | undefined) => (iso ? format(parseISO(iso), "d MMM yyyy") : "—")
const weekday = (iso: string) => format(parseISO(iso), "EEE d MMM yyyy")

// What each indicator does on the session it signals.
const SIGNAL_RULES: Record<string, string> = {
  scan_ema_9_21: "the 9-day EMA crosses above the 21-day EMA",
  scan_ema_stack: "the 9-, 21- and 50-day EMAs line up in rising order (9 > 21 > 50)",
  scan_hma_up: "the 55-day Hull average turns from falling to rising",
  scan_alma_cross: "the close moves above the 21-day ALMA",
  scan_aroon_cross: "Aroon Up (25) crosses above Aroon Down",
  scan_aroon_strong: "Aroon Up (25) reaches 70 (a new 25-day high within 7 sessions)",
  macd_cross: "the MACD line (12, 26) crosses above its 9-day signal line",
  bollinger_bounce: "the close climbs back above the lower Bollinger band (20, 2) after closing below it",
  breakout_20d: "the close rises above the highest high of the previous 20 sessions",
  golden_cross: "the 50-day average crosses above the 200-day average",
  lab_rsi_reversion: "the stock is above its 200-day average, RSI (14) was under 30 in the last 3 sessions and turns up on a higher close",
  lab_range_grid: "after 60 sessions in a flat 8–30% range, the stock closes up in the bottom 20% of that range",
}
// Crossover systems: the two lines, in words.
const CROSS_LINES: Record<string, [string, string]> = {
  xo_ema_9_21: ["the 9-day EMA", "the 21-day EMA"],
  xo_ema_21_50: ["the 21-day EMA", "the 50-day EMA"],
  xo_ema_50_200: ["the 50-day EMA", "the 200-day EMA"],
  xo_price_hma: ["the close", "the 55-day HMA"],
  xo_price_alma: ["the close", "the 21-day ALMA"],
  xo_alma_hma: ["the 21-day ALMA", "the 55-day HMA"],
}
const rule = (key: string) => {
  const base = SIGNAL_RULES[key.replace(/_vol$/, "")] ?? "the signal fires"
  return key.endsWith("_vol") ? `${base}, on a day with at least 1.5× its 50-session average volume` : base
}
const EXIT_LABELS: Record<string, string> = {
  target: "Target hit", stop: "Stop hit", time: "Time limit (sold at close)", rsi_exit: "RSI reached 65", open: "Still open",
  cross_back: "Crossed back down (sold next open)", cross_back_pending: "Crossed back down (sells at next open)",
}

export function StockBacktestPage() {
  const { symbol: param } = useParams()
  const symbol = param?.toUpperCase() ?? null
  const navigate = useNavigate()
  const { data, isLoading, error } = useStockBacktest(symbol)
  const symbols = useEquitySymbols()
  const [input, setInput] = useState(symbol ?? "")

  const submit = (event: FormEvent) => {
    event.preventDefault()
    const next = input.trim().toUpperCase()
    if (next) navigate(`/stock-backtest/${encodeURIComponent(next)}`)
  }
  const message = axios.isAxiosError(error) ? (error.response?.data as { error?: string } | undefined)?.error : undefined

  return (
    <div className="space-y-5">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="flex items-center gap-2 font-display text-2xl font-bold tracking-tight text-ink sm:text-3xl"><History className="h-6 w-6" /> Stock Backtest</h1>
          <p className="mt-1 max-w-3xl text-sm text-slate">
            Every indicator and strategy in the app, traded on one stock's full price history: when each one bought and sold, for how long, and what it made.
            Computed from the latest data each time. Rule checks on past prices, not advice.
          </p>
        </div>
        <form onSubmit={submit} className="flex items-center gap-2" role="search">
          <label htmlFor="backtest-symbol" className="sr-only">Stock symbol</label>
          <input id="backtest-symbol" list="backtest-symbols" value={input} onChange={(e) => setInput(e.target.value)} placeholder="Symbol, e.g. BEDC"
            className="w-44 rounded-lg border border-slate/20 bg-white px-3 py-2 text-sm uppercase text-ink" autoComplete="off" />
          <datalist id="backtest-symbols">{(symbols.data ?? []).map((s) => <option key={s.symbol} value={s.symbol}>{s.name}</option>)}</datalist>
          <Button type="submit">Backtest</Button>
        </form>
      </header>

      {!symbol ? (
        <Card className="p-8 text-center text-sm text-slate">Enter a stock symbol to backtest every strategy on it.</Card>
      ) : isLoading ? (
        <div className="flex h-[40vh] items-center justify-center"><LoadingSpinner size="lg" /></div>
      ) : error || !data ? (
        <Card className="p-8 text-center text-sm text-slate">{message ?? `Couldn't backtest ${symbol}.`}</Card>
      ) : (
        <Report data={data} />
      )}
    </div>
  )
}

function Section({ id, title, note, children }: { id?: string; title: string; note?: ReactNode; children: ReactNode }) {
  return (
    <section id={id} className="space-y-2">
      <div>
        <h2 className="font-display text-lg font-bold text-ink">{title}</h2>
        {note && <p className="max-w-4xl text-xs text-slate">{note}</p>}
      </div>
      {children}
    </section>
  )
}

function Report({ data }: { data: StockBacktest }) {
  const traded = data.strategies.filter((s) => s.stats.trades > 0)
  const best = useMemo(() => {
    for (const min of [20, 10, 5]) {
      const pick = traded.filter((s) => s.stats.trades >= min && s.stats.profit_factor != null).sort((a, b) => (b.stats.profit_factor ?? 0) - (a.stats.profit_factor ?? 0))[0]
      if (pick) return pick
    }
    return null
  }, [traded])
  const [selected, setSelected] = useState<string | null>(null)
  const current = data.strategies.find((s) => s.key === (selected ?? best?.key)) ?? traded[0]

  return (
    <div className="space-y-6">
      <Card>
        <CardBody>
          <p className="text-xs text-slate">{data.name} · {data.sector} · {day(data.from)} to {day(data.to)} · <Link className="font-semibold text-ink underline" to={`/screener/${encodeURIComponent(data.symbol)}`}>stock page</Link></p>
          <p className="mt-2 max-w-4xl text-base text-ink" aria-label="Summary">
            {best ? (
              <><b>{best.label}</b> has the best record on {data.symbol}: profit factor <b className={pfTone(best.stats.profit_factor)}>{best.stats.profit_factor}</b> over{" "}
                <b>{best.stats.trades}</b> trades ({best.stats.win_rate_pct}% won, {pct(best.stats.total_return_pct)} compounded), holding about {best.stats.avg_hold} sessions a trade.</>
            ) : <>No strategy has enough trades on {data.symbol} to judge.</>}{" "}
            Holding the stock throughout made <b className={tone(data.buy_hold.return_pct)}>{pct(data.buy_hold.return_pct)}</b>, with a worst fall of{" "}
            <b className="text-ember">{pct(data.buy_hold.max_drawdown_pct)}</b>.
          </p>
          <dl className="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-4">
            <Fig label="Sessions tested" value={data.sessions.toLocaleString("en-US")} />
            <Fig label="Buy and hold" value={pct(data.buy_hold.return_pct)} valueTone={tone(data.buy_hold.return_pct)} />
            <Fig label="Worst fall while holding" value={pct(data.buy_hold.max_drawdown_pct)} valueTone="text-ember" />
            <Fig label="Average 20-session move" value={pct(data.baseline["20"]?.avg_pct, 2)} note="any day, no signal" />
          </dl>
        </CardBody>
      </Card>

      <Section id="ranking" title="Which indicator worked best" note={<>Each strategy bought at the next session's open after its signal (skipped if that opened more than {data.rules.max_gap_pct}% higher), with a stop just under the 10-session low (at most {data.rules.max_stop_pct}% away), a target of {data.rules.reward_multiple}× the risk, and a sale after {data.rules.hold} sessions otherwise; {data.rules.cost_pct}% costs per round trip. Profit factor = money made on winners ÷ money lost on losers (above 1 made money). <b>Click a row to see its trades.</b></>}>
        <Card className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm" aria-label="Strategy ranking">
              <thead className="border-b border-mist/80 bg-slate/5 text-left text-[11px] font-bold uppercase tracking-wider text-slate">
                <tr>
                  <th className="px-3 py-2">Strategy</th><th className="px-3 py-2 text-right">Trades</th><th className="px-3 py-2 text-right">Won</th>
                  <th className="px-3 py-2">Profit factor</th><th className="px-3 py-2 text-right">Avg / trade</th><th className="px-3 py-2 text-right">Compounded</th>
                  <th className="px-3 py-2 text-right">Avg held</th><th className="px-3 py-2 text-right">Worst run</th><th className="px-3 py-2 text-right">Last signal</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-mist/60">
                {data.strategies.map((s) => (
                  <StrategyRow key={s.key} s={s} active={s.key === current?.key} onSelect={() => setSelected(s.key)} />
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      </Section>

      {current && <TradeLog data={data} strategy={current} />}

      {data.crossovers && data.crossovers.length > 0 && <Crossovers data={data} />}

      <TopTrades data={data} />
      <ByYear data={data} />
      <Now data={data} />

      <details className="text-xs text-slate">
        <summary className="cursor-pointer text-sm font-semibold text-ink">How this was tested, and what it can't tell you</summary>
        <ul className="mt-2 max-w-4xl list-disc space-y-1 pl-5">
          <li>Prices: bonus-adjusted daily closes since 2020 (or the listing), from Merolagani's history and the app's own daily prices. Only completed sessions.</li>
          <li>A trade buys at the open of the session after the signal and sells on the first rule that applies, checked each session: the stop (or the open, if it gapped below), the target (or the open, if it gapped above), or the close of the {data.rules.hold}th session. If both stop and target fall in one session, it counts as the stop. The Lab strategies use their own exits. Trades of one strategy never overlap.</li>
          <li>"Held" counts trading sessions from the buy to the sell, both included; calendar days include weekends and holidays.</li>
          <li>Few trades means a result can be luck: judge the ones with 20 or more. Fills at the open aren't guaranteed on NEPSE (circuits, thin books). Past results don't promise future ones.</li>
        </ul>
      </details>
    </div>
  )
}

function Fig({ label, value, note, valueTone = "text-ink" }: { label: string; value: string; note?: string; valueTone?: string }) {
  return (
    <div className="rounded-xl bg-slate/5 px-3 py-2">
      <dt className="text-[11px] font-semibold text-slate">{label}</dt>
      <dd className={cn("font-mono text-lg font-semibold", valueTone)}>{value}</dd>
      {note && <dd className="text-[11px] text-slate">{note}</dd>}
    </div>
  )
}

function StrategyRow({ s, active, onSelect }: { s: StockBacktestStrategy; active: boolean; onSelect: () => void }) {
  const st = s.stats
  const pf = st.profit_factor ?? null
  const width = pf == null ? 0 : Math.min(pf / 3, 1) * 100
  return (
    <tr className={cn("cursor-pointer hover:bg-slate/5", active && "bg-pine/5", st.trades === 0 && "text-slate")} onClick={onSelect} aria-selected={active}>
      <td className="px-3 py-2">
        <button type="button" onClick={onSelect} className={cn("text-left font-semibold", active ? "text-pine" : "text-ink")}>{s.label}</button>
        <p className="text-[11px] text-slate">{s.family}{st.trades > 0 && st.trades < 10 ? " · few trades" : ""}</p>
      </td>
      <td className="px-3 py-2 text-right font-mono">{st.trades}</td>
      <td className="px-3 py-2 text-right font-mono">{st.win_rate_pct != null ? `${st.win_rate_pct}%` : "—"}</td>
      <td className="px-3 py-2">
        <div className="flex items-center gap-2">
          <div className="relative h-2 w-24 rounded-full bg-slate/10" aria-hidden>
            <div className={cn("absolute inset-y-0 left-0 rounded-full", pf == null ? "" : pf >= 1.3 ? "bg-pine" : pf < 1 ? "bg-ember" : "bg-slate/50")} style={{ width: `${width}%` }} />
            <div className="absolute inset-y-[-3px] w-px bg-ink/40" style={{ left: `${100 / 3}%` }} title="1.0" />
          </div>
          <span className={cn("font-mono font-semibold", pfTone(pf))}>{pf ?? "—"}</span>
        </div>
      </td>
      <td className={cn("px-3 py-2 text-right font-mono", tone(st.avg_return_pct))}>{pct(st.avg_return_pct, 2)}</td>
      <td className={cn("px-3 py-2 text-right font-mono", tone(st.total_return_pct))}>{pct(st.total_return_pct)}</td>
      <td className="px-3 py-2 text-right font-mono">{st.avg_hold != null ? `${st.avg_hold} sessions` : "—"}</td>
      <td className="px-3 py-2 text-right font-mono text-ember">{pct(st.max_drawdown_pct)}</td>
      <td className="px-3 py-2 text-right font-mono text-xs">{s.latest_signal ? `${day(s.latest_signal)}${s.sessions_since_signal === 0 ? " (latest)" : ""}` : "—"}</td>
    </tr>
  )
}

// Every trade of one strategy: when it signalled, bought, sold, how long it held and why it sold.
function TradeLog({ data, strategy }: { data: StockBacktest; strategy: StockBacktestStrategy }) {
  const trades = useMemo(() => data.trades.filter((t) => t.key === strategy.key), [data.trades, strategy.key])
  const closed = trades.filter((t) => !t.open)
  const st = strategy.stats
  const isLab = strategy.key.startsWith("lab_")
  const cross = CROSS_LINES[strategy.key]
  const pending = cross && strategy.sessions_since_signal === 0 && !trades.some((t) => t.open)
  return (
    <Section id={cross ? "crossover-log" : "trade-log"} title={`Trade log: ${strategy.label}`}
      note={cross ? <>
        <b>How it trades:</b> on the session when {cross[0]} crosses above {cross[1]}, it buys at the next session's open. It holds until {cross[0]} closes back
        below {cross[1]} and sells at the next open, or sells earlier if the price falls {data.crossover_rules?.safety_stop_pct ?? 8}% below the buy (safety stop).
        {" "}{data.crossover_rules?.cost_pct ?? 0.8}% costs per round trip.
      </> : <>
        <b>How it trades:</b> on the session when {rule(strategy.key)}, it buys at the next session's open.{" "}
        {isLab ? "It sells at its own stop or target, on its strategy exit, or at the time limit." : <>It sells at the stop (just under the 10-session low), at the target ({data.rules.reward_multiple}× the risk), or at the close of the {data.rules.hold}th session.</>}
      </>}>
      <Card>
        <CardBody className="space-y-3">
          <p className="text-sm text-ink" aria-label={cross ? "Crossover trade log summary" : "Trade log summary"}>
            {closed.length === 0 ? <>No completed trades on {data.symbol}.</> : <>
              <b>{st.trades}</b> trades: <b className="text-pine">{closed.filter((t) => t.return_pct > 0).length} won</b>,{" "}
              <b className="text-ember">{closed.filter((t) => t.return_pct <= 0).length} lost</b>; held <b>{st.avg_hold}</b> sessions on average
              ({Math.min(...closed.map((t) => t.held_sessions))}–{Math.max(...closed.map((t) => t.held_sessions))}); best <span className="font-mono text-pine">{pct(st.best_pct, 2)}</span>,
              worst <span className="font-mono text-ember">{pct(st.worst_pct, 2)}</span>; all trades compounded <b className={tone(st.total_return_pct)}>{pct(st.total_return_pct)}</b>.
            </>}
            {trades.some((t) => t.open) && <> One trade is still open.</>}
            {pending && <> <b className="text-pine">It crossed up on the latest session: the next buy is at the next open.</b></>}
          </p>
          <div className="flex flex-wrap gap-4 text-xs text-slate">
            <span><span className="font-bold">▲</span> bought (below the line) · <span className="font-bold">▼</span> sold (above it) · <span className="font-semibold text-pine">green</span> = the trade made money, <span className="font-semibold text-ember">red</span> = it lost</span>
          </div>
          <TradesChart prices={data.prices} trades={trades} />
          <div className="overflow-x-auto">
            <table className="w-full text-sm" aria-label={cross ? "Crossover trade log" : "Trade log"}>
              <thead className="border-b border-mist/80 text-left text-[11px] font-bold uppercase tracking-wider text-slate">
                <tr>
                  <th className="px-2 py-2">#</th><th className="px-2 py-2">Signal session</th><th className="px-2 py-2">Bought</th><th className="px-2 py-2 text-right">Buy price</th>
                  <th className="px-2 py-2">Sold</th><th className="px-2 py-2 text-right">Sell price</th><th className="px-2 py-2 text-right">Held</th>
                  <th className="px-2 py-2">Why sold</th><th className="px-2 py-2 text-right">Result</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-mist/60">
                {trades.map((t, i) => <TradeRow key={`${t.entry_on}-${i}`} n={i + 1} t={t} />)}
              </tbody>
            </table>
          </div>
        </CardBody>
      </Card>
    </Section>
  )
}

function TradeRow({ n, t }: { n: number; t: StockBacktestTrade }) {
  return (
    <tr className={cn(t.open && "bg-amber-50")}>
      <td className="px-2 py-1.5 font-mono text-xs text-slate">{n}</td>
      <td className="px-2 py-1.5 text-xs text-slate">{weekday(t.signal_on)}</td>
      <td className="px-2 py-1.5 text-xs">{weekday(t.entry_on)}</td>
      <td className="px-2 py-1.5 text-right font-mono">{money(t.entry)}</td>
      <td className="px-2 py-1.5 text-xs">{t.exit_on ? weekday(t.exit_on) : "—"}</td>
      <td className="px-2 py-1.5 text-right font-mono">{money(t.exit)}{t.open ? " (now)" : ""}</td>
      <td className="px-2 py-1.5 text-right font-mono text-xs">{t.held_sessions} {t.held_sessions === 1 ? "session" : "sessions"}<span className="block text-slate">{t.held_days} {t.held_days === 1 ? "day" : "days"}</span></td>
      <td className="px-2 py-1.5 text-xs">{EXIT_LABELS[t.reason] ?? t.reason}</td>
      <td className={cn("px-2 py-1.5 text-right font-mono font-semibold", tone(t.return_pct))}>{pct(t.return_pct, 2)}</td>
    </tr>
  )
}

function TopTrades({ data }: { data: StockBacktest }) {
  const label = (key: string) => data.strategies.find((s) => s.key === key)?.label ?? key
  const top = [...data.trades].filter((t) => !t.open).sort((a, b) => b.return_pct - a.return_pct).slice(0, 10)
  return (
    <Section id="top-trades" title="Where the biggest profits were made" note="The ten best trades across every strategy, after costs. The same move often shows up under several indicators that fired together.">
      <Card className="overflow-x-auto">
        <table className="w-full text-sm" aria-label="Most profitable trades">
          <thead className="border-b border-mist/80 bg-slate/5 text-left text-[11px] font-bold uppercase tracking-wider text-slate">
            <tr><th className="px-3 py-2">Strategy</th><th className="px-3 py-2">Bought</th><th className="px-3 py-2 text-right">At</th><th className="px-3 py-2">Sold</th><th className="px-3 py-2 text-right">At</th><th className="px-3 py-2 text-right">Held</th><th className="px-3 py-2 text-right">Result</th></tr>
          </thead>
          <tbody className="divide-y divide-mist/60">
            {top.map((t, i) => (
              <tr key={`${t.key}-${t.entry_on}-${i}`}>
                <td className="px-3 py-1.5 text-ink">{label(t.key)}</td>
                <td className="px-3 py-1.5 text-xs">{day(t.entry_on)}</td><td className="px-3 py-1.5 text-right font-mono">{money(t.entry)}</td>
                <td className="px-3 py-1.5 text-xs">{day(t.exit_on)}</td><td className="px-3 py-1.5 text-right font-mono">{money(t.exit)}</td>
                <td className="px-3 py-1.5 text-right font-mono text-xs">{t.held_sessions} sessions</td>
                <td className={cn("px-3 py-1.5 text-right font-mono font-semibold", tone(t.return_pct))}>{pct(t.return_pct, 2)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </Section>
  )
}

function ByYear({ data }: { data: StockBacktest }) {
  const years = Object.keys(data.buy_hold.by_year).sort()
  const shown = data.strategies.filter((s) => s.stats.trades >= 10).slice(0, 5)
  return (
    <Section id="by-year" title="Year by year" note="Buy and hold for each calendar year, and each strategy's trades compounded by the year they were bought (strategies with 10+ trades).">
      <Card className="overflow-x-auto">
        <table className="w-full text-sm" aria-label="Results by year">
          <thead className="border-b border-mist/80 bg-slate/5 text-left text-[11px] font-bold uppercase tracking-wider text-slate">
            <tr><th className="px-3 py-2">Strategy</th>{years.map((y) => <th key={y} className="px-3 py-2 text-right">{y}</th>)}</tr>
          </thead>
          <tbody className="divide-y divide-mist/60">
            <tr className="font-semibold"><td className="px-3 py-1.5">Buy and hold</td>{years.map((y) => <td key={y} className={cn("px-3 py-1.5 text-right font-mono", tone(data.buy_hold.by_year[y]))}>{pct(data.buy_hold.by_year[y])}</td>)}</tr>
            {shown.map((s) => (
              <tr key={s.key}>
                <td className="px-3 py-1.5">{s.label}</td>
                {years.map((y) => {
                  const v = s.stats.by_year?.[y]
                  return <td key={y} className={cn("px-3 py-1.5 text-right font-mono", tone(v?.total_return_pct))}>{v ? <>{pct(v.total_return_pct)}<span className="block text-[11px] font-normal text-slate">{v.trades} trades</span></> : "—"}</td>
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </Section>
  )
}

function Now({ data }: { data: StockBacktest }) {
  const fired = data.strategies.filter((s) => s.sessions_since_signal != null && s.sessions_since_signal <= 2)
  const n = data.now
  return (
    <Section id="now" title={`Where ${data.symbol} stands now`} note={`On the ${day(data.to)} close of ${money(data.close)}.`}>
      <div className="grid gap-3 md:grid-cols-3">
        <Card><CardBody>
          <h3 className="text-sm font-bold text-ink">Signals in the last two sessions</h3>
          {fired.length === 0 ? <p className="mt-2 text-sm text-slate">None.</p> : (
            <ul className="mt-2 space-y-1.5 text-sm">
              {fired.map((s) => (
                <li key={s.key} className="flex justify-between gap-2">
                  <span>{s.label}<span className="block text-[11px] text-slate">{s.sessions_since_signal === 0 ? "latest session" : `${s.sessions_since_signal} sessions ago`}</span></span>
                  <span className={cn("shrink-0 font-mono text-xs font-semibold", pfTone(s.stats.profit_factor))}>PF {s.stats.profit_factor ?? "—"} · {s.stats.trades}</span>
                </li>
              ))}
            </ul>
          )}
        </CardBody></Card>
        <Card><CardBody>
          <h3 className="text-sm font-bold text-ink">Levels (the app's rule output)</h3>
          {n.levels ? (
            <dl className="mt-2 space-y-1 text-sm">
              <Line label="Entry range" value={`${money(n.levels.entry_low)}–${money(n.levels.entry_high)}`} valueTone="text-pine" />
              <Line label="Stop" value={money(n.levels.stop)} valueTone="text-ember" />
              <Line label="Target" value={money(n.levels.target)} valueTone="text-pine" />
              <Line label="From" value={n.levels.source === "board_setup" ? "board setup" : "crossover rule"} />
            </dl>
          ) : <p className="mt-2 text-sm text-slate">No levels today.</p>}
        </CardBody></Card>
        <Card><CardBody>
          <h3 className="text-sm font-bold text-ink">Trend and indicators</h3>
          <dl className="mt-2 space-y-1 text-sm">
            <Line label="50 / 200-day average" value={`${money(n.sma50)} / ${money(n.sma200)}`} />
            <Line label="52-week high / low" value={`${money(n.high_52w)} / ${money(n.low_52w)}`} />
            <Line label="RSI (14)" value={n.rsi?.toFixed(1) ?? "—"} />
            <Line label="Board trend checks (of 7)" value={String(n.trend_rules_passed ?? "—")} />
            <Line label="Readiness (board needs 60)" value={String(n.readiness ?? "—")} />
          </dl>
        </CardBody></Card>
      </div>
    </Section>
  )
}

function Line({ label, value, valueTone = "text-ink" }: { label: string; value: string; valueTone?: string }) {
  return <div className="flex justify-between gap-3"><dt className="text-slate">{label}</dt><dd className={cn("font-mono", valueTone)}>{value}</dd></div>
}

// Classic crossover systems: in on the cross up, out on the cross back down.
function Crossovers({ data }: { data: StockBacktest }) {
  const list = data.crossovers ?? []
  const [selected, setSelected] = useState<string | null>(null)
  // Opens on the best-ranked crossover with enough trades to judge.
  const current = list.find((s) => s.key === selected) ?? list.find((s) => s.stats.trades >= 10) ?? list.find((s) => s.stats.trades > 0) ?? list[0]
  return (
    <>
      <Section id="crossovers" title="Crossover trades"
        note={<>Each crossover traded on its own: buy at the next open after the faster line crosses above the slower one, hold until it crosses back below, then
          sell at the next open (or at a {data.crossover_rules?.safety_stop_pct ?? 8}% safety stop). Holding time follows the trend. <b>Click a row to see every buy and sell.</b></>}>
        <Card className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm" aria-label="Crossover ranking">
              <thead className="border-b border-mist/80 bg-slate/5 text-left text-[11px] font-bold uppercase tracking-wider text-slate">
                <tr>
                  <th className="px-3 py-2">Crossover</th><th className="px-3 py-2 text-right">Trades</th><th className="px-3 py-2 text-right">Won</th>
                  <th className="px-3 py-2">Profit factor</th><th className="px-3 py-2 text-right">Avg / trade</th><th className="px-3 py-2 text-right">Compounded</th>
                  <th className="px-3 py-2 text-right">Avg held</th><th className="px-3 py-2 text-right">Worst run</th><th className="px-3 py-2 text-right">Last cross up</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-mist/60">
                {list.map((s) => <StrategyRow key={s.key} s={s} active={s.key === current?.key} onSelect={() => setSelected(s.key)} />)}
              </tbody>
            </table>
          </div>
        </Card>
      </Section>
      {current && <TradeLog data={data} strategy={current} />}
    </>
  )
}
