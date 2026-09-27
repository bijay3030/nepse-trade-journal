import { useEffect, useMemo, useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { ChevronDown, ChevronUp, Wallet } from "lucide-react"
import {
  Area,
  AreaChart,
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts"
import { Badge, Button, Card, CardBody, CardHeader, LoadingSpinner, PriceDisplay } from "../components/ui"
import api from "../lib/axios"
import { Fragment } from "react"
import { useIsMobile } from "../hooks/useIsMobile"
import { usePullToRefresh } from "../hooks/usePullToRefresh"
import { useStockPrices } from "../hooks/useStockPrices"

type Period = "1D" | "1W" | "1M" | "3M" | "1Y" | "ALL"
type SortKey = "stock" | "qty" | "avg" | "current" | "pnlRs" | "pnlPct"

type Stock = {
  id: number
  symbol: string
  name: string
  sector: string
  last_price: number
  change_percent?: number
}

type HoldingTrade = {
  id: number
  type: "BUY" | "SELL"
  qty: number
  price: number
  time: string
}

type Holding = {
  id: number
  symbol: string
  qty: number
  avgPrice: number
  alerts: number[]
  trades: HoldingTrade[]
}

type HoldingRow = Holding & {
  stock: Stock
  current: number
  invested: number
  marketValue: number
  pnlRs: number
  pnlPct: number
  dayPnl: number
}

const PERIOD_OPTIONS: Period[] = ["1D", "1W", "1M", "3M", "1Y", "ALL"]
const HOLDINGS_KEY = "portfolio_holdings_v1"
const CASH_KEY = "portfolio_cash_v1"
const COLORS = ["#003893", "#18745a", "#ff6b2c", "#f59e0b", "#1f2d42", "#14b8a6"]

const fallbackStocks: Stock[] = [
  { id: 1, symbol: "NABIL", name: "Nabil Bank", sector: "Banking", last_price: 762, change_percent: 1.22 },
  { id: 2, symbol: "NTC", name: "Nepal Telecom", sector: "Telecom", last_price: 921, change_percent: -0.64 },
  { id: 3, symbol: "UPPER", name: "Upper Tamakoshi", sector: "Hydropower", last_price: 332, change_percent: 2.15 },
  { id: 4, symbol: "NIFRA", name: "NIFRA", sector: "Investment", last_price: 289, change_percent: 0.41 },
  { id: 5, symbol: "SCB", name: "Standard Chartered", sector: "Banking", last_price: 655, change_percent: -1.1 },
]

function defaultHoldings(stocks: Stock[]): Holding[] {
  return stocks.slice(0, 3).map((stock, idx) => ({
    id: idx + 1,
    symbol: stock.symbol,
    qty: 40 + idx * 20,
    avgPrice: Number((stock.last_price * (0.9 + idx * 0.04)).toFixed(2)),
    alerts: [Number((stock.last_price * 1.08).toFixed(2))],
    trades: [
      {
        id: idx * 10 + 1,
        type: "BUY",
        qty: 20 + idx * 10,
        price: Number((stock.last_price * 0.88).toFixed(2)),
        time: new Date(Date.now() - (idx + 2) * 86400000).toISOString(),
      },
      {
        id: idx * 10 + 2,
        type: "BUY",
        qty: 20 + idx * 10,
        price: Number((stock.last_price * 0.96).toFixed(2)),
        time: new Date(Date.now() - (idx + 1) * 43200000).toISOString(),
      },
    ],
  }))
}

function sparklineSeed(symbol: string) {
  return symbol.split("").reduce((acc, c) => acc + c.charCodeAt(0), 0)
}

function simulatedChangePercent(stock: Stock) {
  if (typeof stock.change_percent === "number") return stock.change_percent
  const seed = sparklineSeed(stock.symbol)
  return Number((Math.sin(seed / 20) * 1.8).toFixed(2))
}

function buildCurve(baseValue: number, period: Period) {
  const pointsByPeriod: Record<Period, number> = { "1D": 12, "1W": 7, "1M": 30, "3M": 90, "1Y": 52, ALL: 180 }
  const points = pointsByPeriod[period]
  return Array.from({ length: points }, (_, i) => {
    const drift = Math.sin(i / 3) * (baseValue * 0.015)
    const trend = (i - points / 2) * (baseValue * 0.0008)
    return { idx: i, value: Math.max(1000, baseValue + drift + trend) }
  })
}

function compareRows(a: HoldingRow, b: HoldingRow, key: SortKey) {
  if (key === "stock") return a.symbol.localeCompare(b.symbol)
  if (key === "qty") return a.qty - b.qty
  if (key === "avg") return a.avgPrice - b.avgPrice
  if (key === "current") return a.current - b.current
  if (key === "pnlPct") return a.pnlPct - b.pnlPct
  return a.pnlRs - b.pnlRs
}

function readCashFromStorage() {
  const raw = localStorage.getItem(CASH_KEY)
  if (!raw) return 250000
  const parsed = Number(raw)
  return Number.isFinite(parsed) ? parsed : 250000
}

function readHoldingsFromStorage(): Holding[] {
  const raw = localStorage.getItem(HOLDINGS_KEY)
  if (!raw) return []

  try {
    const parsed = JSON.parse(raw)
    if (!Array.isArray(parsed)) return []

    return parsed
      .filter((entry) => entry && typeof entry === "object")
      .map((entry, index) => {
        const safe = entry as Partial<Holding>
        const parsedQty = Number(safe.qty)
        const parsedAvg = Number(safe.avgPrice)
        const trades = Array.isArray(safe.trades)
          ? safe.trades
              .filter((trade) => trade && typeof trade === "object")
              .map((trade) => {
                const safeTrade = trade as Partial<HoldingTrade>
                const tradeType: HoldingTrade["type"] = safeTrade.type === "SELL" ? "SELL" : "BUY"
                return {
                  id: Number.isFinite(Number(safeTrade.id)) ? Number(safeTrade.id) : Date.now() + index,
                  type: tradeType,
                  qty: Number.isFinite(Number(safeTrade.qty)) ? Number(safeTrade.qty) : 0,
                  price: Number.isFinite(Number(safeTrade.price)) ? Number(safeTrade.price) : 0,
                  time: typeof safeTrade.time === "string" ? safeTrade.time : new Date().toISOString(),
                }
              })
          : []

        return {
          id: Number.isFinite(Number(safe.id)) ? Number(safe.id) : index + 1,
          symbol: typeof safe.symbol === "string" ? safe.symbol.toUpperCase() : "",
          qty: Number.isFinite(parsedQty) ? parsedQty : 0,
          avgPrice: Number.isFinite(parsedAvg) ? parsedAvg : 0,
          alerts: Array.isArray(safe.alerts) ? safe.alerts.map((value) => Number(value)).filter(Number.isFinite) : [],
          trades,
        }
      })
      .filter((holding) => holding.symbol.length > 0)
  } catch {
    return []
  }
}

export function PortfolioPage() {
  const [period, setPeriod] = useState<Period>("1M")
  const [sortKey, setSortKey] = useState<SortKey>("pnlRs")
  const [sortDir, setSortDir] = useState<"asc" | "desc">("desc")
  const [expandedIds, setExpandedIds] = useState<number[]>([])
  const [selectedSector, setSelectedSector] = useState<string | null>(null)
  const [alertDraft, setAlertDraft] = useState<Record<number, string>>({})
  const [sellDraft, setSellDraft] = useState<{ holdingId: number; qty: string; price: string } | null>(null)
  const isMobile = useIsMobile()

  const [cash, setCash] = useState<number>(() => readCashFromStorage())
  const [holdings, setHoldings] = useState<Holding[]>(() => readHoldingsFromStorage())

  const { data, isLoading } = useQuery({
    queryKey: ["portfolio", "stocks"],
    queryFn: async () => (await api.get<Stock[]>("/stocks")).data,
    staleTime: 30_000,
    retry: 1,
  })

  const { pullDistance, isRefreshing } = usePullToRefresh({
    enabled: isMobile,
    onRefresh: () => setHoldings((prev) => [...prev]),
  })

  const stocks = data && data.length > 0 ? data : fallbackStocks
  const { getPrice } = useStockPrices(stocks.map((stock) => stock.symbol))
  const stockMap = useMemo(
    () =>
      new Map(
        stocks.map((stock) => {
          const live = getPrice(stock.symbol)
          return [
            stock.symbol,
            {
              ...stock,
              last_price: live?.lastPrice ?? stock.last_price,
              change_percent: live?.changePercent ?? simulatedChangePercent(stock),
            },
          ]
        }),
      ),
    [stocks, getPrice],
  )

  useEffect(() => localStorage.setItem(HOLDINGS_KEY, JSON.stringify(holdings)), [holdings])
  useEffect(() => localStorage.setItem(CASH_KEY, String(cash)), [cash])

  const rows = useMemo(() => {
    return holdings
      .map((h) => {
        const stock = stockMap.get(h.symbol)
        if (!stock) return null
        const current = stock.last_price
        const invested = h.avgPrice * h.qty
        const marketValue = current * h.qty
        const pnlRs = marketValue - invested
        const pnlPct = invested === 0 ? 0 : (pnlRs / invested) * 100
        const dayPnl = marketValue * ((stock.change_percent ?? 0) / 100)
        return { ...h, stock, current, invested, marketValue, pnlRs, pnlPct, dayPnl }
      })
      .filter(Boolean) as HoldingRow[]
  }, [holdings, stockMap])

  const filteredRows = useMemo(() => {
    const scoped = selectedSector ? rows.filter((r) => r.stock.sector === selectedSector) : rows
    const sorted = [...scoped].sort((a, b) => compareRows(a, b, sortKey))
    return sortDir === "asc" ? sorted : sorted.reverse()
  }, [rows, selectedSector, sortKey, sortDir])

  const investedAmount = rows.reduce((acc, row) => acc + row.invested, 0)
  const holdingsValue = rows.reduce((acc, row) => acc + row.marketValue, 0)
  const totalPnl = rows.reduce((acc, row) => acc + row.pnlRs, 0)
  const dayPnl = rows.reduce((acc, row) => acc + row.dayPnl, 0)
  const totalValue = holdingsValue + cash
  const equityCurve = useMemo(() => buildCurve(totalValue, period), [totalValue, period])
  const displayCurve = useMemo(
    () => (isMobile ? equityCurve.filter((_, idx) => idx % 3 === 0) : equityCurve),
    [equityCurve, isMobile],
  )

  const sectorAllocation = useMemo(() => {
    const bucket = new Map<string, number>()
    rows.forEach((row) => bucket.set(row.stock.sector, (bucket.get(row.stock.sector) ?? 0) + row.marketValue))
    return Array.from(bucket.entries()).map(([sector, value]) => ({ sector, value }))
  }, [rows])

  const toggleSort = (key: SortKey) => {
    if (sortKey === key) {
      setSortDir((d) => (d === "asc" ? "desc" : "asc"))
      return
    }
    setSortKey(key)
    setSortDir("desc")
  }

  const toggleExpanded = (id: number) => {
    setExpandedIds((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]))
  }

  const openSell = (row: HoldingRow) => {
    setSellDraft({ holdingId: row.id, qty: String(Math.max(1, Math.floor(row.qty / 2))), price: row.current.toFixed(2) })
  }

  const submitSell = () => {
    if (!sellDraft) return
    const qty = Number(sellDraft.qty)
    const price = Number(sellDraft.price)
    if (!qty || qty <= 0 || !price || price <= 0) return

    setHoldings((prev) =>
      prev
        .map((h) => {
          if (h.id !== sellDraft.holdingId) return h
          const nextQty = Math.max(0, h.qty - qty)
          const trade: HoldingTrade = { id: Date.now(), type: "SELL", qty, price, time: new Date().toISOString() }
          return { ...h, qty: nextQty, trades: [trade, ...h.trades] }
        })
        .filter((h) => h.qty > 0),
    )
    setCash((c) => c + qty * price)
    setSellDraft(null)
  }

  const addAlert = (holdingId: number) => {
    const raw = alertDraft[holdingId]
    const next = Number(raw)
    if (!next || next <= 0) return
    setHoldings((prev) => prev.map((h) => (h.id === holdingId ? { ...h, alerts: [...h.alerts, next] } : h)))
    setAlertDraft((prev) => ({ ...prev, [holdingId]: "" }))
  }

  const buyOne = (row: HoldingRow) => {
    setHoldings((prev) =>
      prev.map((h) =>
        h.id === row.id
          ? {
              ...h,
              qty: h.qty + 1,
              avgPrice: (h.avgPrice * h.qty + row.current) / (h.qty + 1),
              trades: [{ id: Date.now(), type: "BUY", qty: 1, price: row.current, time: new Date().toISOString() }, ...h.trades],
            }
          : h,
      ),
    )
    setCash((c) => Math.max(0, c - row.current))
  }

  const loadSample = () => {
    setHoldings(defaultHoldings(stocks))
  }

  if (isLoading && rows.length === 0) {
    return (
      <div className="flex h-96 items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
        <Card>
          <CardHeader title="Portfolio" subtitle="Live valuation with unrealized P&L and equity curve" />
          <CardBody>
            <div className="mb-5 grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
              <div>
                <p className="text-xs uppercase tracking-[0.16em] text-slate/70">Total Value</p>
                <p className="font-display text-3xl font-extrabold text-ink">Rs. {Math.round(totalValue).toLocaleString()}</p>
              </div>
              <div>
                <p className="text-xs uppercase tracking-[0.16em] text-slate/70">Invested Amount</p>
                <p className="font-display text-3xl font-extrabold text-ink">Rs. {Math.round(investedAmount).toLocaleString()}</p>
              </div>
              <div>
                <p className="text-xs uppercase tracking-[0.16em] text-slate/70">Total P&L</p>
                <PriceDisplay amount={totalPnl} showSign size="lg" />
              </div>
              <div>
                <p className="text-xs uppercase tracking-[0.16em] text-slate/70">Day P&L</p>
                <Badge variant={dayPnl >= 0 ? "profit" : "loss"}>
                  {dayPnl >= 0 ? "+" : ""}Rs. {dayPnl.toFixed(2)}
                </Badge>
              </div>
            </div>

            <div className="mb-3 flex flex-wrap gap-2">
              {PERIOD_OPTIONS.map((option) => (
                <button
                  key={option}
                  type="button"
                  onClick={() => setPeriod(option)}
                  className={
                    period === option
                      ? "rounded-lg bg-ink px-3 py-1.5 text-xs font-bold text-white"
                      : "rounded-lg px-3 py-1.5 text-xs font-semibold text-slate hover:bg-slate/10"
                  }
                >
                  {option}
                </button>
              ))}
            </div>

            <div className="h-72">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={displayCurve}>
                  <defs>
                    <linearGradient id="portfolioCurve" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#003893" stopOpacity={0.25} />
                      <stop offset="95%" stopColor="#003893" stopOpacity={0.04} />
                    </linearGradient>
                  </defs>
                  <XAxis dataKey="idx" hide />
                  <YAxis tickFormatter={(v) => `Rs.${(v / 1000).toFixed(0)}k`} />
                  <Tooltip formatter={(value) => `Rs. ${Number(value ?? 0).toLocaleString()}`} />
                  <Area type="monotone" dataKey="value" stroke="#003893" strokeWidth={2.2} fill="url(#portfolioCurve)" />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </CardBody>
        </Card>

        {rows.length === 0 ? (
          <Card>
            <CardBody className="flex flex-col items-center py-12 text-center">
              <div className="mb-4 rounded-full bg-slate/10 p-5">
                <Wallet className="h-10 w-10 text-slate" />
              </div>
              <h2 className="font-display text-2xl font-bold text-ink">No holdings yet</h2>
              <p className="mt-2 max-w-md text-sm text-slate/80">
                Start your first trade to build a portfolio, track sector exposure, and monitor unrealized P&L in real-time.
              </p>
              <div className="mt-4 flex gap-2">
                <Button onClick={loadSample}>Start your first trade</Button>
              </div>
            </CardBody>
          </Card>
        ) : (
          <div className="grid grid-cols-1 gap-5 xl:grid-cols-4">
            <Card className="xl:col-span-3">
              <CardHeader title="Holdings" subtitle="Sortable, expandable rows with trade actions" />
              <CardBody>
                {isMobile ? (
                  <p className="mb-2 text-xs font-semibold text-slate/75">
                    {isRefreshing ? "Refreshing..." : pullDistance > 8 ? "Pull to refresh..." : ""}
                  </p>
                ) : null}
                {isMobile ? (
                  <div className="space-y-2">
                    {filteredRows.map((row) => {
                      const profit = row.pnlRs >= 0
                      const expanded = expandedIds.includes(row.id)
                      return (
                        <div
                          key={row.id}
                          className={
                            profit
                              ? "rounded-xl border border-mist/60 bg-gradient-to-r from-pine/10 to-transparent p-3"
                              : "rounded-xl border border-mist/60 bg-gradient-to-r from-ember/10 to-transparent p-3"
                          }
                        >
                          <div className="flex items-center justify-between">
                            <div>
                              <p className="font-semibold text-ink">{row.symbol}</p>
                              <p className="text-xs text-slate/75">{row.stock.sector}</p>
                            </div>
                            <Badge variant={profit ? "profit" : "loss"}>{row.pnlPct.toFixed(2)}%</Badge>
                          </div>
                          <div className="mt-2 grid grid-cols-2 gap-2 text-sm">
                            <p>Qty: {row.qty}</p>
                            <p>Avg: Rs. {row.avgPrice.toFixed(2)}</p>
                            <p>Current: Rs. {row.current.toFixed(2)}</p>
                            <p>
                              P&L: <PriceDisplay amount={row.pnlRs} showSign size="sm" />
                            </p>
                          </div>
                          <div className="mt-2 flex gap-2">
                            <Button variant="secondary" className="px-2 py-1.5 text-xs" onClick={() => openSell(row)}>
                              Sell
                            </Button>
                            <Button className="px-2 py-1.5 text-xs" onClick={() => buyOne(row)}>
                              Buy
                            </Button>
                            <Button variant="ghost" className="px-2 py-1.5 text-xs" onClick={() => toggleExpanded(row.id)}>
                              {expanded ? "Hide" : "Details"}
                            </Button>
                          </div>
                          {expanded ? (
                            <div className="mt-2 rounded-lg bg-white/80 p-2">
                              <p className="text-xs font-semibold uppercase tracking-[0.12em] text-slate/70">Alerts</p>
                              <div className="mt-1 flex flex-wrap gap-1">
                                {row.alerts.map((alert, idx) => (
                                  <Badge key={`${row.id}-${idx}`} variant="neutral">
                                    Rs. {alert}
                                  </Badge>
                                ))}
                              </div>
                            </div>
                          ) : null}
                        </div>
                      )
                    })}
                  </div>
                ) : (
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[860px] border-collapse text-sm">
                    <thead className="border-b border-mist/80 text-left text-xs uppercase tracking-[0.14em] text-slate/70">
                      <tr>
                        <th className="px-2 py-3">
                          <button type="button" onClick={() => toggleSort("stock")}>
                            Stock
                          </button>
                        </th>
                        <th className="px-2 py-3">
                          <button type="button" onClick={() => toggleSort("qty")}>
                            Qty
                          </button>
                        </th>
                        <th className="px-2 py-3">
                          <button type="button" onClick={() => toggleSort("avg")}>
                            Avg Price
                          </button>
                        </th>
                        <th className="px-2 py-3">
                          <button type="button" onClick={() => toggleSort("current")}>
                            Current
                          </button>
                        </th>
                        <th className="px-2 py-3">
                          <button type="button" onClick={() => toggleSort("pnlRs")}>
                            P&L (Rs)
                          </button>
                        </th>
                        <th className="px-2 py-3">
                          <button type="button" onClick={() => toggleSort("pnlPct")}>
                            P&L (%)
                          </button>
                        </th>
                        <th className="px-2 py-3">Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filteredRows.map((row) => {
                        const profit = row.pnlRs >= 0
                        const expanded = expandedIds.includes(row.id)
                        return (
                          <Fragment key={row.id}>
                            <tr
                              className={
                                profit
                                  ? "border-b border-mist/40 bg-gradient-to-r from-pine/10 to-transparent"
                                  : "border-b border-mist/40 bg-gradient-to-r from-ember/10 to-transparent"
                              }
                            >
                              <td className="px-2 py-3">
                                <div className="font-semibold text-ink">{row.symbol}</div>
                                <div className="text-xs text-slate/75">{row.stock.sector}</div>
                              </td>
                              <td className="px-2 py-3">{row.qty}</td>
                              <td className="px-2 py-3">Rs. {row.avgPrice.toFixed(2)}</td>
                              <td className="px-2 py-3">
                                <PriceDisplay amount={row.current} symbol={row.symbol} showArrow size="sm" />
                              </td>
                              <td className="px-2 py-3 font-semibold">
                                <PriceDisplay amount={row.pnlRs} showSign size="sm" />
                              </td>
                              <td className="px-2 py-3">
                                <Badge variant={profit ? "profit" : "loss"}>{row.pnlPct.toFixed(2)}%</Badge>
                              </td>
                              <td className="px-2 py-3">
                                <div className="flex items-center gap-2">
                                  <Button variant="secondary" className="px-2 py-1.5 text-xs" onClick={() => openSell(row)}>
                                    Sell
                                  </Button>
                                  <button type="button" className="text-slate/70 hover:text-ink" onClick={() => toggleExpanded(row.id)}>
                                    {expanded ? <ChevronUp className="h-4 w-4" /> : <ChevronDown className="h-4 w-4" />}
                                  </button>
                                </div>
                              </td>
                            </tr>
                            {expanded ? (
                              <tr className="border-b border-mist/40 bg-white/75">
                                <td colSpan={7} className="px-3 py-3">
                                  <div className="grid gap-3 lg:grid-cols-3">
                                    <div>
                                      <p className="mb-1 text-xs font-semibold uppercase tracking-[0.12em] text-slate/70">Trades</p>
                                      <div className="space-y-1">
                                        {row.trades.slice(0, 6).map((trade) => (
                                          <div key={trade.id} className="flex justify-between rounded-lg border border-mist/60 px-2 py-1 text-xs">
                                            <span>{trade.type} {trade.qty}</span>
                                            <span>Rs. {trade.price.toFixed(2)}</span>
                                          </div>
                                        ))}
                                      </div>
                                    </div>
                                    <div>
                                      <p className="mb-1 text-xs font-semibold uppercase tracking-[0.12em] text-slate/70">Quick Trade</p>
                                      <div className="flex gap-2">
                                        <Button className="px-3 py-2 text-xs" onClick={() => buyOne(row)}>
                                          Buy
                                        </Button>
                                        <Button variant="secondary" className="px-3 py-2 text-xs" onClick={() => openSell(row)}>
                                          Sell
                                        </Button>
                                      </div>
                                    </div>
                                    <div>
                                      <p className="mb-1 text-xs font-semibold uppercase tracking-[0.12em] text-slate/70">Price Alerts</p>
                                      <div className="mb-2 flex flex-wrap gap-1">
                                        {row.alerts.map((alert, idx) => (
                                          <Badge key={`${row.id}-${idx}`} variant="neutral">
                                            Rs. {alert}
                                          </Badge>
                                        ))}
                                      </div>
                                      <div className="flex gap-2">
                                        <input
                                          value={alertDraft[row.id] ?? ""}
                                          onChange={(e) => setAlertDraft((prev) => ({ ...prev, [row.id]: e.target.value }))}
                                          placeholder="Set alert price"
                                          className="h-9 w-full rounded-lg border border-mist px-2 text-xs"
                                        />
                                        <Button variant="ghost" className="px-2 py-1.5 text-xs" onClick={() => addAlert(row.id)}>
                                          Add
                                        </Button>
                                      </div>
                                    </div>
                                  </div>
                                </td>
                              </tr>
                            ) : null}
                          </Fragment>
                        )
                      })}
                    </tbody>
                  </table>
                </div>
                )}
              </CardBody>
            </Card>

            <div className="space-y-5">
              <Card>
                <CardHeader title="Sector Allocation" subtitle="Click slice to filter holdings" />
                <CardBody>
                  <div className="h-56">
                    <ResponsiveContainer width="100%" height="100%">
                      <PieChart>
                        <Pie
                          data={sectorAllocation}
                          dataKey="value"
                          nameKey="sector"
                          innerRadius={50}
                          outerRadius={84}
                          onClick={(_, index) => {
                            const next = sectorAllocation[index]?.sector
                            if (!next) return
                            setSelectedSector((prev) => (prev === next ? null : next))
                          }}
                        >
                          {sectorAllocation.map((entry, idx) => (
                            <Cell
                              key={entry.sector}
                              fill={COLORS[idx % COLORS.length]}
                              stroke={selectedSector === entry.sector ? "#10151f" : "#fff"}
                              strokeWidth={selectedSector === entry.sector ? 2 : 1}
                            />
                          ))}
                        </Pie>
                        <Tooltip formatter={(value) => `Rs. ${Math.round(Number(value ?? 0)).toLocaleString()}`} />
                      </PieChart>
                    </ResponsiveContainer>
                  </div>
                  <div className="flex flex-wrap gap-1">
                    {sectorAllocation.map((entry, idx) => (
                      <button
                        key={entry.sector}
                        type="button"
                        onClick={() => setSelectedSector((prev) => (prev === entry.sector ? null : entry.sector))}
                        className="rounded-full px-2 py-1 text-xs font-semibold"
                        style={{
                          background: `${COLORS[idx % COLORS.length]}20`,
                          color: "#1f2d42",
                          outline: selectedSector === entry.sector ? `2px solid ${COLORS[idx % COLORS.length]}` : "none",
                        }}
                      >
                        {entry.sector}
                      </button>
                    ))}
                  </div>
                </CardBody>
              </Card>

              <Card>
                <CardHeader title="Cash Position" />
                <CardBody>
                  <p className="text-xs uppercase tracking-[0.14em] text-slate/70">Available Cash</p>
                  <p className="mt-1 font-display text-3xl font-extrabold text-ink">Rs. {Math.round(cash).toLocaleString()}</p>
                  <Button className="mt-3 w-full" onClick={() => setCash((c) => c + 50_000)}>
                    Add Funds
                  </Button>
                </CardBody>
              </Card>
            </div>
          </div>
        )}

        {sellDraft ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-ink/35 px-4">
          <Card className="w-full max-w-md">
            <CardHeader title="Sell Position" subtitle="Pre-filled trade form" />
            <CardBody>
              <div className="space-y-3">
                <div>
                  <p className="text-xs text-slate/75">Side</p>
                  <p className="font-semibold text-ink">SELL</p>
                </div>
                <label className="block">
                  <span className="mb-1 block text-xs text-slate/75">Quantity</span>
                  <input
                    className="h-10 w-full rounded-lg border border-mist px-3 text-sm"
                    value={sellDraft.qty}
                    onChange={(e) => setSellDraft((d) => (d ? { ...d, qty: e.target.value } : d))}
                  />
                </label>
                <label className="block">
                  <span className="mb-1 block text-xs text-slate/75">Price</span>
                  <input
                    className="h-10 w-full rounded-lg border border-mist px-3 text-sm"
                    value={sellDraft.price}
                    onChange={(e) => setSellDraft((d) => (d ? { ...d, price: e.target.value } : d))}
                  />
                </label>
                <div className="flex justify-end gap-2 pt-2">
                  <Button variant="ghost" onClick={() => setSellDraft(null)}>
                    Cancel
                  </Button>
                  <Button onClick={submitSell}>Submit Sell (mock)</Button>
                </div>
              </div>
            </CardBody>
          </Card>
        </div>
        ) : null}
    </div>
  )
}
