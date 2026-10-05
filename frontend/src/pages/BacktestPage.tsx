import { useState } from "react"
import { Link } from "react-router-dom"

import { Badge, Card, CardBody, CardHeader, LoadingSpinner } from "../components/ui"
import { useBacktest } from "../features/backtest/api"
import { GroupChart } from "../features/backtest/GroupChart"
import type { Horizon } from "../features/backtest/types"
import { FLOW_LABELS, GUARD_LABELS, SETUP_TYPE_LABELS, ZONE_LABELS } from "../features/readiness/labels"
import { cn } from "../lib/cn"

const HORIZONS: Horizon[] = ["5", "10", "20"]
const ZONE_ORDER = ["too_early", "in_zone", "extended", "failed", "no_setup"]
const FLOW_ORDER = ["accumulation", "neutral", "distribution", "no_data"]
const GUARD_ORDER = ["Passed guards", "thin_volume", "upper_circuit", "lower_circuit"]
const EXIT_LABELS = { stop: "Stopped out", target: "Target reached", time: "Time exit (20 sessions)" }

function Stat({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="rounded-xl bg-slate/5 px-4 py-3">
      <p className="text-xs text-slate">{label}</p>
      <p className="font-display text-xl font-bold text-ink">{value}</p>
      {hint && <p className="text-[11px] text-slate">{hint}</p>}
    </div>
  )
}

const fmt = (value: number | null | undefined, suffix = "%") => (value === null || value === undefined ? "—" : `${value}${suffix}`)

export function BacktestPage() {
  const { data, isLoading, isError } = useBacktest()
  const [horizon, setHorizon] = useState<Horizon>("10")

  if (isLoading) return <div className="flex h-[50vh] items-center justify-center"><LoadingSpinner size="lg" /></div>
  if (isError || !data) {
    return (
      <Card className="p-8 text-center">
        <p className="font-semibold text-ink">No backtest yet.</p>
        <p className="mt-1 text-sm text-slate">
          Run <code>bin/rails "nepse:data:setup_history[120]"</code> then <code>bin/rails nepse:data:backtest</code>.
        </p>
      </Card>
    )
  }

  const { results, parameters } = data
  const trades = results.trades
  const heldBack = Object.values(trades.held_back ?? {}).reduce((sum, count) => sum + (count ?? 0), 0)
  const period = results.period

  return (
    <div className="space-y-6">
      <div>
        <h1 className="font-display text-2xl font-bold tracking-tight text-ink sm:text-3xl">Backtest</h1>
        <p className="mt-1 text-sm text-slate">
          How the app's signals would have played out from {period.from} to {period.to}: {period.sessions} sessions, {period.stocks} stocks,{" "}
          {period.snapshots.toLocaleString()} daily snapshots, each built only from data available that day. Updated after each close.
        </p>
      </div>

      <Card>
        <CardHeader
          title="Entry zone now: simulated trades"
          subtitle={`Each signal enters at the next session's open; exits at the invalidation stop, the target, or after ${parameters.max_hold} sessions. Net of ${parameters.round_trip_cost_pct}% round-trip costs. Entries under ${trades.min_risk_pct ?? 1}% above the stop are skipped.`}
        />
        <CardBody>
          <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
            <Stat
              label="Closed trades"
              value={String(trades.closed)}
              hint={[
                trades.open ? `${trades.open} still open` : null,
                trades.skipped ? `${trades.skipped} skipped` : null,
                heldBack ? `${heldBack} held back by guards` : null,
              ].filter(Boolean).join(", ") || undefined}
            />
            <Stat label="Win rate" value={fmt(trades.win_rate_pct)} />
            <Stat label="Avg return" value={fmt(trades.avg_return_pct)} hint={`wins ${fmt(trades.avg_win_pct)}, losses ${fmt(trades.avg_loss_pct)}`} />
            <Stat label="Median R multiple" value={fmt(trades.median_r ?? trades.avg_r, "R")} hint={trades.avg_r === null ? undefined : `average ${trades.avg_r}R`} />
            <Stat label="Profit factor" value={fmt(trades.profit_factor, "")} />
            <Stat label="Avg holding" value={fmt(trades.avg_sessions_held, " sessions")} />
          </div>
          <div className="mt-3 flex flex-wrap gap-2 text-xs">
            {(Object.keys(EXIT_LABELS) as Array<keyof typeof EXIT_LABELS>).map((reason) => (
              <Badge key={reason} tone={reason === "target" ? "gain" : reason === "stop" ? "loss" : "neutral"}>
                {EXIT_LABELS[reason]}: {trades.exits[reason] ?? 0}
              </Badge>
            ))}
          </div>
          {trades.closed < 30 && (
            <p className="mt-3 rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-800">
              Only {trades.closed} closed trades: too few to judge the rules. Treat these numbers as early evidence.
            </p>
          )}

          {trades.list.length > 0 && (
            <div className="mt-4 overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="text-left text-xs text-slate">
                  <tr>
                    <th className="py-1.5 font-medium">Stock</th>
                    <th className="py-1.5 font-medium">Signal</th>
                    <th className="py-1.5 text-right font-medium">Entry</th>
                    <th className="py-1.5 text-right font-medium">Exit</th>
                    <th className="py-1.5 font-medium">Reason</th>
                    <th className="py-1.5 text-right font-medium">Return</th>
                    <th className="py-1.5 text-right font-medium">R</th>
                    <th className="py-1.5 text-right font-medium">Sessions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-mist/60">
                  {[...trades.list].reverse().map((trade) => (
                    <tr key={`${trade.symbol}-${trade.signal_on}`}>
                      <td className="py-1.5 font-semibold"><Link className="hover:underline" to={`/screener/${trade.symbol}`}>{trade.symbol}</Link></td>
                      <td className="py-1.5 text-slate">{trade.signal_on}</td>
                      <td className="py-1.5 text-right font-mono">{trade.entry.toFixed(2)}</td>
                      <td className="py-1.5 text-right font-mono">{trade.exit === undefined ? "open" : trade.exit.toFixed(2)}</td>
                      <td className="py-1.5">{trade.exit_reason ? EXIT_LABELS[trade.exit_reason] : "—"}</td>
                      <td className={cn("py-1.5 text-right font-mono", trade.return_pct === undefined ? "text-slate" : trade.return_pct > 0 ? "text-pine" : "text-ember")}>{fmt(trade.return_pct)}</td>
                      <td className="py-1.5 text-right font-mono">{fmt(trade.r_multiple, "R")}</td>
                      <td className="py-1.5 text-right font-mono">{trade.sessions_held ?? "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardBody>
      </Card>

      <div className="flex flex-wrap items-center gap-3">
        <span className="text-sm font-semibold text-ink">Forward returns after</span>
        <div className="inline-flex rounded-xl border border-mist/80 bg-slate/5 p-1" role="tablist" aria-label="Horizon">
          {HORIZONS.map((value) => (
            <button
              key={value}
              role="tab"
              aria-selected={horizon === value}
              onClick={() => setHorizon(value)}
              className={cn("rounded-lg px-4 py-1.5 text-xs font-semibold", horizon === value ? "bg-white text-ink shadow-xs" : "text-slate")}
            >
              {value} sessions
            </button>
          ))}
        </div>
        <span className="text-xs text-slate">
          All snapshots: avg {fmt(results.baseline[horizon]?.avg_return_pct)}, win rate {fmt(results.baseline[horizon]?.win_rate_pct)} (n={results.baseline[horizon]?.n?.toLocaleString() ?? 0})
        </span>
      </div>

      <div className="grid gap-5 xl:grid-cols-2">
        <Card>
          <CardHeader title="By entry readiness" subtitle="Does a higher score lead to better returns?" />
          <CardBody><GroupChart groups={results.groups.readiness} horizon={horizon} order={parameters.readiness_bands} /></CardBody>
        </Card>
        <Card>
          <CardHeader title="Entry zone now vs everything else" subtitle="The board's criteria against all other snapshots" />
          <CardBody><GroupChart groups={results.groups.entry_zone} horizon={horizon} order={["Entry zone now", "Everything else"]} /></CardBody>
        </Card>
        <Card>
          <CardHeader title="By broker flow" subtitle="Accumulation, distribution and neutral over 20 sessions" />
          <CardBody><GroupChart groups={results.groups.flow_state} horizon={horizon} labels={FLOW_LABELS} order={FLOW_ORDER} /></CardBody>
        </Card>
        <Card>
          <CardHeader title="By zone state" subtitle="Where the price sat against the best setup's zone" />
          <CardBody><GroupChart groups={results.groups.zone_state} horizon={horizon} labels={ZONE_LABELS} order={ZONE_ORDER} /></CardBody>
        </Card>
        {results.groups.setup_type && (
          <Card>
            <CardHeader title="By setup type" subtitle="Stocks inside their entry zone, by the setup that put them there" />
            <CardBody>
              <GroupChart groups={results.groups.setup_type} horizon={horizon} labels={SETUP_TYPE_LABELS} order={["vcp", "base_breakout", "pullback", "ma_pullback"]} />
            </CardBody>
          </Card>
        )}
        {results.groups.extension && (
          <Card>
            <CardHeader title="By extension from the 50-day" subtitle="Distance above the 50-day average in ADRs (the stock's average daily range); 4+ is flagged extended" />
            <CardBody><GroupChart groups={results.groups.extension} horizon={horizon} /></CardBody>
          </Card>
        )}
        {results.groups.day_move && (
          <Card>
            <CardHeader title="By the day's move" subtitle="The signal day's change in ADRs; over 1 is flagged as a big move" />
            <CardBody><GroupChart groups={results.groups.day_move} horizon={horizon} /></CardBody>
          </Card>
        )}
        {results.groups.breakout_age && (
          <Card>
            <CardHeader title="By breakout age" subtitle="Breakout setups in their zone: sessions since the first close above the pivot; 5+ is flagged stale" />
            <CardBody>
              <GroupChart groups={results.groups.breakout_age} horizon={horizon} order={["breakouts in zone: day 0", "breakouts in zone: days 1-2", "breakouts in zone: days 3-4", "breakouts in zone: day 5+"]} />
            </CardBody>
          </Card>
        )}
        {results.groups.guards && (
          <Card>
            <CardHeader title="By tradability guard" subtitle="Charts meeting the entry rules: passed every guard, or held back by thin volume or a circuit" />
            <CardBody><GroupChart groups={results.groups.guards} horizon={horizon} labels={GUARD_LABELS} order={GUARD_ORDER} /></CardBody>
          </Card>
        )}
        <Card>
          <CardHeader title="By trend template" subtitle="Stocks passing 5+ of the 7 price rules vs the rest" />
          <CardBody><GroupChart groups={results.groups.trend} horizon={horizon} order={["5+ of 7 rules", "under 5"]} /></CardBody>
        </Card>
      </div>

      <Card className="p-5 text-sm text-slate">
        <h2 className="font-semibold text-ink">Read these results with care</h2>
        <ul className="mt-2 list-disc space-y-1 pl-5">
          <li>The period is short ({period.sessions} sessions) and mostly a weak market; rules can behave differently in a strong one.</li>
          <li>Daily snapshots of the same stock overlap, so forward-return samples are not independent; the trade simulation avoids this.</li>
          <li>Only stocks listed today are included (delisted ones are missing), which flatters results slightly.</li>
          <li>Prices are adjusted for bonus and rights issues. Fills at the open and exact stop prices are assumed; real fills can be worse.</li>
          <li>Past results don't guarantee future ones. This tests the app's rules; it isn't advice.</li>
        </ul>
      </Card>
    </div>
  )
}
