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
    <div className="space-y-1" aria-label="Levels">
      <span className={cn("inline-block rounded-full px-2 py-0.5 text-xs font-semibold", state.tone)} title={`${useLive ? "Live" : "Close"} ${money(price)}`}>
        {state.text}
      </span>
      <p className="whitespace-nowrap text-xs" title={`${source} Rule output, not advice.`}>
        <span className="font-semibold text-pine">Entry {money(levels.entry_low)}–{money(levels.entry_high)}</span>
        <span className="text-slate"> · </span>
        <span className="font-semibold text-ember">Stop {money(levels.stop)}</span>
        {levels.target !== null && (<><span className="text-slate"> · </span><span className="font-semibold text-pine">Target {money(levels.target)}</span></>)}
      </p>
      <p className="text-[10px] uppercase tracking-wide text-slate">{levels.source === "board_setup" ? `${SETUP_NAMES[levels.setup_type ?? ""] ?? "setup"} levels` : "crossover rule"}</p>
    </div>
  )
}
