import type { CautiousSize as Cautious } from "./types"

// Outside an uptrend: a smaller size at a share of the usual risk, for the trader to weigh.
export function CautiousSize({ cautious, onUse }: { cautious?: Cautious; onUse?: (quantity: number) => void }) {
  if (!cautious) return null
  return (
    <span className="block text-xs text-amber-800" aria-label="Cautious size">
      Market {cautious.label.toLowerCase()}: a cautious size at {Math.round(cautious.size_factor * 100)}% of your risk would be{" "}
      <b>{cautious.quantity} shares</b>
      {onUse && cautious.quantity > 0 && (
        <>
          {" "}
          <button type="button" className="font-semibold underline" onClick={() => onUse(cautious.quantity)}>Use {cautious.quantity}</button>
        </>
      )}
    </span>
  )
}
