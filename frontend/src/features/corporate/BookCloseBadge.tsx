import { cn } from "../../lib/cn"
import { bookCloseText } from "./format"
import type { BookClose } from "./types"

// Amber when a bonus will adjust the price; neutral for cash-only book closes.
export function BookCloseBadge({ bookClose, className }: { bookClose: BookClose; className?: string }) {
  const bonus = Boolean(bookClose.bonus_percent)
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold",
        bonus ? "bg-amber-100 text-amber-800" : "bg-slate/10 text-slate",
        className,
      )}
      title={bonus ? "The price will be adjusted for the bonus on the book close." : undefined}
    >
      {bookCloseText(bookClose)}
    </span>
  )
}
