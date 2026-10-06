import { useState } from "react"
import { Link } from "react-router-dom"

import { Button, Card, LoadingSpinner, Textarea } from "../../components/ui"
import { cn } from "../../lib/cn"
import { apiErrorMessage } from "../watchlist/api"
import { usePositionStats, usePositions, useReviewPosition } from "./api"
import type { PlanFollowed, Position, ReviewTag } from "./types"

const money = (value: number) => value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const signed = (value: number) => `${value > 0 ? "+" : ""}${money(value)}`
const tone = (value: number | null | undefined) => (!value ? "text-slate" : value > 0 ? "text-pine" : "text-ember")

const TAG_LABELS: Record<ReviewTag, string> = {
  chased_entry: "Chased the entry",
  moved_stop_down: "Moved the stop down",
  sold_too_early: "Sold too early",
  held_past_stop: "Held past the stop",
  oversized: "Oversized",
  ignored_market: "Ignored the market",
}
const PLAN_LABELS: Record<PlanFollowed, string> = { yes: "Followed the plan", partly: "Partly", no: "Didn't follow it" }

function StatsStrip() {
  const { data } = usePositionStats()
  if (!data || data.closed === 0) return null
  const items: Array<[string, string, string?]> = [
    ["Closed trades", String(data.closed)],
    ["Win rate", `${data.win_rate_pct}%`],
    ["Net P&L after tax", `Rs ${signed(data.net_pnl ?? 0)}`, tone(data.net_pnl)],
    ["Expectancy / trade", `Rs ${signed(data.expectancy ?? 0)}`, tone(data.expectancy)],
    ["Average R", data.avg_r == null ? "—" : `${data.avg_r > 0 ? "+" : ""}${data.avg_r}R`, tone(data.avg_r)],
    ["Plan followed", data.plan_followed_pct == null ? "—" : `${data.plan_followed_pct}% of ${data.reviewed} reviewed`],
  ]
  return (
    <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6" aria-label="Closed trade stats">
      {items.map(([label, value, className]) => (
        <div key={label} className="rounded-xl bg-slate/5 px-4 py-3">
          <p className="text-xs text-slate">{label}</p>
          <p className={cn("font-display text-lg font-bold text-ink", className)}>{value}</p>
        </div>
      ))}
    </div>
  )
}

function ReviewForm({ position, onDone }: { position: Position; onDone: () => void }) {
  const [plan, setPlan] = useState<PlanFollowed | null>(position.review?.plan_followed ?? null)
  const [tags, setTags] = useState<ReviewTag[]>(position.review?.tags ?? [])
  const [lesson, setLesson] = useState(position.review?.lesson ?? "")
  const review = useReviewPosition()
  const toggle = (tag: ReviewTag) => setTags((current) => (current.includes(tag) ? current.filter((t) => t !== tag) : [...current, tag]))

  return (
    <div className="mt-3 space-y-3 rounded-xl border border-slate/15 p-3" aria-label={`Review ${position.symbol}`}>
      <fieldset>
        <legend className="text-xs font-semibold text-slate">Did you follow the plan?</legend>
        <div className="mt-1 flex flex-wrap gap-2">
          {(Object.keys(PLAN_LABELS) as PlanFollowed[]).map((value) => (
            <label key={value} className={cn("cursor-pointer rounded-full border px-3 py-1 text-xs font-semibold", plan === value ? "border-ink bg-ink text-white" : "border-slate/20 text-ink")}>
              <input type="radio" className="sr-only" name={`plan-${position.id}`} checked={plan === value} onChange={() => setPlan(value)} />
              {PLAN_LABELS[value]}
            </label>
          ))}
        </div>
      </fieldset>
      <fieldset>
        <legend className="text-xs font-semibold text-slate">What went wrong? (optional)</legend>
        <div className="mt-1 flex flex-wrap gap-2">
          {(Object.keys(TAG_LABELS) as ReviewTag[]).map((tag) => (
            <label key={tag} className={cn("cursor-pointer rounded-full border px-3 py-1 text-xs", tags.includes(tag) ? "border-ember bg-ember/10 font-semibold text-ember" : "border-slate/20 text-ink")}>
              <input type="checkbox" className="sr-only" checked={tags.includes(tag)} onChange={() => toggle(tag)} />
              {TAG_LABELS[tag]}
            </label>
          ))}
        </div>
      </fieldset>
      <label className="block text-xs font-semibold text-slate">
        Lesson
        <Textarea className="mt-1" rows={2} value={lesson} onChange={(event) => setLesson(event.target.value)} placeholder="What would you do differently?" />
      </label>
      {review.isError && <p role="alert" className="text-sm text-ember">{apiErrorMessage(review.error)}</p>}
      <div className="flex gap-2">
        <Button size="sm" disabled={review.isPending} onClick={() => review.mutate({ id: position.id, review: { plan_followed: plan, tags, lesson: lesson || null } }, { onSuccess: onDone })}>
          {review.isPending ? "Saving…" : "Save review"}
        </Button>
        <Button size="sm" variant="ghost" onClick={onDone}>Later</Button>
      </div>
    </div>
  )
}

function ClosedCard({ position }: { position: Position }) {
  const reviewed = Boolean(position.review?.reviewed_at)
  const [reviewing, setReviewing] = useState(false)
  const realized = position.realized
  const excursions = position.excursions

  return (
    <article aria-label={`${position.symbol} closed position`}>
      <Card className="p-4">
        <div className="flex flex-wrap items-start justify-between gap-2">
          <div>
            <Link to={`/screener/${encodeURIComponent(position.symbol)}`} className="font-display text-lg font-bold text-ink hover:underline">{position.symbol}</Link>
            <p className="text-xs text-slate">
              {position.opened_on} → {position.closed_on} · {position.days_held} days · bought at {money(position.average_price)}, sold at {position.average_sell_price ? money(position.average_sell_price) : "—"}
            </p>
          </div>
          {realized && (
            <div className="text-right">
              <p className={cn("font-mono text-lg font-bold", tone(realized.net))}>Rs {signed(realized.net)}</p>
              <p className="text-xs text-slate">net after fees and Rs {money(realized.tax)} tax</p>
            </div>
          )}
        </div>
        <dl className="mt-3 grid grid-cols-2 gap-x-4 gap-y-2 text-sm sm:grid-cols-4">
          <div><dt className="text-xs text-slate">R</dt><dd className={cn("font-mono font-semibold", tone(position.closed_r_multiple))}>{position.closed_r_multiple == null ? "—" : `${position.closed_r_multiple > 0 ? "+" : ""}${position.closed_r_multiple}R`}</dd></div>
          <div><dt className="text-xs text-slate">Gain after fees</dt><dd className={cn("font-mono font-semibold", tone(realized?.gain))}>{realized ? `Rs ${signed(realized.gain)}` : "—"}</dd></div>
          <div><dt className="text-xs text-slate">Worst while held (MAE)</dt><dd className="font-mono font-semibold text-ember">{excursions?.mae_pct == null ? "—" : `${excursions.mae_pct}%${excursions.mae_r != null ? ` · ${excursions.mae_r}R` : ""}`}</dd></div>
          <div><dt className="text-xs text-slate">Best while held (MFE)</dt><dd className="font-mono font-semibold text-pine">{excursions?.mfe_pct == null ? "—" : `+${excursions.mfe_pct}%${excursions.mfe_r != null ? ` · ${excursions.mfe_r}R` : ""}`}</dd></div>
        </dl>

        {reviewing ? (
          <ReviewForm position={position} onDone={() => setReviewing(false)} />
        ) : reviewed && position.review ? (
          <div className="mt-3 rounded-lg bg-slate/5 px-3 py-2 text-sm" aria-label="Review">
            <p className="text-ink">
              <b>{position.review.plan_followed ? PLAN_LABELS[position.review.plan_followed] : "Reviewed"}</b>
              {position.review.tags.length > 0 && <span className="text-ember"> · {position.review.tags.map((tag) => TAG_LABELS[tag]).join(", ")}</span>}
            </p>
            {position.review.lesson && <p className="mt-0.5 text-slate">{position.review.lesson}</p>}
            <button type="button" className="mt-1 text-xs font-semibold text-ink underline" onClick={() => setReviewing(true)}>Edit review</button>
          </div>
        ) : (
          <Button className="mt-3" size="sm" variant="outline" onClick={() => setReviewing(true)}>Review this trade</Button>
        )}
      </Card>
    </article>
  )
}

// Closed positions with results after costs and CGT, MAE/MFE and the trader's review.
export function ClosedPositions() {
  const { data, isLoading, isError } = usePositions("closed")
  if (isLoading) return <div className="flex h-40 items-center justify-center"><LoadingSpinner /></div>
  if (isError || !data) return <p className="text-sm text-ember">Couldn't load closed positions.</p>
  if (data.length === 0) return <Card className="p-8 text-center text-sm text-slate">No closed positions yet. Record a sell on an open position to close it.</Card>

  return (
    <div className="space-y-4">
      <StatsStrip />
      <div className="grid gap-4 xl:grid-cols-2">{data.map((position) => <ClosedCard key={position.id} position={position} />)}</div>
    </div>
  )
}
