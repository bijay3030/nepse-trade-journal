import type { TextareaHTMLAttributes } from "react"
import { cn } from "../../lib/cn"

export function Textarea({ className, ...props }: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return (
    <textarea
      className={cn(
        "min-h-24 w-full rounded-xl border border-mist bg-white px-3 py-2.5 text-sm text-ink placeholder:text-slate/60 focus:border-ink/35 focus:outline-none",
        className,
      )}
      {...props}
    />
  )
}
