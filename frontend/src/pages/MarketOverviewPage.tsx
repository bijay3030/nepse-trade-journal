import { format } from "date-fns"
import { MarketDirectionCard } from "../features/market/MarketDirectionCard"
import { Activity, BarChart3, Layers, TrendingUp } from "lucide-react"
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts"

import { Badge, Button, Card, CardBody, CardHeader, LoadingSpinner, StatCard } from "../components/ui"
import { MarketHeatmap } from "../features/market/MarketHeatmap"
import { useMarketOverview } from "../features/screener/api"
import type { MarketRegime, SectorOverviewRow } from "../features/screener/types"
import { cn } from "../lib/cn"

function formatTurnover(value: number): string {
  if (value >= 1_000_000_000) return `NPR ${(value / 1_000_000_000).toFixed(2)}B`
  return `NPR ${(value / 1_000_000).toFixed(2)}M`
}

function formatPct(value: number): string {
  return `${value >= 0 ? "+" : ""}${value.toFixed(2)}%`
}

function titleCase(value: string): string {
  return value.charAt(0).toUpperCase() + value.slice(1)
}

const regimeTone: Record<MarketRegime, "gain" | "neutral" | "loss"> = {
  strong: "gain",
  neutral: "neutral",
  weak: "loss",
}

export function MarketOverviewPage() {
  const { data, isLoading, isError, refetch } = useMarketOverview()

  if (isLoading) {
    return (
      <div className="flex h-[50vh] items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  if (isError || !data) {
    return (
      <Card className="border-rose-200 bg-rose-50/40 p-8 text-center">
        <p className="font-display text-lg font-bold text-ink">Market overview unavailable</p>
        <p className="mt-2 text-sm text-slate">We could not load the latest market snapshot. Please try again.</p>
        <div className="mt-4">
          <Button variant="secondary" onClick={() => refetch()}>
            Retry
          </Button>
        </div>
      </Card>
    )
  }

  if (!data.traded_on) {
    return (
      <Card className="p-8 text-center">
        <p className="font-display text-lg font-bold text-ink">No market sessions available</p>
        <p className="mt-2 text-sm text-slate">Import NEPSE index history to view the market overview.</p>
      </Card>
    )
  }

  const breadthTotal = data.advancing_stocks + data.declining_stocks + data.unchanged_stocks || 1
  const advPct = (data.advancing_stocks / breadthTotal) * 100
  const decPct = (data.declining_stocks / breadthTotal) * 100
  const unchPct = (data.unchanged_stocks / breadthTotal) * 100

  return (
    <div className="space-y-6">
      <header>
        <h1 className="font-display text-2xl font-bold tracking-tight text-ink sm:text-3xl">Market Overview</h1>
        <p className="mt-1 text-sm text-slate">
          Daily snapshot of the NEPSE index, market breadth, and sector performance for {data.traded_on}.
        </p>
      </header>

      {data.market_direction && <MarketDirectionCard direction={data.market_direction} />}

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          title="NEPSE Index"
          value={data.nepse_index.toLocaleString("en-US", { maximumFractionDigits: 2 })}
          change={formatPct(data.index_change_pct)}
          changeType={data.index_change_pct >= 0 ? "positive" : "negative"}
          icon={Activity}
        />
        <StatCard
          title="Market Regime"
          value={
            <Badge tone={regimeTone[data.regime_status]} className="text-sm">
              {titleCase(data.regime_status)}
            </Badge>
          }
          change={`Index trend: ${data.index_trend}`}
          changeType="neutral"
          icon={TrendingUp}
        />
        <StatCard
          title="Turnover"
          value={formatTurnover(data.market_turnover)}
          icon={BarChart3}
        />
        <StatCard
          title="Breadth"
          value={
            <Badge tone={regimeTone[data.breadth_rating]} className="text-sm">
              {titleCase(data.breadth_rating)}
            </Badge>
          }
          change={`${data.advancing_stocks} advancing / ${data.declining_stocks} declining`}
          changeType="neutral"
          icon={Layers}
          helpText={`${data.pct_stocks_above_sma50.toFixed(2)}% of stocks above their 50-day average`}
        />
      </div>

      <Card>
        <CardHeader title="NEPSE Index Trend" subtitle="Recent closing values of the NEPSE index." />
        <CardBody>
          <div className="h-72">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={data.index_history}>
                <defs>
                  <linearGradient id="nepseIndexGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#003893" stopOpacity={0.22} />
                    <stop offset="100%" stopColor="#003893" stopOpacity={0.02} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="4 4" stroke="#d9e0ea" />
                <XAxis
                  dataKey="traded_on"
                  stroke="#1f2d42"
                  tickFormatter={(d: string) => format(new Date(d), "MMM dd")}
                />
                <YAxis stroke="#1f2d42" domain={["dataMin", "dataMax"]} />
                <Tooltip
                  contentStyle={{
                    borderRadius: "0.5rem",
                    border: "1px solid rgba(255,255,255,0.8)",
                    background: "rgba(255,255,255,0.95)",
                    padding: "0.75rem",
                    boxShadow: "0 10px 30px rgba(16,21,31,0.12)",
                  }}
                  labelFormatter={(label) => format(new Date(label as string), "MMM dd, yyyy")}
                />
                <Area
                  type="monotone"
                  dataKey="value"
                  stroke="#003893"
                  strokeWidth={2.5}
                  fill="url(#nepseIndexGradient)"
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </CardBody>
      </Card>

      <Card>
        <CardHeader
          title="Market Breadth"
          subtitle={`${data.total_stocks_audited} stocks audited, ${data.market_breadth_pct.toFixed(2)}% breadth, A/D ratio ${data.advance_decline_ratio.toFixed(2)}.`}
        />
        <CardBody>
          <div className="flex h-4 w-full overflow-hidden rounded-full bg-slate/10">
            <div className="bg-pine" style={{ width: `${advPct}%` }} />
            <div className="bg-ember" style={{ width: `${decPct}%` }} />
            <div className="bg-slate/40" style={{ width: `${unchPct}%` }} />
          </div>
          <div className="mt-3 flex flex-wrap gap-4 text-sm text-slate">
            <span className="flex items-center gap-2">
              <span className="h-2.5 w-2.5 rounded-full bg-pine" />
              {data.advancing_stocks} advancing
            </span>
            <span className="flex items-center gap-2">
              <span className="h-2.5 w-2.5 rounded-full bg-ember" />
              {data.declining_stocks} declining
            </span>
            <span className="flex items-center gap-2">
              <span className="h-2.5 w-2.5 rounded-full bg-slate/40" />
              {data.unchanged_stocks} unchanged
            </span>
          </div>
        </CardBody>
      </Card>

      <MarketHeatmap />

      <Card>
        <CardHeader title="Sector Overview" subtitle="Performance and breadth by sector." />
        <CardBody>
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
            {data.sectors.map((sector: SectorOverviewRow) => (
              <div key={sector.sector} className="rounded-2xl border border-mist/70 bg-white/70 p-4">
                <div className="flex items-start justify-between gap-2">
                  <h4 className="font-display text-base font-bold text-ink">{sector.sector}</h4>
                  <Badge tone={regimeTone[sector.relative_strength_rating]}>
                    {titleCase(sector.relative_strength_rating)}
                  </Badge>
                </div>
                <p
                  className={cn(
                    "mt-2 font-display text-2xl font-extrabold",
                    sector.sector_performance_pct >= 0 ? "text-pine" : "text-ember",
                  )}
                >
                  {formatPct(sector.sector_performance_pct)}
                </p>
                <dl className="mt-3 space-y-1 text-sm text-slate">
                  <div className="flex justify-between">
                    <dt>Trend</dt>
                    <dd className="font-semibold text-ink">{titleCase(sector.sector_trend)}</dd>
                  </div>
                  <div className="flex justify-between">
                    <dt>Turnover</dt>
                    <dd className="font-semibold text-ink">{formatTurnover(sector.sector_turnover)}</dd>
                  </div>
                  <div className="flex justify-between">
                    <dt>Advancing / Declining</dt>
                    <dd className="font-semibold text-ink">
                      {sector.advancing_stocks} / {sector.declining_stocks}
                    </dd>
                  </div>
                </dl>
              </div>
            ))}
          </div>
        </CardBody>
      </Card>
    </div>
  )
}
