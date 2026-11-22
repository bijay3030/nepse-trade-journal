import { format, parseISO } from "date-fns"
import { Megaphone } from "lucide-react"
import { useMemo, useState } from "react"
import { Link } from "react-router-dom"

import { Badge, Button, Card, CardBody, LoadingSpinner } from "../components/ui"
import { useMarketEvents } from "../features/events/api"
import { IMPACT_LOOK, KIND_LABELS } from "../features/events/labels"
import type { EventImpact, EventKind, MarketEvent, MarketEventFilters, MarketEventsResponse } from "../features/events/types"
import { cn } from "../lib/cn"

const pct = (v: number | null | undefined) => (v == null ? "—" : `${v > 0 ? "+" : ""}${v.toFixed(1)}%`)
const tone = (v: number | null | undefined) => (v == null ? "text-slate" : v > 0 ? "text-pine" : v < 0 ? "text-ember" : "text-slate")
const day = (iso: string) => format(parseISO(iso), "EEE d MMM")
const IMPACTS: Array<EventImpact | ""> = ["", "positive", "negative", "mixed", "neutral"]
const DAYS = [3, 7, 14, 30, 90]

export function MarketEventsPage() {
  const [filters, setFilters] = useState<MarketEventFilters>({ scope: "all", impact: "", kind: "", days: 14 })
  const { data, isLoading, isError, refetch, isFetching } = useMarketEvents(filters)
  const set = (patch: Partial<MarketEventFilters>) => setFilters((current) => ({ ...current, ...patch }))

  return (
    <div className="space-y-5">
      <header>
        <h1 className="flex items-center gap-2 font-display text-2xl font-bold tracking-tight text-ink sm:text-3xl"><Megaphone className="h-6 w-6" /> Market Events</h1>
        <p className="mt-1 max-w-3xl text-sm text-slate">
          Company announcements and corporate actions on NEPSE (ShareSansar announcements, Chukul's bonus, dividend and rights lists), checked every hour and
          rated good, bad, mixed or neutral for the share price by fixed rules, each with its reason. Your stocks (watchlist, positions, scanner radar, Strategy Lab
          list) are marked; Telegram tells you about them. Rule checks, not advice.
        </p>
      </header>

      {isLoading ? (
        <div className="flex h-[40vh] items-center justify-center"><LoadingSpinner size="lg" /></div>
      ) : isError || !data ? (
        <Card className="p-8 text-center">
          <p className="font-display text-lg font-bold text-ink">Couldn't load market events</p>
          <Button className="mt-4" variant="outline" onClick={() => void refetch()}>Retry</Button>
        </Card>
      ) : (
        <>
          <Upcoming events={data.upcoming} asOf={data.as_of} />

          <Card className="p-4">
            <div className="flex flex-wrap items-center gap-x-5 gap-y-2 text-sm" role="group" aria-label="Filters">
              <div className="inline-flex rounded-xl border border-mist/80 bg-slate/5 p-1" role="tablist">
                {(["all", "mine"] as const).map((scope) => (
                  <button key={scope} type="button" role="tab" aria-selected={filters.scope === scope} onClick={() => set({ scope })}
                    className={cn("rounded-lg px-3 py-1 font-semibold", filters.scope === scope ? "bg-white text-ink shadow-sm" : "text-slate")}>
                    {scope === "all" ? "All companies" : "My stocks"}
                  </button>
                ))}
              </div>
              <div className="flex flex-wrap gap-1.5" aria-label="Rating">
                {IMPACTS.map((impact) => (
                  <button key={impact || "any"} type="button" onClick={() => set({ impact })} aria-pressed={filters.impact === impact}
                    className={cn("rounded-full border px-3 py-1 text-xs font-semibold", filters.impact === impact ? "border-ink bg-ink text-white" : "border-slate/20 text-ink hover:bg-slate/5")}>
                    {impact ? IMPACT_LOOK[impact].label : "Any rating"}
                  </button>
                ))}
              </div>
              <label className="flex items-center gap-2 text-slate">Type
                <select aria-label="Type" className="rounded-lg border border-slate/20 bg-white px-2 py-1 text-ink" value={filters.kind} onChange={(e) => set({ kind: e.target.value as EventKind | "" })}>
                  <option value="">All types</option>
                  {(Object.keys(KIND_LABELS) as EventKind[]).map((kind) => <option key={kind} value={kind}>{KIND_LABELS[kind]}</option>)}
                </select>
              </label>
              <label className="flex items-center gap-2 text-slate">Last
                <select aria-label="Days" className="rounded-lg border border-slate/20 bg-white px-2 py-1 text-ink" value={filters.days} onChange={(e) => set({ days: Number(e.target.value) })}>
                  {DAYS.map((d) => <option key={d} value={d}>{d} days</option>)}
                </select>
              </label>
              <span className={cn("ml-auto text-xs text-slate", isFetching && "animate-pulse")} aria-live="polite"><b className="text-ink">{data.events.length}</b> events</span>
            </div>
          </Card>

          <EventList events={data.events} />
          <Study study={data.study} />
        </>
      )}
    </div>
  )
}

function Upcoming({ events, asOf }: { events: MarketEvent[]; asOf: string }) {
  if (events.length === 0) return null
  const today = parseISO(asOf)
  return (
    <section className="space-y-2" aria-label="Book closes ahead">
      <h2 className="font-display text-lg font-bold text-ink">Book closes in the next two weeks</h2>
      <p className="text-xs text-slate">The price adjusts down on the book close day by the bonus, rights or cash. To get the entitlement, shares must be bought (settled) before it.</p>
      <div className="flex gap-3 overflow-x-auto pb-1">
        {events.map((e) => {
          const days = Math.round((parseISO(e.event_on as string).getTime() - today.getTime()) / 86_400_000)
          const what = e.kind === "rights" ? `${num(e.data.right)}% rights`
            : [num(e.data.bonus) > 0 ? `${num(e.data.bonus)}% bonus` : null, num(e.data.cash) > 0 ? `${num(e.data.cash)}% cash` : null].filter(Boolean).join(" + ")
          return (
            <div key={e.id} className={cn("min-w-[170px] rounded-2xl border bg-white px-3 py-2 shadow-sm", e.mine ? "border-pine/50" : "border-mist/80")}>
              <p className="flex items-center justify-between gap-2">
                {e.symbol ? <Link className="font-display font-bold text-ink hover:underline" to={`/screener/${encodeURIComponent(e.symbol)}`}>{e.symbol}</Link> : <b>—</b>}
                <span className="text-[11px] font-semibold text-slate">{days === 0 ? "today" : days === 1 ? "tomorrow" : `in ${days} days`}</span>
              </p>
              <p className="text-sm text-ink">{what || KIND_LABELS[e.kind]}</p>
              <p className="text-[11px] text-slate">{day(e.event_on as string)}{e.mine ? " · your stock" : ""}</p>
            </div>
          )
        })}
      </div>
    </section>
  )
}

function num(value: unknown) { return Number(value ?? 0) }

function EventList({ events }: { events: MarketEvent[] }) {
  const byDay = useMemo(() => {
    const map = new Map<string, MarketEvent[]>()
    for (const e of events) map.set(e.published_on, [...(map.get(e.published_on) ?? []), e])
    return [...map.entries()]
  }, [events])
  if (events.length === 0) return <Card className="p-8 text-center text-sm text-slate">No events match these filters.</Card>
  return (
    <section className="space-y-4" aria-label="Events">
      {byDay.map(([date, list]) => (
        <div key={date}>
          <h3 className="mb-2 text-xs font-bold uppercase tracking-wider text-slate">{format(parseISO(date), "EEEE d MMMM yyyy")}</h3>
          <Card className="divide-y divide-mist/60">
            {list.map((e) => <EventRow key={e.id} e={e} />)}
          </Card>
        </div>
      ))}
    </section>
  )
}

function EventRow({ e }: { e: MarketEvent }) {
  const look = IMPACT_LOOK[e.impact]
  return (
    <article className={cn("flex gap-3 px-4 py-3", e.mine && "bg-pine/5")} aria-label={`${e.symbol ?? "Market"} event`}>
      <span className={cn("mt-0.5 h-fit shrink-0 rounded-full px-2 py-0.5 text-xs font-bold", look.chip)}>{look.label}</span>
      <div className="min-w-0 flex-1">
        <p className="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm">
          {e.symbol ? <Link className="font-bold text-ink hover:underline" to={`/screener/${encodeURIComponent(e.symbol)}`}>{e.symbol}</Link> : <b className="text-slate">Unlisted / market</b>}
          <Badge tone="neutral">{KIND_LABELS[e.kind]}</Badge>
          {e.mine && <Badge tone="gain">Your stock</Badge>}
          {e.important && <span className="text-[11px] font-semibold text-amber-700">Important</span>}
          {e.event_on && <span className="text-[11px] text-slate">Book close {day(e.event_on)}</span>}
        </p>
        <p className="mt-1 text-sm text-ink">{e.reason}</p>
        <p className="mt-0.5 text-xs text-slate">
          {e.url ? <a className="hover:underline" href={e.url} target="_blank" rel="noreferrer">{e.title}</a> : e.title}
          {e.source !== "sharesansar" && <span> · Chukul</span>}
        </p>
      </div>
    </article>
  )
}

function Study({ study }: { study: MarketEventsResponse["study"] }) {
  return (
    <section className="space-y-2" id="book-close-study">
      <h2 className="font-display text-lg font-bold text-ink">How prices moved around book closes</h2>
      <p className="max-w-4xl text-xs text-slate">
        Every bonus, cash dividend and rights book close on NEPSE since {study.from?.slice(0, 4) ?? "2020"} ({study.events} cases), on bonus-adjusted prices (so the
        adjustment itself isn't counted as a fall): the move over the {study.window} sessions before the book close, and the {study.window} after it, also against NEPSE over
        the same days.
      </p>
      <Card className="overflow-x-auto">
        <table className="w-full text-sm" aria-label="Book close study">
          <thead className="border-b border-mist/80 bg-slate/5 text-left text-[11px] font-bold uppercase tracking-wider text-slate">
            <tr>
              <th className="px-3 py-2">Event</th><th className="px-3 py-2 text-right">Cases</th>
              <th className="px-3 py-2 text-right">{study.window} sessions before</th><th className="px-3 py-2 text-right">Went up</th><th className="px-3 py-2 text-right">vs NEPSE</th>
              <th className="px-3 py-2 text-right">{study.window} sessions after</th><th className="px-3 py-2 text-right">Went up</th><th className="px-3 py-2 text-right">vs NEPSE</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-mist/60">
            {study.groups.map((g) => (
              <tr key={g.key}>
                <td className="px-3 py-1.5 text-ink">{g.label}</td>
                <td className="px-3 py-1.5 text-right font-mono text-slate">{g.count}</td>
                <td className={cn("px-3 py-1.5 text-right font-mono", tone(g.run_up_avg))}>{pct(g.run_up_avg)}</td>
                <td className="px-3 py-1.5 text-right font-mono">{g.run_up_up_pct != null ? `${g.run_up_up_pct}%` : "—"}</td>
                <td className={cn("px-3 py-1.5 text-right font-mono", tone(g.run_up_excess))}>{pct(g.run_up_excess)}</td>
                <td className={cn("px-3 py-1.5 text-right font-mono", tone(g.after_avg))}>{pct(g.after_avg)}</td>
                <td className="px-3 py-1.5 text-right font-mono">{g.after_up_pct != null ? `${g.after_up_pct}%` : "—"}</td>
                <td className={cn("px-3 py-1.5 text-right font-mono", tone(g.after_excess))}>{pct(g.after_excess)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
      <Card><CardBody className="space-y-2 text-sm text-slate">
        <p><b className="text-ink">Bonus shares:</b> new shares for free, in proportion to what you hold. On the book close the price is adjusted down by the bonus (Rs 1,100 with a 10% bonus becomes about Rs 1,000), so your holding's value doesn't change; you hold more shares at a lower price. Earnings per share fall because the same profit is spread over more shares.</p>
        <p><b className="text-ink">Rights shares:</b> the right to buy new shares, usually at Rs 100. The price adjusts to (price + ratio × 100) ÷ (1 + ratio): a 1:1 rights on a Rs 500 stock adjusts to Rs 300. Holders who don't subscribe are diluted; the company has more capital to earn on.</p>
        <p><b className="text-ink">Cash dividends</b> also lower the price by the amount paid. Tax is withheld at source.</p>
      </CardBody></Card>
    </section>
  )
}
