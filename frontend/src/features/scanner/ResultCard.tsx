import { CandlestickChart as ChartIcon } from "lucide-react"
import { Link } from "react-router-dom"

import { Badge, Button } from "../../components/ui"
import { cn } from "../../lib/cn"
import type { LiveStockPrice } from "../../stores/stockPricesStore"
import { LevelsTag } from "./LevelsTag"
import { SIGNALS } from "./signals"
import type { CrossoverSignal, ScanRow } from "./types"

const money = (value: number) => value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const pct = (value: number | null | undefined) => (value == null ? "—" : `${value > 0 ? "+" : ""}${value.toFixed(2)}%`)
const tone = (value: number | null | undefined) => (value == null ? "text-slate" : value > 0 ? "text-pine" : value < 0 ? "text-ember" : "text-slate")
const age = (sessions: number) => (sessions === 0 ? "today" : `${sessions}d`)

type Props = {
  row: ScanRow
  selected: CrossoverSignal[]
  volumeThreshold: number
  asOf: string | null
  live?: LiveStockPrice
  charting: boolean
  onChart: () => void
}

// One stock on the scanner: price, the signals that hold (ticked ones first), its levels and readiness.
export function ResultCard({ row, selected, volumeThreshold, asOf, live, charting, onChart }: Props) {
  const held = SIGNALS.filter((signal) => row.signals[signal.key] !== null)
    .sort((a, b) => Number(selected.includes(b.key)) - Number(selected.includes(a.key)))
  const readiness = row.readiness ?? null

  return (
    <article aria-label={`${row.symbol} scan row`}
      className={cn("flex flex-col rounded-2xl border bg-white p-4 shadow-sm transition-colors", charting ? "border-pine/50 ring-2 ring-pine/20" : "border-mist/80 hover:border-slate/30")}>
      <header className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <Link to={`/screener/${encodeURIComponent(row.symbol)}`} className="font-display text-lg font-bold text-ink hover:underline">{row.symbol}</Link>
          <p className="truncate text-xs text-slate" title={row.name}>{row.sector}</p>
        </div>
        <div className="shrink-0 text-right">
          <p className="font-mono text-lg font-semibold text-ink">{money(row.close)}</p>
          <p className={cn("font-mono text-xs font-semibold", tone(row.change_pct))}>{pct(row.change_pct)}</p>
        </div>
      </header>

      <ul className="mt-3 flex flex-wrap gap-1.5" aria-label="Signals">
        {held.map((signal) => {
          const sessions = row.signals[signal.key] as number
          const ratio = row.signal_volume?.[signal.key]
          const strong = ratio != null && ratio >= volumeThreshold
          const ticked = selected.includes(signal.key)
          return (
            <li key={signal.key}
              title={`${signal.label}: ${sessions === 0 ? "latest session" : `${sessions} sessions ago`}${ratio != null ? `, on ${ratio}× average volume` : ""}`}
              className={cn("whitespace-nowrap rounded-full px-2.5 py-1 text-xs", ticked ? "bg-pine/15 text-pine" : "bg-slate/10 text-slate")}>
              <b>{signal.short}</b> · {age(sessions)}
              {strong && <span className="font-mono"> · {ratio}× vol</span>}
            </li>
          )
        })}
      </ul>

      <div className="mt-3 grid flex-1 gap-3 border-t border-mist/60 pt-3 sm:grid-cols-[minmax(0,1fr)_auto]">
        <LevelsTag levels={row.levels} close={row.close} asOf={asOf} live={live} />
        <div className="flex items-end justify-between gap-4 sm:flex-col sm:items-end sm:justify-start">
          <div className="text-right" aria-label="Readiness">
            <p className="text-[10px] font-bold uppercase tracking-wider text-slate">Readiness</p>
            <p className="flex items-center justify-end gap-2">
              {row.in_buy_zone && <Badge tone="gain">Entry zone</Badge>}
              <span className="font-mono text-lg font-semibold text-ink">{readiness ?? "—"}</span>
            </p>
            {readiness != null && (
              <div className="ml-auto mt-1 h-1.5 w-20 rounded-full bg-slate/10" aria-hidden>
                <div className={cn("h-full rounded-full", readiness >= 60 ? "bg-pine" : "bg-slate/40")} style={{ width: `${Math.min(readiness, 100)}%` }} />
              </div>
            )}
          </div>
          <p className="text-xs text-slate" title="Aroon Up / Down (25 sessions)">
            Aroon <span className="font-mono text-ink">↑{row.values.aroon_up ?? "—"} ↓{row.values.aroon_down ?? "—"}</span>
          </p>
          <Button size="sm" variant="outline" onClick={onChart} className="inline-flex items-center gap-1.5" aria-label={`Chart ${row.symbol}`}>
            <ChartIcon className="h-3.5 w-3.5" /> Chart
          </Button>
        </div>
      </div>
    </article>
  )
}
