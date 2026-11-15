import { cn } from "../../lib/cn"
import { SIGNALS } from "./signals"
import type { CrossoverScan, CrossoverSignal, MarketPhaseName } from "./types"

const LOOK: Record<MarketPhaseName, { label: string; box: string; dot: string }> = {
  uptrend: { label: "Uptrend", box: "border-pine/30 bg-pine/5", dot: "bg-pine" },
  sideways: { label: "Sideways", box: "border-amber-300 bg-amber-50", dot: "bg-amber-500" },
  downtrend: { label: "Downtrend", box: "border-ember/30 bg-ember/5", dot: "bg-ember" },
}

const pct = (value: number) => `${value > 0 ? "+" : ""}${value.toFixed(2)}%`
const index = (value: number) => value.toLocaleString("en-US", { maximumFractionDigits: 0 })

// NEPSE's phase now, and how the ticked signals did in that phase since 2020.
export function MarketPhaseBanner({ scan, selected }: { scan: CrossoverScan; selected: CrossoverSignal[] }) {
  const current = scan.market_phase
  if (!current?.phase) return null
  const look = LOOK[current.phase]
  const phases = scan.backtest.by_phase
  const base = phases?.all?.[current.phase]
  const keys = selected.length > 0 ? selected : SIGNALS.map((signal) => signal.key)
  const results = keys
    .map((key) => ({ key, stats: phases?.[key]?.[current.phase as MarketPhaseName] }))
    .filter((entry) => entry.stats && entry.stats.n > 0 && entry.stats.avg_return_pct != null)
  const since = scan.backtest.period.from?.slice(0, 4)
  const relation = current.phase === "uptrend" ? "more than 1% above" : current.phase === "downtrend" ? "more than 1% below" : "within 1% of"

  return (
    <section aria-label="Market phase" className={cn("rounded-2xl border px-4 py-3", look.box)}>
      <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
        <p className="flex items-center gap-2 font-display text-base font-bold text-ink">
          <span className={cn("h-2.5 w-2.5 rounded-full", look.dot)} aria-hidden />
          NEPSE: {look.label}{" "}
          {current.sessions != null && <span className="text-sm font-semibold text-slate">for {current.sessions} {current.sessions === 1 ? "session" : "sessions"}</span>}
        </p>
        {current.sma20 != null && current.sma50 != null && (
          <p className="text-xs text-slate">20-day average {index(current.sma20)} is {relation} the 50-day {index(current.sma50)}</p>
        )}
      </div>
      {base?.avg_return_pct != null && results.length > 0 && (
        <div className="mt-2 text-sm text-ink">
          <p className="text-slate">
            In {look.label.toLowerCase()} phases since {since ?? "2020"}, 20 sessions after {selected.length > 0 ? "the ticked signals" : "each signal"} began
            (all stock-days: <b className="font-mono text-ink">{pct(base.avg_return_pct)}</b>):
          </p>
          <ul className="mt-1.5 flex flex-wrap gap-1.5">
            {results.map(({ key, stats }) => {
              const avg = stats?.avg_return_pct as number
              const edge = avg - (base.avg_return_pct as number)
              return (
                <li key={key} className={cn("rounded-full border bg-white px-2.5 py-1 text-xs",
                  edge > 0.5 ? "border-pine/30" : edge < -0.5 ? "border-ember/30" : "border-slate/20")}>
                  <b>{SIGNALS.find((signal) => signal.key === key)?.short}</b>{" "}
                  <span className={cn("font-mono font-semibold", edge > 0.5 ? "text-pine" : edge < -0.5 ? "text-ember" : "text-ink")}>{pct(avg)}</span>{" "}
                  <span className="text-slate">{edge > 0.5 ? "better than average" : edge < -0.5 ? "worse than average" : "about average"}</span>
                </li>
              )
            })}
          </ul>
        </div>
      )}
      <p className="mt-2 text-[11px] text-slate">Describes the index, not a forecast. Phases change; check the by-phase table in the track record details.</p>
    </section>
  )
}
