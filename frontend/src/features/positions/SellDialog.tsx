import { X } from "lucide-react"
import { useState } from "react"
import { createPortal } from "react-dom"

import { Button, Input } from "../../components/ui"
import { nptToday } from "../../lib/marketHours"
import { apiErrorMessage } from "../watchlist/api"
import { useSellPosition } from "./api"
import type { Position } from "./types"

const money = (value: number) => value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })

// Records a sell made on TMS. Selling every share closes the position.
export function SellDialog({ position, onClose }: { position: Position; onClose: () => void }) {
  const [price, setPrice] = useState(String(position.last_price))
  const [quantity, setQuantity] = useState(String(position.quantity))
  const [date, setDate] = useState(nptToday())
  const sell = useSellPosition()
  const shares = Number(quantity)
  const valid = Number(price) > 0 && Number.isInteger(shares) && shares > 0 && shares <= position.quantity
  const settled = position.settled_quantity
  const unsettled = settled !== undefined && date === nptToday() && shares > settled

  return createPortal(
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-ink/40 p-0 sm:items-center sm:p-4" onClick={onClose}>
      <div role="dialog" aria-modal="true" aria-labelledby="sell-title"
        className="max-h-[92vh] w-full max-w-lg overflow-y-auto rounded-t-2xl bg-white p-5 shadow-xl sm:rounded-2xl" onClick={(event) => event.stopPropagation()}>
        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 id="sell-title" className="font-display text-lg font-bold text-ink">Record a sell of {position.symbol}</h2>
            <p className="text-sm text-slate">What you sold on TMS. Selling all {position.quantity} shares closes the position.</p>
          </div>
          <button type="button" aria-label="Close" onClick={onClose} className="rounded-lg p-2 text-slate hover:bg-slate/10"><X className="h-4 w-4" /></button>
        </div>

        {sell.isSuccess ? (
          <div className="mt-5 rounded-xl border border-pine/30 bg-pine/10 p-4 text-sm text-ink">
            <p className="font-semibold">
              Recorded: sold {shares} at {money(Number(price))}.{" "}
              {sell.data.status === "closed" ? "The position is closed: review it under Closed." : `${sell.data.quantity} shares left.`}
            </p>
            {sell.data.realized && (
              <p className="mt-1 text-slate">
                Realized so far: Rs {money(sell.data.realized.gain)} after fees, Rs {money(sell.data.realized.tax)} capital gains tax, Rs {money(sell.data.realized.net)} net.
              </p>
            )}
            {sell.data.warning && <p className="mt-1 text-amber-800">{sell.data.warning}.</p>}
            <Button className="mt-3" size="sm" variant="outline" onClick={onClose}>Close</Button>
          </div>
        ) : (
          <>
            <div className="mt-4 grid gap-3 sm:grid-cols-3">
              <label className="text-xs font-semibold text-slate">
                Price (Rs)
                <Input className="mt-1" type="number" inputMode="decimal" min="0" step="0.1" value={price} onChange={(event) => setPrice(event.target.value)} />
              </label>
              <label className="text-xs font-semibold text-slate">
                Quantity (of {position.quantity})
                <Input className="mt-1" type="number" inputMode="numeric" min="1" max={position.quantity} step="1" value={quantity} onChange={(event) => setQuantity(event.target.value)} />
              </label>
              <label className="text-xs font-semibold text-slate">
                Date
                <Input className="mt-1" type="date" value={date} max={nptToday()} onChange={(event) => setDate(event.target.value)} />
              </label>
            </div>
            {unsettled && (
              <p className="mt-3 text-xs text-amber-800">Only {settled} shares have settled (T+2) today; it will be recorded with a note.</p>
            )}
            <p className="mt-3 text-xs text-slate">Capital gains tax is worked out first-in, first-out: 10% on lots held up to a year, 7.5% beyond, on the net gain.</p>
            {sell.isError && <p role="alert" className="mt-2 text-sm text-ember">{apiErrorMessage(sell.error)}</p>}
            <div className="mt-4 flex justify-end gap-2">
              <Button variant="outline" onClick={onClose}>Cancel</Button>
              <Button disabled={!valid || sell.isPending} onClick={() => sell.mutate({ id: position.id, price: Number(price), quantity: shares, traded_on: date })}>
                {sell.isPending ? "Recording…" : "Record sell"}
              </Button>
            </div>
          </>
        )}
      </div>
    </div>,
    document.body,
  )
}
