import { useMemo, useState } from "react"
import { Link } from "react-router-dom"

import { Badge, Button, Card, CardBody, CardHeader, LoadingSpinner } from "../components/ui"
import { useCrossoverScan } from "../features/scanner/api"
import type { CrossoverScan, CrossoverSignal, ScanRow, SignalStats } from "../features/scanner/types"
import { cn } from "../lib/cn"

const SIGNALS: Array<{ key: CrossoverSignal; label: string; short: string; help: string }> = [
  { key: "ema_9_21", label: "EMA 9 crossed above 21", short: "9/21", help: "Short-term momentum turned up: the 2-week average rose above the 1-month one." },
  { key: "ema_21_50", label: "EMA 21 crossed above 50", short: "21/50", help: "Medium-term turn: the 1-month average rose above the 2½-month one." },
  { key: "ema_stack", label: "EMA 9 > 21 > 50", short: "Stack", help: "Every timeframe agrees on an uptrend (age = sessions since the stack formed)." },
  { key: "hma_up", label: "HMA turned up", short: "HMA↑", help: "The Hull average (low lag) switched from falling to rising." },
  { key: "alma_cross", label: "Price crossed above ALMA", short: "ALMA", help: "The close moved above the Arnaud Legoux average (smooth, responsive)." },
  { key: "aroon_cross", label: "Aroon Up crossed above Down", short: "Aroon×", help: "New highs became more recent than new lows: a possible new uptrend." },
  { key: "aroon_strong", label: "Aroon Up ≥ 70", short: "Aroon≥70", help: "A new 25-session high within the last 7 sessions: the uptrend is fresh." },
]

const RECENCY = [
  { value: 0, label: "Latest session" },
  { value: 3, label: "Last 3 sessions" },
  { value: 5, label: "Last 5 sessions" },
  { value: 10, label: "Last 10 sessions" },
]

const pct = (value: number | null | undefined) => (value == null ? "—" : `${value > 0 ? "+" : ""}${value.toFixed(2)}%`)
const tone = (value: number | null | undefined) => (value == null ? "text-slate" : value > 0 ? "text-pine" : value < 0 ? "text-ember" : "text-slate")
const money = (value: number) => value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })

// Conditions rather than events: they match while they hold, however long ago they began.
const STATES: CrossoverSignal[] = ["ema_stack", "aroon_strong"]

// Crossovers must have begun within the window; states only need to hold now.
function matches(row: ScanRow, selected: CrossoverSignal[], within: number) {
  return selected.every((key) => {
    const age = row.signals[key]
    return age !== null && (STATES.includes(key) || age <= within)
  })
}

export function ScannerPage() {
  const { data, isLoading, isError, refetch } = useCrossoverScan()
  const [selected, setSelected] = useState<CrossoverSignal[]>(["ema_9_21"])
  const [within, setWithin] = useState(3)
  const [hideThin, setHideThin] = useState(true)

  const rows = useMemo(() => {
    if (!data) return []
    return data.rows
      .filter((row) => matches(row, selected, within))
      .filter((row) => !hideThin || !(row.guards ?? []).includes("thin_volume"))
      .sort((a, b) => (b.readiness ?? -1) - (a.readiness ?? -1) || a.symbol.localeCompare(b.symbol))
  }, [data, selected, within, hideThin])

  if (isLoading) return <div className="flex h-[50vh] items-center justify-center"><LoadingSpinner size="lg" /></div>
  if (isError || !data) {
    return (
      <Card className="p-8 text-center">
        <p className="font-display text-lg font-bold text-ink">Couldn't load the scan</p>
        <Button className="mt-4" variant="outline" onClick={() => void refetch()}>Retry</Button>
      </Card>
    )
  }

  const toggle = (key: CrossoverSignal) => setSelected((current) => (current.includes(key) ? current.filter((k) => k !== key) : [...current, key]))

  return (
    <div className="space-y-6">
      <header>
        <h1 className="font-display text-2xl font-bold tracking-tight text-ink sm:text-3xl">Indicator Scanner</h1>
        <p className="mt-1 text-sm text-slate">
          Stocks matching every signal you tick, on completed sessions up to <b>{data.as_of ?? "—"}</b>. Settings (TradingView defaults): EMA{" "}
          {data.params.ema.join(" / ")}, HMA {data.params.hma}, ALMA {data.params.alma.length} (offset {data.params.alma.offset}, sigma {data.params.alma.sigma}),
          Aroon {data.params.aroon}. Rule checks, not recommendations.
        </p>
      </header>

      <Card className="p-4">
        <fieldset>
          <legend className="text-xs font-semibold uppercase tracking-wide text-slate">Signals (all must match)</legend>
          <div className="mt-2 flex flex-wrap gap-2">
            {SIGNALS.map((signal) => (
              <label key={signal.key} title={signal.help}
                className={cn("cursor-pointer rounded-full border px-3 py-1.5 text-sm", selected.includes(signal.key) ? "border-ink bg-ink text-white" : "border-slate/20 text-ink")}>
                <input type="checkbox" className="sr-only" checked={selected.includes(signal.key)} onChange={() => toggle(signal.key)} />
                {signal.label}
              </label>
            ))}
          </div>
        </fieldset>
        <div className="mt-3 flex flex-wrap items-center gap-4 text-sm">
          <label className="flex items-center gap-2 text-slate">
            Crosses began within
            <select className="rounded-lg border border-slate/20 bg-white px-2 py-1 text-ink" value={within} onChange={(event) => setWithin(Number(event.target.value))}>
              {RECENCY.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
            </select>
          </label>
          <label className="flex items-center gap-2 text-slate">
            <input type="checkbox" checked={hideThin} onChange={(event) => setHideThin(event.target.checked)} />
            Hide thinly traded stocks
          </label>
          <span className="ml-auto font-semibold text-ink" aria-live="polite">{rows.length} of {data.rows.length} stocks</span>
        </div>
      </Card>

      <SignalTrackRecord backtest={data.backtest} selected={selected} />

      {rows.length === 0 ? (
        <Card className="p-8 text-center text-sm text-slate">No stock matches every ticked signal{selected.length > 0 ? " in that window" : ""}. Untick a signal or widen the window.</Card>
      ) : (
        <Card className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-mist/80 bg-slate/5 text-[11px] font-bold uppercase tracking-wider text-slate">
                <tr>
                  <th className="px-4 py-3">Symbol</th>
                  <th className="px-4 py-3 text-right">Close</th>
                  <th className="px-4 py-3 text-right">Change</th>
                  <th className="px-4 py-3">Signals (sessions ago)</th>
                  <th className="px-4 py-3 text-right">Aroon Up / Down</th>
                  <th className="px-4 py-3 text-right">Readiness</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-mist/60">
                {rows.map((row) => (
                  <tr key={row.symbol} className="hover:bg-slate/5" aria-label={`${row.symbol} scan row`}>
                    <td className="px-4 py-3">
                      <Link to={`/screener/${encodeURIComponent(row.symbol)}`} className="font-bold text-ink hover:underline">{row.symbol}</Link>
                      <p className="max-w-48 truncate text-xs text-slate">{row.sector}</p>
                    </td>
                    <td className="px-4 py-3 text-right font-mono">{money(row.close)}</td>
                    <td className={cn("px-4 py-3 text-right font-mono", tone(row.change_pct))}>{pct(row.change_pct)}</td>
                    <td className="px-4 py-3">
                      <div className="flex flex-wrap gap-1">
                        {SIGNALS.filter((signal) => row.signals[signal.key] !== null).map((signal) => (
                          <span key={signal.key} title={`${signal.label}: ${row.signals[signal.key] === 0 ? "latest session" : `${row.signals[signal.key]} sessions ago`}`}
                            className={cn("rounded-full px-2 py-0.5 text-xs font-semibold", selected.includes(signal.key) ? "bg-pine/15 text-pine" : "bg-slate/10 text-slate")}>
                            {signal.short} {row.signals[signal.key] === 0 ? "today" : `${row.signals[signal.key]}d`}
                          </span>
                        ))}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-right font-mono text-xs">{row.values.aroon_up ?? "—"} / {row.values.aroon_down ?? "—"}</td>
                    <td className="px-4 py-3 text-right">
                      <span className="font-mono font-semibold">{row.readiness ?? "—"}</span>
                      {row.in_buy_zone && <Badge tone="gain" className="ml-2">Entry zone</Badge>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}
    </div>
  )
}

// How each signal did on NEPSE history: forward returns after it began.
function SignalTrackRecord({ backtest, selected }: { backtest: CrossoverScan["backtest"]; selected: CrossoverSignal[] }) {
  const [horizon, setHorizon] = useState(20)
  const base = backtest.signals.all?.[String(horizon)]
  const cell = (stats: SignalStats | undefined) => stats && stats.n > 0 ? stats : null
  return (
    <Card>
      <CardHeader
        title="How these signals did on NEPSE"
        subtitle={`Every time a signal began, ${backtest.period.from ?? "—"} to ${backtest.period.to ?? "—"}: the return over the next sessions (close to close, before costs), against all stock-days.`}
      />
      <CardBody>
        <div className="mb-3 inline-flex rounded-xl border border-mist/80 bg-slate/5 p-1" role="tablist">
          {backtest.horizons.map((h) => (
            <button key={h} type="button" role="tab" aria-selected={horizon === h} onClick={() => setHorizon(h)}
              className={cn("rounded-lg px-3 py-1 text-sm font-semibold", horizon === h ? "bg-white text-ink shadow-sm" : "text-slate")}>
              {h} sessions
            </button>
          ))}
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm" aria-label="Signal track record">
            <thead className="text-left text-xs text-slate">
              <tr><th className="py-1 pr-4">Signal</th><th className="py-1 pr-4 text-right">Samples</th><th className="py-1 pr-4 text-right">Avg return</th><th className="py-1 pr-4 text-right">Went up</th><th className="py-1 text-right">vs NEPSE</th></tr>
            </thead>
            <tbody className="divide-y divide-mist/60">
              {[{ key: "all" as const, label: "All stock-days (baseline)" }, ...SIGNALS.map((s) => ({ key: s.key, label: s.label }))].map(({ key, label }) => {
                const stats = cell(backtest.signals[key]?.[String(horizon)])
                const worse = stats && base?.avg_return_pct != null && stats.avg_return_pct != null && key !== "all" && stats.avg_return_pct < base.avg_return_pct
                return (
                  <tr key={key} className={cn(key !== "all" && selected.includes(key as CrossoverSignal) && "font-semibold")}>
                    <td className="py-1.5 pr-4 text-ink">{label}</td>
                    <td className="py-1.5 pr-4 text-right font-mono text-slate">{stats?.n.toLocaleString("en-US") ?? "—"}</td>
                    <td className={cn("py-1.5 pr-4 text-right font-mono", tone(stats?.avg_return_pct))}>{pct(stats?.avg_return_pct)}{worse ? " ▼" : ""}</td>
                    <td className="py-1.5 pr-4 text-right font-mono">{stats?.win_rate_pct != null ? `${stats.win_rate_pct}%` : "—"}</td>
                    <td className={cn("py-1.5 text-right font-mono", tone(stats?.avg_excess_pct))}>{pct(stats?.avg_excess_pct)}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
        <p className="mt-3 text-xs text-slate">
          ▼ = did worse than the average stock-day. One year of data in a mostly sideways market, where trend-following crosses tend to come
          after a short rise that then fades; they usually do better in trending markets. Treat these signals as a shortlist to study, not entries
          on their own; the Entry zone board's rules were tested separately.
        </p>
      </CardBody>
    </Card>
  )
}
