import type { ReactNode } from "react"
import type { LucideIcon } from "lucide-react"
import { Card } from "./Card"
import { Badge } from "./Badge"
import { HelpTooltip } from "./HelpTooltip"
import { cn } from "../../lib/cn"

type StatCardProps = {
  label?: string
  title?: string
  value: ReactNode
  change?: string
  changeType?: "positive" | "negative" | "neutral"
  positive?: boolean
  icon?: LucideIcon
  helpText?: string
  helpLink?: string
}

export function StatCard({ label, title, value, change, changeType, positive, icon: Icon, helpText, helpLink }: StatCardProps) {
  const heading = title ?? label ?? ""
  const tone =
    changeType === "positive"
      ? "gain"
      : changeType === "negative"
        ? "loss"
        : changeType === "neutral"
          ? "neutral"
          : positive === false
            ? "loss"
            : "gain"

  return (
    <Card className="animate-rise">
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-1">
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate/75">{heading}</p>
          {helpText ? <HelpTooltip text={helpText} link={helpLink} /> : null}
        </div>
        {Icon ? (
          <span className="inline-flex h-8 w-8 items-center justify-center rounded-xl bg-slate/10 text-slate">
            <Icon className="h-4 w-4" />
          </span>
        ) : null}
      </div>
      <p className={cn("mt-3 font-display text-3xl font-extrabold text-ink", typeof value === "string" && "leading-none")}>
        {value}
      </p>
      {change ? (
        <div className="mt-3">
          <Badge tone={tone}>{change}</Badge>
        </div>
      ) : null}
    </Card>
  )
}
