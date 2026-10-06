import { cn } from "../../lib/cn"
import type { Signals } from "../screener/types"

const pill = "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold"
const neutral = "bg-slate/10 text-slate"
const warn = "bg-amber-100 text-amber-800"

// Base count and volume signatures from the nightly snapshot (Setups::Signals).
export function SignalBadges({ signals, className }: { signals?: Signals | null; className?: string }) {
  if (!signals) return null
  const flags = signals.flags ?? []
  const badges: Array<{ key: string; text: string; title: string; warning?: boolean }> = []

  if (signals.base_number) {
    const late = flags.includes("late_stage_base")
    badges.push({
      key: "base", warning: late,
      text: `Base ${signals.base_number}${signals.base_partial ? "+" : ""}${late ? " · late stage" : ""}`,
      title: `${signals.in_base ? "Current" : "Latest"} base since the stock's low${signals.base_partial ? " (earlier bases may predate the price history)" : ""}. Later bases fail more often.`,
    })
  }
  if (signals.pocket_pivot_age != null) {
    badges.push({ key: "pp", text: signals.pocket_pivot_age === 0 ? "Pocket pivot" : `Pocket pivot ${signals.pocket_pivot_age}d ago`,
      title: "An up day on more volume than any down day in the 10 before, near the 10-day or 50-day average. Shown for information; it didn't separate results in the backtest." })
  }
  if (signals.up_down_ratio != null && (flags.includes("strong_up_down") || flags.includes("weak_up_down"))) {
    badges.push({ key: "ud", text: `U/D vol ${signals.up_down_ratio}`,
      title: "Volume on up days ÷ volume on down days over 50 sessions: 1.2+ suggests buying, under 0.8 selling. Information only." })
  }
  if (flags.includes("dry_up")) {
    badges.push({ key: "dry", text: "Volume dry-up",
      title: `${signals.dry_up_days} of the last 10 sessions traded under half the 50-day average volume. Information only.` })
  }

  return (
    <>
      {badges.map((badge) => (
        <span key={badge.key} className={cn(pill, badge.warning ? warn : neutral, className)} title={badge.title}>{badge.text}</span>
      ))}
    </>
  )
}
