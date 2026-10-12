import { cn } from "../../lib/cn"
import type { LiveStockPrice } from "../../stores/stockPricesStore"

type Props = {
  live?: LiveStockPrice
  /** The snapshot's session (YYYY-MM-DD): only a newer live price is shown. */
  snapshotOn: string | null | undefined
  zoneLow?: number | null
  zoneHigh?: number | null
  stop?: number | null
}

const npDate = (iso: string) => new Date(iso).toLocaleDateString("en-CA", { timeZone: "Asia/Kathmandu" })
const money = (value: number) => value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })

// Today's live price against the snapshot's zone. The board itself is still judged on
// the close (that's what the backtest measured); this only shows where the price is now.
export function LiveStatus({ live, snapshotOn, zoneLow, zoneHigh, stop }: Props) {
  if (!live || !live.updatedAt || !snapshotOn || npDate(live.updatedAt) <= snapshotOn) return null
  const price = live.lastPrice
  let state: { text: string; tone: string }
  if (stop && price <= stop) state = { text: "at or below the stop", tone: "text-ember" }
  else if (zoneLow && price < zoneLow) state = { text: `${((zoneLow / price - 1) * 100).toFixed(1)}% below the zone`, tone: "text-slate" }
  else if (zoneHigh && price <= zoneHigh) state = { text: "in the zone now", tone: "text-pine" }
  else if (zoneHigh) state = { text: `${((price / zoneHigh - 1) * 100).toFixed(1)}% above the zone`, tone: "text-amber-800" }
  else state = { text: "", tone: "text-slate" }

  return (
    <p className="text-xs" aria-label="Live price">
      <b className="text-ink">Live {money(price)}</b>{" "}
      <span className={live.changePercent >= 0 ? "text-pine" : "text-ember"}>({live.changePercent >= 0 ? "+" : ""}{live.changePercent.toFixed(2)}%)</span>
      {state.text && <span className={cn("font-semibold", state.tone)}> · {state.text}</span>}
    </p>
  )
}
