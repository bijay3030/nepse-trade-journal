import type { ReactNode } from "react"
import { cn } from "../../lib/cn"

type Tone = "neutral" | "gain" | "loss"
type Variant = "neutral" | "profit" | "loss" | "outline" | "secondary"

export function Badge({
  children,
  tone = "neutral",
  variant,
  className,
}: {
  children: ReactNode
  tone?: Tone
  variant?: Variant
  className?: string
}) {
  const resolvedTone: Tone =
    variant === "profit" ? "gain" : variant === "loss" ? "loss" : (variant === "outline" || variant === "secondary" || variant === "neutral" ? "neutral" : tone)

  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold tracking-wide",
        resolvedTone === "neutral" && "bg-slate/10 text-slate",
        resolvedTone === "gain" && "bg-pine/15 text-pine",
        resolvedTone === "loss" && "bg-ember/15 text-ember",
        className,
      )}
    >
      {children}
    </span>
  )
}
