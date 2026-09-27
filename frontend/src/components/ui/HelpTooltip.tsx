import { Info } from "lucide-react"
import { useState } from "react"

type HelpTooltipProps = {
  text: string
  link?: string
}

export function HelpTooltip({ text, link }: HelpTooltipProps) {
  const [open, setOpen] = useState(false)

  return (
    <span className="relative inline-flex items-center">
      <button
        type="button"
        className="inline-flex h-5 w-5 items-center justify-center rounded-full text-slate transition hover:bg-slate/10"
        onMouseEnter={() => setOpen(true)}
        onMouseLeave={() => setOpen(false)}
        onFocus={() => setOpen(true)}
        onBlur={() => setOpen(false)}
        aria-label="Help"
      >
        <Info className="h-3.5 w-3.5" />
      </button>

      {open ? (
        <span className="absolute left-6 top-0 z-40 w-64 rounded-lg border border-mist/70 bg-white p-2 text-xs text-slate shadow-panel">
          {text}
          {link ? (
            <a href={link} className="ml-1 font-semibold text-ink underline">
              Learn more
            </a>
          ) : null}
        </span>
      ) : null}
    </span>
  )
}
