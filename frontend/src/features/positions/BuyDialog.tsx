import { X } from "lucide-react"
import { useEffect, useState } from "react"
import { createPortal } from "react-dom"
import { Link } from "react-router-dom"

import { Button, Input } from "../../components/ui"
import { nptToday } from "../../lib/marketHours"
import { apiErrorMessage } from "../watchlist/api"
import { formatPrice } from "../watchlist/labels"
import { useRecordBuy } from "./api"
import { MAX_STOP_PCT, defaultStop } from "./rules"

type Props = {
  symbol: string
  currentPrice: number
  /** Opening a position from a watchlist setup. */
  watchlistItemId?: number
  setupStop?: number | null
  target?: number | null
  /** Adding to an open position: its stop is kept. */
  existingStop?: number
  onClose: () => void
}

const money = (value: number) => value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })

// Records a buy made on TMS: price, quantity and date.
export function BuyDialog({ symbol, currentPrice, watchlistItemId, setupStop, target, existingStop, onClose }: Props) {
  const [price, setPrice] = useState(currentPrice > 0 ? String(currentPrice) : "")
  const [quantity, setQuantity] = useState("")
  const [date, setDate] = useState(nptToday())
  const buy = useRecordBuy()

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => event.key === "Escape" && onClose()
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  }, [onClose])

  const entry = Number(price)
  const shares = Number(quantity)
  const valid = entry > 0 && Number.isInteger(shares) && shares > 0 && Boolean(date)
  const stop = existingStop ?? (entry > 0 ? defaultStop(entry, setupStop) : null)
  const capped = existingStop === undefined && stop !== null && setupStop != null && stop > setupStop
  const risk = stop !== null && entry > stop ? entry - stop : null
  const reward = target && risk ? (target - entry) / risk : null
  const adding = existingStop !== undefined

  const submit = () => buy.mutate({ watchlist_item_id: watchlistItemId, symbol: watchlistItemId ? undefined : symbol, price: entry, quantity: shares, traded_on: date })

  return createPortal(
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-ink/40 p-0 sm:items-center sm:p-4" onClick={onClose}>
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="buy-title"
        className="max-h-[92vh] w-full max-w-lg overflow-y-auto rounded-t-2xl bg-white p-5 shadow-xl sm:rounded-2xl"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 id="buy-title" className="font-display text-lg font-bold text-ink">{adding ? `Add a buy to ${symbol}` : `Mark ${symbol} as bought`}</h2>
            <p className="text-sm text-slate">Record what you bought on TMS. The app then tracks it against your stop and target.</p>
          </div>
          <button type="button" aria-label="Close" onClick={onClose} className="rounded-lg p-2 text-slate hover:bg-slate/10">
            <X className="h-4 w-4" />
          </button>
        </div>

        {buy.isSuccess ? (
          <div className="mt-5 rounded-xl border border-pine/30 bg-pine/10 p-4 text-sm text-ink">
            <p className="font-semibold">
              Recorded: {shares} {symbol} at {money(entry)}. Position now {buy.data.quantity} shares at an average {money(buy.data.average_price)}.
            </p>
            <p className="mt-1 text-slate">Stop {formatPrice(buy.data.stop_price)}{buy.data.target_price ? ` · target ${formatPrice(buy.data.target_price)}` : ""} · sellable from {buy.data.sellable_on ?? "—"} (T+2).</p>
            <div className="mt-3 flex gap-2">
              <Link to="/positions" className="rounded-lg bg-ink px-3 py-1.5 text-xs font-bold text-white">View positions</Link>
              <Button size="sm" variant="outline" onClick={onClose}>Close</Button>
            </div>
          </div>
        ) : (
          <>
            <div className="mt-4 grid gap-3 sm:grid-cols-3">
              <label className="text-xs font-semibold text-slate">
                Price (Rs)
                <Input className="mt-1" type="number" inputMode="decimal" min="0" step="0.1" value={price} onChange={(event) => setPrice(event.target.value)} />
              </label>
              <label className="text-xs font-semibold text-slate">
                Quantity (shares)
                <Input className="mt-1" type="number" inputMode="numeric" min="1" step="1" value={quantity} onChange={(event) => setQuantity(event.target.value)} autoFocus />
              </label>
              <label className="text-xs font-semibold text-slate">
                Date
                <Input className="mt-1" type="date" value={date} max={nptToday()} onChange={(event) => setDate(event.target.value)} />
              </label>
            </div>

            <dl className="mt-4 grid grid-cols-2 gap-x-4 gap-y-2 rounded-xl bg-slate/5 p-3 text-sm sm:grid-cols-4">
              <div><dt className="text-xs text-slate">Stop</dt><dd className="font-mono font-semibold text-ember">{stop === null ? "—" : money(stop)}</dd></div>
              <div><dt className="text-xs text-slate">Target</dt><dd className="font-mono font-semibold text-pine">{target ? money(target) : "—"}</dd></div>
              <div><dt className="text-xs text-slate">Risk / share</dt><dd className="font-mono font-semibold text-ink">{risk === null ? "—" : money(risk)}</dd></div>
              <div><dt className="text-xs text-slate">Reward:risk</dt><dd className="font-mono font-semibold text-ink">{reward === null ? "—" : `${reward.toFixed(2)}R`}</dd></div>
            </dl>
            <p className="mt-2 text-xs text-slate">
              {adding ? "Your position's stop is kept." : capped ? `The setup's stop is more than ${MAX_STOP_PCT}% below this price, so the stop is set ${MAX_STOP_PCT}% below it.` : "Stop and target come from the setup."}
              {valid && risk !== null && <> If the stop is hit, this buy loses about <b className="text-ink">Rs {money(risk * shares)}</b> before fees.</>}{" "}
              You can change them later on the Positions page.
            </p>

            {buy.isError && <p role="alert" className="mt-3 text-sm text-ember">{apiErrorMessage(buy.error)}</p>}
            <div className="mt-4 flex gap-2">
              <Button onClick={submit} disabled={!valid || buy.isPending}>{buy.isPending ? "Saving…" : "Record buy"}</Button>
              <Button variant="outline" onClick={onClose}>Cancel</Button>
            </div>
          </>
        )}
      </div>
    </div>,
    document.body,
  )
}
