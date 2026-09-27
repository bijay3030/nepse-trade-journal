import { AnimatePresence, motion } from "framer-motion"
import {
  ArrowDownRight,
  ArrowUpDown,
  ArrowUpRight,
  Building2,
  ChevronRight,
  DollarSign,
  Filter,
  Grid,
  Layers,
  LayoutList,
  PlusCircle,
  RefreshCw,
  Search,
  SlidersHorizontal,
  TrendingDown,
  TrendingUp,
  X,
} from "lucide-react"
import { useEffect, useMemo, useState } from "react"
import { useNavigate } from "react-router-dom"
import { Badge, Button, Card, LoadingSpinner } from "../components/ui"
import api from "../lib/axios"
import { cn } from "../lib/cn"

export interface StockItem {
  id: number
  symbol: string
  name: string
  sector: string
  security_type: string
  last_price: number
  change_percent: number
  volume: number
  listed_shares: number
  market_cap: number
  high_52w: number
  low_52w: number
  eps: number | null
  pe_ratio: number | null
  book_value: number | null
  pb_ratio: number | null
  last_updated: string
}

export interface HistoricalPrice {
  id: number
  traded_on: string
  open_price: number
  high_price: number
  low_price: number
  close_price: number
  previous_close: number
  change_amount: number
  change_percent: number
  volume: number
  turnover: number
  total_trades: number
}

export interface FinancialReport {
  id: number
  fiscal_year: string
  quarter: string
  reported_on: string | null
  eps: number
  pe_ratio: number
  book_value: number
  pb_ratio: number
  roe: number
  net_profit: number
  paid_up_capital: number
}

type SortField = "symbol" | "last_price" | "change_percent" | "market_cap" | "volume" | "high_52w" | "eps" | "pe_ratio"
type SortOrder = "asc" | "desc"
type ViewMode = "grid" | "table"
type PriceFilter = "all" | "gainers" | "losers" | "unchanged"

export function StocksPage() {
  const navigate = useNavigate()
  const [stocks, setStocks] = useState<StockItem[]>([])
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Filters & Search
  const [search, setSearch] = useState("")
  const [selectedSector, setSelectedSector] = useState("all")
  const [selectedSecurityType, setSelectedSecurityType] = useState("all")
  const [priceFilter, setPriceFilter] = useState<PriceFilter>("all")
  const [sortField, setSortField] = useState<SortField>("market_cap")
  const [sortOrder, setSortOrder] = useState<SortOrder>("desc")
  const [viewMode, setViewMode] = useState<ViewMode>("grid")

  // Available metadata options
  const [availableSectors, setAvailableSectors] = useState<string[]>([])
  const [availableSecurityTypes, setAvailableSecurityTypes] = useState<string[]>([])

  // Modal / Detail state
  const [selectedStock, setSelectedStock] = useState<StockItem | null>(null)
  const [historicalPrices, setHistoricalPrices] = useState<HistoricalPrice[]>([])
  const [financials, setFinancials] = useState<FinancialReport[]>([])
  const [loadingDetails, setLoadingDetails] = useState(false)
  const [detailTab, setDetailTab] = useState<"overview" | "history" | "financials">("overview")

  const fetchStocks = async () => {
    try {
      setLoading(true)
      setError(null)
      const response = await api.get<StockItem[]>("/stocks")
      setStocks(response.data)
    } catch (err: any) {
      console.error("Failed to fetch stocks:", err)
      setError(err.response?.data?.error || "Failed to load stocks data. Please verify Rails API server is running.")
    } finally {
      setLoading(false)
    }
  }

  const fetchMetadata = async () => {
    try {
      const response = await api.get<{ sectors: string[]; security_types: string[] }>("/stocks/sectors")
      setAvailableSectors(response.data.sectors || [])
      setAvailableSecurityTypes(response.data.security_types || [])
    } catch (err) {
      console.error("Failed to fetch metadata:", err)
    }
  }

  useEffect(() => {
    fetchStocks()
    fetchMetadata()
  }, [])

  const handleRefresh = async () => {
    try {
      setRefreshing(true)
      await api.post("/data_imports/fetch_prices")
      await fetchStocks()
    } catch (err) {
      console.error("Failed to trigger live refresh:", err)
    } finally {
      setRefreshing(false)
    }
  }

  const handleOpenDetail = async (stock: StockItem) => {
    setSelectedStock(stock)
    setDetailTab("overview")
    setLoadingDetails(true)
    try {
      const [histRes, finRes] = await Promise.all([
        api.get<HistoricalPrice[]>(`/stocks/${stock.symbol}/historical_prices`),
        api.get<FinancialReport[]>(`/stocks/${stock.symbol}/financials`),
      ])
      setHistoricalPrices(histRes.data)
      setFinancials(finRes.data)
    } catch (err) {
      console.error("Failed to fetch stock details:", err)
    } finally {
      setLoadingDetails(false)
    }
  }

  // Statistics calculation
  const stats = useMemo(() => {
    const total = stocks.length
    const gainers = stocks.filter((s) => s.change_percent > 0).length
    const losers = stocks.filter((s) => s.change_percent < 0).length
    const unchanged = stocks.filter((s) => s.change_percent === 0).length
    const totalMarketCap = stocks.reduce((acc, s) => acc + (s.market_cap || 0), 0)

    return { total, gainers, losers, unchanged, totalMarketCap }
  }, [stocks])

  // Filtered and Sorted list
  const filteredStocks = useMemo(() => {
    return stocks
      .filter((stock) => {
        // Search query
        if (search.trim()) {
          const q = search.toLowerCase()
          const matchSymbol = stock.symbol.toLowerCase().includes(q)
          const matchName = stock.name.toLowerCase().includes(q)
          if (!matchSymbol && !matchName) return false
        }

        // Sector filter
        if (selectedSector !== "all" && stock.sector !== selectedSector) return false

        // Security type filter
        if (selectedSecurityType !== "all" && stock.security_type !== selectedSecurityType) return false

        // Price movement filter
        if (priceFilter === "gainers" && stock.change_percent <= 0) return false
        if (priceFilter === "losers" && stock.change_percent >= 0) return false
        if (priceFilter === "unchanged" && stock.change_percent !== 0) return false

        return true
      })
      .sort((a, b) => {
        let valA = a[sortField] ?? 0
        let valB = b[sortField] ?? 0

        if (typeof valA === "string") {
          valA = (valA as string).toLowerCase()
          valB = (valB as string).toLowerCase()
        }

        if (valA < valB) return sortOrder === "asc" ? -1 : 1
        if (valA > valB) return sortOrder === "asc" ? 1 : -1
        return 0
      })
  }, [stocks, search, selectedSector, selectedSecurityType, priceFilter, sortField, sortOrder])

  const toggleSort = (field: SortField) => {
    if (sortField === field) {
      setSortOrder((prev) => (prev === "asc" ? "desc" : "asc"))
    } else {
      setSortField(field)
      setSortOrder("desc")
    }
  }

  const formatLargeNumber = (val: number | null | undefined) => {
    if (val === null || val === undefined || val === 0) return "N/A"
    if (val >= 1_000_000_000_000) return `NPR ${(val / 1_000_000_000_000).toFixed(2)} Trillion`
    if (val >= 1_000_000_000) return `NPR ${(val / 1_000_000_000).toFixed(2)} Billion`
    if (val >= 1_000_000) return `NPR ${(val / 1_000_000).toFixed(2)} Million`
    return `NPR ${val.toLocaleString()}`
  }

  return (
    <div className="space-y-6">
      {/* Top Header & Metrics Dashboard */}
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="font-display text-2xl font-bold tracking-tight text-ink sm:text-3xl">NEPSE Stocks Explorer</h1>
          <p className="mt-1 text-sm text-slate">
            Real-time market insights, fundamental ratios, and daily floor sheet records from listed companies.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <Button
            variant="secondary"
            onClick={handleRefresh}
            disabled={refreshing || loading}
            className="flex items-center gap-2"
          >
            <RefreshCw className={cn("h-4 w-4", refreshing && "animate-spin")} />
            {refreshing ? "Syncing..." : "Sync Daily Prices"}
          </Button>
        </div>
      </div>

      {/* Overview Stat Cards */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-5">
        <Card className="p-4 bg-white/90 border-slate/10 shadow-sm">
          <div className="flex items-center justify-between text-slate text-xs font-semibold uppercase tracking-wider">
            <span>Total Listed</span>
            <Building2 className="h-4 w-4 text-ink/40" />
          </div>
          <p className="mt-2 text-2xl font-bold text-ink">{stats.total}</p>
          <p className="text-xs text-slate/70 mt-0.5">Active NEPSE Securities</p>
        </Card>

        <Card className="p-4 bg-emerald-50/50 border-emerald-200/60 shadow-sm">
          <div className="flex items-center justify-between text-emerald-800 text-xs font-semibold uppercase tracking-wider">
            <span>Gainers</span>
            <TrendingUp className="h-4 w-4 text-emerald-600" />
          </div>
          <p className="mt-2 text-2xl font-bold text-emerald-700">+{stats.gainers}</p>
          <p className="text-xs text-emerald-600/80 mt-0.5">{stats.total > 0 ? ((stats.gainers / stats.total) * 100).toFixed(1) : 0}% of Market</p>
        </Card>

        <Card className="p-4 bg-rose-50/50 border-rose-200/60 shadow-sm">
          <div className="flex items-center justify-between text-rose-800 text-xs font-semibold uppercase tracking-wider">
            <span>Losers</span>
            <TrendingDown className="h-4 w-4 text-rose-600" />
          </div>
          <p className="mt-2 text-2xl font-bold text-rose-700">-{stats.losers}</p>
          <p className="text-xs text-rose-600/80 mt-0.5">{stats.total > 0 ? ((stats.losers / stats.total) * 100).toFixed(1) : 0}% of Market</p>
        </Card>

        <Card className="p-4 bg-slate/5 border-slate/10 shadow-sm">
          <div className="flex items-center justify-between text-slate text-xs font-semibold uppercase tracking-wider">
            <span>Unchanged</span>
            <SlidersHorizontal className="h-4 w-4 text-slate/40" />
          </div>
          <p className="mt-2 text-2xl font-bold text-slate/80">{stats.unchanged}</p>
          <p className="text-xs text-slate/60 mt-0.5">Static Price</p>
        </Card>

        <Card className="col-span-2 sm:col-span-4 lg:col-span-1 p-4 bg-indigo-50/50 border-indigo-200/60 shadow-sm">
          <div className="flex items-center justify-between text-indigo-800 text-xs font-semibold uppercase tracking-wider">
            <span>Market Cap</span>
            <DollarSign className="h-4 w-4 text-indigo-600" />
          </div>
          <p className="mt-2 text-xl font-bold text-indigo-900">{formatLargeNumber(stats.totalMarketCap)}</p>
          <p className="text-xs text-indigo-600/80 mt-0.5">Combined Value</p>
        </Card>
      </div>

      {/* Control Toolbar: Search, Filters & Views */}
      <Card className="p-4 bg-white/90 border-slate/15 space-y-4 shadow-sm">
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-3">
          {/* Search bar */}
          <div className="relative flex-1 min-w-[280px]">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-slate/50" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search stock by Symbol (e.g. NABIL, NTC) or Name..."
              className="w-full pl-10 pr-9 py-2.5 rounded-xl border border-mist/80 bg-slate/5 text-sm text-ink focus:bg-white focus:border-ink/50 focus:outline-none transition"
            />
            {search && (
              <button
                onClick={() => setSearch("")}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate/40 hover:text-ink"
              >
                <X className="h-4 w-4" />
              </button>
            )}
          </div>

          {/* Filter Dropdowns */}
          <div className="flex flex-wrap items-center gap-2.5">
            {/* Sector Filter */}
            <div className="relative">
              <select
                value={selectedSector}
                onChange={(e) => setSelectedSector(e.target.value)}
                className="appearance-none pl-3 pr-8 py-2 rounded-xl border border-mist/80 bg-white text-xs font-semibold text-ink focus:outline-none focus:border-ink/50"
              >
                <option value="all">All Sectors</option>
                {availableSectors.map((sec) => (
                  <option key={sec} value={sec}>
                    {sec}
                  </option>
                ))}
              </select>
              <Filter className="absolute right-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-slate/40 pointer-events-none" />
            </div>

            {/* Security Type Filter */}
            <div className="relative">
              <select
                value={selectedSecurityType}
                onChange={(e) => setSelectedSecurityType(e.target.value)}
                className="appearance-none pl-3 pr-8 py-2 rounded-xl border border-mist/80 bg-white text-xs font-semibold text-ink focus:outline-none focus:border-ink/50"
              >
                <option value="all">All Security Types</option>
                {availableSecurityTypes.map((st) => (
                  <option key={st} value={st}>
                    {st}
                  </option>
                ))}
              </select>
              <Layers className="absolute right-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-slate/40 pointer-events-none" />
            </div>

            {/* Price Movement Filter Buttons */}
            <div className="inline-flex rounded-xl border border-mist/80 bg-slate/5 p-1">
              {(["all", "gainers", "losers"] as const).map((mode) => (
                <button
                  key={mode}
                  onClick={() => setPriceFilter(mode)}
                  className={cn(
                    "px-2.5 py-1 text-xs font-bold rounded-lg capitalize transition",
                    priceFilter === mode ? "bg-white text-ink shadow-xs" : "text-slate hover:text-ink",
                  )}
                >
                  {mode}
                </button>
              ))}
            </div>

            {/* View Mode Toggle */}
            <div className="inline-flex rounded-xl border border-mist/80 bg-slate/5 p-1">
              <button
                onClick={() => setViewMode("grid")}
                className={cn(
                  "p-1.5 rounded-lg transition",
                  viewMode === "grid" ? "bg-white text-ink shadow-xs" : "text-slate hover:text-ink",
                )}
                title="Grid View"
              >
                <Grid className="h-4 w-4" />
              </button>
              <button
                onClick={() => setViewMode("table")}
                className={cn(
                  "p-1.5 rounded-lg transition",
                  viewMode === "table" ? "bg-white text-ink shadow-xs" : "text-slate hover:text-ink",
                )}
                title="Table View"
              >
                <LayoutList className="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>

        {/* Quick Sorting Pills */}
        <div className="flex flex-wrap items-center gap-2 pt-2 border-t border-slate/10 text-xs">
          <span className="font-semibold text-slate/70">Sort by:</span>
          {(
            [
              { id: "market_cap", label: "Market Cap" },
              { id: "symbol", label: "Symbol" },
              { id: "last_price", label: "Price (LTP)" },
              { id: "change_percent", label: "% Change" },
              { id: "volume", label: "Volume" },
              { id: "eps", label: "EPS" },
              { id: "pe_ratio", label: "P/E Ratio" },
            ] as const
          ).map((item) => {
            const isActive = sortField === item.id
            return (
              <button
                key={item.id}
                onClick={() => toggleSort(item.id)}
                className={cn(
                  "inline-flex items-center gap-1 px-3 py-1 rounded-full border text-xs font-semibold transition",
                  isActive
                    ? "bg-ink text-white border-ink"
                    : "bg-white text-slate border-mist/80 hover:border-slate/40 hover:text-ink",
                )}
              >
                <span>{item.label}</span>
                {isActive && (
                  <ArrowUpDown className={cn("h-3 w-3 transition-transform", sortOrder === "asc" && "rotate-180")} />
                )}
              </button>
            )
          })}
        </div>
      </Card>

      {/* Main Content Area */}
      {loading ? (
        <div className="flex h-64 items-center justify-center rounded-2xl bg-white border border-mist/70">
          <div className="text-center space-y-3">
            <LoadingSpinner size="lg" />
            <p className="text-sm font-semibold text-slate">Loading NEPSE Listed Stocks...</p>
          </div>
        </div>
      ) : error ? (
        <Card className="p-8 text-center bg-rose-50/40 border-rose-200">
          <p className="text-rose-700 font-semibold">{error}</p>
          <Button variant="secondary" className="mt-4" onClick={fetchStocks}>
            Retry Loading
          </Button>
        </Card>
      ) : filteredStocks.length === 0 ? (
        <Card className="p-12 text-center bg-white border-mist/80 space-y-3">
          <Search className="h-10 w-10 text-slate/30 mx-auto" />
          <h3 className="text-lg font-bold text-ink">No stocks found matching your filters</h3>
          <p className="text-sm text-slate max-w-md mx-auto">
            Try adjusting your search keywords, sector filters, or price movement filters.
          </p>
          <Button
            variant="outline"
            onClick={() => {
              setSearch("")
              setSelectedSector("all")
              setSelectedSecurityType("all")
              setPriceFilter("all")
            }}
          >
            Reset Filters
          </Button>
        </Card>
      ) : viewMode === "grid" ? (
        /* GRID VIEW */
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {filteredStocks.map((stock) => {
            const isPositive = stock.change_percent > 0
            const isNegative = stock.change_percent < 0
            return (
              <div key={stock.id} className="h-full">
                <Card
                  onClick={() => handleOpenDetail(stock)}
                  className="group relative p-5 bg-white border-mist/80 hover:border-ink/40 hover:shadow-md transition-all cursor-pointer flex flex-col justify-between h-full"
                >
                  <div>
                    {/* Card Header */}
                    <div className="flex items-start justify-between gap-2">
                      <div>
                        <div className="flex items-center gap-2">
                          <span className="font-display text-lg font-bold text-ink group-hover:text-primary transition">
                            {stock.symbol}
                          </span>
                          <Badge variant="outline" className="text-[10px] uppercase font-bold text-slate/70">
                            {stock.security_type || "Equity"}
                          </Badge>
                        </div>
                        <p className="text-xs text-slate line-clamp-1 mt-0.5">{stock.name}</p>
                      </div>

                      <span
                        className={cn(
                          "inline-flex items-center gap-0.5 px-2 py-1 rounded-lg text-xs font-bold",
                          isPositive && "bg-emerald-100/70 text-emerald-700",
                          isNegative && "bg-rose-100/70 text-rose-700",
                          !isPositive && !isNegative && "bg-slate/10 text-slate",
                        )}
                      >
                        {isPositive ? (
                          <ArrowUpRight className="h-3.5 w-3.5" />
                        ) : isNegative ? (
                          <ArrowDownRight className="h-3.5 w-3.5" />
                        ) : null}
                        {stock.change_percent >= 0 ? `+${stock.change_percent}%` : `${stock.change_percent}%`}
                      </span>
                    </div>

                    {/* Price Section */}
                    <div className="mt-4">
                      <div className="text-2xl font-extrabold text-ink font-mono tracking-tight">
                        NPR {stock.last_price ? stock.last_price.toLocaleString() : "N/A"}
                      </div>
                      <p className="text-[11px] text-slate/60 mt-0.5">{stock.sector || "Uncategorized Sector"}</p>
                    </div>

                    {/* Key Fundamentals Grid */}
                    <div className="mt-4 grid grid-cols-2 gap-2 p-2.5 rounded-xl bg-slate/5 text-xs">
                      <div>
                        <span className="text-slate/60 text-[10px] block">EPS</span>
                        <span className="font-semibold text-ink">{stock.eps ? `Rs. ${stock.eps}` : "N/A"}</span>
                      </div>
                      <div>
                        <span className="text-slate/60 text-[10px] block">P/E Ratio</span>
                        <span className="font-semibold text-ink">{stock.pe_ratio ? `${stock.pe_ratio}x` : "N/A"}</span>
                      </div>
                      <div>
                        <span className="text-slate/60 text-[10px] block">Book Value</span>
                        <span className="font-semibold text-ink">{stock.book_value ? `Rs. ${stock.book_value}` : "N/A"}</span>
                      </div>
                      <div>
                        <span className="text-slate/60 text-[10px] block">Market Cap</span>
                        <span className="font-semibold text-ink line-clamp-1">{formatLargeNumber(stock.market_cap)}</span>
                      </div>
                    </div>
                  </div>

                  {/* Card Footer Actions */}
                  <div className="mt-4 pt-3 border-t border-slate/10 flex items-center justify-between text-xs">
                    <span className="text-slate/60 text-[11px]">Click for Details</span>
                    <ChevronRight className="h-4 w-4 text-slate/40 group-hover:translate-x-1 transition-transform" />
                  </div>
                </Card>
              </div>
            )
          })}
        </div>
      ) : (
        /* TABLE VIEW */
        <Card className="overflow-hidden border-mist/80 bg-white shadow-sm">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs text-ink">
              <thead className="bg-slate/5 text-slate uppercase font-bold text-[10px] tracking-wider border-b border-mist/80">
                <tr>
                  <th className="py-3 px-4">Symbol & Security</th>
                  <th className="py-3 px-4">Sector</th>
                  <th className="py-3 px-4 text-right">LTP (NPR)</th>
                  <th className="py-3 px-4 text-right">% Change</th>
                  <th className="py-3 px-4 text-right">Market Cap</th>
                  <th className="py-3 px-4 text-right">EPS</th>
                  <th className="py-3 px-4 text-right">P/E Ratio</th>
                  <th className="py-3 px-4 text-right">Book Value</th>
                  <th className="py-3 px-4 text-center">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-mist/60 font-medium">
                {filteredStocks.map((stock) => {
                  const isPositive = stock.change_percent > 0
                  const isNegative = stock.change_percent < 0
                  return (
                    <tr
                      key={stock.id}
                      onClick={() => handleOpenDetail(stock)}
                      className="hover:bg-slate/5 transition cursor-pointer"
                    >
                      <td className="py-3 px-4">
                        <div className="font-bold text-sm text-ink">{stock.symbol}</div>
                        <div className="text-[11px] text-slate/70 line-clamp-1">{stock.name}</div>
                      </td>
                      <td className="py-3 px-4 text-slate/80">{stock.sector || "-"}</td>
                      <td className="py-3 px-4 text-right font-mono font-bold text-sm">
                        {stock.last_price ? stock.last_price.toLocaleString() : "N/A"}
                      </td>
                      <td className="py-3 px-4 text-right">
                        <span
                          className={cn(
                            "inline-flex items-center gap-0.5 px-2 py-0.5 rounded text-xs font-bold",
                            isPositive && "bg-emerald-100 text-emerald-700",
                            isNegative && "bg-rose-100 text-rose-700",
                            !isPositive && !isNegative && "bg-slate/10 text-slate",
                          )}
                        >
                          {stock.change_percent >= 0 ? `+${stock.change_percent}%` : `${stock.change_percent}%`}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-right font-mono text-slate/90">
                        {formatLargeNumber(stock.market_cap)}
                      </td>
                      <td className="py-3 px-4 text-right font-mono">{stock.eps ? `Rs. ${stock.eps}` : "-"}</td>
                      <td className="py-3 px-4 text-right font-mono">{stock.pe_ratio ? `${stock.pe_ratio}x` : "-"}</td>
                      <td className="py-3 px-4 text-right font-mono">{stock.book_value ? `Rs. ${stock.book_value}` : "-"}</td>
                      <td className="py-3 px-4 text-center">
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={(e) => {
                            e.stopPropagation()
                            handleOpenDetail(stock)
                          }}
                        >
                          Details
                        </Button>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      {/* Stock Detail Modal Drawer */}
      <AnimatePresence>
        {selectedStock && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-ink/60 backdrop-blur-xs"
            onClick={() => setSelectedStock(null)}
          >
            <motion.div
              initial={{ scale: 0.95, opacity: 0, y: 10 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.95, opacity: 0, y: 10 }}
              onClick={(e) => e.stopPropagation()}
              className="w-full max-w-3xl rounded-3xl bg-white border border-mist shadow-2xl overflow-hidden max-h-[90vh] flex flex-col"
            >
              {/* Modal Header */}
              <div className="p-6 bg-ink text-white flex items-start justify-between gap-4">
                <div>
                  <div className="flex items-center gap-3">
                    <h2 className="font-display text-2xl font-bold">{selectedStock.symbol}</h2>
                    <Badge variant="secondary" className="bg-white/20 text-white border-0 text-xs">
                      {selectedStock.security_type || "Equity"}
                    </Badge>
                  </div>
                  <p className="text-sm text-white/70 mt-1">{selectedStock.name}</p>
                </div>

                <button
                  onClick={() => setSelectedStock(null)}
                  className="p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white transition"
                >
                  <X className="h-5 w-5" />
                </button>
              </div>

              {/* Price Banner */}
              <div className="px-6 py-4 bg-slate/5 border-b border-mist/80 flex flex-wrap items-center justify-between gap-4">
                <div>
                  <span className="text-xs text-slate/70 uppercase font-semibold">Last Traded Price (LTP)</span>
                  <div className="flex items-baseline gap-2 mt-0.5">
                    <span className="font-mono text-3xl font-extrabold text-ink">
                      NPR {selectedStock.last_price ? selectedStock.last_price.toLocaleString() : "N/A"}
                    </span>
                    <span
                      className={cn(
                        "text-sm font-bold",
                        selectedStock.change_percent >= 0 ? "text-emerald-600" : "text-rose-600",
                      )}
                    >
                      {selectedStock.change_percent >= 0 ? `+${selectedStock.change_percent}%` : `${selectedStock.change_percent}%`}
                    </span>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <Button
                    onClick={() => {
                      setSelectedStock(null)
                      navigate(`/trade/new?symbol=${selectedStock.symbol}`)
                    }}
                    className="flex items-center gap-1.5"
                  >
                    <PlusCircle className="h-4 w-4" />
                    Log Trade for {selectedStock.symbol}
                  </Button>
                </div>
              </div>

              {/* Navigation Tabs */}
              <div className="px-6 border-b border-mist/80 flex gap-6 text-sm font-semibold text-slate">
                {(["overview", "history", "financials"] as const).map((tab) => (
                  <button
                    key={tab}
                    onClick={() => setDetailTab(tab)}
                    className={cn(
                      "py-3 border-b-2 capitalize transition",
                      detailTab === tab ? "border-ink text-ink font-bold" : "border-transparent hover:text-ink",
                    )}
                  >
                    {tab}
                  </button>
                ))}
              </div>

              {/* Modal Body */}
              <div className="p-6 overflow-y-auto space-y-6 flex-1">
                {detailTab === "overview" && (
                  <div className="space-y-6">
                    {/* 52-Week Range Bar */}
                    <div className="p-4 rounded-2xl bg-slate/5 border border-mist/70">
                      <div className="flex justify-between text-xs font-semibold text-slate mb-2">
                        <span>52-Week Low: NPR {selectedStock.low_52w || selectedStock.last_price}</span>
                        <span className="font-bold text-ink">52-Week Range</span>
                        <span>52-Week High: NPR {selectedStock.high_52w || selectedStock.last_price}</span>
                      </div>
                      <div className="relative h-3 w-full rounded-full bg-slate/20 overflow-hidden">
                        <div
                          className="absolute h-full bg-ink rounded-full"
                          style={{
                            width: `${
                              selectedStock.high_52w > selectedStock.low_52w
                                ? Math.min(
                                    100,
                                    Math.max(
                                      5,
                                      ((selectedStock.last_price - selectedStock.low_52w) /
                                        (selectedStock.high_52w - selectedStock.low_52w)) *
                                        100,
                                    ),
                                  )
                                : 50
                            }%`,
                          }}
                        />
                      </div>
                    </div>

                    {/* Fundamental Metrics Grid */}
                    <div>
                      <h4 className="font-bold text-sm text-ink mb-3 uppercase tracking-wider">Fundamental Metrics</h4>
                      <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                        <div className="p-3 rounded-xl border border-mist/80 bg-white">
                          <span className="text-xs text-slate/70 block">Earnings Per Share (EPS)</span>
                          <span className="text-base font-bold text-ink">{selectedStock.eps ? `Rs. ${selectedStock.eps}` : "N/A"}</span>
                        </div>
                        <div className="p-3 rounded-xl border border-mist/80 bg-white">
                          <span className="text-xs text-slate/70 block">P/E Ratio</span>
                          <span className="text-base font-bold text-ink">{selectedStock.pe_ratio ? `${selectedStock.pe_ratio}x` : "N/A"}</span>
                        </div>
                        <div className="p-3 rounded-xl border border-mist/80 bg-white">
                          <span className="text-xs text-slate/70 block">Book Value</span>
                          <span className="text-base font-bold text-ink">{selectedStock.book_value ? `Rs. ${selectedStock.book_value}` : "N/A"}</span>
                        </div>
                        <div className="p-3 rounded-xl border border-mist/80 bg-white">
                          <span className="text-xs text-slate/70 block">P/B Ratio</span>
                          <span className="text-base font-bold text-ink">{selectedStock.pb_ratio ? `${selectedStock.pb_ratio}x` : "N/A"}</span>
                        </div>
                        <div className="p-3 rounded-xl border border-mist/80 bg-white">
                          <span className="text-xs text-slate/70 block">Listed Shares</span>
                          <span className="text-base font-bold text-ink">{selectedStock.listed_shares ? selectedStock.listed_shares.toLocaleString() : "N/A"}</span>
                        </div>
                        <div className="p-3 rounded-xl border border-mist/80 bg-white">
                          <span className="text-xs text-slate/70 block">Market Cap</span>
                          <span className="text-base font-bold text-ink">{formatLargeNumber(selectedStock.market_cap)}</span>
                        </div>
                      </div>
                    </div>
                  </div>
                )}

                {detailTab === "history" && (
                  <div>
                    <h4 className="font-bold text-sm text-ink mb-3 uppercase tracking-wider">Historical Daily Prices</h4>
                    {loadingDetails ? (
                      <LoadingSpinner className="my-8 mx-auto" />
                    ) : historicalPrices.length === 0 ? (
                      <p className="text-sm text-slate text-center py-6">No daily floor sheet records archived yet.</p>
                    ) : (
                      <div className="overflow-x-auto border border-mist/80 rounded-xl">
                        <table className="w-full text-left text-xs text-ink">
                          <thead className="bg-slate/5 text-slate uppercase font-bold text-[10px]">
                            <tr>
                              <th className="py-2.5 px-3">Date</th>
                              <th className="py-2.5 px-3 text-right">Open</th>
                              <th className="py-2.5 px-3 text-right">High</th>
                              <th className="py-2.5 px-3 text-right">Low</th>
                              <th className="py-2.5 px-3 text-right">Close</th>
                              <th className="py-2.5 px-3 text-right">Volume</th>
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-mist/60 font-mono">
                            {historicalPrices.map((hp) => (
                              <tr key={hp.id} className="hover:bg-slate/5">
                                <td className="py-2 px-3">{hp.traded_on}</td>
                                <td className="py-2 px-3 text-right">{hp.open_price}</td>
                                <td className="py-2 px-3 text-right text-emerald-700">{hp.high_price}</td>
                                <td className="py-2 px-3 text-right text-rose-700">{hp.low_price}</td>
                                <td className="py-2 px-3 text-right font-bold">{hp.close_price}</td>
                                <td className="py-2 px-3 text-right">{hp.volume?.toLocaleString()}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </div>
                )}

                {detailTab === "financials" && (
                  <div>
                    <h4 className="font-bold text-sm text-ink mb-3 uppercase tracking-wider">Quarterly Financial Reports</h4>
                    {loadingDetails ? (
                      <LoadingSpinner className="my-8 mx-auto" />
                    ) : financials.length === 0 ? (
                      <p className="text-sm text-slate text-center py-6">No financial reports uploaded for this stock yet.</p>
                    ) : (
                      <div className="overflow-x-auto border border-mist/80 rounded-xl">
                        <table className="w-full text-left text-xs text-ink">
                          <thead className="bg-slate/5 text-slate uppercase font-bold text-[10px]">
                            <tr>
                              <th className="py-2.5 px-3">Fiscal Year / Quarter</th>
                              <th className="py-2.5 px-3 text-right">EPS</th>
                              <th className="py-2.5 px-3 text-right">P/E</th>
                              <th className="py-2.5 px-3 text-right">Book Value</th>
                              <th className="py-2.5 px-3 text-right">ROE %</th>
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-mist/60 font-mono">
                            {financials.map((fin) => (
                              <tr key={fin.id} className="hover:bg-slate/5">
                                <td className="py-2 px-3 font-bold">{fin.fiscal_year} - {fin.quarter}</td>
                                <td className="py-2 px-3 text-right">Rs. {fin.eps}</td>
                                <td className="py-2 px-3 text-right">{fin.pe_ratio}x</td>
                                <td className="py-2 px-3 text-right">Rs. {fin.book_value}</td>
                                <td className="py-2 px-3 text-right">{fin.roe}%</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}
                  </div>
                )}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
