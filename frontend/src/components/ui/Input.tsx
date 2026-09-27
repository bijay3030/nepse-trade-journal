import type { InputHTMLAttributes } from "react"
import { cn } from "../../lib/cn"

export function Input({ className, ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={cn(
        "h-11 w-full rounded-xl border border-mist bg-white px-3 text-sm text-ink placeholder:text-slate/60 focus:border-ink/35 focus:outline-none",
        className,
      )}
      {...props}
    />
  )
}
