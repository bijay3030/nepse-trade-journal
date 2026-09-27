import { useMemo, useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { Activity, Calendar, Filter, Target, TrendingDown, TrendingUp } from "lucide-react"
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts"
import { format, startOfYear, subDays } from "date-fns"
import api from "../../lib/axios"
import { Badge, Card, CardBody, CardHeader, HelpTooltip, LoadingSpinner, PriceDisplay, StatCard } from "../ui"

const DATE_RANGES = [
  { label: "Last 7 Days", value: "7d" },
  { label: "Last 30 Days", value: "30d" },
  { label: "Last 90 Days", value: "90d" },
  { label: "Year to Date", value: "ytd" },
] as const

const COLORS = ["#18745a", "#ff6b2c", "#f59e0b", "#1f2d42", "#003893", "#14b8a6"]

type Overview = {
  total_pnl: number
}

type EquityPoint = {
  date: string
  equity: number
}

type StrategyItem = {
  name: string
  trades: number
  expectancy: number
  pnl: number
}

type MistakeItem = {
  name: string
  count: number
}

type EmotionItem = {
  mood: string
  win_rate: number
}

type DashboardResponse = {
  overview: Overview
  performance_chart: EquityPoint[]
  strategy_breakdown: StrategyItem[]
  mistake_analysis: MistakeItem[]
  emotional_correlation: EmotionItem[]
}

type StatsResponse = {
  win_rate: number
  profit_factor: number
  expectancy: number
  total_trades: number
  winning_trades: number
  losing_trades: number
}

const mockDashboard = (): DashboardResponse => {
  const performance = Array.from({ length: 30 }, (_, i) => {
    const day = subDays(new Date(), 29 - i)
    const base = 1_000_000 + i * 3_800
    const noise = Math.round(Math.sin(i / 3) * 11_500)
    return { date: day.toISOString(), equity: base + noise }
  })

  return {
    overview: { total_pnl: 126_540 },
    performance_chart: performance,
    strategy_breakdown: [
      { name: "Breakout Continuation", trades: 18, expectancy: 1_720, pnl: 30_960 },
      { name: "Support Bounce", trades: 14, expectancy: 980, pnl: 13_720 },
      { name: "Gap Reversion", trades: 9, expectancy: -430, pnl: -3_870 },
    ],
    mistake_analysis: [
      { name: "Late Entry", count: 8 },
      { name: "No Stop Discipline", count: 5 },
      { name: "Oversized Risk", count: 4 },
      { name: "Emotional Exit", count: 6 },
    ],
    emotional_correlation: [
      { mood: "Calm", win_rate: 74 },
      { mood: "Focused", win_rate: 66 },
      { mood: "Anxious", win_rate: 41 },
      { mood: "Impulsive", win_rate: 28 },
    ],
  }
}

const mockStats = (): StatsResponse => ({
  win_rate: 61.5,
  profit_factor: 1.74,
  expectancy: 1_285,
  total_trades: 41,
  winning_trades: 25,
  losing_trades: 16,
})

function periodToStartDate(period: string) {
  if (period === "7d") return subDays(new Date(), 7)
  if (period === "90d") return subDays(new Date(), 90)
  if (period === "ytd") return startOfYear(new Date())
  return subDays(new Date(), 30)
}

function EquityTooltip({ active, payload }: { active?: boolean; payload?: Array<{ payload?: EquityPoint }> }) {
  if (!active || !payload || payload.length === 0) return null

  const point = payload[0]?.payload as EquityPoint | undefined
  if (!point) return null

  return (
    <div className="rounded-lg border border-white/80 bg-white/95 p-3 shadow-panel">
      <p className="text-xs text-slate/80">{format(new Date(point.date), "MMM dd, yyyy")}</p>
      <p className="font-display text-base font-bold text-ink">Rs. {point.equity.toLocaleString()}</p>
    </div>
  )
}

export function AnalyticsDashboard() {
  const [dateRange, setDateRange] = useState("30d")

  const {
    data: dashboardData,
    isLoading,
    error: dashboardError,
  } = useQuery({
    queryKey: ["dashboard", dateRange],
    queryFn: async () => {
      const response = await api.get<DashboardResponse>(`/analytics/dashboard?period=${dateRange}`)
      return response.data
    },
    retry: 1,
  })

  const {
    data: stats,
    isLoading: statsLoading,
    error: statsError,
  } = useQuery({
    queryKey: ["statistics", dateRange],
    queryFn: async () => {
      const response = await api.get<StatsResponse>(`/analytics/trade_statistics?period=${dateRange}`)
      return response.data
    },
    retry: 1,
  })

  const fallbackDashboard = useMemo(() => mockDashboard(), [])
  const fallbackStats = useMemo(() => mockStats(), [])

  const sourceDashboard = dashboardData ?? fallbackDashboard
  const sourceStats = stats ?? fallbackStats

  const overview = sourceDashboard.overview
  const equityCurve = sourceDashboard.performance_chart
  const strategies = sourceDashboard.strategy_breakdown
  const mistakes = sourceDashboard.mistake_analysis
  const emotions = sourceDashboard.emotional_correlation
  const usingFallback = Boolean((dashboardError || statsError) && (!dashboardData || !stats))

  if (isLoading || statsLoading) {
    return (
      <div className="flex h-96 items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="font-display text-2xl font-bold text-ink">Trading Dashboard</h1>
          <p className="mt-1 text-sm text-slate/80">Track performance, spot behavioral drift, and tighten execution.</p>
          {usingFallback ? (
            <p className="mt-2 text-xs font-semibold uppercase tracking-[0.12em] text-ember">Showing demo data</p>
          ) : null}
        </div>

        <div className="flex flex-wrap items-center gap-2 rounded-xl border border-white/70 bg-white/90 p-1 shadow-panel">
          <Filter className="ml-2 h-4 w-4 text-slate/70" />
          {DATE_RANGES.map((range) => (
            <button
              key={range.value}
              type="button"
              onClick={() => setDateRange(range.value)}
              className={
                dateRange === range.value
                  ? "rounded-lg bg-ink px-3 py-1.5 text-xs font-bold text-white"
                  : "rounded-lg px-3 py-1.5 text-xs font-semibold text-slate hover:bg-slate/10"
              }
            >
              {range.label}
            </button>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          title="Total P&L"
          value={<PriceDisplay amount={overview.total_pnl} showSign size="lg" />}
          change={`${sourceStats.win_rate}% win rate`}
          changeType={overview.total_pnl >= 0 ? "positive" : "negative"}
          icon={overview.total_pnl >= 0 ? TrendingUp : TrendingDown}
          helpText="Total net profit/loss after fees for selected period."
          helpLink="/help#pnl"
        />
        <StatCard
          title="Profit Factor"
          value={sourceStats.profit_factor.toFixed(2)}
          change={sourceStats.profit_factor > 1.5 ? "Good" : sourceStats.profit_factor > 1 ? "Okay" : "Poor"}
          changeType={sourceStats.profit_factor > 1.5 ? "positive" : sourceStats.profit_factor > 1 ? "neutral" : "negative"}
          icon={Activity}
          helpText="Gross profits divided by gross losses. >1 means profitable system."
        />
        <StatCard
          title="Expectancy / Trade"
          value={<PriceDisplay amount={sourceStats.expectancy} showSign />}
          change="Average per trade"
          changeType={sourceStats.expectancy >= 0 ? "positive" : "negative"}
          icon={Target}
          helpText="Average outcome per trade; positive expectancy suggests edge over time."
          helpLink="/help#expectancy"
        />
        <StatCard
          title="Total Trades"
          value={sourceStats.total_trades.toString()}
          change={`${sourceStats.winning_trades}W / ${sourceStats.losing_trades}L`}
          changeType="neutral"
          icon={Calendar}
        />
      </div>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-3">
        <Card className="xl:col-span-2">
          <CardHeader title="Equity Curve" subtitle={`From ${format(periodToStartDate(dateRange), "MMM dd, yyyy")} to today`} />
          <CardBody>
            <div className="h-80">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={equityCurve}>
                  <defs>
                    <linearGradient id="equityGradient" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#003893" stopOpacity={0.22} />
                      <stop offset="100%" stopColor="#003893" stopOpacity={0.02} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="4 4" stroke="#d9e0ea" />
                  <XAxis dataKey="date" tickFormatter={(date) => format(new Date(date), "MMM dd")} stroke="#1f2d42" />
                  <YAxis tickFormatter={(val) => `Rs.${(val / 1000).toFixed(0)}k`} stroke="#1f2d42" />
                  <Tooltip content={<EquityTooltip />} />
                  <Area type="monotone" dataKey="equity" stroke="#003893" strokeWidth={2.5} fill="url(#equityGradient)" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </CardBody>
        </Card>

        <Card>
          <CardHeader
            title={
              <span className="inline-flex items-center gap-1">
                Strategy Performance
                <HelpTooltip text="Compare strategy edge using expectancy, win rate, and net P&L." link="/help#strategy-examples" />
              </span>
            }
            subtitle="Expectancy by system"
          />
          <CardBody className="space-y-3">
            {strategies.map((strategy) => (
              <div key={strategy.name} className="rounded-xl border border-mist/70 bg-white/90 p-3">
                <div className="mb-2 flex items-center justify-between gap-2">
                  <p className="text-sm font-bold text-ink">{strategy.name}</p>
                  <Badge variant={strategy.expectancy > 0 ? "profit" : "loss"}>
                    {strategy.expectancy > 0 ? "Positive edge" : "Needs review"}
                  </Badge>
                </div>
                <div className="flex items-center justify-between text-xs text-slate/80">
                  <span>{strategy.trades} trades</span>
                  <PriceDisplay amount={strategy.pnl} showSign size="sm" />
                </div>
              </div>
            ))}
          </CardBody>
        </Card>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader title="Mistake Analysis" subtitle="Most frequent execution leaks" />
          <CardBody>
            <div className="h-72">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={mistakes}>
                  <CartesianGrid strokeDasharray="4 4" stroke="#d9e0ea" />
                  <XAxis dataKey="name" tick={{ fill: "#1f2d42", fontSize: 12 }} />
                  <YAxis allowDecimals={false} tick={{ fill: "#1f2d42", fontSize: 12 }} />
                  <Tooltip />
                  <Bar dataKey="count" fill="#ff6b2c" radius={[8, 8, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </CardBody>
        </Card>

        <Card>
          <CardHeader title="Emotional Correlation" subtitle="Win rate by emotional state at exit" />
          <CardBody>
            <div className="h-72">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie data={emotions} dataKey="win_rate" nameKey="mood" cx="50%" cy="50%" outerRadius={94} label>
                    {emotions.map((entry, idx) => (
                      <Cell key={entry.mood} fill={COLORS[idx % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip />
                  <Legend />
                </PieChart>
              </ResponsiveContainer>
            </div>
          </CardBody>
        </Card>
      </div>
    </div>
  )
}
