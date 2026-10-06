import { cn } from "../../lib/cn"
import type { MarketDirection } from "../screener/types"

const TONE: Record<MarketDirection["state"], string> = {
  uptrend: "border-pine/30 bg-pine/5",
  under_pressure: "border-amber-300 bg-amber-50",
  correction: "border-ember/30 bg-ember/5",
}

const date = (iso: string) => new Date(`${iso}T00:00:00`).toLocaleDateString("en-GB", { day: "numeric", month: "short" })

// The NEPSE index's state (distribution and follow-through days). Description, not advice.
export function MarketDirectionCard({ direction, compact = false }: { direction: MarketDirection; compact?: boolean }) {
  const { state, thresholds } = direction
  const detail = [
    `${direction.distribution_days} distribution day${direction.distribution_days === 1 ? "" : "s"} in the last 25 sessions`,
    `index ${direction.drawdown_pct}% from its high`,
    state === "correction" && direction.rally_day ? `rally attempt day ${direction.rally_day}` : null,
    state !== "correction" && direction.follow_through_on ? `last follow-through ${date(direction.follow_through_on)}` : null,
  ].filter(Boolean).join(" · ")

  return (
    <section className={cn("rounded-xl border px-4 py-3 text-sm", TONE[state])} aria-label="Market direction">
      <p className="text-ink">
        <b>Market: {direction.label}</b>
        <span className="text-slate"> · {detail}</span>
      </p>
      {state !== "uptrend" && (
        <p className="mt-1 text-xs text-slate">
          Position sizes also show a cautious size at {Math.round(direction.size_factor * 100)}% of your usual risk. In the
          backtest this state didn't reliably predict later returns, so it's for your judgement.
        </p>
      )}
      {!compact && (
        <p className="mt-1 text-xs text-slate">
          A distribution day is the index closing down {thresholds.down_pct}%+ on higher turnover; a follow-through day is a
          {" "}{thresholds.up_pct}%+ gain on higher turnover from day 4 of a rally attempt. Thresholds are scaled to NEPSE's
          larger daily moves.
        </p>
      )}
    </section>
  )
}
