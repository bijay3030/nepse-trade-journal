import { ArrowLeft } from "lucide-react"
import { useMemo, useState } from "react"
import { Link } from "react-router-dom"

import { Button, Card, Input, LoadingSpinner, Select, Textarea } from "../../components/ui"
import { apiErrorMessage, useCreatePlanFromSetup, useWatchlist } from "./api"
import { SETUP_LABELS, formatPrice } from "./labels"
import { positionSize } from "./sizing"
import type { WatchlistItem } from "./types"

const STRATEGIES = ["Turtle Breakout", "Support Bounce", "Sector Rotation", "Dividend Capture"]
const DEFAULT_STRATEGY = { vcp: "Turtle Breakout", pullback: "Support Bounce", ma_pullback: "Support Bounce", base_breakout: "Turtle Breakout", three_weeks_tight: "Turtle Breakout", undercut_rally: "Support Bounce" } as const

function PlanForm({ item, createPlan }: { item: WatchlistItem; createPlan: ReturnType<typeof useCreatePlanFromSetup> }) {
  const [entry, setEntry] = useState(String(item.entry_zone_low))
  const [stop, setStop] = useState(String(item.stop_loss_price ?? item.invalidation_price))
  const [target, setTarget] = useState(item.target_price === null ? "" : String(item.target_price))
  const [capital, setCapital] = useState("")
  const [riskPercent, setRiskPercent] = useState("1")
  const [quantity, setQuantity] = useState("")
  const [strategy, setStrategy] = useState<string>(DEFAULT_STRATEGY[item.setup_type])
  const [thesis, setThesis] = useState(
    `${SETUP_LABELS[item.setup_type]} on ${item.symbol}: buy ${formatPrice(item.entry_zone_low)}–${formatPrice(item.entry_zone_high)}, ` +
      `invalidated below ${formatPrice(item.invalidation_price)}.${item.notes ? ` ${item.notes}` : ""}`,
  )

  const suggestedQty = positionSize(Number(capital), Number(riskPercent), Number(entry), Number(stop))
  const rr = useMemo(() => {
    const e = Number(entry), s = Number(stop), t = Number(target)
    return e > s && t > e ? Math.round(((t - e) / (e - s)) * 100) / 100 : null
  }, [entry, stop, target])

  const field = "text-xs font-semibold text-slate"
  return (
    <Card className="p-5">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h2 className="font-display text-lg font-bold text-ink">Plan {item.symbol} from your setup</h2>
        <p className="text-sm text-slate">
          Now {formatPrice(item.current_price)} · zone {formatPrice(item.entry_zone_low)}–{formatPrice(item.entry_zone_high)}
        </p>
      </div>

      <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <label htmlFor="plan-entry" className={field}>Planned entry<Input id="plan-entry" type="number" step="0.01" className="mt-1 font-mono" value={entry} onChange={(e) => setEntry(e.target.value)} /></label>
        <label htmlFor="plan-stop" className={field}>Stop loss<Input id="plan-stop" type="number" step="0.01" className="mt-1 font-mono" value={stop} onChange={(e) => setStop(e.target.value)} /></label>
        <label htmlFor="plan-target" className={field}>Target<Input id="plan-target" type="number" step="0.01" className="mt-1 font-mono" value={target} onChange={(e) => setTarget(e.target.value)} /></label>
        <label htmlFor="plan-strategy" className={field}>Strategy
          <Select id="plan-strategy" className="mt-1" value={strategy} onChange={(e) => setStrategy(e.target.value)}>
            {STRATEGIES.map((name) => <option key={name}>{name}</option>)}
          </Select>
        </label>
      </div>
      <p className="mt-2 text-xs text-slate">Risk:reward <b className="text-ink">{rr === null ? "—" : `${rr}R`}</b></p>

      <fieldset className="mt-4 rounded-xl border border-mist p-3">
        <legend className="px-1 text-xs font-bold text-ink">Position size</legend>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
          <label htmlFor="plan-capital" className={field}>Account size (NPR)<Input id="plan-capital" type="number" min="0" className="mt-1 font-mono" value={capital} onChange={(e) => setCapital(e.target.value)} /></label>
          <label htmlFor="plan-risk" className={field}>Risk per trade (%)<Input id="plan-risk" type="number" min="0" step="0.1" className="mt-1 font-mono" value={riskPercent} onChange={(e) => setRiskPercent(e.target.value)} /></label>
          <label htmlFor="plan-qty" className={field}>Quantity
            <Input id="plan-qty" type="number" min="1" className="mt-1 font-mono" value={quantity} placeholder={suggestedQty ? String(suggestedQty) : ""} onChange={(e) => setQuantity(e.target.value)} />
          </label>
        </div>
        <p className="mt-2 text-xs text-slate">
          {suggestedQty !== null
            ? <>Risking {riskPercent}% of {Number(capital).toLocaleString()} suggests <b className="text-ink">{suggestedQty} shares</b> (about NPR {(suggestedQty * Number(entry)).toLocaleString(undefined, { maximumFractionDigits: 0 })}).</>
            : "Enter your account size to get a suggested quantity, or type one directly."}
        </p>
      </fieldset>

      <label htmlFor="plan-thesis" className={`${field} mt-4 block`}>Thesis
        <Textarea id="plan-thesis" rows={3} className="mt-1" value={thesis} onChange={(e) => setThesis(e.target.value)} />
      </label>

      {createPlan.isError && <p role="alert" className="mt-3 text-sm text-ember">{apiErrorMessage(createPlan.error)}</p>}

      <div className="mt-5 flex justify-end gap-2">
        <Link to="/watchlist" className="rounded-xl border border-mist/80 bg-white px-4 py-2.5 text-sm font-bold text-ink">Cancel</Link>
        <Button
          disabled={createPlan.isPending || !entry || !stop}
          onClick={() =>
            createPlan.mutate({
              id: item.id,
              planned_entry_price: Number(entry),
              stop_loss_price: Number(stop),
              target_price: target ? Number(target) : undefined,
              planned_quantity: Number(quantity) || suggestedQty || undefined,
              thesis,
              strategy,
            })
          }
        >
          {createPlan.isPending ? "Saving…" : "Save plan"}
        </Button>
      </div>
    </Card>
  )
}

export function PlanFromSetup({ itemId }: { itemId: number }) {
  const { data, isLoading, isError, error } = useWatchlist()
  const item = data?.find((candidate) => candidate.id === itemId)
  // Owned here so the confirmation survives the watchlist refetch that follows a save.
  const createPlan = useCreatePlanFromSetup()

  return (
    <div className="space-y-4">
      <Link to="/watchlist" className="inline-flex items-center gap-1 text-sm font-semibold text-slate hover:text-ink">
        <ArrowLeft className="h-4 w-4" /> Watchlist
      </Link>
      {createPlan.isSuccess ? (
        <Card className="p-6">
          <p className="font-display text-lg font-bold text-ink">
            Plan #{createPlan.data.trade_plan_id} saved for {createPlan.data.watchlist_item.symbol}
          </p>
          <p className="mt-1 text-sm text-slate">
            The watchlist item is now marked Planned. Alerts keep running so you'll still hear if it runs away or fails.
          </p>
          <div className="mt-4 flex gap-2">
            <Link to="/watchlist" className="rounded-xl bg-ink px-4 py-2 text-sm font-bold text-white">
              Back to watchlist
            </Link>
          </div>
        </Card>
      ) : isLoading ? (
        <div className="flex justify-center py-12"><LoadingSpinner /></div>
      ) : isError ? (
        <Card className="p-6 text-sm text-ember">{apiErrorMessage(error)}</Card>
      ) : !item ? (
        <Card className="p-6 text-sm text-slate">That watchlist item was not found. It may have been removed or archived.</Card>
      ) : item.trade_plan_id ? (
        <Card className="p-6 text-sm text-slate">A plan (#{item.trade_plan_id}) already exists for this setup.</Card>
      ) : (
        <PlanForm item={item} createPlan={createPlan} />
      )}
    </div>
  )
}
