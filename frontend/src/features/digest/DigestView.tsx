import { format, parseISO } from "date-fns"
import { Link } from "react-router-dom"

import { Badge, Card, CardBody, CardHeader } from "../../components/ui"
import { GUARD_LABELS, SETUP_TYPE_LABELS, ZONE_LABELS } from "../readiness/labels"
import { ALERT_LABELS, ALERT_TONE, formatPrice } from "../watchlist/labels"
import { CLOSE_STATE_LABELS, CLOSE_STATE_TONE } from "./labels"
import type { DigestContent } from "./types"

const pct = (value: number) => `${value > 0 ? "+" : ""}${value.toFixed(2)}%`
const day = (value: string) => format(parseISO(value), "MMM d")
const REGIME_TONE = { strong: "gain", neutral: "neutral", weak: "loss" } as const

function StockLink({ symbol }: { symbol: string }) {
  return (
    <Link to={`/screener/${encodeURIComponent(symbol)}`} className="font-bold text-ink hover:underline">
      {symbol}
    </Link>
  )
}

function Empty({ children }: { children: string }) {
  return <p className="text-sm text-slate">{children}</p>
}

// The sections of one digest. Sections the user switched off are absent from the content.
export function DigestView({ content }: { content: DigestContent }) {
  const { market, entry_zone: entry, watchlist } = content
  return (
    <div className="space-y-5">
      {market && (
        <Card>
          <CardHeader title="Market summary" subtitle={market.index_on ? `NEPSE session ${market.index_on}` : undefined} />
          <CardBody>
            <div className="flex flex-wrap items-baseline gap-x-5 gap-y-2">
              <p className="font-display text-2xl font-bold text-ink">
                {market.nepse_index.toLocaleString("en-US", { maximumFractionDigits: 2 })}
                <span className={`ml-2 text-base ${market.index_change_pct >= 0 ? "text-pine" : "text-ember"}`}>{pct(market.index_change_pct)}</span>
              </p>
              <Badge tone={REGIME_TONE[market.regime]}>{market.regime.charAt(0).toUpperCase() + market.regime.slice(1)} market</Badge>
              <p className="text-sm text-slate">
                {market.advancing} up · {market.declining} down · {market.unchanged} unchanged ({market.breadth_pct.toFixed(1)}% breadth)
              </p>
            </div>
            <div className="mt-4 grid gap-4 sm:grid-cols-2">
              {([["Best sectors", market.best_sectors], ["Weakest sectors", market.worst_sectors]] as const).map(([title, rows]) => (
                <div key={title}>
                  <h4 className="text-xs font-bold uppercase tracking-wide text-slate">{title}</h4>
                  <ul className="mt-1 space-y-1 text-sm">
                    {rows.map((row) => (
                      <li key={row.sector} className="flex justify-between gap-2">
                        <span className="text-ink">{row.sector}</span>
                        <span className={row.change_pct >= 0 ? "text-pine" : "text-ember"}>{pct(row.change_pct)}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          </CardBody>
        </Card>
      )}

      {entry && (
        <Card>
          <CardHeader
            title="Entry zone changes"
            subtitle={`${entry.count} on the board${content.previous_session ? `, compared with ${day(content.previous_session)}` : ""}. Rule checks, not recommendations.`}
          />
          <CardBody className="space-y-4">
            <section aria-label="Joined the board">
              <h4 className="text-xs font-bold uppercase tracking-wide text-slate">Joined ({entry.joined.length})</h4>
              {entry.joined.length === 0 ? (
                <Empty>No new stocks in the entry zone.</Empty>
              ) : (
                <ul className="mt-1 divide-y divide-slate/10">
                  {entry.joined.map((row) => (
                    <li key={row.symbol} className="flex flex-wrap items-baseline gap-x-2 py-1.5 text-sm">
                      <StockLink symbol={row.symbol} />
                      <span className="text-xs text-slate">{row.sector}</span>
                      <span className="text-slate">
                        {row.setup_type ? SETUP_TYPE_LABELS[row.setup_type] : "—"} · readiness {row.readiness} · zone {formatPrice(row.entry_zone_low)}–{formatPrice(row.entry_zone_high)} · close {formatPrice(row.close)}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </section>
            <section aria-label="Left the board">
              <h4 className="text-xs font-bold uppercase tracking-wide text-slate">Left ({entry.left.length})</h4>
              {entry.left.length === 0 ? (
                <Empty>None left the board.</Empty>
              ) : (
                <ul className="mt-1 flex flex-wrap gap-2 text-sm">
                  {entry.left.map((row) => (
                    <li key={row.symbol} className="rounded-lg bg-slate/5 px-2 py-1">
                      <StockLink symbol={row.symbol} />{" "}
                      <span className="text-xs text-slate">
                        {row.guards.length ? row.guards.map((guard) => GUARD_LABELS[guard]).join(", ") : ZONE_LABELS[row.zone_state]} · {row.readiness}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </section>
            {entry.held_back.length > 0 && (
              <section aria-label="Held back by guards">
                <h4 className="text-xs font-bold uppercase tracking-wide text-slate">Held back by guards ({entry.held_back.length})</h4>
                <p className="mt-1 text-sm text-slate">
                  {entry.held_back.map((row, i) => (
                    <span key={row.symbol}>
                      {i > 0 && ", "}
                      <StockLink symbol={row.symbol} /> ({row.guards.map((guard) => GUARD_LABELS[guard]).join(", ")})
                    </span>
                  ))}
                </p>
              </section>
            )}
          </CardBody>
        </Card>
      )}

      {watchlist && (
        <Card>
          <CardHeader title="Watchlist status" subtitle={`${watchlist.tracked} tracked ${watchlist.tracked === 1 ? "stock" : "stocks"}`} />
          <CardBody className="space-y-4">
            <section aria-label="End-of-day verdicts">
              <h4 className="text-xs font-bold uppercase tracking-wide text-slate">End-of-day verdicts</h4>
              {watchlist.verdicts.length === 0 ? (
                <Empty>No verdicts for this close.</Empty>
              ) : (
                <ul className="mt-1 space-y-1 text-sm">
                  {watchlist.verdicts.map((row) => (
                    <li key={row.symbol} className="flex flex-wrap items-center gap-2">
                      <StockLink symbol={row.symbol} />
                      <Badge tone={CLOSE_STATE_TONE[row.state] ?? "neutral"}>{CLOSE_STATE_LABELS[row.state] ?? row.state.replaceAll("_", " ")}</Badge>
                      <span className="text-slate">closed {formatPrice(row.close)}</span>
                    </li>
                  ))}
                </ul>
              )}
            </section>
            <section aria-label="Alerts">
              <h4 className="text-xs font-bold uppercase tracking-wide text-slate">Alerts during the session ({watchlist.alerts.length})</h4>
              {watchlist.alerts.length === 0 ? (
                <Empty>No alerts.</Empty>
              ) : (
                <ul className="mt-1 space-y-1 text-sm">
                  {watchlist.alerts.map((alert, i) => (
                    <li key={`${alert.symbol}-${alert.kind}-${i}`} className="flex flex-wrap items-center gap-2">
                      <Badge tone={ALERT_TONE[alert.kind]}>{ALERT_LABELS[alert.kind]}</Badge>
                      <span className="text-ink">{alert.message}</span>
                    </li>
                  ))}
                </ul>
              )}
            </section>
            <section aria-label="Book closes">
              <h4 className="text-xs font-bold uppercase tracking-wide text-slate">Book closes in the next 10 days</h4>
              {watchlist.book_closes.length === 0 ? (
                <Empty>None for your tracked stocks.</Empty>
              ) : (
                <ul className="mt-1 space-y-1 text-sm">
                  {watchlist.book_closes.map((row) => (
                    <li key={row.symbol}>
                      <StockLink symbol={row.symbol} />{" "}
                      <span className="text-slate">
                        {day(row.book_close_on)} ({row.days_until === 0 ? "today" : `in ${row.days_until} ${row.days_until === 1 ? "day" : "days"}`})
                        {row.bonus_percent ? ` · ${row.bonus_percent}% bonus, levels will be adjusted` : ""}
                        {row.cash_percent ? ` · ${row.cash_percent}% cash` : ""}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          </CardBody>
        </Card>
      )}
    </div>
  )
}
