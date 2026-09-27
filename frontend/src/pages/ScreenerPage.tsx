import { useMemo, useState } from "react"
import { ChevronDown, FilterX, Search, X } from "lucide-react"
import { Link } from "react-router-dom"

import { useScreener } from "../features/screener/api"
import type {
  LiquidityRating,
  MarketRegime,
  ScreenerRow,
  SetupState,
  TrendState,
} from "../features/screener/types"
import { SETUP_STATE_LABELS } from "../features/screener/types"
import { Badge, Button, Card, LoadingSpinner } from "../components/ui"
import { AddToWatchlistButton } from "../features/watchlist/AddToWatchlist"
import { cn } from "../lib/cn"

type TabId = "watchlist" | "breakout"

type Filters = {
  query: string
  sector: string
  minScore: number | null
  liquidity: LiquidityRating | "any"
  trend: TrendState | "any"
  maxDistance: number | null
  regime: MarketRegime | "any"
}

const INITIAL_FILTERS: Filters = {
  query: "",
  sector: "all",
  minScore: null,
  liquidity: "any",
  trend: "any",
  maxDistance: null,
  regime: "any",
}

const SETUP_TONE: Record<SetupState, "neutral" | "gain" | "loss"> = {
  watch: "neutral",
  near_pivot: "gain",
  breakout: "gain",
  failed_breakout: "loss",
  invalidated: "loss",
}

const REGIME_TONE: Record<MarketRegime, "neutral" | "gain" | "loss"> = {
  strong: "gain",
  neutral: "neutral",
  weak: "loss",
}

const REGIME_LABEL: Record<MarketRegime, string> = {
  strong: "Strong",
  neutral: "Neutral",
  weak: "Weak",
}

function formatPrice(value: number) {
  return `Rs. ${value.toLocaleString(undefined, { maximumFractionDigits: 2 })}`
}

function formatDistance(value: number | null) {
  if (value === null) return "—"
  const sign = value > 0 ? "+" : ""
  return `${sign}${value.toFixed(2)}%`
}

function formatVolume(value: number) {
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`
  if (value >= 1_000) return `${(value / 1_000).toFixed(1)}K`
  return String(value)
}

function FilterSelect({
  label,
  value,
  onChange,
  children,
}: {
  label: string
  value: string
  onChange: (value: string) => void
  children: React.ReactNode
}) {
  return (
    <label className="flex flex-col gap-1">
      <span className="text-[10px] font-bold uppercase tracking-wider text-slate">{label}</span>
      <span className="relative">
        <select
          aria-label={label}
          value={value}
          onChange={(event) => onChange(event.target.value)}
          className="appearance-none pl-3 pr-8 py-2 rounded-xl border border-mist/80 bg-white text-xs font-semibold text-ink focus:outline-none focus:border-ink/50"
        >
          {children}
        </select>
        <ChevronDown className="pointer-events-none absolute right-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-slate/50" />
      </span>
    </label>
  )
}

function ScreenerTable({
  rows,
  showSetupColumn,
}: {
  rows: ScreenerRow[]
  showSetupColumn: boolean
}) {
  return (
    <Card className="overflow-hidden border-mist/80 bg-white shadow-sm">
      <div className="overflow-x-auto">
        <table className="w-full text-left text-xs text-ink">
          <thead className="bg-slate/5 text-slate uppercase font-bold text-[10px] tracking-wider border-b border-mist/80">
            <tr>
              {showSetupColumn && <th className="py-3 px-4">Setup</th>}
              <th className="py-3 px-4">Symbol</th>
              <th className="py-3 px-4 text-right">Price</th>
              <th className="py-3 px-4 text-right">VCP Score</th>
              <th className="py-3 px-4">Price-action state</th>
              <th className="py-3 px-4 text-right">Volume</th>
              <th className="py-3 px-4 text-right">Pivot</th>
              <th className="py-3 px-4 text-right">Distance to pivot</th>
              <th className="py-3 px-4">Sector</th>
              <th className="py-3 px-4">Market regime</th>
              <th className="py-3 px-4"><span className="sr-only">Track</span></th>
            </tr>
          </thead>
          <tbody className="divide-y divide-mist/60 font-medium">
            {rows.map((row) => (
              <tr
                key={row.symbol}
                className="hover:bg-slate/5 transition"
              >
                {showSetupColumn && (
                  <td className="py-3 px-4">
                    <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-slate/10 font-mono text-[10px] font-bold text-slate">
                      {row.symbol.slice(0, 2)}
                    </span>
                  </td>
                )}
                <td className="py-3 px-4 font-bold"><Link className="rounded text-ink underline-offset-2 hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-ink" to={`/screener/${encodeURIComponent(row.symbol)}`}>{row.symbol}</Link></td>
                <td className="py-3 px-4 text-right font-mono">{formatPrice(row.current_price)}</td>
                <td className="py-3 px-4 text-right font-mono">{row.vcp_score}</td>
                <td className="py-3 px-4">
                  <div className="flex flex-col gap-1"><Badge tone={SETUP_TONE[row.setup_state]}>{SETUP_STATE_LABELS[row.setup_state]}</Badge><span className="text-[11px] text-slate">{row.price_action_state.replaceAll("_", " ")}</span></div>
                </td>
                <td className="py-3 px-4 text-right font-mono">{formatVolume(row.volume)}</td>
                <td className="py-3 px-4 text-right font-mono">
                  {row.pivot === null ? "—" : formatPrice(row.pivot)}
                </td>
                <td
                  className={cn(
                    "py-3 px-4 text-right font-mono",
                    row.distance_to_pivot !== null && row.distance_to_pivot <= 0 ? "text-pine" : "text-ink",
                  )}
                >
                  {formatDistance(row.distance_to_pivot)}
                </td>
                <td className="py-3 px-4">{row.sector}</td>
                <td className="py-3 px-4">
                  <Badge tone={REGIME_TONE[row.market_regime]}>{REGIME_LABEL[row.market_regime]}</Badge>
                </td>
                <td className="py-3 px-4 text-right">
                  <AddToWatchlistButton symbol={row.symbol} size="sm" />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  )
}

export function ScreenerPage() {
  const { data, isLoading, isError, refetch } = useScreener()
  const [tab, setTab] = useState<TabId>("watchlist")
  const [filters, setFilters] = useState<Filters>(INITIAL_FILTERS)

  const results = useMemo(() => data?.results ?? [], [data])

  const filteredRows = useMemo(() => {
    const query = filters.query.trim().toLowerCase()
    return results.filter((row) => {
      if (query && !row.symbol.toLowerCase().includes(query)) return false
      if (filters.sector !== "all" && row.sector !== filters.sector) return false
      if (filters.minScore !== null && row.vcp_score < filters.minScore) return false
      if (filters.liquidity !== "any" && row.liquidity_rating !== filters.liquidity) return false
      if (filters.trend !== "any" && row.trend_state !== filters.trend) return false
      if (
        filters.maxDistance !== null &&
        (row.distance_to_pivot === null || Math.abs(row.distance_to_pivot) > filters.maxDistance)
      )
        return false
      if (filters.regime !== "any" && row.market_regime !== filters.regime) return false
      return true
    })
  }, [results, filters])

  const breakoutRows = useMemo(() => filteredRows
    .filter((row) => row.pivot !== null && row.distance_to_pivot !== null && Math.abs(row.distance_to_pivot) <= 2 && row.setup_state !== "invalidated")
    .sort((a, b) => Math.abs(a.distance_to_pivot!) - Math.abs(b.distance_to_pivot!)), [filteredRows])

  const updateFilter = <K extends keyof Filters>(key: K, value: Filters[K]) =>
    setFilters((prev) => ({ ...prev, [key]: value }))

  if (isLoading) {
    return (
      <div className="flex h-[50vh] items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  if (isError || !data) {
    return (
      <Card className="p-8 text-center bg-rose-50/40 border-rose-200">
        <p className="text-sm font-semibold text-ink">Could not load screener data.</p>
        <p className="mt-1 text-xs text-slate">Please check your connection and try again.</p>
        <Button variant="secondary" className="mt-4" onClick={() => refetch()}>
          Retry
        </Button>
      </Card>
    )
  }

  const activeRows = tab === "watchlist" ? filteredRows : breakoutRows
  const hasActiveFilters =
    filters.query !== "" ||
    filters.sector !== "all" ||
    filters.minScore !== null ||
    filters.liquidity !== "any" ||
    filters.trend !== "any" ||
    filters.maxDistance !== null ||
    filters.regime !== "any"

  return (
    <div className="space-y-6">
      <div>
        <h1 className="font-display text-2xl font-bold tracking-tight text-ink sm:text-3xl">VCP Screener</h1>
        <p className="mt-1 text-sm text-slate">
          Market regime: <span className="font-semibold">{REGIME_LABEL[data.market_regime]}</span> · Volatility
          contraction setups {data.traded_on ? `as of ${data.traded_on}` : "awaiting daily prices"}
        </p>
      </div>

      <div className="flex flex-wrap items-center gap-4">
        <div className="inline-flex rounded-xl border border-mist/80 bg-slate/5 p-1" role="tablist">
          {(
            [
              { id: "watchlist", label: "All setups" },
              { id: "breakout", label: "Breakout Watch" },
            ] as const
          ).map((item) => (
            <button
              key={item.id}
              role="tab"
              aria-selected={tab === item.id}
              onClick={() => setTab(item.id)}
              className={cn(
                "rounded-lg px-4 py-1.5 text-xs font-semibold transition",
                tab === item.id ? "bg-white text-ink shadow-xs" : "text-slate",
              )}
            >
              {item.label}
            </button>
          ))}
        </div>
        <p className="text-xs font-semibold text-slate">
          {tab === "watchlist" ? `${filteredRows.length} setups` : `${breakoutRows.length} near pivot`}
        </p>
      </div>

      {(
        <Card className="p-4 bg-white/90 border-slate/15 space-y-4 shadow-sm">
          <div className="relative">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-slate/50" />
            <input
              type="text"
              value={filters.query}
              onChange={(event) => updateFilter("query", event.target.value)}
              placeholder="Search by symbol..."
              className="w-full pl-10 pr-9 py-2.5 rounded-xl border border-mist/80 bg-slate/5 text-sm text-ink focus:bg-white focus:border-ink/50 focus:outline-none transition"
            />
            {filters.query !== "" && (
              <button
                aria-label="Clear search"
                onClick={() => updateFilter("query", "")}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate/50 hover:text-ink transition"
              >
                <X className="h-4 w-4" />
              </button>
            )}
          </div>
          <div className="flex flex-wrap gap-3">
            <FilterSelect label="Sector" value={filters.sector} onChange={(v) => updateFilter("sector", v)}>
              <option value="all">All</option>
              {data.sectors.map((sector) => (
                <option key={sector} value={sector}>
                  {sector}
                </option>
              ))}
            </FilterSelect>
            <FilterSelect
              label="Min VCP Score"
              value={filters.minScore === null ? "any" : String(filters.minScore)}
              onChange={(v) => updateFilter("minScore", v === "any" ? null : Number(v))}
            >
              <option value="any">Any</option>
              <option value="60">60+</option>
              <option value="75">75+</option>
              <option value="85">85+</option>
            </FilterSelect>
            <FilterSelect
              label="Liquidity"
              value={filters.liquidity}
              onChange={(v) => updateFilter("liquidity", v as Filters["liquidity"])}
            >
              <option value="any">Any</option>
              <option value="high">High</option>
              <option value="medium">Medium</option>
              <option value="low">Low</option>
            </FilterSelect>
            <FilterSelect
              label="Trend"
              value={filters.trend}
              onChange={(v) => updateFilter("trend", v as Filters["trend"])}
            >
              <option value="any">Any</option>
              <option value="uptrend">Uptrend</option>
              <option value="sideways">Sideways</option>
              <option value="downtrend">Downtrend</option>
            </FilterSelect>
            <FilterSelect
              label="Distance to Pivot"
              value={filters.maxDistance === null ? "any" : String(filters.maxDistance)}
              onChange={(v) => updateFilter("maxDistance", v === "any" ? null : Number(v))}
            >
              <option value="any">Any</option>
              <option value="2">≤2%</option>
              <option value="5">≤5%</option>
              <option value="10">≤10%</option>
            </FilterSelect>
            <FilterSelect
              label="Market Regime"
              value={filters.regime}
              onChange={(v) => updateFilter("regime", v as Filters["regime"])}
            >
              <option value="any">Any</option>
              <option value="strong">Strong</option>
              <option value="neutral">Neutral</option>
              <option value="weak">Weak</option>
            </FilterSelect>
          </div>
        </Card>
      )}

      {activeRows.length === 0 ? (
        <Card className="p-12 text-center">
          <FilterX className="mx-auto h-8 w-8 text-slate/40" />
          <p className="mt-3 text-sm font-semibold text-ink">
            {tab === "watchlist" ? "No setups match your filters." : "No stocks near their pivot right now."}
          </p>
          {tab === "watchlist" && hasActiveFilters && (
            <Button variant="outline" className="mt-4" onClick={() => setFilters(INITIAL_FILTERS)}>
              Reset Filters
            </Button>
          )}
        </Card>
      ) : (
        <ScreenerTable
          rows={activeRows}
          showSetupColumn={tab === "breakout"}
        />
      )}
    </div>
  )
}
