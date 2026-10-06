import { Pencil, Plus, Trash2 } from "lucide-react"
import { useState } from "react"
import { Link } from "react-router-dom"

import { Badge, Button, Card, Input, LoadingSpinner, Textarea } from "../components/ui"
import { usePortfolio, usePositions, useRemoveFill, useUpdatePosition } from "../features/positions/api"
import { BuyDialog } from "../features/positions/BuyDialog"
import { HeatCard, SectorCard } from "../features/positions/PortfolioCards"
import { PositionAlertsPanel } from "../features/positions/PositionAlertsPanel"
import { useTradingSettings } from "../features/sizing/api"
import type { Position } from "../features/positions/types"
import { apiErrorMessage } from "../features/watchlist/api"
import { SETUP_LABELS } from "../features/watchlist/labels"
import { nptToday } from "../lib/marketHours"
import { cn } from "../lib/cn"

const money = (value: number) => value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const signed = (value: number, suffix = "") => `${value > 0 ? "+" : ""}${money(value)}${suffix}`
const tone = (value: number | null) => (value === null || value === 0 ? "text-slate" : value > 0 ? "text-pine" : "text-ember")

function Stat({ label, value, className }: { label: string; value: string; className?: string }) {
  return (
    <div className="rounded-xl bg-slate/5 px-4 py-3">
      <p className="text-xs text-slate">{label}</p>
      <p className={cn("font-display text-xl font-bold text-ink", className)}>{value}</p>
    </div>
  )
}

function PlanEditor({ position, onDone }: { position: Position; onDone: () => void }) {
  const [stop, setStop] = useState(String(position.stop_price))
  const [target, setTarget] = useState(position.target_price === null ? "" : String(position.target_price))
  const [notes, setNotes] = useState(position.notes ?? "")
  const update = useUpdatePosition()
  const save = () =>
    update.mutate(
      { id: position.id, stop_price: Number(stop), target_price: target === "" ? null : Number(target), notes },
      { onSuccess: onDone },
    )

  return (
    <div className="mt-3 space-y-2">
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="text-xs font-semibold text-slate">
          Stop (Rs)
          <Input className="mt-1" type="number" step="0.1" value={stop} onChange={(event) => setStop(event.target.value)} />
        </label>
        <label className="text-xs font-semibold text-slate">
          Target (Rs)
          <Input className="mt-1" type="number" step="0.1" value={target} onChange={(event) => setTarget(event.target.value)} />
        </label>
      </div>
      <label className="block text-xs font-semibold text-slate">
        Notes
        <Textarea className="mt-1" rows={2} value={notes} onChange={(event) => setNotes(event.target.value)} />
      </label>
      {update.isError && <p role="alert" className="text-sm text-ember">{apiErrorMessage(update.error)}</p>}
      <div className="flex gap-2">
        <Button size="sm" onClick={save} disabled={update.isPending || !(Number(stop) > 0)}>{update.isPending ? "Saving…" : "Save plan"}</Button>
        <Button size="sm" variant="outline" onClick={onDone}>Cancel</Button>
      </div>
    </div>
  )
}

function PositionCard({ position }: { position: Position }) {
  const [editing, setEditing] = useState(false)
  const [adding, setAdding] = useState(false)
  const [showFills, setShowFills] = useState(false)
  const removeFill = useRemoveFill()
  const toStop = ((position.stop_price / position.last_price - 1) * 100)
  const toTarget = position.target_price ? ((position.target_price / position.last_price - 1) * 100) : null
  const sellableLater = position.sellable_on !== null && position.sellable_on > nptToday()

  return (
    <article aria-label={`${position.symbol} position`}>
      <Card className="p-4">
        <div className="flex flex-wrap items-start justify-between gap-2">
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2">
              <Link to={`/screener/${encodeURIComponent(position.symbol)}`} className="font-display text-lg font-bold text-ink hover:underline">{position.symbol}</Link>
              {position.setup_type && <span className="text-xs font-semibold text-slate">{SETUP_LABELS[position.setup_type]}</span>}
              {sellableLater && <Badge tone="neutral">Sellable from {position.sellable_on}</Badge>}
            </div>
            <p className="truncate text-xs text-slate">{position.name} · {position.quantity} shares at {money(position.average_price)} · held {position.days_held} {position.days_held === 1 ? "day" : "days"}</p>
          </div>
          <div className="text-right">
            <p className="font-mono text-lg font-bold text-ink">{money(position.last_price)}</p>
            <p className={cn("text-xs font-semibold", tone(position.unrealized_pnl))}>
              {signed(position.unrealized_pnl)} ({position.unrealized_pct === null ? "—" : signed(position.unrealized_pct, "%")})
            </p>
          </div>
        </div>

        {editing ? (
          <PlanEditor position={position} onDone={() => setEditing(false)} />
        ) : (
          <dl className="mt-3 grid grid-cols-2 gap-x-4 gap-y-2 text-sm sm:grid-cols-5">
            <div><dt className="text-xs text-slate">R multiple</dt><dd className={cn("font-mono font-semibold", tone(position.r_multiple))}>{position.r_multiple === null ? "—" : `${position.r_multiple > 0 ? "+" : ""}${position.r_multiple}R`}</dd></div>
            <div><dt className="text-xs text-slate">Stop</dt><dd className="font-mono font-semibold text-ember">{money(position.stop_price)} <span className="text-xs text-slate">({signed(toStop, "%")})</span></dd></div>
            <div><dt className="text-xs text-slate">Target</dt><dd className="font-mono font-semibold text-pine">{position.target_price ? <>{money(position.target_price)} <span className="text-xs text-slate">({signed(toTarget as number, "%")})</span></> : "—"}</dd></div>
            <div><dt className="text-xs text-slate">Risk at stop</dt><dd className="font-mono font-semibold text-ink">Rs {money(position.open_risk)}</dd></div>
            <div><dt className="text-xs text-slate">Opened</dt><dd className="font-mono font-semibold text-ink">{position.opened_on ?? "—"}</dd></div>
            <div><dt className="text-xs text-slate">Cost incl. fees</dt><dd className="font-mono font-semibold text-ink">Rs {money(position.cost_basis)}</dd></div>
            <div><dt className="text-xs text-slate">Net if sold now</dt><dd className={cn("font-mono font-semibold", tone(position.net_pnl_if_sold))}>Rs {signed(position.net_pnl_if_sold)}</dd></div>
            <div><dt className="text-xs text-slate">Break-even</dt><dd className="font-mono font-semibold text-ink">{position.break_even_price === null ? "—" : money(position.break_even_price)}</dd></div>
          </dl>
        )}
        {!editing && position.notes && <p className="mt-2 text-sm text-ink">{position.notes}</p>}
        {position.latest_alert && (
          <p className={cn("mt-2 rounded-lg px-3 py-1.5 text-xs", position.latest_alert.read ? "bg-slate/5 text-slate" : "bg-amber-50 font-semibold text-amber-900")} aria-label="Latest alert">
            {position.latest_alert.message}
          </p>
        )}

        {showFills && (
          <ul className="mt-3 divide-y divide-slate/10 rounded-lg border border-slate/15 text-sm" aria-label={`${position.symbol} fills`}>
            {position.fills.map((fill) => (
              <li key={fill.id} className="flex items-center justify-between gap-2 px-3 py-1.5">
                <span className="text-ink">{fill.traded_on} · {fill.side === "buy" ? "Bought" : "Sold"} {fill.quantity} at {money(fill.price)}</span>
                <button
                  type="button"
                  aria-label={`Remove fill from ${fill.traded_on}`}
                  className="rounded p-1 text-ember hover:bg-ember/10"
                  onClick={() => window.confirm(position.fills.length === 1 ? `Remove this buy? ${position.symbol}'s position will be removed and it goes back to your watchlist.` : "Remove this fill?") && removeFill.mutate({ positionId: position.id, fillId: fill.id })}
                >
                  <Trash2 className="h-3.5 w-3.5" />
                </button>
              </li>
            ))}
          </ul>
        )}

        {!editing && (
          <div className="mt-3 flex flex-wrap gap-2">
            <Button size="sm" variant="outline" onClick={() => setEditing(true)} className="inline-flex items-center gap-1.5"><Pencil className="h-3.5 w-3.5" /> Edit stop / target</Button>
            <Button size="sm" variant="outline" onClick={() => setAdding(true)} className="inline-flex items-center gap-1.5"><Plus className="h-3.5 w-3.5" /> Add a buy</Button>
            <Button size="sm" variant="ghost" onClick={() => setShowFills((open) => !open)}>{showFills ? "Hide fills" : `Fills (${position.fills.length})`}</Button>
          </div>
        )}
      </Card>
      {adding && (
        <BuyDialog symbol={position.symbol} currentPrice={position.last_price} existingStop={position.stop_price} target={position.target_price} onClose={() => setAdding(false)} />
      )}
    </article>
  )
}

export function PositionsPage() {
  const { data, isLoading, isError, refetch } = usePositions("open")
  const portfolio = usePortfolio().data
  const sectorLimit = useTradingSettings().data?.max_sector_pct ?? 30

  if (isLoading) return <div className="flex h-[50vh] items-center justify-center"><LoadingSpinner size="lg" /></div>
  if (isError || !data) {
    return (
      <Card className="p-8 text-center">
        <p className="font-display text-lg font-bold text-ink">Couldn't load your positions</p>
        <Button className="mt-4" variant="outline" onClick={() => void refetch()}>Retry</Button>
      </Card>
    )
  }

  const value = data.reduce((sum, position) => sum + position.last_price * position.quantity, 0)
  const net = data.reduce((sum, position) => sum + position.net_pnl_if_sold, 0)
  const risk = data.reduce((sum, position) => sum + position.open_risk, 0)

  return (
    <div className="space-y-6">
      <header>
        <h1 className="font-display text-2xl font-bold tracking-tight text-ink sm:text-3xl">Positions</h1>
        <p className="mt-1 text-sm text-slate">Stocks you've bought, tracked against your stop and target. Prices update every few minutes during market hours.</p>
      </header>

      {data.length === 0 ? (
        <Card className="p-10 text-center">
          <p className="font-semibold text-ink">No open positions.</p>
          <p className="mt-1 text-sm text-slate">
            After you buy on TMS, use <b>Mark as bought</b> on the stock's <Link to="/watchlist" className="font-semibold text-ink underline">watchlist</Link> card.
          </p>
        </Card>
      ) : (
        <>
          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            <Stat label="Open positions" value={String(data.length)} />
            <Stat label="Market value" value={`Rs ${money(value)}`} />
            <Stat label="Net if all sold now" value={`Rs ${signed(net)}`} className={tone(net)} />
            <Stat label="Risk if every stop is hit" value={`Rs ${money(risk)}`} />
          </div>
          {portfolio && (
            <div className="grid gap-4 lg:grid-cols-2">
              <HeatCard portfolio={portfolio} />
              <SectorCard portfolio={portfolio} limit={sectorLimit} />
            </div>
          )}
          <PositionAlertsPanel />
          <div className="grid gap-4 xl:grid-cols-2">
            {data.map((position) => <PositionCard key={position.id} position={position} />)}
          </div>
        </>
      )}
      <p className="text-xs text-slate">
        The P&L next to each price is before fees. "Net if sold now", "Risk at stop" and break-even include NEPSE commission, the SEBON fee and the Rs 25 DP charge;
        capital gains tax is counted when you close a position. Rule checks, not recommendations.
      </p>
    </div>
  )
}
