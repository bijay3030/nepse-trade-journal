import { cn } from "../../lib/cn"
import type { LiveStockPrice } from "../../stores/stockPricesStore"
import { levelState } from "./levels"
import type { RowLevels } from "./types"

const money = (value: number) => value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const npDate = (iso: string) => new Date(iso).toLocaleDateString("en-CA", { timeZone: "Asia/Kathmandu" })

const SETUP_NAMES: Record<string, string> = {
  vcp: "VCP", pullback: "support pullback", ma_pullback: "MA pullback", base_breakout: "flat base", three_weeks_tight: "3-weeks-tight", undercut_rally: "undercut-and-rally",
}

/**
 * Entry / stop / target for a scanner row, and where the price is now: the live price
 * during the session (once newer than the scan), else the scan's close.
 */
export function LevelsTag({ levels, close, asOf, live }: { levels?: RowLevels | null; close: number; asOf: string | null; live?: LiveStockPrice }) {
  if (!levels) return <span className="text-xs text-slate">—</span>
  const useLive = Boolean(live?.updatedAt && asOf && npDate(live.updatedAt) > asOf)
  const price = useLive && live ? live.lastPrice : close
  const state = levelState(price, levels)
  const source = levels.source === "board_setup"
    ? `From the ${SETUP_NAMES[levels.setup_type ?? ""] ?? "board"} setup (board rules).`
    : "Crossover rule: entry = signal close to +1 ADR, stop under EMA 21 (max 8%), target 2× the risk. It lost money in the backtest."

  return (
    <div className="space-y-1.5" aria-label="Levels">
      <div className="flex flex-wrap items-center gap-2">
        <span className={cn("inline-block rounded-full px-2 py-0.5 text-xs font-semibold", state.tone)} title={`${useLive ? "Live" : "Close"} ${money(price)}`}>
          {state.text}
        </span>
        <span className="text-[10px] uppercase tracking-wide text-slate" title={`${source} Rule output, not advice.`}>
          {levels.source === "board_setup" ? `${SETUP_NAMES[levels.setup_type ?? ""] ?? "setup"} levels` : "crossover rule"}
        </span>
      </div>
      <LevelsBar levels={levels} price={price} />
      <p className="text-xs" title={`${source} Rule output, not advice.`}>
        <span className="whitespace-nowrap font-semibold text-pine">Entry {money(levels.entry_low)}–{money(levels.entry_high)}</span>
        <span className="text-slate"> · </span>
        <span className="whitespace-nowrap font-semibold text-ember">Stop {money(levels.stop)}</span>
        {levels.target !== null && (<><span className="text-slate"> · </span><span className="whitespace-nowrap font-semibold text-pine">Target {money(levels.target)}</span></>)}
      </p>
    </div>
  )
}

// Stop → entry zone → target on one line, with a marker at the price.
function LevelsBar({ levels, price }: { levels: RowLevels; price: number }) {
  const top = levels.target ?? levels.entry_high + (levels.entry_high - levels.stop)
  const low = Math.min(levels.stop, price)
  const high = Math.max(top, price)
  const span = high - low || 1
  const at = (value: number) => `${((value - low) / span) * 100}%`
  const width = (from: number, to: number) => `${(Math.max(to - from, 0) / span) * 100}%`

  return (
    <div className="relative h-2 w-full max-w-xs rounded-full bg-slate/10" aria-hidden title={`Price ${money(price)}`}>
      <div className="absolute inset-y-0 rounded-l-full bg-ember/25" style={{ left: at(levels.stop), width: width(levels.stop, levels.entry_low) }} />
      <div className="absolute inset-y-0 bg-pine/60" style={{ left: at(levels.entry_low), width: width(levels.entry_low, levels.entry_high) }} />
      {levels.target !== null && <div className="absolute inset-y-0 rounded-r-full bg-pine/20" style={{ left: at(levels.entry_high), width: width(levels.entry_high, levels.target) }} />}
      <div className="absolute -top-1 h-4 w-1 -translate-x-1/2 rounded-full bg-ink ring-2 ring-white" style={{ left: at(price) }} />
    </div>
  )
}
