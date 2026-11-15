import { ChevronDown } from "lucide-react"
import { useState, type ReactNode } from "react"

import { Card, CardBody } from "../../components/ui"
import { cn } from "../../lib/cn"
import { SIGNALS } from "./signals"
import type { CrossoverScan, CrossoverSignal, MarketPhaseName, SignalStats } from "./types"

type Backtest = CrossoverScan["backtest"]

const pct = (value: number | null | undefined) => (value == null ? "—" : `${value > 0 ? "+" : ""}${value.toFixed(2)}%`)
const tone = (value: number | null | undefined) => (value == null ? "text-slate" : value > 0 ? "text-pine" : value < 0 ? "text-ember" : "text-slate")
const cell = (stats: SignalStats | undefined | null) => (stats && stats.n > 0 ? stats : null)
const diff = (stats: SignalStats | null, against: SignalStats | null | undefined) =>
  stats?.avg_return_pct != null && against?.avg_return_pct != null ? Math.round((stats.avg_return_pct - against.avg_return_pct) * 100) / 100 : null
const verdict = (edge: number | null) => (edge == null ? "" : edge > 0.5 ? "better than average" : edge < -0.5 ? "worse than average" : "about average")
const ROWS = [{ key: "all" as const, label: "All stock-days (baseline)" }, ...SIGNALS.map((s) => ({ key: s.key, label: s.label }))]
const PHASES: Array<{ key: MarketPhaseName; label: string }> = [
  { key: "uptrend", label: "NEPSE uptrend" }, { key: "sideways", label: "Sideways" }, { key: "downtrend", label: "Downtrend" },
]

// How the ticked signals did on NEPSE since 2020, in plain numbers, with the full tables underneath.
export function TrackRecord({ backtest, selected }: { backtest: Backtest; selected: CrossoverSignal[] }) {
  const [open, setOpen] = useState(false)
  const base = cell(backtest.signals.all?.["20"])
  const since = backtest.period.from?.slice(0, 4)
  const ticked = selected.filter((key) => cell(backtest.signals[key]?.["20"]))

  return (
    <Card>
      <CardBody>
        <div className="flex flex-wrap items-baseline justify-between gap-2">
          <h2 className="font-display text-base font-bold text-ink">Track record on NEPSE{since ? ` since ${since}` : ""}</h2>
          <p className="text-xs text-slate">20 sessions after each signal began · before costs</p>
        </div>

        {ticked.length === 0 || !base ? (
          <p className="mt-2 text-sm text-slate" aria-label="Track record summary">Tick a signal to see how it did after it began, against the average stock-day.</p>
        ) : (
          <div className="mt-3 space-y-3" aria-label="Track record summary">
            {ticked.map((key) => {
              const stats = cell(backtest.signals[key]?.["20"]) as SignalStats
              const strong = cell(backtest.signals_with_volume?.[key]?.["20"])
              const trade = backtest.trades?.[key]
              const edge = diff(stats, base)
              return (
                <div key={key}>
                  <p className="text-sm text-ink">
                    <b>{SIGNALS.find((s) => s.key === key)?.label}</b>{" "}
                    <span className={cn("font-semibold", edge != null && edge > 0.5 ? "text-pine" : edge != null && edge < -0.5 ? "text-ember" : "text-slate")}>· {verdict(edge)}</span>
                  </p>
                  <dl className="mt-1.5 grid grid-cols-2 gap-2 sm:grid-cols-4">
                    <Stat label="Average return" value={pct(stats.avg_return_pct)} valueTone={tone(stats.avg_return_pct)} note={`all stock-days ${pct(base.avg_return_pct)}`} />
                    <Stat label="Went up" value={stats.win_rate_pct != null ? `${stats.win_rate_pct}%` : "—"} note={`all stock-days ${base.win_rate_pct ?? "—"}%`} />
                    <Stat label={`On ${backtest.strong_volume}× volume`} value={pct(strong?.avg_return_pct)} valueTone={tone(strong?.avg_return_pct)}
                      note={strong?.win_rate_pct != null ? `${strong.win_rate_pct}% went up` : "no samples"} />
                    <Stat label="Crossover-level trades" value={trade?.win_rate_pct != null ? `${trade.win_rate_pct}% won` : "—"}
                      valueTone={trade?.profit_factor != null && trade.profit_factor < 1 ? "text-ember" : "text-ink"}
                      note={trade?.profit_factor != null ? `profit factor ${trade.profit_factor}${trade.profit_factor < 1 ? " (lost money)" : ""}` : "after costs"} />
                  </dl>
                </div>
              )
            })}
          </div>
        )}

        <button type="button" aria-expanded={open} onClick={() => setOpen((value) => !value)}
          className="mt-4 inline-flex items-center gap-1 text-sm font-semibold text-ink hover:underline">
          <ChevronDown className={cn("h-4 w-4 transition-transform", open && "rotate-180")} /> {open ? "Hide track record details" : "Track record details"}
        </button>
        {open && <Details backtest={backtest} selected={selected} />}
      </CardBody>
    </Card>
  )
}

function Stat({ label, value, note, valueTone = "text-ink" }: { label: string; value: string; note: string; valueTone?: string }) {
  return (
    <div className="rounded-xl bg-slate/5 px-3 py-2">
      <dt className="text-[11px] font-semibold text-slate">{label}</dt>
      <dd className={cn("font-mono text-base font-semibold", valueTone)}>{value}</dd>
      <dd className="text-[11px] text-slate">{note}</dd>
    </div>
  )
}

function Section({ title, note, children }: { title: string; note: ReactNode; children: ReactNode }) {
  return (
    <section className="mt-5">
      <h3 className="text-sm font-bold text-ink">{title}</h3>
      <p className="text-xs text-slate">{note}</p>
      <div className="mt-2 overflow-x-auto">{children}</div>
    </section>
  )
}

function Details({ backtest, selected }: { backtest: Backtest; selected: CrossoverSignal[] }) {
  const [horizon, setHorizon] = useState(20)
  const h = String(horizon)
  const base = cell(backtest.signals.all?.[h])
  const years = Object.keys(backtest.by_year?.all ?? {})
  const bold = (key: string) => key !== "all" && selected.includes(key as CrossoverSignal) && "font-semibold"
  const th = "py-1.5 pr-3 text-right font-semibold"

  return (
    <div className="mt-2">
      <Section title="All signals" note={<>Every time a signal began, {backtest.period.from ?? "—"} to {backtest.period.to ?? "—"}: the return over the next sessions (close to close), against every stock-day (the baseline).</>}>
        <div className="mb-2 inline-flex rounded-xl border border-mist/80 bg-slate/5 p-1" role="tablist">
          {backtest.horizons.map((value) => (
            <button key={value} type="button" role="tab" aria-selected={horizon === value} onClick={() => setHorizon(value)}
              className={cn("rounded-lg px-3 py-1 text-sm font-semibold", horizon === value ? "bg-white text-ink shadow-sm" : "text-slate")}>
              {value} sessions
            </button>
          ))}
        </div>
        <table className="w-full text-sm" aria-label="Signal track record">
          <thead className="text-left text-xs text-slate">
            <tr>
              <th className="py-1.5 pr-3 font-semibold">Signal</th><th className={th}>Samples</th><th className={th}>Avg return</th>
              <th className={th}>Went up</th><th className={th}>vs baseline</th><th className={th}>On {backtest.strong_volume}× volume</th><th className={th}>Went up</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-mist/60">
            {ROWS.map(({ key, label }) => {
              const stats = cell(backtest.signals[key]?.[h])
              const strong = key === "all" ? null : cell(backtest.signals_with_volume?.[key]?.[h])
              const edge = key === "all" ? null : diff(stats, base)
              return (
                <tr key={key} className={cn(bold(key))}>
                  <td className="py-1.5 pr-3 text-ink">{label}</td>
                  <td className="py-1.5 pr-3 text-right font-mono text-slate">{stats?.n.toLocaleString("en-US") ?? "—"}</td>
                  <td className={cn("py-1.5 pr-3 text-right font-mono", tone(stats?.avg_return_pct))}>{pct(stats?.avg_return_pct)}</td>
                  <td className="py-1.5 pr-3 text-right font-mono">{stats?.win_rate_pct != null ? `${stats.win_rate_pct}%` : "—"}</td>
                  <td className={cn("py-1.5 pr-3 text-right font-mono", tone(edge))}>{key === "all" ? "" : pct(edge)}</td>
                  <td className={cn("py-1.5 pr-3 text-right font-mono", tone(strong?.avg_return_pct))}>{key === "all" ? "" : pct(strong?.avg_return_pct)}</td>
                  <td className="py-1.5 pr-3 text-right font-mono">{strong?.win_rate_pct != null ? `${strong.win_rate_pct}%` : ""}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </Section>

      {backtest.by_phase && (
        <Section title="By NEPSE phase" note={<>Average return 20 sessions after each signal began, by NEPSE's phase that day (20-day average against the 50-day). ▼ = worse than the baseline in that phase.</>}>
          <table className="w-full text-sm" aria-label="Track record by phase">
            <thead className="text-left text-xs text-slate">
              <tr><th className="py-1.5 pr-3 font-semibold">Signal</th>{PHASES.map((phase) => <th key={phase.key} className={th}>{phase.label}</th>)}</tr>
            </thead>
            <tbody className="divide-y divide-mist/60">
              {ROWS.map(({ key, label }) => (
                <tr key={key} className={cn(bold(key))}>
                  <td className="py-1.5 pr-3 text-ink">{label}</td>
                  {PHASES.map((phase) => {
                    const stats = cell(backtest.by_phase?.[key]?.[phase.key])
                    const worse = key !== "all" && (diff(stats, cell(backtest.by_phase?.all?.[phase.key])) ?? 0) < 0
                    return (
                      <td key={phase.key} className={cn("whitespace-nowrap py-1.5 pr-3 text-right font-mono", tone(stats?.avg_return_pct))}
                        title={stats ? `${stats.n.toLocaleString("en-US")} samples, ${stats.win_rate_pct}% went up` : undefined}>
                        {pct(stats?.avg_return_pct)}{worse ? " ▼" : ""}
                      </td>
                    )
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </Section>
      )}

      {years.length > 0 && backtest.by_year && (
        <Section title="By year" note={<>Average return {backtest.year_horizon} sessions after each signal began, by the year it began. ▼ = worse than the baseline that year.</>}>
          <table className="w-full text-sm" aria-label="Track record by year">
            <thead className="text-left text-xs text-slate">
              <tr><th className="py-1.5 pr-3 font-semibold">Signal</th>{years.map((year) => <th key={year} className={th}>{year}</th>)}</tr>
            </thead>
            <tbody className="divide-y divide-mist/60">
              {ROWS.map(({ key, label }) => (
                <tr key={key} className={cn(bold(key))}>
                  <td className="py-1.5 pr-3 text-ink">{label}</td>
                  {years.map((year) => {
                    const stats = cell(backtest.by_year?.[key]?.[year])
                    const worse = key !== "all" && (diff(stats, cell(backtest.by_year?.all?.[year])) ?? 0) < 0
                    return <td key={year} className={cn("whitespace-nowrap py-1.5 pr-3 text-right font-mono", tone(stats?.avg_return_pct))}>{pct(stats?.avg_return_pct)}{worse ? " ▼" : ""}</td>
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </Section>
      )}

      {backtest.trades && backtest.trade_rules && (
        <Section title="Trading the crossover levels" note={<>Buy at the next open if it's inside the entry zone; sell at the stop or target ({backtest.trade_rules.reward_multiple}× the risk), or after{" "}
          {backtest.trade_rules.max_hold} sessions; {backtest.trade_rules.cost_pct}% round-trip costs. Stocks with a board setup show that setup's levels instead.</>}>
          <table className="w-full text-sm" aria-label="Crossover level trades">
            <thead className="text-left text-xs text-slate">
              <tr><th className="py-1.5 pr-3 font-semibold">Signal</th><th className={th}>Trades</th><th className={th}>Won</th><th className={th}>Avg / trade</th><th className={th}>Avg R</th><th className={th}>Profit factor</th></tr>
            </thead>
            <tbody className="divide-y divide-mist/60">
              {SIGNALS.map((signal) => {
                const t = backtest.trades?.[signal.key]
                return (
                  <tr key={signal.key} className={cn(bold(signal.key))}>
                    <td className="py-1.5 pr-3 text-ink">{signal.label}</td>
                    <td className="py-1.5 pr-3 text-right font-mono text-slate">{t?.closed ?? 0}</td>
                    <td className="py-1.5 pr-3 text-right font-mono">{t?.win_rate_pct != null ? `${t.win_rate_pct}%` : "—"}</td>
                    <td className={cn("py-1.5 pr-3 text-right font-mono", tone(t?.avg_return_pct))}>{pct(t?.avg_return_pct)}</td>
                    <td className={cn("py-1.5 pr-3 text-right font-mono", tone(t?.avg_r))}>{t?.avg_r != null ? `${t.avg_r > 0 ? "+" : ""}${t.avg_r}R` : "—"}</td>
                    <td className={cn("py-1.5 pr-3 text-right font-mono", t?.profit_factor != null && t.profit_factor < 1 ? "text-ember" : "text-ink")}>{t?.profit_factor ?? "—"}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
          <p className="mt-1 text-xs text-slate">Profit factor = gains ÷ losses; under 1 means the rule lost money overall.</p>
        </Section>
      )}

      <p className="mt-4 text-xs text-slate">
        The market mattered more than the signal: when NEPSE was in an uptrend, most signals did well ahead of the baseline; in downtrends
        they did worse than it. Every signal did better when it began on strong volume. Treat these signals as a shortlist to study, not entries on
        their own; the Entry zone board's rules were tested separately.
      </p>
    </div>
  )
}
