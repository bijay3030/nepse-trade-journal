import { ArrowDown, ArrowUp, CandlestickChart as ChartIcon } from "lucide-react"
import { useMemo, useState } from "react"
import { Link } from "react-router-dom"

import { Badge, Button, Card, CardBody, LoadingSpinner } from "../components/ui"
import { useCrossoverScan } from "../features/scanner/api"
import { ChartPanel } from "../features/scanner/ChartPanel"
import { LevelsTag } from "../features/scanner/LevelsTag"
import { useStockPrices } from "../hooks/useStockPrices"
import { SIGNALS } from "../features/scanner/signals"
import { TelegramAlertControl } from "../features/scanner/TelegramAlertControl"
import type { CrossoverScan, CrossoverSignal, ScanRow, SignalStats } from "../features/scanner/types"
import { cn } from "../lib/cn"

const RECENCY = [
  { value: 0, label: "Latest session" },
  { value: 3, label: "Last 3 sessions" },
  { value: 5, label: "Last 5 sessions" },
  { value: 10, label: "Last 10 sessions" },
]

// Conditions rather than events: they match while they hold, however long ago they began.
const STATES: CrossoverSignal[] = ["ema_stack", "aroon_strong"]

type SortKey = "symbol" | "close" | "change" | "newest" | "aroon" | "readiness"
type Sort = { key: SortKey; dir: "asc" | "desc" }

const pct = (value: number | null | undefined) => (value == null ? "—" : `${value > 0 ? "+" : ""}${value.toFixed(2)}%`)
const tone = (value: number | null | undefined) => (value == null ? "text-slate" : value > 0 ? "text-pine" : value < 0 ? "text-ember" : "text-slate")
const money = (value: number) => value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })

// Crossovers must have begun within the window; states only need to hold now.
function matches(row: ScanRow, selected: CrossoverSignal[], within: number) {
  return selected.every((key) => {
    const age = row.signals[key]
    return age !== null && (STATES.includes(key) || age <= within)
  })
}

// The youngest of the ticked signals (or of all signals when none is ticked).
function newest(row: ScanRow, selected: CrossoverSignal[]) {
  const keys = selected.length > 0 ? selected : SIGNALS.map((signal) => signal.key)
  const ages = keys.map((key) => row.signals[key]).filter((age): age is number => age !== null)
  return ages.length > 0 ? Math.min(...ages) : Number.POSITIVE_INFINITY
}

function sortValue(row: ScanRow, key: SortKey, selected: CrossoverSignal[]): number | string {
  switch (key) {
    case "symbol": return row.symbol
    case "close": return row.close
    case "change": return row.change_pct ?? Number.NEGATIVE_INFINITY
    case "newest": return newest(row, selected)
    case "aroon": return row.values.aroon_up ?? Number.NEGATIVE_INFINITY
    case "readiness": return row.readiness ?? Number.NEGATIVE_INFINITY
  }
}

export function ScannerPage() {
  const { data, isLoading, isError, refetch } = useCrossoverScan()
  const [selected, setSelected] = useState<CrossoverSignal[]>(["ema_9_21"])
  const [within, setWithin] = useState(3)
  const [hideThin, setHideThin] = useState(true)
  const [sort, setSort] = useState<Sort>({ key: "readiness", dir: "desc" })
  const [charting, setCharting] = useState<string | null>(null)

  const rows = useMemo(() => {
    if (!data) return []
    const direction = sort.dir === "asc" ? 1 : -1
    return data.rows
      .filter((row) => matches(row, selected, within))
      .filter((row) => !hideThin || !(row.guards ?? []).includes("thin_volume"))
      .sort((a, b) => {
        const x = sortValue(a, sort.key, selected)
        const y = sortValue(b, sort.key, selected)
        const order = typeof x === "string" ? x.localeCompare(y as string) : (x as number) - (y as number)
        return order * direction || a.symbol.localeCompare(b.symbol)
      })
  }, [data, selected, within, hideThin, sort])

  const symbols = useMemo(() => rows.map((row) => row.symbol), [rows])
  const { getPrice } = useStockPrices(symbols)

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
  // A second click on the same column reverses it; a new column starts A-Z / newest first / highest first.
  const sortBy = (key: SortKey) =>
    setSort((current) => current.key === key
      ? { key, dir: current.dir === "asc" ? "desc" : "asc" }
      : { key, dir: key === "symbol" || key === "newest" ? "asc" : "desc" })
  const chartIndex = charting ? rows.findIndex((row) => row.symbol === charting) : -1

  const header = (key: SortKey, label: string, align: "left" | "right" = "left") => (
    <th className={cn("px-4 py-3", align === "right" && "text-right")} aria-sort={sort.key === key ? (sort.dir === "asc" ? "ascending" : "descending") : "none"}>
      <button type="button" onClick={() => sortBy(key)} className={cn("inline-flex items-center gap-1 uppercase", sort.key === key ? "text-ink" : "hover:text-ink")}>
        {label}
        {sort.key === key && (sort.dir === "asc" ? <ArrowUp className="h-3 w-3" /> : <ArrowDown className="h-3 w-3" />)}
      </button>
    </th>
  )

  return (
    <div className="space-y-4">
      <header>
        <h1 className="font-display text-2xl font-bold tracking-tight text-ink sm:text-3xl">Indicator Scanner</h1>
        <p className="mt-1 text-sm text-slate">
          Stocks matching every signal you tick, on completed sessions up to <b>{data.as_of ?? "—"}</b>. Settings (TradingView defaults): EMA{" "}
          {data.params.ema.join(" / ")}, HMA {data.params.hma}, ALMA {data.params.alma.length} (offset {data.params.alma.offset}, sigma {data.params.alma.sigma}),
          Aroon {data.params.aroon}. Rule checks, not recommendations.
        </p>
      </header>

      <div className="sticky top-0 z-20 -mx-1 px-1 pt-1">
        <Card className="p-3 shadow-sm">
          <fieldset>
            <legend className="sr-only">Signals (all must match)</legend>
            <div className="flex flex-wrap gap-1.5">
              {SIGNALS.map((signal) => (
                <label key={signal.key} title={signal.help}
                  className={cn("cursor-pointer rounded-full border px-2.5 py-1 text-xs font-semibold", selected.includes(signal.key) ? "border-ink bg-ink text-white" : "border-slate/20 text-ink hover:bg-slate/5")}>
                  <input type="checkbox" className="sr-only" checked={selected.includes(signal.key)} onChange={() => toggle(signal.key)} />
                  {signal.label}
                </label>
              ))}
            </div>
          </fieldset>
          <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-2 text-xs">
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
            <TelegramAlertControl selected={selected} />
            <span className="ml-auto font-semibold text-ink" aria-live="polite">{rows.length} of {data.rows.length} stocks</span>
          </div>
        </Card>
      </div>

      <SignalTrackRecord backtest={data.backtest} selected={selected} />

      {rows.length === 0 ? (
        <Card className="p-8 text-center text-sm text-slate">No stock matches every ticked signal{selected.length > 0 ? " in that window" : ""}. Untick a signal or widen the window.</Card>
      ) : (
        <Card className="overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-mist/80 bg-slate/5 text-[11px] font-bold tracking-wider text-slate">
                <tr>
                  {header("symbol", "Symbol")}
                  {header("close", "Close", "right")}
                  {header("change", "Change", "right")}
                  {header("newest", "Signals (sessions ago)")}
                  {header("aroon", "Aroon Up / Down", "right")}
                  <th className="px-4 py-3">Levels (rule output)</th>
                  {header("readiness", "Readiness", "right")}
                  <th className="px-4 py-3"><span className="sr-only">Chart</span></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-mist/60">
                {rows.map((row) => (
                  <tr key={row.symbol} className={cn("hover:bg-slate/5", charting === row.symbol && "bg-pine/5")} aria-label={`${row.symbol} scan row`}>
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
                    <td className="px-4 py-3"><LevelsTag levels={row.levels} close={row.close} asOf={data.as_of} live={getPrice(row.symbol)} /></td>
                    <td className="px-4 py-3 text-right">
                      <span className="font-mono font-semibold">{row.readiness ?? "—"}</span>
                      {row.in_buy_zone && <Badge tone="gain" className="ml-2">Entry zone</Badge>}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <Button size="sm" variant="outline" onClick={() => setCharting(row.symbol)} className="inline-flex items-center gap-1.5" aria-label={`Chart ${row.symbol}`}>
                        <ChartIcon className="h-3.5 w-3.5" /> Chart
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      {charting && (
        <ChartPanel
          symbol={charting}
          signals={selected}
          position={{ index: Math.max(chartIndex, 0), total: rows.length }}
          onPrevious={chartIndex > 0 ? () => setCharting(rows[chartIndex - 1].symbol) : undefined}
          onNext={chartIndex >= 0 && chartIndex < rows.length - 1 ? () => setCharting(rows[chartIndex + 1].symbol) : undefined}
          onClose={() => setCharting(null)}
        />
      )}
    </div>
  )
}

// How each signal did on NEPSE history: a one-line summary that expands into the table.
function SignalTrackRecord({ backtest, selected }: { backtest: CrossoverScan["backtest"]; selected: CrossoverSignal[] }) {
  const [open, setOpen] = useState(false)
  const [horizon, setHorizon] = useState(20)
  const base = backtest.signals.all?.[String(horizon)]
  const cell = (stats: SignalStats | undefined) => (stats && stats.n > 0 ? stats : null)
  const ticked = selected.map((key) => ({ key, stats: cell(backtest.signals[key]?.["20"]) })).filter((entry) => entry.stats)
  const baseline20 = cell(backtest.signals.all?.["20"])

  return (
    <Card>
      <CardBody>
        <div className="flex flex-wrap items-center justify-between gap-2">
          <p className="text-sm text-slate" aria-label="Track record summary">
            <b className="text-ink">Track record on NEPSE:</b>{" "}
            {ticked.length > 0 && baseline20
              ? <>20 sessions after the ticked {ticked.length === 1 ? "signal" : "signals"}:{" "}
                  {ticked.map(({ key, stats }) => (
                    <span key={key} className={cn("font-mono", tone(stats?.avg_return_pct))}>{SIGNALS.find((s) => s.key === key)?.short} {pct(stats?.avg_return_pct)} </span>
                  ))}
                  vs <span className="font-mono">{pct(baseline20.avg_return_pct)}</span> for the average stock-day.
                  {ticked.some(({ key }) => backtest.trades?.[key]?.profit_factor != null) && (
                    <> Trading the crossover levels: {ticked.map(({ key }) => {
                      const t = backtest.trades?.[key]
                      return t?.win_rate_pct != null ? <span key={key} className="font-mono">{SIGNALS.find((s) => s.key === key)?.short} {t.win_rate_pct}% won, PF {t.profit_factor ?? "—"} </span> : null
                    })}</>
                  )}</>
              : "how each signal did after it began, against the average stock-day."}
          </p>
          <Button size="sm" variant="ghost" aria-expanded={open} onClick={() => setOpen((value) => !value)}>{open ? "Hide track record" : "Show track record"}</Button>
        </div>
        {open && (
          <div className="mt-3">
            <p className="text-xs text-slate">
              Every time a signal began, {backtest.period.from ?? "—"} to {backtest.period.to ?? "—"}: the return over the next sessions (close to close, before costs).
            </p>
            <div className="my-3 inline-flex rounded-xl border border-mist/80 bg-slate/5 p-1" role="tablist">
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
            {backtest.trades && backtest.trade_rules && (
              <div className="mt-4">
                <h3 className="text-sm font-bold text-ink">Trading the crossover levels</h3>
                <p className="text-xs text-slate">
                  Buy at the next open if it's inside the entry zone; sell at the stop or target ({backtest.trade_rules.reward_multiple}× the risk), or after{" "}
                  {backtest.trade_rules.max_hold} sessions; {backtest.trade_rules.cost_pct}% round-trip costs. Rows with a board setup use that setup's levels instead.
                </p>
                <div className="mt-2 overflow-x-auto">
                  <table className="w-full text-sm" aria-label="Crossover level trades">
                    <thead className="text-left text-xs text-slate">
                      <tr><th className="py-1 pr-4">Signal</th><th className="py-1 pr-4 text-right">Trades</th><th className="py-1 pr-4 text-right">Won</th><th className="py-1 pr-4 text-right">Avg / trade</th><th className="py-1 pr-4 text-right">Avg R</th><th className="py-1 text-right">Profit factor</th></tr>
                    </thead>
                    <tbody className="divide-y divide-mist/60">
                      {SIGNALS.map((signal) => {
                        const t = backtest.trades?.[signal.key]
                        return (
                          <tr key={signal.key} className={cn(selected.includes(signal.key) && "font-semibold")}>
                            <td className="py-1.5 pr-4 text-ink">{signal.label}</td>
                            <td className="py-1.5 pr-4 text-right font-mono text-slate">{t?.closed ?? 0}</td>
                            <td className="py-1.5 pr-4 text-right font-mono">{t?.win_rate_pct != null ? `${t.win_rate_pct}%` : "—"}</td>
                            <td className={cn("py-1.5 pr-4 text-right font-mono", tone(t?.avg_return_pct))}>{pct(t?.avg_return_pct)}</td>
                            <td className={cn("py-1.5 pr-4 text-right font-mono", tone(t?.avg_r))}>{t?.avg_r != null ? `${t.avg_r > 0 ? "+" : ""}${t.avg_r}R` : "—"}</td>
                            <td className={cn("py-1.5 text-right font-mono", t?.profit_factor != null && t.profit_factor < 1 ? "text-ember" : "text-ink")}>{t?.profit_factor ?? "—"}</td>
                          </tr>
                        )
                      })}
                    </tbody>
                  </table>
                </div>
                <p className="mt-1 text-xs text-slate">Profit factor = gains ÷ losses; under 1 means the rule lost money overall.</p>
              </div>
            )}
            <p className="mt-3 text-xs text-slate">
              ▼ = did worse than the average stock-day. One year of data in a mostly sideways market, where trend-following crosses tend to come
              after a short rise that then fades; they usually do better in trending markets. Treat these signals as a shortlist to study, not entries
              on their own; the Entry zone board's rules were tested separately.
            </p>
          </div>
        )}
      </CardBody>
    </Card>
  )
}
