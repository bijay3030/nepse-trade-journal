import { Link } from "react-router-dom"

import { Badge, Button, Card, LoadingSpinner } from "../../components/ui"
import { useBuyZone } from "../screener/api"
import type { BuyZoneRow } from "../screener/types"
import { BookCloseBadge } from "../corporate/BookCloseBadge"
import { AddToWatchlistButton } from "../watchlist/AddToWatchlist"
import { GuardBadges } from "./GuardBadges"
import { FLOW_LABELS, GUARD_LABELS, SETUP_TYPE_LABELS, ZONE_LABELS, ZONE_TONE, formatTurnover } from "./labels"
import { ReadinessGauge } from "./ReadinessGauge"
import { ReadinessSparkline } from "./ReadinessSparkline"

const price = (value: number | null) => (value === null ? "—" : value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 }))

// Stocks meeting the entry-zone criteria on the latest nightly snapshot, highest readiness first.
export function EntryZoneBoard() {
  const { data, isLoading, isError, refetch } = useBuyZone()

  if (isLoading) return <div className="flex justify-center py-12"><LoadingSpinner /></div>
  if (isError || !data) {
    return (
      <Card className="p-6 text-center">
        <p className="text-sm text-ember">Couldn't load the entry-zone list.</p>
        <Button className="mt-3" variant="outline" onClick={() => void refetch()}>Retry</Button>
      </Card>
    )
  }

  const { criteria } = data
  const heldBack = data.held_back ?? []
  return (
    <div className="space-y-3">
      <p className="text-sm text-slate">
        Price inside a setup's entry zone, at least {criteria.min_trend_rules} of 7 trend rules and readiness {criteria.min_readiness}+,
        on the {data.traded_on ?? "—"} close.
        {criteria.min_avg_turnover !== undefined && (
          <> Tradable only: average turnover {formatTurnover(criteria.min_avg_turnover)}+ a day, and a daily move under ±{criteria.circuit_near_pct ?? 9.5}% (not at the ±10% circuit).</>
        )}{" "}
        Rule checks, not recommendations.
      </p>
      {data.results.length === 0 ? (
        <Card className="p-10 text-center">
          <p className="font-semibold text-ink">No stocks meet the criteria on this close.</p>
          <p className="mt-1 text-sm text-slate">That's common in a weak market. Check the All setups tab for stocks that are building.</p>
        </Card>
      ) : (
        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          {data.results.map((row) => <BoardCard key={row.symbol} row={row} />)}
        </div>
      )}
      {heldBack.length > 0 && (
        <section aria-label="Held back by guards" className="pt-2">
          <h3 className="text-sm font-bold text-ink">Held back by guards ({heldBack.length})</h3>
          <p className="text-xs text-slate">These charts meet the rules above but are hard to trade right now.</p>
          <ul className="mt-2 divide-y divide-slate/10 rounded-lg border border-slate/15 bg-white/60">
            {heldBack.map((row) => (
              <li key={row.symbol} className="flex flex-wrap items-center gap-2 px-3 py-2 text-sm">
                <Link to={`/screener/${encodeURIComponent(row.symbol)}`} className="font-bold text-ink hover:underline">{row.symbol}</Link>
                <span className="text-xs text-slate">readiness {row.readiness_score}</span>
                <GuardBadges guards={row.guards} />
                <span className="text-xs text-slate">{guardFacts(row)}</span>
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  )
}

function guardFacts(row: BuyZoneRow) {
  const facts: string[] = []
  if (row.guards?.includes("thin_volume") && row.avg_turnover != null) facts.push(`${formatTurnover(row.avg_turnover)} a day`)
  if (row.change_pct != null && (row.guards?.includes("upper_circuit") || row.guards?.includes("lower_circuit"))) {
    facts.push(`${row.change_pct > 0 ? "+" : ""}${row.change_pct.toFixed(2)}% on the day`)
  }
  return facts.join(" · ") || (row.guards ?? []).map((guard) => GUARD_LABELS[guard]).join(", ")
}

function BoardCard({ row }: { row: BuyZoneRow }) {
  return (
    <article aria-label={`${row.symbol} entry zone`}>
      <Card className="flex h-full gap-3 p-4">
        <div className="flex shrink-0 flex-col items-center gap-1">
          <ReadinessGauge score={row.readiness_score} size={58} />
          {row.readiness_history && row.readiness_history.length > 1 && (
            <ReadinessSparkline history={row.readiness_history} width={64} height={24} showDots={false} fitRange />
          )}
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <Link to={`/screener/${encodeURIComponent(row.symbol)}`} className="font-display text-lg font-bold text-ink hover:underline">
              {row.symbol}
            </Link>
            <Badge tone={ZONE_TONE[row.zone_state]}>{ZONE_LABELS[row.zone_state]}</Badge>
          </div>
          <p className="truncate text-xs text-slate">{row.name} · {row.sector}</p>
          <p className="mt-1 text-sm text-ink">
            {row.setup_type ? SETUP_TYPE_LABELS[row.setup_type] : "—"} · close {price(row.close_price)}
          </p>
          <p className="text-xs text-slate">
            Zone {price(row.entry_zone_low)}–{price(row.entry_zone_high)} · invalidation {price(row.invalidation_price)}
          </p>
          <p className="text-xs text-slate">
            Trend {row.trend_rules_passed}/7 · RS {row.rs_rating ?? "—"}
            {row.flow_state && row.flow_state !== "no_data" && <> · {FLOW_LABELS[row.flow_state]}</>}
          </p>
          {row.next_book_close && <BookCloseBadge bookClose={row.next_book_close} className="mt-1" />}
          <div className="mt-2"><AddToWatchlistButton symbol={row.symbol} size="sm" /></div>
        </div>
      </Card>
    </article>
  )
}

