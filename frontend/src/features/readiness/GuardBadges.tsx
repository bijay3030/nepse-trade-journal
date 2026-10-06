import { cn } from "../../lib/cn"
import type { Guard } from "../screener/types"
import { GUARD_DETAILS, GUARD_LABELS } from "./labels"

// Amber for thin volume, red for a stock at either daily limit.
export function GuardBadges({ guards, className }: { guards?: Guard[] | null; className?: string }) {
  // "Extended" and the late-stage base have their own badges with the figures.
  const shown = guards?.filter((guard) => guard !== "extended" && guard !== "late_stage_base") ?? []
  if (!shown.length) return null
  return (
    <>
      {shown.map((guard) => (
        <span
          key={guard}
          className={cn(
            "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold",
            guard === "thin_volume" ? "bg-amber-100 text-amber-800" : "bg-ember/10 text-ember",
            className,
          )}
          title={GUARD_DETAILS[guard]}
        >
          {GUARD_LABELS[guard]}
        </span>
      ))}
    </>
  )
}
