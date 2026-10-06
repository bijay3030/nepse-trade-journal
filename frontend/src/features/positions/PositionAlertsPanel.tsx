import { BellRing } from "lucide-react"

import { Badge, Button, Card } from "../../components/ui"
import { cn } from "../../lib/cn"
import { useMarkPositionAlertsRead, usePositionAlerts, useUpdatePosition } from "./api"
import type { PositionAlert, PositionAlertKind } from "./types"

const POSITION_ALERT_LABELS: Record<PositionAlertKind, string> = {
  stop_hit: "Stop hit",
  target_reached: "Target reached",
  one_r: "Up 1R",
  profit_zone: "+20% zone",
  fifty_day_break: "50-day break",
  climax_run: "Climax run",
  time_stop: "Time stop",
}

const TONE: Record<PositionAlertKind, "neutral" | "gain" | "loss"> = {
  stop_hit: "loss",
  target_reached: "gain",
  one_r: "gain",
  profit_zone: "gain",
  fifty_day_break: "loss",
  climax_run: "neutral",
  time_stop: "neutral",
}

const ago = (iso: string) => {
  const minutes = Math.round((Date.now() - new Date(iso).getTime()) / 60_000)
  if (minutes < 60) return `${Math.max(minutes, 0)}m ago`
  const hours = Math.round(minutes / 60)
  return hours < 24 ? `${hours}h ago` : `${Math.round(hours / 24)}d ago`
}

// Sell-rule alerts for open positions. Nothing is changed for the user; +1R offers a button.
export function PositionAlertsPanel() {
  const { data } = usePositionAlerts()
  const markRead = useMarkPositionAlertsRead()
  const alerts = data?.alerts ?? []
  if (alerts.length === 0) return null

  return (
    <Card className="p-4" aria-label="Position alerts">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="flex items-center gap-2 font-display text-base font-bold text-ink">
          <BellRing className="h-4 w-4" /> Position alerts
          {data && data.unread_count > 0 && <span className="rounded-full bg-ember px-2 py-0.5 text-xs font-bold text-white">{data.unread_count} new</span>}
        </h2>
        {data && data.unread_count > 0 && (
          <Button size="sm" variant="ghost" onClick={() => markRead.mutate(undefined)} disabled={markRead.isPending}>Mark all read</Button>
        )}
      </div>
      <ul className="mt-3 divide-y divide-mist/60">
        {alerts.slice(0, 10).map((alert) => <AlertRow key={alert.id} alert={alert} />)}
      </ul>
    </Card>
  )
}

function AlertRow({ alert }: { alert: PositionAlert }) {
  const update = useUpdatePosition()
  const breakEven = alert.break_even_price
  const moved = breakEven !== null && alert.stop_price >= breakEven

  return (
    <li className={cn("flex flex-col gap-1 py-2.5 sm:flex-row sm:items-center sm:gap-3", !alert.read_at && "font-semibold")}>
      <div className="flex shrink-0 items-center gap-2">
        {!alert.read_at && <span className="h-2 w-2 rounded-full bg-ember" aria-label="Unread" />}
        <Badge tone={TONE[alert.kind]}>{POSITION_ALERT_LABELS[alert.kind]}</Badge>
      </div>
      <p className="min-w-0 flex-1 text-sm text-ink">{alert.message}</p>
      {breakEven !== null && !moved && (
        <Button size="sm" variant="outline" disabled={update.isPending || update.isSuccess}
          onClick={() => update.mutate({ id: alert.position_id, stop_price: breakEven })}>
          {update.isSuccess ? `Stop moved to ${breakEven.toFixed(2)}` : `Move stop to break-even (${breakEven.toFixed(2)})`}
        </Button>
      )}
      <span className="shrink-0 text-xs text-slate">{ago(alert.created_at)}</span>
    </li>
  )
}
