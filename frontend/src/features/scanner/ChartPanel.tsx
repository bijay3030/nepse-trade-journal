import { ChevronLeft, ChevronRight, X } from "lucide-react"
import { useEffect, useMemo, useState } from "react"
import { createPortal } from "react-dom"
import { Link } from "react-router-dom"

import { Button, LoadingSpinner } from "../../components/ui"
import { cn } from "../../lib/cn"
import { useCrossoverChart } from "./api"
import { IndicatorChart } from "./IndicatorChart"
import { LINE_STYLES, SIGNAL_BY_KEY, type LineKey } from "./signals"
import type { CrossoverSignal } from "./types"

const RANGES = [
  { label: "3M", sessions: 63 },
  { label: "6M", sessions: 126 },
  { label: "1Y", sessions: 260 },
]
const LINES: LineKey[] = ["ema9", "ema21", "ema50", "hma", "alma"]

const money = (value: number) => value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const pct = (value: number) => `${value > 0 ? "+" : ""}${value.toFixed(2)}%`

type Props = {
  symbol: string
  /** Signals ticked on the scanner: their ▲/▼ markers are shown. */
  signals: CrossoverSignal[]
  position: { index: number; total: number }
  onPrevious?: () => void
  onNext?: () => void
  onClose: () => void
}

// A panel over the scanner with one stock's chart, its indicators and signal history.
export function ChartPanel({ symbol, signals, position, onPrevious, onNext, onClose }: Props) {
  const { data, isLoading, isError } = useCrossoverChart(symbol)
  const [sessions, setSessions] = useState(126)
  const [lines, setLines] = useState<LineKey[]>(LINES)
  const [showAroon, setShowAroon] = useState(true)
  const marked = useMemo(() => (signals.length > 0 ? signals : (["ema_9_21"] as CrossoverSignal[])), [signals])

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose()
      if (event.key === "ArrowRight" && onNext) onNext()
      if (event.key === "ArrowLeft" && onPrevious) onPrevious()
    }
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  }, [onClose, onNext, onPrevious])

  const toggleLine = (key: LineKey) => setLines((current) => (current.includes(key) ? current.filter((k) => k !== key) : [...current, key]))
  const from = data ? data.candles[Math.max(data.candles.length - sessions, 0)]?.traded_on : undefined

  return createPortal(
    <div className="fixed inset-0 z-50 flex justify-end bg-ink/40" onClick={onClose}>
      <aside role="dialog" aria-modal="true" aria-label={`${symbol} chart`}
        className="flex h-full w-full max-w-5xl flex-col overflow-y-auto bg-white p-4 shadow-xl sm:p-6" onClick={(event) => event.stopPropagation()}>
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 className="font-display text-xl font-bold text-ink">{symbol}</h2>
            <p className="text-sm text-slate">{data ? `${data.name} · ${data.sector}` : " "}</p>
          </div>
          <div className="flex items-center gap-2">
            <span className="text-xs text-slate">{position.index + 1} of {position.total}</span>
            <Button size="sm" variant="outline" aria-label="Previous stock" disabled={!onPrevious} onClick={onPrevious}><ChevronLeft className="h-4 w-4" /></Button>
            <Button size="sm" variant="outline" aria-label="Next stock" disabled={!onNext} onClick={onNext}><ChevronRight className="h-4 w-4" /></Button>
            <Link to={`/screener/${encodeURIComponent(symbol)}`} className="rounded-lg border border-slate/20 px-3 py-1.5 text-xs font-semibold text-ink hover:bg-slate/5">Stock page</Link>
            <button type="button" aria-label="Close chart" onClick={onClose} className="rounded-lg p-2 text-slate hover:bg-slate/10"><X className="h-4 w-4" /></button>
          </div>
        </div>

        <div className="mt-3 flex flex-wrap items-center gap-2 text-xs">
          <div className="inline-flex rounded-lg border border-mist/80 bg-slate/5 p-0.5" role="tablist" aria-label="Range">
            {RANGES.map((range) => (
              <button key={range.label} type="button" role="tab" aria-selected={sessions === range.sessions} onClick={() => setSessions(range.sessions)}
                className={cn("rounded-md px-2.5 py-1 font-semibold", sessions === range.sessions ? "bg-white text-ink shadow-sm" : "text-slate")}>{range.label}</button>
            ))}
          </div>
          {LINES.map((key) => (
            <label key={key} className={cn("flex cursor-pointer items-center gap-1.5 rounded-full border px-2.5 py-1", lines.includes(key) ? "border-ink/30 text-ink" : "border-slate/20 text-slate/70")}>
              <input type="checkbox" className="sr-only" checked={lines.includes(key)} onChange={() => toggleLine(key)} />
              <span className="inline-block h-0.5 w-4" style={{ backgroundColor: LINE_STYLES[key].color }} />
              {LINE_STYLES[key].label}
            </label>
          ))}
          <label className={cn("flex cursor-pointer items-center gap-1.5 rounded-full border px-2.5 py-1", showAroon ? "border-ink/30 text-ink" : "border-slate/20 text-slate/70")}>
            <input type="checkbox" className="sr-only" checked={showAroon} onChange={() => setShowAroon((on) => !on)} />
            Aroon 25
          </label>
        </div>

        <div className="mt-3">
          {isLoading ? (
            <div className="flex h-96 items-center justify-center"><LoadingSpinner /></div>
          ) : isError || !data ? (
            <p className="py-12 text-center text-sm text-ember">Couldn't load the chart for {symbol}.</p>
          ) : (
            <>
              <IndicatorChart chart={data} sessions={sessions} lines={lines} showAroon={showAroon} signals={marked} />
              <p className="mt-2 text-xs text-slate">
                ▲ where a signal began · ▼ where it ended. Markers: {marked.map((key) => SIGNAL_BY_KEY[key].label).join(", ")}
                {signals.length === 0 && " (tick signals on the scanner to choose)"}. Completed sessions only.
              </p>
            </>
          )}
        </div>

        {data && (
          <section className="mt-4" aria-label="Signal history">
            <h3 className="font-display text-sm font-bold text-ink">What happened after each signal (in this range)</h3>
            <div className="mt-2 overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="text-left text-xs text-slate">
                  <tr><th className="py-1 pr-3">Signal</th><th className="py-1 pr-3">Began ▲</th><th className="py-1 pr-3">Ended ▼</th><th className="py-1 pr-3 text-right">Sessions</th><th className="py-1 text-right">Change</th></tr>
                </thead>
                <tbody className="divide-y divide-mist/60">
                  {marked.flatMap((key) =>
                    data.episodes[key].filter((episode) => !from || episode.start_on >= from).reverse().map((episode) => (
                      <tr key={`${key}-${episode.start_on}`}>
                        <td className="py-1.5 pr-3 text-ink">{SIGNAL_BY_KEY[key].short}</td>
                        <td className="py-1.5 pr-3 font-mono text-xs">{episode.start_on} at {money(episode.start_price)}</td>
                        <td className="py-1.5 pr-3 font-mono text-xs">{episode.open ? <span className="font-sans font-semibold text-pine">still on</span> : `${episode.end_on} at ${money(episode.end_price as number)}`}</td>
                        <td className="py-1.5 pr-3 text-right font-mono">{episode.sessions}</td>
                        <td className={cn("py-1.5 text-right font-mono", episode.change_pct >= 0 ? "text-pine" : "text-ember")}>{pct(episode.change_pct)}{episode.open ? " so far" : ""}</td>
                      </tr>
                    )),
                  )}
                </tbody>
              </table>
              {marked.every((key) => data.episodes[key].every((episode) => from && episode.start_on < from)) && (
                <p className="py-3 text-center text-xs text-slate">No signal began in this range. Try 1Y.</p>
              )}
            </div>
            <p className="mt-2 text-xs text-slate">
              Change = close when the signal ended (or the latest close) against the close when it began, before costs. These are the indicator's own
              signals, not recommendations; on NEPSE they did worse than the average stock-day over the past year (see the track record on the scanner).
            </p>
          </section>
        )}
      </aside>
    </div>,
    document.body,
  )
}
