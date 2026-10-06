import type { HeatCheck } from "./types"

// Warns when a buy would take open risk past the user's limit. It never blocks the buy.
export function HeatWarning({ heat, onUse }: { heat?: HeatCheck; onUse?: (quantity: number) => void }) {
  if (!heat || heat.after_pct === null || (heat.state !== "over" && heat.state !== "near")) return null
  const over = heat.state === "over"
  return (
    <span className={over ? "block text-xs font-semibold text-ember" : "block text-xs text-amber-800"} aria-label="Portfolio heat">
      This buy takes open risk to {heat.after_pct.toFixed(1)}% of capital (limit {heat.limit_pct}%
      {heat.now_pct !== null ? `, now ${heat.now_pct.toFixed(1)}%` : ""}).
      {over && (heat.fits_quantity > 0 ? <> {heat.fits_quantity} shares would stay within it{onUse && <> <button type="button" className="underline" onClick={() => onUse(heat.fits_quantity)}>Use {heat.fits_quantity}</button></>}.</> : " No size fits within it.")}
    </span>
  )
}
