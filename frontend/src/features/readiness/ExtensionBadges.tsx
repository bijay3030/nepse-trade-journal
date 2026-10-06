import { cn } from "../../lib/cn"
import type { Extension } from "../screener/types"

const pill = "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold"
const warn = "bg-amber-100 text-amber-800"

// Stretch and breakout-freshness badges from the nightly snapshot (Setups::Extension).
export function ExtensionBadges({ extension, className }: { extension?: Extension | null; className?: string }) {
  if (!extension) return null
  const flags = extension.flags ?? []
  const badges: Array<{ key: string; text: string; title: string; warning: boolean }> = []

  if (flags.includes("extended") && extension.extension_adr != null) {
    badges.push({ key: "extended", text: `Extended ${extension.extension_adr} ADR`, warning: true,
      title: "Far above the 50-day average for this stock's usual daily range; pullbacks are common from here." })
  }
  if (flags.includes("big_move") && extension.day_move_adr != null) {
    badges.push({ key: "big_move", text: `Big move ${extension.day_move_adr} ADR`, warning: true,
      title: "The session already moved more than this stock's average daily range: chasing it adds risk." })
  }
  if (extension.breakout_age != null) {
    const stale = flags.includes("stale_breakout")
    badges.push({ key: "age", text: stale ? `Stale breakout · day ${extension.breakout_age}` : `Breakout day ${extension.breakout_age}`, warning: stale,
      title: "Sessions since the price first closed above the pivot in this run (day 0 = the breakout day)." })
  }

  return (
    <>
      {badges.map((badge) => (
        <span key={badge.key} className={cn(pill, badge.warning ? warn : "bg-slate/10 text-slate", className)} title={badge.title}>
          {badge.text}
        </span>
      ))}
    </>
  )
}
