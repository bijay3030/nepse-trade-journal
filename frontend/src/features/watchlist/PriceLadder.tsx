import type { WatchlistItem } from "./types"

// A horizontal scale from just below invalidation to just above the target, with
// the entry zone shaded and a marker at the current price.
export function PriceLadder({ item }: { item: WatchlistItem }) {
  const top = Math.max(item.target_price ?? item.entry_zone_high * 1.1, item.current_price, item.entry_zone_high)
  const bottom = Math.min(item.invalidation_price, item.current_price)
  const padding = (top - bottom) * 0.08 || 1
  const min = bottom - padding
  const max = top + padding
  const pct = (value: number) => `${Math.min(100, Math.max(0, ((value - min) / (max - min)) * 100))}%`

  return (
    <div className="relative mt-3 h-10" aria-hidden="true">
      <div className="absolute inset-x-0 top-4 h-2 rounded-full bg-slate/10" />
      <div className="absolute top-4 h-2 bg-ember/40" style={{ left: 0, width: pct(item.invalidation_price) }} />
      <div
        className="absolute top-3 h-4 rounded bg-pine/30 ring-1 ring-pine/50"
        style={{ left: pct(item.entry_zone_low), width: `calc(${pct(item.entry_zone_high)} - ${pct(item.entry_zone_low)})`, minWidth: 4 }}
      />
      {item.target_price !== null && <div className="absolute top-2 h-6 w-0.5 bg-ink/40" style={{ left: pct(item.target_price) }} />}
      <div className="absolute top-1 -ml-1.5 h-8 w-3 rounded-full border-2 border-white bg-ink shadow" style={{ left: pct(item.current_price) }} />
    </div>
  )
}
