import { Bell, BellOff } from "lucide-react"
import { Link } from "react-router-dom"

import { Button } from "../../components/ui"
import { useSaveScannerAlert, useScannerAlert } from "./api"
import { SIGNAL_BY_KEY } from "./signals"
import type { CrossoverSignal } from "./types"

const same = (a: CrossoverSignal[], b: CrossoverSignal[]) => a.length === b.length && a.every((key) => b.includes(key))
const names = (signals: CrossoverSignal[]) => signals.map((key) => SIGNAL_BY_KEY[key].short).join(" + ")

// Save the ticked signals as the filter Telegram messages are sent for (after each close).
export function TelegramAlertControl({ selected }: { selected: CrossoverSignal[] }) {
  const { data } = useScannerAlert()
  const save = useSaveScannerAlert()
  if (!data) return null

  if (!data.telegram_linked) {
    return (
      <span className="text-xs text-slate">
        <Link to="/settings" className="font-semibold text-ink underline">Connect Telegram</Link> to get this filter's new matches after each close.
      </span>
    )
  }

  const saved = data.signals
  const current = saved.length > 0 && same(saved, selected)
  return (
    <span className="flex flex-wrap items-center gap-2 text-xs" aria-label="Telegram alerts">
      {current ? (
        <span className="inline-flex items-center gap-1 font-semibold text-pine"><Bell className="h-3.5 w-3.5" /> Telegram alerts on for this filter</span>
      ) : saved.length > 0 ? (
        <span className="text-slate">Telegram alerts on for: <b className="text-ink">{names(saved)}</b></span>
      ) : null}
      {!current && selected.length > 0 && (
        <Button size="sm" variant="outline" disabled={save.isPending} onClick={() => save.mutate(selected)} className="inline-flex items-center gap-1.5">
          <Bell className="h-3.5 w-3.5" /> {saved.length > 0 ? "Alert me for this filter instead" : "Alert me on Telegram"}
        </Button>
      )}
      {saved.length > 0 && (
        <Button size="sm" variant="ghost" disabled={save.isPending} onClick={() => save.mutate([])} className="inline-flex items-center gap-1.5">
          <BellOff className="h-3.5 w-3.5" /> Stop alerts
        </Button>
      )}
      {save.isError && <span className="text-ember">Couldn't save.</span>}
    </span>
  )
}
