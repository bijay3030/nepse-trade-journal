import { Archive, Bell, BellOff, ClipboardList, Pencil, RotateCcw, Trash2 } from "lucide-react"
import { useState } from "react"
import { Link } from "react-router-dom"

import { Badge, Button, Card, LoadingSpinner, Textarea } from "../components/ui"
import {
  apiErrorMessage,
  useMarkAlertsRead,
  useRemoveWatchlistItem,
  useUpdateWatchlistItem,
  useWatchlist,
  useWatchlistAlerts,
} from "../features/watchlist/api"
import {
  ALERT_LABELS,
  ALERT_TONE,
  PRICE_STATE_LABELS,
  SETUP_LABELS,
  STATUS_LABELS,
  STATUS_TONE,
  formatPrice,
} from "../features/watchlist/labels"
import { LevelFields } from "../features/watchlist/LevelFields"
import { draftToLevels, levelsToDraft, type LevelDraft } from "../features/watchlist/levels"
import { BookCloseBadge } from "../features/corporate/BookCloseBadge"
import { EntryChecklistPanel } from "../features/watchlist/EntryChecklistPanel"
import { PriceLadder } from "../features/watchlist/PriceLadder"
import type { WatchlistItem } from "../features/watchlist/types"
import { cn } from "../lib/cn"

function timeAgo(iso: string) {
  const minutes = Math.round((Date.now() - new Date(iso).getTime()) / 60_000)
  if (minutes < 1) return "just now"
  if (minutes < 60) return `${minutes} min ago`
  const hours = Math.round(minutes / 60)
  if (hours < 24) return `${hours} hr ago`
  return new Date(iso).toLocaleDateString("en-US", { month: "short", day: "numeric" })
}

function zoneDistanceText(item: WatchlistItem) {
  if (item.price_state === "in_zone") return "Inside the entry zone"
  if (item.price_state === "extended") return `${Math.abs(((item.current_price - item.entry_zone_high) / item.entry_zone_high) * 100).toFixed(2)}% above the zone`
  if (item.price_state === "invalidated") return "At or below invalidation"
  return item.distance_to_zone_pct === null ? "—" : `${item.distance_to_zone_pct.toFixed(2)}% below the zone`
}

function AlertsPanel() {
  const { data, isLoading, isError } = useWatchlistAlerts()
  const markRead = useMarkAlertsRead()
  const alerts = data?.alerts ?? []

  return (
    <Card className="p-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="flex items-center gap-2 font-display text-base font-bold text-ink">
          <Bell className="h-4 w-4" /> Alerts
          {data && data.unread_count > 0 && (
            <span className="rounded-full bg-ember px-2 py-0.5 text-xs font-bold text-white">{data.unread_count} new</span>
          )}
        </h2>
        {data && data.unread_count > 0 && (
          <Button size="sm" variant="ghost" onClick={() => markRead.mutate(undefined)} disabled={markRead.isPending}>
            Mark all read
          </Button>
        )}
      </div>
      {isLoading ? (
        <p className="mt-3 text-sm text-slate">Loading alerts…</p>
      ) : isError ? (
        <p className="mt-3 text-sm text-ember">Couldn't load alerts.</p>
      ) : alerts.length === 0 ? (
        <p className="mt-3 flex items-center gap-2 text-sm text-slate">
          <BellOff className="h-4 w-4" /> No alerts yet. They appear here when a tracked stock enters its zone, runs above it, or fails.
        </p>
      ) : (
        <ul className="mt-3 divide-y divide-mist/60">
          {alerts.slice(0, 10).map((alert) => (
            <li key={alert.id} className={cn("flex flex-col gap-1 py-2.5 sm:flex-row sm:items-center sm:gap-3", !alert.read_at && "font-semibold")}>
              <div className="flex shrink-0 items-center gap-2">
                {!alert.read_at && <span className="h-2 w-2 rounded-full bg-ember" aria-label="Unread" />}
                <Badge tone={ALERT_TONE[alert.kind]}>{ALERT_LABELS[alert.kind]}</Badge>
              </div>
              <p className="min-w-0 flex-1 text-sm text-ink">{alert.message}</p>
              <span className="shrink-0 text-xs text-slate">{timeAgo(alert.created_at)}</span>
            </li>
          ))}
        </ul>
      )}
    </Card>
  )
}

function WatchlistCard({ item }: { item: WatchlistItem }) {
  const [editing, setEditing] = useState(false)
  const [levels, setLevels] = useState<LevelDraft>(() => levelsToDraft(item))
  const [notes, setNotes] = useState(item.notes ?? "")
  const update = useUpdateWatchlistItem()
  const remove = useRemoveWatchlistItem()
  const snapshot = item.setup_snapshot
  const archived = item.status === "archived"

  const save = () =>
    update.mutate(
      { id: item.id, ...draftToLevels(levels), notes },
      { onSuccess: () => setEditing(false) },
    )

  return (
    <article aria-label={`${item.symbol} setup`}>
      <Card className={cn("p-4", archived && "opacity-70")}>
        <div className="flex flex-wrap items-start justify-between gap-2">
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2">
              <Link to={`/screener/${encodeURIComponent(item.symbol)}`} className="font-display text-lg font-bold text-ink hover:underline">
                {item.symbol}
              </Link>
              <Badge tone={STATUS_TONE[item.status]}>{STATUS_LABELS[item.status]}</Badge>
            {item.next_book_close && <BookCloseBadge bookClose={item.next_book_close} />}
              <span className="text-xs font-semibold text-slate">{SETUP_LABELS[item.setup_type]}</span>
            </div>
            <p className="truncate text-xs text-slate">{item.name} · {item.sector}</p>
          </div>
          <div className="text-right">
            <p className="font-mono text-lg font-bold text-ink">{formatPrice(item.current_price)}</p>
            <p className={cn("text-xs font-semibold", item.change_percent > 0 ? "text-pine" : item.change_percent < 0 ? "text-ember" : "text-slate")}>
              {item.change_percent > 0 ? "+" : ""}{item.change_percent.toFixed(2)}%
            </p>
          </div>
        </div>

        <p className="mt-2 text-sm text-ink">
          <span className="font-semibold">{item.price_state ? PRICE_STATE_LABELS[item.price_state] : "Not evaluated"}</span>
          <span className="text-slate"> · {zoneDistanceText(item)}</span>
        </p>
        <PriceLadder item={item} />

        {editing ? (
          <div className="mt-3 space-y-3">
            <LevelFields idPrefix={`edit-${item.id}`} value={levels} onChange={setLevels} />
            <label htmlFor={`notes-${item.id}`} className="block text-xs font-semibold text-slate">
              Notes
              <Textarea id={`notes-${item.id}`} className="mt-1" rows={2} value={notes} onChange={(event) => setNotes(event.target.value)} />
            </label>
            {update.isError && <p role="alert" className="text-sm text-ember">{apiErrorMessage(update.error)}</p>}
            <div className="flex gap-2">
              <Button size="sm" onClick={save} disabled={update.isPending}>{update.isPending ? "Saving…" : "Save levels"}</Button>
              <Button size="sm" variant="outline" onClick={() => { setEditing(false); setLevels(levelsToDraft(item)); setNotes(item.notes ?? "") }}>Cancel</Button>
            </div>
          </div>
        ) : (
          <dl className="mt-3 grid grid-cols-2 gap-x-4 gap-y-2 text-sm sm:grid-cols-5">
            <div><dt className="text-xs text-slate">Entry zone</dt><dd className="font-mono font-semibold text-ink">{formatPrice(item.entry_zone_low)}–{formatPrice(item.entry_zone_high)}</dd></div>
            <div><dt className="text-xs text-slate">Invalidation</dt><dd className="font-mono font-semibold text-ember">{formatPrice(item.invalidation_price)}</dd></div>
            <div><dt className="text-xs text-slate">Stop</dt><dd className="font-mono font-semibold text-ink">{formatPrice(item.stop_loss_price)}</dd></div>
            <div><dt className="text-xs text-slate">Target</dt><dd className="font-mono font-semibold text-pine">{formatPrice(item.target_price)}</dd></div>
            <div><dt className="text-xs text-slate">Risk:reward</dt><dd className="font-mono font-semibold text-ink">{item.risk_reward === null ? "—" : `${item.risk_reward}R`}</dd></div>
          </dl>
        )}

        {item.level_adjustments && item.level_adjustments.length > 0 && (
          <p className="mt-2 text-xs text-slate">
            Levels adjusted for {item.level_adjustments.map((adjustment) => `a ${adjustment.bonus_percent}% bonus (book close ${adjustment.book_close_on})`).join(" and ")}.
          </p>
        )}
        {!archived && <EntryChecklistPanel checklist={item.checklist} />}

        <p className="mt-3 rounded-lg bg-slate/5 px-3 py-2 text-xs text-slate">
          Added {new Date(item.created_at).toLocaleDateString("en-US", { month: "short", day: "numeric" })} at {formatPrice(item.price_at_add)}
          {snapshot.vcp_score !== undefined && <> · VCP score {snapshot.vcp_score}</>}
          {snapshot.contractions_count ? <> · {snapshot.contractions_count} contractions</> : null}
          {snapshot.trend && <> · {snapshot.trend}</>}
          {snapshot.market_regime && <> · market {snapshot.market_regime}</>}
          {snapshot.analysed_on && <> · data as of {snapshot.analysed_on}</>}
        </p>
        {!editing && item.notes && <p className="mt-2 text-sm text-ink">{item.notes}</p>}

        {!editing && (
          <div className="mt-3 flex flex-wrap gap-2">
            {item.trade_plan_id ? (
              // The Trades page still reads browser storage, not saved plans, so this is a label, not a link.
              <span className="inline-flex items-center gap-1.5 rounded-xl border border-pine/30 bg-pine/10 px-3 py-1.5 text-xs font-bold text-pine">
                <ClipboardList className="h-4 w-4" /> Plan #{item.trade_plan_id} saved
              </span>
            ) : (
              !archived && item.status !== "invalidated" && (
                <Link to={`/trade/new?watchlist=${item.id}`} className="inline-flex items-center gap-1.5 rounded-xl bg-ink px-3 py-1.5 text-xs font-bold text-white">
                  <ClipboardList className="h-4 w-4" /> Create plan
                </Link>
              )
            )}
            {!archived && (
              <Button size="sm" variant="outline" onClick={() => setEditing(true)} className="inline-flex items-center gap-1.5">
                <Pencil className="h-3.5 w-3.5" /> Edit levels
              </Button>
            )}
            {(item.status === "invalidated" || archived) && (
              <Button size="sm" variant="outline" onClick={() => update.mutate({ id: item.id, status: "watching" })} className="inline-flex items-center gap-1.5">
                <RotateCcw className="h-3.5 w-3.5" /> {archived ? "Restore" : "Reset setup"}
              </Button>
            )}
            {!archived && (
              <Button size="sm" variant="ghost" onClick={() => update.mutate({ id: item.id, status: "archived" })} className="inline-flex items-center gap-1.5">
                <Archive className="h-3.5 w-3.5" /> Archive
              </Button>
            )}
            <Button
              size="sm"
              variant="ghost"
              className="inline-flex items-center gap-1.5 text-ember"
              onClick={() => window.confirm(`Remove ${item.symbol} and its alerts from your watchlist?`) && remove.mutate(item.id)}
            >
              <Trash2 className="h-3.5 w-3.5" /> Remove
            </Button>
          </div>
        )}
      </Card>
    </article>
  )
}

export function WatchlistPage() {
  const [view, setView] = useState<"active" | "archived">("active")
  const { data, isLoading, isError, error, refetch } = useWatchlist(view === "archived")
  const items = (data ?? []).filter((item) => (view === "archived" ? item.status === "archived" : item.status !== "archived"))

  return (
    <div className="space-y-5">
      <div>
        <h1 className="font-display text-2xl font-bold tracking-tight text-ink sm:text-3xl">Watchlist</h1>
        <p className="mt-1 text-sm text-slate">
          Stocks you're tracking toward an entry. Levels are checked after every price sync (every 5 minutes in market hours).
        </p>
      </div>

      <AlertsPanel />

      <div className="inline-flex rounded-xl border border-mist/80 bg-slate/5 p-1" role="tablist">
        {(["active", "archived"] as const).map((id) => (
          <button
            key={id}
            role="tab"
            aria-selected={view === id}
            onClick={() => setView(id)}
            className={cn("rounded-lg px-4 py-1.5 text-xs font-semibold capitalize", view === id ? "bg-white text-ink shadow-xs" : "text-slate")}
          >
            {id}
          </button>
        ))}
      </div>

      {isLoading ? (
        <div className="flex justify-center py-12"><LoadingSpinner /></div>
      ) : isError ? (
        <Card className="p-6 text-center">
          <p className="text-sm text-ember">{apiErrorMessage(error, "Couldn't load your watchlist.")}</p>
          <Button className="mt-3" variant="outline" onClick={() => void refetch()}>Retry</Button>
        </Card>
      ) : items.length === 0 ? (
        <Card className="p-10 text-center">
          <p className="font-semibold text-ink">{view === "archived" ? "No archived setups." : "Nothing tracked yet."}</p>
          {view === "active" && (
            <p className="mt-1 text-sm text-slate">
              Open the <Link to="/screener" className="font-semibold text-ink underline">VCP Screener</Link> or a stock's analysis page and choose{" "}
              <b>Add to watchlist</b>.
            </p>
          )}
        </Card>
      ) : (
        <div className="grid gap-4 xl:grid-cols-2">
          {items.map((item) => <WatchlistCard key={item.id} item={item} />)}
        </div>
      )}
    </div>
  )
}
