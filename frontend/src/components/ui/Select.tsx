import type { SelectHTMLAttributes } from "react"
import { cn } from "../../lib/cn"

export function Select({ className, ...props }: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      className={cn(
        "h-11 w-full rounded-xl border border-mist bg-white px-3 text-sm text-ink focus:border-ink/35 focus:outline-none",
        className,
      )}
      {...props}
    />
  )
}
