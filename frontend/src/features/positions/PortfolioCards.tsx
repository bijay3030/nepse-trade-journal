import { Card } from "../../components/ui"
import { cn } from "../../lib/cn"
import type { Portfolio } from "./types"

const rupees = (value: number) => `Rs ${value.toLocaleString("en-US", { maximumFractionDigits: 0 })}`

const BAR: Record<Portfolio["heat"]["state"], string> = { ok: "bg-pine", near: "bg-amber-500", over: "bg-ember", unknown: "bg-slate/40" }

// Open risk (every stop hit, after costs) as % of capital, against the user's limit.
export function HeatCard({ portfolio }: { portfolio: Portfolio }) {
  const { heat } = portfolio
  if (heat.pct === null) {
    return <Card className="p-4 text-sm text-slate">Set your trading capital in Settings to see portfolio heat and sector exposure.</Card>
  }
  const scale = Math.max(heat.limit_pct * 1.25, heat.pct)
  const fill = Math.min(heat.pct / scale, 1) * 100
  const mark = (heat.limit_pct / scale) * 100

  return (
    <Card className="p-4" aria-label="Portfolio heat">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h2 className="font-display text-base font-bold text-ink">Portfolio heat</h2>
        <p className={cn("text-sm font-semibold", heat.state === "over" ? "text-ember" : heat.state === "near" ? "text-amber-800" : "text-pine")}>
          {heat.pct.toFixed(1)}% of capital at risk · limit {heat.limit_pct}%
        </p>
      </div>
      <div className="relative mt-3 h-3 rounded-full bg-slate/10">
        <div className={cn("h-3 rounded-full", BAR[heat.state])} style={{ width: `${fill}%` }} />
        <div className="absolute -top-1 h-5 w-0.5 bg-ink" style={{ left: `${mark}%` }} title={`Limit ${heat.limit_pct}%`} />
      </div>
      <p className="mt-2 text-xs text-slate">
        {rupees(portfolio.open_risk)} lost if every stop is hit, after costs.
        {heat.room !== null && heat.state !== "over" ? ` Room for ${rupees(heat.room)} more risk.` : " New entries would add to risk over your limit."}
        {portfolio.cash !== null && ` Cash ${rupees(portfolio.cash)} · invested ${rupees(portfolio.invested)}.`}
      </p>
      {portfolio.positions.length > 1 && (
        <ul className="mt-2 flex flex-wrap gap-2 text-xs text-slate" aria-label="Heat by position">
          {portfolio.positions.map((row) => (
            <li key={row.position_id} className="rounded-full bg-slate/10 px-2.5 py-1">
              {row.symbol} {row.heat_pct?.toFixed(1)}% <span className="text-slate/70">({row.share_of_risk_pct?.toFixed(0)}% of risk)</span>
            </li>
          ))}
        </ul>
      )}
    </Card>
  )
}

// Market value per sector as % of capital; sectors over the user's limit are flagged.
export function SectorCard({ portfolio, limit }: { portfolio: Portfolio; limit: number }) {
  if (portfolio.sectors.length === 0 || portfolio.capital === null) return null
  return (
    <Card className="p-4" aria-label="Sector exposure">
      <h2 className="font-display text-base font-bold text-ink">Sector exposure</h2>
      <ul className="mt-3 space-y-2">
        {portfolio.sectors.map((row) => (
          <li key={row.sector} className="text-sm">
            <div className="flex justify-between gap-2">
              <span className="text-ink">{row.sector} <span className="text-xs text-slate">{row.symbols.join(", ")}</span></span>
              <span className={cn("font-mono font-semibold", row.over ? "text-ember" : "text-ink")}>{row.pct?.toFixed(1)}%</span>
            </div>
            <div className="mt-1 h-1.5 rounded-full bg-slate/10">
              <div className={cn("h-1.5 rounded-full", row.over ? "bg-ember" : "bg-pine")} style={{ width: `${Math.min(row.pct ?? 0, 100)}%` }} />
            </div>
            {row.over && <p className="mt-0.5 text-xs text-ember">Over your {limit}% sector limit: one sector's news would hit a large share of your capital.</p>}
          </li>
        ))}
      </ul>
    </Card>
  )
}
