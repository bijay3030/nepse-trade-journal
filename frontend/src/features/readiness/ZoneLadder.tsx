import { cn } from "../../lib/cn"
import type { ZoneState } from "../screener/types"
import { ZONE_LABELS } from "./labels"

const STEPS: Array<{ state: ZoneState; active: string }> = [
  { state: "too_early", active: "bg-slate/15 text-ink ring-2 ring-slate/40" },
  { state: "in_zone", active: "bg-pine/15 text-pine ring-2 ring-pine/50" },
  { state: "extended", active: "bg-amber-100 text-amber-800 ring-2 ring-amber-400" },
  { state: "failed", active: "bg-ember/15 text-ember ring-2 ring-ember/50" },
]

// Four-step strip highlighting where the price sits against the entry zone.
export function ZoneLadder({ state }: { state: ZoneState }) {
  return (
    <ol className="grid grid-cols-4 gap-1.5 text-center text-xs font-semibold" aria-label={`Zone: ${ZONE_LABELS[state]}`}>
      {STEPS.map((step) => (
        <li
          key={step.state}
          aria-current={step.state === state ? "step" : undefined}
          className={cn("rounded-lg px-2 py-1.5", step.state === state ? step.active : "bg-slate/5 text-slate/70")}
        >
          {ZONE_LABELS[step.state]}
        </li>
      ))}
    </ol>
  )
}
