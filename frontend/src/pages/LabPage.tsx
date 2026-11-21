import { FlaskConical } from "lucide-react"
import { useMemo, useState, type ReactNode } from "react"
import { Link } from "react-router-dom"

import { Badge, Button, Card, CardBody, LoadingSpinner } from "../components/ui"
import { useLab } from "../features/lab/api"
import { STRATEGY_HELP } from "../features/lab/strategies"
import type { LabCandidate, LabPaperTrade, LabReport, LabStats, LabStrategyKey } from "../features/lab/types"
import type { MarketPhaseName } from "../features/scanner/types"
import { cn } from "../lib/cn"

const money = (value: number | null | undefined) => (value == null ? "—" : value.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 }))
const pct = (value: number | null | undefined) => (value == null ? "—" : `${value > 0 ? "+" : ""}${value.toFixed(2)}%`)
const tone = (value: number | null | undefined) => (value == null ? "text-slate" : value > 0 ? "text-pine" : value < 0 ? "text-ember" : "text-slate")
const pfTone = (pf: number | null | undefined) => (pf == null ? "text-slate" : pf >= 1.3 ? "text-pine" : pf < 1 ? "text-ember" : "text-ink")
const PHASES: Array<{ key: MarketPhaseName; label: string }> = [{ key: "uptrend", label: "NEPSE uptrend" }, { key: "sideways", label: "Sideways" }, { key: "downtrend", label: "Downtrend" }]
const STATUS_TONE: Record<LabPaperTrade["status"], string> = {
  pending: "bg-slate/10 text-slate", open: "bg-amber-100 text-amber-800", closed: "bg-ink/10 text-ink", skipped: "bg-slate/10 text-slate",
}

export function LabPage() {
  const { data, isLoading, isError, refetch } = useLab()

  if (isLoading) return <div className="flex h-[50vh] items-center justify-center"><LoadingSpinner size="lg" /></div>
  if (isError || !data) {
    return (
      <Card className="p-8 text-center">
        <p className="font-display text-lg font-bold text-ink">Couldn't load the Strategy Lab</p>
        <Button className="mt-4" variant="outline" onClick={() => void refetch()}>Retry</Button>
      </Card>
    )
  }

  return (
    <div className="space-y-5">
      <header>
        <h1 className="flex items-center gap-2 font-display text-2xl font-bold tracking-tight text-ink sm:text-3xl"><FlaskConical className="h-6 w-6" /> Strategy Lab</h1>
        <p className="mt-1 max-w-3xl text-sm text-slate">
          Two strategies adapted from <a className="font-semibold text-ink underline" href="https://github.com/Open-Trader/opentrader" target="_blank" rel="noreferrer">opentrader</a>{" "}
          for NEPSE (daily bars, buy-only), backtested on every stock from {data.period.from.slice(0, 4)} to <b className="text-ink">{data.as_of ?? "—"}</b> with{" "}
          {data.rules.cost_pct}% round-trip costs. A stock is listed only when a strategy triggers today <i>and</i>{" "}has a good record on that stock. Rule checks and
          paper trades, not recommendations; a past record doesn't promise future profit.
        </p>
      </header>

      <HonestyBanner data={data} />

      <Section title="Today's candidates" note={<>Triggered on the {data.as_of ?? "latest"} close, on stocks where the strategy has {data.rules.min_trades}+ trades, a profit factor above {data.rules.min_profit_factor} and a positive record since {data.oos_from.slice(0, 4)} (out of sample).</>}>
        {data.candidates.length === 0 ? <NoCandidates data={data} /> : (
          <div className="grid gap-3 xl:grid-cols-2">{data.candidates.map((candidate) => <CandidateCard key={`${candidate.symbol}-${candidate.strategy}`} candidate={candidate} />)}</div>
        )}
      </Section>

      <Leaderboard data={data} />
      <PaperTrades data={data} />
    </div>
  )
}

function Section({ title, note, children }: { title: string; note?: ReactNode; children: ReactNode }) {
  return (
    <section className="space-y-2">
      <div>
        <h2 className="font-display text-lg font-bold text-ink">{title}</h2>
        {note && <p className="text-xs text-slate">{note}</p>}
      </div>
      {children}
    </section>
  )
}

// What the market-wide record says, in plain words, next to NEPSE's phase today.
function HonestyBanner({ data }: { data: LabReport }) {
  const phase = data.market_phase?.phase ?? null
  const lines = data.strategies.map(({ key, label }) => {
    const all = data.leaderboard[key]
    const here = phase ? all?.by_phase?.[phase] : undefined
    return { key, label, all, here }
  })
  return (
    <Card>
      <CardBody>
        <p className="text-sm font-semibold text-ink">Across all stocks since {data.period.from.slice(0, 4)}:</p>
        <ul className="mt-1 space-y-1 text-sm text-slate">
          {lines.map(({ key, label, all, here }) => (
            <li key={key}>
              <b className="text-ink">{label}</b>: {all?.trades ?? 0} trades, profit factor{" "}
              <span className={cn("font-mono font-semibold", pfTone(all?.profit_factor))}>{all?.profit_factor ?? "—"}</span>
              {all?.profit_factor != null && all.profit_factor < 1 && <span className="text-ember"> (lost money overall)</span>}
              {phase && here && here.trades > 0 && (
                <> · when NEPSE was {phase}, as now: <span className={cn("font-mono font-semibold", pfTone(here.profit_factor))}>{here.profit_factor ?? "—"}</span> ({here.trades} trades)</>
              )}
            </li>
          ))}
        </ul>
        <p className="mt-2 text-xs text-slate">
          Profit factor = gains ÷ losses (above 1 made money). A strategy that loses across the market can still work on particular stocks; that's
          what the per-stock record checks, but with ~300 stocks some good records are luck, which the out-of-sample check only partly filters.
        </p>
      </CardBody>
    </Card>
  )
}

function NoCandidates({ data }: { data: LabReport }) {
  return (
    <Card className="p-5 text-sm text-slate">
      <p className="font-semibold text-ink">No stock qualifies today.</p>
      <ul className="mt-2 space-y-1" aria-label="Qualifying stocks">
        {data.strategies.map(({ key, label }) => {
          const list = data.qualifying[key] ?? []
          return (
            <li key={key}>
              <b className="text-ink">{label}</b>:{" "}
              {list.length === 0 ? "no stock has a good enough record."
                : <>watching {list.length} {list.length === 1 ? "stock" : "stocks"} with a good record: {list.map((q, i) => (
                    <span key={q.symbol}>{i > 0 && ", "}<Link className="font-semibold text-ink hover:underline" to={`/screener/${encodeURIComponent(q.symbol)}`}>{q.symbol}</Link> <span className="font-mono">(PF {q.profit_factor ?? "—"})</span></span>
                  ))}. They appear here on a day the strategy triggers.</>}
            </li>
          )
        })}
      </ul>
    </Card>
  )
}

function CandidateCard({ candidate: c }: { candidate: LabCandidate }) {
  const help = STRATEGY_HELP[c.strategy]
  return (
    <article aria-label={`${c.symbol} candidate`} className="rounded-2xl border border-mist/80 bg-white p-4 shadow-sm">
      <header className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <Link to={`/screener/${encodeURIComponent(c.symbol)}`} className="font-display text-lg font-bold text-ink hover:underline">{c.symbol}</Link>
          <p className="truncate text-xs text-slate" title={c.name}>{c.sector}</p>
        </div>
        <div className="text-right">
          <p className="font-mono text-lg font-semibold text-ink">{money(c.close)}</p>
          <p className={cn("font-mono text-xs font-semibold", tone(c.change_pct))}>{pct(c.change_pct)}</p>
        </div>
      </header>
      <p className="mt-2 text-xs"><span title={help.rule}><Badge tone="neutral">{help.label}</Badge></span>{c.rsi != null && c.strategy === "rsi_reversion" && <span className="ml-2 text-slate">RSI {c.rsi.toFixed(0)}</span>}</p>
      <dl className="mt-3 grid grid-cols-2 gap-2 text-sm sm:grid-cols-4">
        <Box label="Entry range" value={`${money(c.levels.entry_low)}–${money(c.levels.entry_high)}`} tone="text-pine" />
        <Box label="Stop" value={money(c.levels.stop)} tone="text-ember" note={`${((1 - c.levels.stop / c.levels.entry_low) * 100).toFixed(1)}% below`} />
        <Box label="Target" value={money(c.levels.target)} tone="text-pine" note={`+${((c.levels.target / c.levels.entry_low - 1) * 100).toFixed(1)}%`} />
        <Box label="Reward : risk" value={`${c.levels.reward_risk}`} />
      </dl>
      <p className="mt-3 text-xs text-slate" aria-label="Record on this stock">
        On {c.symbol} since 2020: <b className="text-ink">{c.record.trades} trades</b>, {c.record.win_rate_pct}% won, profit factor{" "}
        <b className={pfTone(c.record.profit_factor)}>{c.record.profit_factor ?? "—"}</b>, average {pct(c.record.avg_return_pct)} per trade, worst run{" "}
        {c.record.max_drawdown_pct}% · since 2025: {c.record.oos.trades} trades, {pct(c.record.oos.avg_return_pct)} average.
        {c.readiness != null && <> Readiness {c.readiness}.</>}
      </p>
      <p className="mt-1 text-[11px] text-slate">{help.exit}</p>
    </article>
  )
}

function Box({ label, value, note, tone: valueTone = "text-ink" }: { label: string; value: string; note?: string; tone?: string }) {
  return (
    <div className="rounded-xl bg-slate/5 px-3 py-2">
      <dt className="text-[11px] font-semibold text-slate">{label}</dt>
      <dd className={cn("font-mono font-semibold", valueTone)}>{value}</dd>
      {note && <dd className="text-[11px] text-slate">{note}</dd>}
    </div>
  )
}

function Leaderboard({ data }: { data: LabReport }) {
  const years = useMemo(() => Array.from(new Set(Object.values(data.leaderboard).flatMap((entry) => Object.keys(entry.by_year ?? {})))).sort(), [data])
  const th = "py-1.5 pr-3 text-right font-semibold"
  const cell = (stats?: LabStats) => (
    <span className={cn("font-mono", pfTone(stats?.profit_factor))} title={stats ? `${stats.trades} trades, ${stats.win_rate_pct ?? "—"}% won, ${pct(stats.avg_return_pct)} average` : undefined}>
      {stats && stats.trades > 0 ? (stats.profit_factor ?? "—") : "—"}
    </span>
  )
  return (
    <Section title="Strategy leaderboard" note={<>Every trade across all stocks since {data.period.from.slice(0, 4)}, after costs. Numbers in the phase and year columns are profit factors (hover for details).</>}>
      <Card>
        <CardBody className="space-y-4">
          <div className="overflow-x-auto">
            <table className="w-full text-sm" aria-label="Strategy leaderboard">
              <thead className="text-left text-xs text-slate">
                <tr>
                  <th className="py-1.5 pr-3 font-semibold">Strategy</th><th className={th}>Trades</th><th className={th}>Won</th><th className={th}>Avg / trade</th>
                  <th className={th}>Avg R</th><th className={th}>Profit factor</th><th className={th}>Since {data.oos_from.slice(0, 4)}</th>
                  {PHASES.map((phase) => <th key={phase.key} className={th}>{phase.label}</th>)}
                </tr>
              </thead>
              <tbody className="divide-y divide-mist/60">
                {data.strategies.map(({ key, label }) => {
                  const entry = data.leaderboard[key]
                  return (
                    <tr key={key}>
                      <td className="py-1.5 pr-3 text-ink" title={STRATEGY_HELP[key].rule}>{label}</td>
                      <td className="py-1.5 pr-3 text-right font-mono text-slate">{entry.trades.toLocaleString("en-US")}</td>
                      <td className="py-1.5 pr-3 text-right font-mono">{entry.win_rate_pct ?? "—"}%</td>
                      <td className={cn("py-1.5 pr-3 text-right font-mono", tone(entry.avg_return_pct))}>{pct(entry.avg_return_pct)}</td>
                      <td className="py-1.5 pr-3 text-right font-mono">{entry.avg_r ?? "—"}</td>
                      <td className="py-1.5 pr-3 text-right">{cell(entry)}</td>
                      <td className="py-1.5 pr-3 text-right">{cell(entry.oos)}</td>
                      {PHASES.map((phase) => <td key={phase.key} className="py-1.5 pr-3 text-right">{cell(entry.by_phase?.[phase.key])}</td>)}
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-sm" aria-label="Leaderboard by year">
              <thead className="text-left text-xs text-slate">
                <tr><th className="py-1.5 pr-3 font-semibold">Profit factor by year</th>{years.map((year) => <th key={year} className={th}>{year}</th>)}</tr>
              </thead>
              <tbody className="divide-y divide-mist/60">
                {data.strategies.map(({ key, label }) => (
                  <tr key={key}>
                    <td className="py-1.5 pr-3 text-ink">{label}</td>
                    {years.map((year) => <td key={year} className="py-1.5 pr-3 text-right">{cell(data.leaderboard[key].by_year?.[year])}</td>)}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <ul className="space-y-1 text-xs text-slate">
            {data.strategies.map(({ key }) => <li key={key}><b className="text-ink">{STRATEGY_HELP[key].label}:</b> {STRATEGY_HELP[key].rule} {STRATEGY_HELP[key].exit}</li>)}
          </ul>
        </CardBody>
      </Card>
    </Section>
  )
}

function PaperTrades({ data }: { data: LabReport }) {
  const [show, setShow] = useState<"all" | "active" | "closed">("all")
  const { summary, trades } = data.paper_trades
  const shown = trades.filter((t) => show === "all" || (show === "active" ? t.status === "open" || t.status === "pending" : t.status === "closed"))
  const label = (key: LabStrategyKey) => data.strategies.find((s) => s.key === key)?.label ?? key

  return (
    <Section title="Paper trades" note="Every candidate is recorded on the day it appears and followed with the same rules each night: filled at the next open if inside the entry range, then closed at the stop, target, strategy exit or time limit. Nothing is bought or sold.">
      <Card>
        <CardBody>
          <dl className="grid grid-cols-2 gap-2 sm:grid-cols-5" aria-label="Paper trade summary">
            <Box label="Recorded" value={String(summary.total)} note={`${summary.pending} waiting · ${summary.skipped} skipped`} />
            <Box label="Open" value={String(summary.open)} />
            <Box label="Closed" value={String(summary.closed)} />
            <Box label="Won" value={summary.win_rate_pct == null ? "—" : `${summary.win_rate_pct}%`} />
            <Box label="Avg / trade" value={pct(summary.avg_return_pct)} tone={tone(summary.avg_return_pct)} note={summary.profit_factor != null ? `profit factor ${summary.profit_factor}` : undefined} />
          </dl>
          {trades.length === 0 ? (
            <p className="mt-3 text-sm text-slate">No paper trades yet. The first is recorded the next time a candidate appears (after the nightly analysis).</p>
          ) : (
            <>
              <div className="mt-3 inline-flex rounded-xl border border-mist/80 bg-slate/5 p-1" role="tablist">
                {(["all", "active", "closed"] as const).map((value) => (
                  <button key={value} type="button" role="tab" aria-selected={show === value} onClick={() => setShow(value)}
                    className={cn("rounded-lg px-3 py-1 text-sm font-semibold capitalize", show === value ? "bg-white text-ink shadow-sm" : "text-slate")}>{value}</button>
                ))}
              </div>
              <div className="mt-2 overflow-x-auto">
                <table className="w-full text-sm" aria-label="Paper trades">
                  <thead className="text-left text-xs text-slate">
                    <tr>
                      <th className="py-1.5 pr-3 font-semibold">Stock</th><th className="py-1.5 pr-3 font-semibold">Strategy</th><th className="py-1.5 pr-3 font-semibold">Signal</th>
                      <th className="py-1.5 pr-3 font-semibold">Status</th><th className="py-1.5 pr-3 text-right font-semibold">Entry</th>
                      <th className="py-1.5 pr-3 text-right font-semibold">Stop / target</th><th className="py-1.5 pr-3 text-right font-semibold">Exit</th>
                      <th className="py-1.5 text-right font-semibold">Return</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-mist/60">
                    {shown.map((t) => (
                      <tr key={t.id}>
                        <td className="py-1.5 pr-3"><Link className="font-semibold text-ink hover:underline" to={`/screener/${encodeURIComponent(t.symbol)}`}>{t.symbol}</Link></td>
                        <td className="py-1.5 pr-3 text-slate">{label(t.strategy)}</td>
                        <td className="py-1.5 pr-3 font-mono text-xs text-slate">{t.signal_on}</td>
                        <td className="py-1.5 pr-3"><span className={cn("rounded-full px-2 py-0.5 text-xs font-semibold capitalize", STATUS_TONE[t.status])} title={t.exit_reason ?? undefined}>{t.status}</span></td>
                        <td className="py-1.5 pr-3 text-right font-mono">{t.entry_price != null ? money(t.entry_price) : `${money(t.levels.entry_low)}–${money(t.levels.entry_high)}`}</td>
                        <td className="py-1.5 pr-3 text-right font-mono text-xs"><span className="text-ember">{money(t.levels.stop)}</span> / <span className="text-pine">{money(t.levels.target)}</span></td>
                        <td className="py-1.5 pr-3 text-right font-mono text-xs">{t.exit_price != null ? `${money(t.exit_price)}${t.status === "open" ? " (now)" : ""}` : "—"}{t.exit_reason && t.status === "closed" ? ` · ${t.exit_reason.replace("_", " ")}` : ""}</td>
                        <td className={cn("py-1.5 text-right font-mono", tone(t.return_pct))}>{pct(t.return_pct)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          )}
        </CardBody>
      </Card>
    </Section>
  )
}
