import type { ButtonHTMLAttributes, ReactNode } from "react"
import { cn } from "../../lib/cn"

type Variant = "primary" | "secondary" | "ghost" | "outline"
type Size = "sm" | "md"

export function Button({
  children,
  className,
  variant = "primary",
  size = "md",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { children: ReactNode; variant?: Variant; size?: Size }) {
  return (
    <button
      className={cn(
        "rounded-xl font-bold transition duration-300 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ink/30",
        size === "md" && "min-h-[44px] px-4 py-2.5 text-sm",
        size === "sm" && "min-h-[36px] px-3 py-1.5 text-xs",
        variant === "primary" && "bg-ink text-white hover:-translate-y-0.5 hover:bg-ink/90",
        variant === "secondary" && "bg-white text-ink shadow-panel hover:-translate-y-0.5",
        variant === "ghost" && "bg-transparent text-slate hover:bg-slate/10",
        variant === "outline" && "border border-mist/80 bg-white text-ink hover:bg-slate/10",
        className,
      )}
      {...props}
    >
      {children}
    </button>
  )
}
