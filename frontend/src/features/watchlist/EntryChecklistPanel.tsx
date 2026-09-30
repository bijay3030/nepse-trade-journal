import { CheckCircle2, CircleDashed, MinusCircle, XCircle } from "lucide-react"

import { cn } from "../../lib/cn"
import type { CheckStatus, EntryChecklist } from "./types"

const ICONS: Record<CheckStatus, { Icon: typeof CheckCircle2; className: string; label: string }> = {
  pass: { Icon: CheckCircle2, className: "text-pine", label: "Met" },
  fail: { Icon: XCircle, className: "text-ember", label: "Not met" },
  pending: { Icon: CircleDashed, className: "text-slate", label: "Waiting" },
  "n/a": { Icon: MinusCircle, className: "text-slate/50", label: "Not applicable" },
}

export function EntryChecklistPanel({ checklist }: { checklist: EntryChecklist }) {
  return (
    <section aria-label="Entry checklist" className="mt-3 rounded-xl border border-mist/80 p-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h3 className="text-xs font-bold uppercase tracking-wide text-slate">Entry checklist</h3>
        <span
          className={cn(
            "rounded-full px-2.5 py-0.5 text-xs font-bold",
            checklist.all_passed ? "bg-pine/15 text-pine" : "bg-slate/10 text-slate",
          )}
        >
          {checklist.all_passed ? "All conditions met" : `${checklist.passed} of ${checklist.total} met`}
        </span>
      </div>
      <ul className="mt-2 space-y-1.5">
        {checklist.checks.map((check) => {
          const { Icon, className, label } = ICONS[check.status]
          return (
            <li key={check.key} className="flex items-start gap-2 text-sm">
              <Icon className={cn("mt-0.5 h-4 w-4 shrink-0", className)} aria-label={label} />
              <span className={cn("min-w-0", check.status === "n/a" && "text-slate/60")}>
                <span className="font-medium text-ink">{check.label}</span>
                {check.detail && <span className="block text-xs text-slate">{check.detail}</span>}
              </span>
            </li>
          )
        })}
      </ul>
      <p className="mt-2 text-[11px] text-slate">Rule checks on stored data, not a recommendation. Close and volume update after the 4 PM close.</p>
    </section>
  )
}
