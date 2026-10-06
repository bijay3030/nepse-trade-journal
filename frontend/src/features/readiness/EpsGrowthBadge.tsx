import { cn } from "../../lib/cn"
import type { EpsGrowth } from "../screener/types"

// Year-on-year EPS growth of the latest quarterly report. Information only.
export function EpsGrowthBadge({ growth, className }: { growth?: EpsGrowth | null; className?: string }) {
  if (!growth) return null
  const tone = growth.strong ? "bg-pine/10 text-pine" : growth.growth_pct < 0 ? "bg-ember/10 text-ember" : "bg-slate/10 text-slate"
  const from = growth.source === "reported" && growth.prior_eps !== null
    ? `EPS ${growth.eps} vs ${growth.prior_eps} in the same quarter a year earlier`
    : "growth rate reported by Chukul"
  return (
    <span className={cn("inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold", tone, className)}
      title={`${growth.quarter} ${growth.fiscal_year}: ${from}. CAN SLIM looks for 25%+. Information only; not in the backtest yet.`}>
      EPS {growth.growth_pct > 0 ? "+" : ""}{growth.growth_pct}% YoY
    </span>
  )
}
