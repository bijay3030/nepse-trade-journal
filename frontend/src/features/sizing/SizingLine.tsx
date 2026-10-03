import { Link } from "react-router-dom"

import { rupees, signedRupees } from "./format"
import { isSized, type WatchlistSizing } from "./types"

// One-line position size on a watchlist card: what to enter on TMS and what it risks.
export function SizingLine({ sizing }: { sizing: WatchlistSizing | null | undefined }) {
  if (!sizing) {
    return (
      <p className="mt-2 text-xs text-slate">
        <Link to="/settings" className="font-semibold text-ink underline">Set your trading capital</Link> to see a position size for this setup.
      </p>
    )
  }
  if ("error" in sizing) return <p className="mt-2 text-xs text-ember">{sizing.error}</p>
  if (!isSized(sizing)) return <p className="mt-2 text-xs text-slate" aria-label="Position size">Size: {sizing.note}.</p>

  return (
    <p className="mt-2 rounded-lg bg-pine/5 px-3 py-2 text-xs text-slate" aria-label="Position size">
      <b className="text-ink">Size: {sizing.quantity} shares</b> at {sizing.entry?.toFixed(2)} = {rupees(sizing.amount)} + {rupees(sizing.buy_costs.total)} fees
      {" · "}loss at stop {sizing.stop?.toFixed(2)}: <b className="text-ember">{rupees(sizing.loss_at_stop)}</b>
      {sizing.loss_pct_of_capital !== null && ` (${sizing.loss_pct_of_capital}% of capital)`}
      {sizing.break_even !== null && ` · break-even ${sizing.break_even.toFixed(2)}`}
      {sizing.gain_at_target !== null && <> · at target <b className="text-pine">{signedRupees(sizing.gain_at_target)}</b>{sizing.reward_risk !== null && ` (${sizing.reward_risk}R)`}</>}
      {sizing.limited_by === "capital" && " · limited by your capital"}
    </p>
  )
}
