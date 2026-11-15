import { ArrowDownWideNarrow, ArrowUpNarrowWide } from "lucide-react"
import { useMemo, useState } from "react"

import { Button, Card, LoadingSpinner } from "../components/ui"
import { useCrossoverScan } from "../features/scanner/api"
import { ChartPanel } from "../features/scanner/ChartPanel"
import { MarketPhaseBanner } from "../features/scanner/MarketPhaseBanner"
import { ResultCard } from "../features/scanner/ResultCard"
import { SIGNALS, STRONG_VOLUME } from "../features/scanner/signals"
import { TelegramAlertControl } from "../features/scanner/TelegramAlertControl"
import { TrackRecord } from "../features/scanner/TrackRecord"
import type { CrossoverSignal, ScanRow } from "../features/scanner/types"
import { useStockPrices } from "../hooks/useStockPrices"
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

// Each sort's natural first direction: A-Z / newest first / highest first.
const SORTS: Array<{ key: SortKey; label: string; dir: Sort["dir"] }> = [
  { key: "readiness", label: "Readiness", dir: "desc" },
  { key: "newest", label: "Newest signal", dir: "asc" },
  { key: "change", label: "Change today", dir: "desc" },
  { key: "aroon", label: "Aroon Up", dir: "desc" },
  { key: "close", label: "Price", dir: "desc" },
  { key: "symbol", label: "Symbol", dir: "asc" },
]

// Crossovers must have begun within the window; states only need to hold now.
function matches(row: ScanRow, selected: CrossoverSignal[], within: number) {
  return selected.every((key) => {
    const age = row.signals[key]
    return age !== null && (STATES.includes(key) || age <= within)
  })
}

// The youngest of the ticked signals (or of all signals when none is ticked).
function youngest(row: ScanRow, selected: CrossoverSignal[]): CrossoverSignal | null {
  const keys = selected.length > 0 ? selected : SIGNALS.map((signal) => signal.key)
  let best: CrossoverSignal | null = null
  for (const key of keys) {
    const age = row.signals[key]
    if (age !== null && (best === null || age < (row.signals[best] as number))) best = key
  }
  return best
}

function newest(row: ScanRow, selected: CrossoverSignal[]) {
  const key = youngest(row, selected)
  return key ? (row.signals[key] as number) : Number.POSITIVE_INFINITY
}

// The day the combination began (its youngest signal) had strong volume: in the 2020-2026
// test, signals on 1.5x average volume did 3-7 points better.
function strongVolume(row: ScanRow, selected: CrossoverSignal[], threshold: number) {
  const key = youngest(row, selected)
  return key !== null && (row.signal_volume?.[key] ?? 0) >= threshold
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
  const threshold = data?.backtest.strong_volume ?? STRONG_VOLUME
  const [selected, setSelected] = useState<CrossoverSignal[]>(["ema_9_21"])
  const [within, setWithin] = useState(3)
  const [hideThin, setHideThin] = useState(true)
  const [volumeOnly, setVolumeOnly] = useState(true)
  const [sort, setSort] = useState<Sort>({ key: "readiness", dir: "desc" })
  const [charting, setCharting] = useState<string | null>(null)

  const rows = useMemo(() => {
    if (!data) return []
    const direction = sort.dir === "asc" ? 1 : -1
    return data.rows
      .filter((row) => matches(row, selected, within))
      .filter((row) => !hideThin || !(row.guards ?? []).includes("thin_volume"))
      .filter((row) => !volumeOnly || strongVolume(row, selected, threshold))
      .sort((a, b) => {
        const x = sortValue(a, sort.key, selected)
        const y = sortValue(b, sort.key, selected)
        const order = typeof x === "string" ? x.localeCompare(y as string) : (x as number) - (y as number)
        return order * direction || a.symbol.localeCompare(b.symbol)
      })
  }, [data, selected, within, hideThin, volumeOnly, threshold, sort])

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
  const chartIndex = charting ? rows.findIndex((row) => row.symbol === charting) : -1
  const sortLabel = SORTS.find((option) => option.key === sort.key)?.label

  return (
    <div className="space-y-4">
      <header>
        <h1 className="font-display text-2xl font-bold tracking-tight text-ink sm:text-3xl">Indicator Scanner</h1>
        <p className="mt-1 max-w-3xl text-sm text-slate">
          Stocks matching every signal you tick, on completed sessions up to <b className="text-ink">{data.as_of ?? "—"}</b>. Rule checks, not recommendations.
        </p>
        <p className="mt-0.5 text-xs text-slate">
          Settings (chosen from a 2020–2026 test on NEPSE): EMA {data.params.ema.join(" / ")}, HMA {data.params.hma}, ALMA {data.params.alma.length}{" "}
          (offset {data.params.alma.offset}, sigma {data.params.alma.sigma}), Aroon {data.params.aroon}.
        </p>
      </header>

      <MarketPhaseBanner scan={data} selected={selected} />

      <div>
        <Card className="space-y-3 p-4 shadow-sm">
          <fieldset>
            <legend className="mb-1.5 text-[11px] font-bold uppercase tracking-wider text-slate">Signals · a stock must match all ticked</legend>
            <div className="flex flex-wrap gap-1.5">
              {SIGNALS.map((signal) => (
                <label key={signal.key} title={signal.help}
                  className={cn("cursor-pointer rounded-full border px-3 py-1 text-xs font-semibold transition-colors focus-within:ring-2 focus-within:ring-pine/40",
                    selected.includes(signal.key) ? "border-ink bg-ink text-white" : "border-slate/20 text-ink hover:bg-slate/5")}>
                  <input type="checkbox" className="sr-only" checked={selected.includes(signal.key)} onChange={() => toggle(signal.key)} />
                  {signal.label}
                </label>
              ))}
            </div>
          </fieldset>
          <div className="flex flex-wrap items-center gap-x-5 gap-y-2 border-t border-mist/60 pt-3 text-xs">
            <span className="text-[11px] font-bold uppercase tracking-wider text-slate">Options</span>
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
            <label className="flex items-center gap-2 text-slate" title="The day the newest ticked signal began traded at least this multiple of its 50-session average volume.">
              <input type="checkbox" checked={volumeOnly} onChange={(event) => setVolumeOnly(event.target.checked)} />
              Volume ≥ {threshold}× on the signal day
            </label>
            <span className="sm:ml-auto"><TelegramAlertControl selected={selected} volume={volumeOnly} /></span>
          </div>
        </Card>
      </div>

      <TrackRecord backtest={data.backtest} selected={selected} />

      <div className="sticky top-[calc(var(--app-header-h,0px)+0.5rem)] z-20 -mx-1 flex flex-wrap items-center justify-between gap-2 rounded-xl border border-mist/80 bg-white/95 px-3 py-2 shadow-sm backdrop-blur">
        <p className="text-sm text-slate" aria-live="polite">
          <b className="text-ink">{rows.length} of {data.rows.length} stocks</b> match{" "}
          <span className="text-xs">
            {selected.length > 0 ? selected.map((key) => SIGNALS.find((signal) => signal.key === key)?.short).join(" + ") : "any signal"}
            {" · "}{RECENCY.find((option) => option.value === within)?.label.toLowerCase()}{volumeOnly ? ` · ${threshold}× vol` : ""}
          </span>
        </p>
        <div className="flex items-center gap-2 text-sm">
          <label className="flex items-center gap-2 text-slate">
            Sort by
            <select aria-label="Sort by" className="rounded-lg border border-slate/20 bg-white px-2 py-1 text-ink" value={sort.key}
              onChange={(event) => {
                const option = SORTS.find((entry) => entry.key === event.target.value) ?? SORTS[0]
                setSort({ key: option.key, dir: option.dir })
              }}>
              {SORTS.map((option) => <option key={option.key} value={option.key}>{option.label}</option>)}
            </select>
          </label>
          <Button size="sm" variant="outline" aria-label={`Reverse order (${sortLabel}, ${sort.dir === "asc" ? "ascending" : "descending"})`}
            onClick={() => setSort((current) => ({ ...current, dir: current.dir === "asc" ? "desc" : "asc" }))}>
            {sort.dir === "asc" ? <ArrowUpNarrowWide className="h-4 w-4" /> : <ArrowDownWideNarrow className="h-4 w-4" />}
          </Button>
        </div>
      </div>

      {rows.length === 0 ? (
        <Card className="p-8 text-center text-sm text-slate">
          No stock matches every ticked signal{selected.length > 0 ? " in that window" : ""}{volumeOnly ? ` on ${threshold}× volume` : ""}. Untick a signal{volumeOnly ? ", the volume filter" : ""} or widen the window.
        </Card>
      ) : (
        <div className="grid gap-3 xl:grid-cols-2" aria-label="Results">
          {rows.map((row) => (
            <ResultCard key={row.symbol} row={row} selected={selected} volumeThreshold={threshold} asOf={data.as_of}
              live={getPrice(row.symbol)} charting={charting === row.symbol} onChart={() => setCharting(row.symbol)} />
          ))}
        </div>
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
