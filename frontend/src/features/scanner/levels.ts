import type { RowLevels } from "./types"

export type LevelState = { text: string; tone: string }

// Where the price is against the levels: in the zone, below it, above it, or under the stop.
export function levelState(price: number, levels: RowLevels): LevelState {
  if (price <= levels.stop) return { text: "Below stop", tone: "bg-ember/10 text-ember" }
  if (price < levels.entry_low) return { text: `Wait: ${((levels.entry_low / price - 1) * 100).toFixed(1)}% below entry`, tone: "bg-slate/10 text-slate" }
  if (price <= levels.entry_high) return { text: "In entry zone", tone: "bg-pine/15 text-pine" }
  return { text: `Extended +${((price / levels.entry_high - 1) * 100).toFixed(1)}% (chasing)`, tone: "bg-amber-100 text-amber-800" }
}

