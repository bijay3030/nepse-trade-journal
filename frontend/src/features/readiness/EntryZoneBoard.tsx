import { Link } from "react-router-dom"

import { Badge, Button, Card, LoadingSpinner } from "../../components/ui"
import { useBuyZone } from "../screener/api"
import { BookCloseBadge } from "../corporate/BookCloseBadge"
import { AddToWatchlistButton } from "../watchlist/AddToWatchlist"
import { FLOW_LABELS, SETUP_TYPE_LABELS, ZONE_LABELS, ZONE_TONE } from "./labels"
import { ReadinessGauge } from "./ReadinessGauge"

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
  return (
    <div className="space-y-3">
      <p className="text-sm text-slate">
        Price inside a setup's entry zone, at least {criteria.min_trend_rules} of 7 trend rules and readiness {criteria.min_readiness}+,
        on the {data.traded_on ?? "—"} close. Rule checks, not recommendations.
      </p>
      {data.results.length === 0 ? (
        <Card className="p-10 text-center">
          <p className="font-semibold text-ink">No stocks meet the criteria on this close.</p>
          <p className="mt-1 text-sm text-slate">That's common in a weak market. Check the All setups tab for stocks that are building.</p>
        </Card>
      ) : (
        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          {data.results.map((row) => (
            <article key={row.symbol} aria-label={`${row.symbol} entry zone`}>
              <Card className="flex h-full gap-3 p-4">
                <ReadinessGauge score={row.readiness_score} size={58} />
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
          ))}
        </div>
      )}
    </div>
  )
}
