import { format, parseISO } from "date-fns"
import { ArrowLeft } from "lucide-react"
import { useMemo } from "react"
import { useNavigate, useParams } from "react-router-dom"
import { Badge, Button, Card, CardBody, CardHeader, LoadingSpinner } from "../components/ui"
import { useStockAnalysis } from "../features/screener/api"
import type { PriceLevel, RsLine, StockAnalysis, VolumePace } from "../features/screener/types"
import { SETUP_STATE_LABELS } from "../features/screener/types"
import { CandlestickChart, type ChartLevels } from "../features/readiness/CandlestickChart"
import { CorporateActionsCard } from "../features/corporate/CorporateActionsCard"
import { BrokerFlowCard } from "../features/flows/BrokerFlowCard"
import { SETUP_TYPE_LABELS } from "../features/readiness/labels"
import { ReadinessCard } from "../features/readiness/ReadinessCard"
import { AddToWatchlistButton } from "../features/watchlist/AddToWatchlist"
import { useWatchlist } from "../features/watchlist/api"
import { formatPrice } from "../features/watchlist/labels"
import type { WatchlistItem } from "../features/watchlist/types"
import { cn } from "../lib/cn"

const STRUCTURE_LABELS: Record<string, string> = {
  higher_high_higher_low: "Higher Highs, Higher Lows",
  lower_high_lower_low: "Lower Highs, Lower Lows",
  mixed: "Mixed Structure",
}

function prettyLabel(value: string | null | undefined): string {
  if (!value) return "—"
  return value
    .split("_")
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(" ")
}

function changeTone(change: number): "gain" | "loss" | "neutral" {
  if (change > 0) return "gain"
  if (change < 0) return "loss"
  return "neutral"
}

// "Pullback to support" -> "pullback to support"; acronyms like "VCP" stay as they are.
function inSentence(label: string) {
  return /^[A-Z]{2}/.test(label) ? label : label.charAt(0).toLowerCase() + label.slice(1)
}

const signedPct = (value: number) => `${value > 0 ? "+" : ""}${value.toFixed(2)}%`

// How the stock did against NEPSE, from the RS line.
function RsSummary({ rsLine }: { rsLine: RsLine }) {
  const periods = (["20", "60"] as const).filter((key) => rsLine.change[key] !== null)
  return (
    <p className="mb-3 text-sm text-slate" aria-label="Relative strength vs NEPSE">
      <span className="font-semibold text-ink">RS vs NEPSE:</span>{" "}
      {periods.length === 0
        ? "not enough history yet"
        : periods.map((key, i) => {
            const change = rsLine.change[key] as number
            return (
              <span key={key}>
                {i > 0 && ", "}
                <b className={change >= 0 ? "text-pine" : "text-ember"}>{signedPct(change)}</b> over {key} sessions
              </span>
            )
          })}
      {rsLine.last_new_high_on && (
        <>
          {" · "}last RS new high {format(parseISO(rsLine.last_new_high_on), "MMM d")}
          {rsLine.last_new_high_leads_price && " (before price)"}
        </>
      )}
    </p>
  )
}

const shares = (value: number) => value.toLocaleString("en-US")

// During the session: today's volume so far and where it's heading by the close.
function VolumePaceLine({ pace }: { pace: VolumePace }) {
  const strong = pace.ratio !== null && pace.ratio >= 1.5
  return (
    <p className="rounded-xl bg-white/80 px-4 py-2 text-sm text-slate" aria-label="Volume pace">
      <b className="text-ink">Volume today:</b> {shares(pace.so_far)} so far
      {pace.projected === null ? (
        " · too early in the session to project"
      ) : (
        <>
          {" · "}projected {shares(pace.projected)} by the close
          {pace.ratio !== null && pace.average !== null && (
            <> = <b className={strong ? "text-pine" : "text-ink"}>{pace.ratio}×</b> the 50-day average of {shares(pace.average)}</>
          )}
        </>
      )}
      <span className="text-xs">
        {" "}({pace.curve.source === "learned" ? `pace learned from the last ${pace.curve.sessions} sessions` : "estimated pace until enough NEPSE sessions are recorded"})
      </span>
    </p>
  )
}

function PriceChart({ data, plan }: { data: StockAnalysis; plan?: WatchlistItem }) {
  // Your watchlist levels when you track the stock, otherwise the nightly best setup.
  const readiness = data.readiness
  const levels = useMemo<ChartLevels | undefined>(() => {
    if (plan) {
      return { entryLow: plan.entry_zone_low, entryHigh: plan.entry_zone_high, invalidation: plan.invalidation_price, target: plan.target_price, pivot: plan.pivot_price }
    }
    if (readiness?.entry_zone_low) {
      return { entryLow: readiness.entry_zone_low, entryHigh: readiness.entry_zone_high, invalidation: readiness.invalidation_price, target: readiness.target_price, pivot: readiness.pivot_price }
    }
    return undefined
  }, [plan, readiness])
  const source = plan ? "your watchlist levels" : readiness?.setup_type ? `the ${inSentence(SETUP_TYPE_LABELS[readiness.setup_type])} setup found on ${readiness.traded_on}` : null

  return (
    <Card>
      <CardHeader
        title="Price &amp; Trend"
        subtitle={
          levels
            ? `Entry zone ${formatPrice(levels.entryLow)}–${formatPrice(levels.entryHigh)}, invalidation ${formatPrice(levels.invalidation)}${levels.target ? `, target ${formatPrice(levels.target)}` : ""} (from ${source})`
            : "Daily candles, volume and moving averages"
        }
      />
      <CardBody>
        {data.rs_line && data.rs_line.points.length > 1 && <RsSummary rsLine={data.rs_line} />}
        <CandlestickChart candles={data.candles} levels={levels} contractions={data.vcp.contractions} addedOn={plan?.created_at.slice(0, 10)} rsLine={data.rs_line?.points} />
      </CardBody>
    </Card>
  )
}

function VcpContractions({ data }: { data: StockAnalysis }) {
  const contractions = data.vcp.contractions
  const maxDepth = Math.max(...contractions.map((c) => c.depth_pct), 1)
  const maxVolume = Math.max(...contractions.map((c) => c.volume), 1)

  return (
    <Card>
      <CardHeader
        title="Volatility Contraction"
        subtitle={
          <>
            {prettyLabel(data.vcp.classification)}
            {data.vcp.contraction_sequence_text ? ` · ${data.vcp.contraction_sequence_text}` : ""}
          </>
        }
      />
      <CardBody>
        {contractions.length === 0 ? (
          <p className="text-sm text-slate/70">No contractions detected in the current base.</p>
        ) : (
          <div className="space-y-3">
            {contractions.map((c, i) => {
              const shrinking = i > 0 && c.depth_pct < contractions[i - 1].depth_pct
              const volumeOpacity = 0.4 + 0.6 * (c.volume / maxVolume)
              return (
                <div key={c.name}>
                  <div className="mb-1 flex items-center justify-between text-xs">
                    <span className="font-bold text-ink">{c.name}</span>
                    <span className="text-slate/80">{c.depth_pct}%</span>
                  </div>
                  <div className="h-4 w-full rounded-full bg-slate/10">
                    <div
                      className={cn("h-4 rounded-full", shrinking || i === 0 ? "bg-pine" : "bg-ember")}
                      style={{ width: `${(c.depth_pct / maxDepth) * 100}%`, opacity: volumeOpacity }}
                    />
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </CardBody>
    </Card>
  )
}

function VcpScoreBreakdown({ data }: { data: StockAnalysis }) {
  const total = data.vcp_breakdown.reduce((sum, c) => sum + c.score, 0)
  const maxTotal = data.vcp_breakdown.reduce((sum, c) => sum + c.max, 0)

  return (
    <Card>
      <CardHeader title="VCP Score" subtitle="Component breakdown of the setup quality score" />
      <CardBody>
        <div className="mb-4">
          <span className="font-display text-3xl font-bold text-ink">
            {total}/{maxTotal}
          </span>
        </div>
        <div className="space-y-3">
          {data.vcp_breakdown.map((c) => (
            <div key={c.component}>
              <div className="mb-1 flex items-center justify-between text-xs">
                <span className="font-bold text-ink">{c.label}</span>
                <span className="text-slate/80">
                  {c.score}/{c.max}
                </span>
              </div>
              <div className="h-2 rounded-full bg-slate/15">
                <div className="h-2 rounded-full bg-ink" style={{ width: `${c.max > 0 ? (c.score / c.max) * 100 : 0}%` }} />
              </div>
            </div>
          ))}
        </div>
      </CardBody>
    </Card>
  )
}

function LevelRow({ level }: { level: PriceLevel }) {
  return (
    <tr className="border-t border-mist/60">
      <td className="py-2 text-sm font-bold text-ink">Rs. {level.level.toLocaleString()}</td>
      <td className="py-2 text-sm text-slate/80">{level.touch_count}</td>
      <td className="py-2 text-sm text-slate/80">{level.pct_distance}%</td>
    </tr>
  )
}

function PriceActionCard({ data }: { data: StockAnalysis }) {
  const pa = data.price_action
  return (
    <Card>
      <CardHeader title="Price Action Structure" subtitle="Swing structure and key levels" />
      <CardBody>
        <div className="mb-4 flex flex-wrap items-center gap-2">
          <span className="text-sm text-ink">{STRUCTURE_LABELS[pa.structure] ?? prettyLabel(pa.structure)}</span>
          <Badge tone={pa.trend === "uptrend" ? "gain" : pa.trend === "downtrend" ? "loss" : "neutral"}>
            {prettyLabel(pa.trend)}
          </Badge>
          <span className="text-xs text-slate/70">Confidence {Math.round(pa.confidence * 100)}%</span>
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <p className="mb-1 text-xs font-bold uppercase tracking-wide text-slate/70">Swing highs</p>
            <ul className="space-y-1 text-sm text-ink">
              {pa.swing_highs.map((s) => (
                <li key={`h-${s.traded_on}-${s.price}`}>
                  Rs. {s.price.toLocaleString()} · {format(parseISO(s.traded_on), "MMM dd")}
                </li>
              ))}
            </ul>
          </div>
          <div>
            <p className="mb-1 text-xs font-bold uppercase tracking-wide text-slate/70">Swing lows</p>
            <ul className="space-y-1 text-sm text-ink">
              {pa.swing_lows.map((s) => (
                <li key={`l-${s.traded_on}-${s.price}`}>
                  Rs. {s.price.toLocaleString()} · {format(parseISO(s.traded_on), "MMM dd")}
                </li>
              ))}
            </ul>
          </div>
        </div>
        <table className="mt-4 w-full text-left">
          <thead>
            <tr className="text-xs uppercase tracking-wide text-slate/70">
              <th className="py-1">Level</th>
              <th className="py-1">Touches</th>
              <th className="py-1">Distance</th>
            </tr>
          </thead>
          <tbody>
            {pa.support_levels[0] && <LevelRow level={pa.support_levels[0]} />}
            {pa.resistance_levels[0] && <LevelRow level={pa.resistance_levels[0]} />}
          </tbody>
        </table>
      </CardBody>
    </Card>
  )
}

function ContextCard({ data }: { data: StockAnalysis }) {
  const market = data.market
  const sector = data.sector_context
  return (
    <Card>
      <CardHeader title="Market &amp; Sector Context" subtitle="Regime and relative strength backdrop" />
      <CardBody>
        <div className="mb-4 flex flex-wrap items-center gap-2">
          <Badge tone={market.regime_status === "strong" ? "gain" : market.regime_status === "weak" ? "loss" : "neutral"}>
            {prettyLabel(market.regime_status)}
          </Badge>
          <span className="text-sm text-ink">{prettyLabel(market.index_trend)}</span>
          <span className="text-xs text-slate/70">Breadth {market.market_breadth_pct}%</span>
        </div>
        {sector ? (
          <div className="flex flex-wrap items-center gap-2 border-t border-mist/60 pt-3">
            <span className="text-sm font-bold text-ink">{sector.name}</span>
            <span className="text-sm text-slate/80">{prettyLabel(sector.sector_trend)}</span>
            <Badge
              tone={
                sector.relative_strength_rating === "strong"
                  ? "gain"
                  : sector.relative_strength_rating === "weak"
                    ? "loss"
                    : "neutral"
              }
            >
              {prettyLabel(sector.relative_strength_rating)} RS
            </Badge>
          </div>
        ) : (
          <p className="border-t border-mist/60 pt-3 text-sm text-slate/70">No sector context available.</p>
        )}
      </CardBody>
    </Card>
  )
}

export function StockAnalysisPage() {
  const { symbol } = useParams<{ symbol: string }>()
  const navigate = useNavigate()

  if (!symbol) return null

  return <StockAnalysisBody symbol={symbol} onBack={() => navigate(-1)} />
}

function StockAnalysisBody({ symbol, onBack }: { symbol: string; onBack: () => void }) {
  const { data, isLoading, isError, refetch } = useStockAnalysis(symbol)
  const plan = useWatchlist().data?.find((item) => item.symbol === symbol.toUpperCase() && item.status !== "archived")

  if (isLoading) {
    return (
      <div className="flex h-[50vh] items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  if (isError) {
    return (
      <Card className="border-rose-200 bg-rose-50/40 p-8 text-center">
        <p className="mb-4 text-sm text-ink">Could not load analysis for {symbol}. Please try again.</p>
        <Button variant="secondary" onClick={() => refetch()}>
          Retry
        </Button>
      </Card>
    )
  }

  if (!data) {
    return (
      <Card className="p-12 text-center text-sm text-slate/80">No analysis available for this symbol.</Card>
    )
  }

  return (
    <div className="space-y-6">
      <Button variant="ghost" size="sm" onClick={onBack} className="inline-flex items-center gap-1">
        <ArrowLeft className="h-4 w-4" /> Back
      </Button>

      <header className="flex flex-wrap items-center gap-3">
        <div>
          <h1 className="font-display text-2xl font-bold tracking-tight text-ink">
            {data.symbol}
            {data.name ? <span className="ml-2 font-normal text-slate/80">{data.name}</span> : null}
          </h1>
          <p className="mt-1 text-sm text-slate/70">
            {data.candles.length ? `As of ${format(parseISO(data.candles[data.candles.length - 1].traded_on), "MMM dd, yyyy")}` : "No daily prices available"}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Badge tone="neutral">{SETUP_STATE_LABELS[data.setup_state]}</Badge>
          <Badge tone="neutral">{data.sector}</Badge>
          <AddToWatchlistButton symbol={data.symbol} size="sm" />
        </div>
        <div className="ml-auto flex items-baseline gap-2">
          <span className="font-display text-xl font-bold text-ink">Rs. {data.current_price.toLocaleString()}</span>
          <Badge tone={changeTone(data.change_percent)}>
            {data.change_percent > 0 ? "+" : ""}
            {data.change_percent}%
          </Badge>
        </div>
      </header>

      {data.volume_pace ? <VolumePaceLine pace={data.volume_pace} /> : null}

      {data.readiness ? <ReadinessCard snapshot={data.readiness} history={data.readiness_history} /> : null}

       {data.candles.length > 0 ? (
         <>
           <PriceChart data={data} plan={plan} />
           {data.broker_flow ? <BrokerFlowCard flow={data.broker_flow} /> : null}
           {data.corporate_actions ? <CorporateActionsCard upcoming={data.corporate_actions.upcoming} history={data.corporate_actions.history} /> : null}
         </>
       ) : null}

      <div className="grid gap-5 xl:grid-cols-2">
        <VcpContractions data={data} />
        <VcpScoreBreakdown data={data} />
      </div>

      <div className="grid gap-5 xl:grid-cols-2">
        <PriceActionCard data={data} />
        <ContextCard data={data} />
      </div>
    </div>
  )
}
