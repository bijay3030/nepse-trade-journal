import { AnimatePresence, motion } from "framer-motion"
import { ArrowUpDown, ChartNoAxesCombined, FileDown, Pencil, Play, Printer, RefreshCw, Trash2, X } from "lucide-react"
import { useEffect, useMemo, useRef, useState } from "react"
import {
  CartesianGrid,
  Line,
  LineChart,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts"
import { useIsMobile } from "../hooks/useIsMobile"
import { usePullToRefresh } from "../hooks/usePullToRefresh"
import { TradeEntryWizard, type TradeDraft } from "../components/trade/TradeEntryWizard"
import { Badge, Button, Card, Input, PriceDisplay, Select } from "../components/ui"
import { cn } from "../lib/cn"

type TradeStatus = "planned" | "active" | "closed"
type PnlFilter = "all" | "win" | "loss"
type DateRangeFilter = "all" | "7d" | "30d" | "90d"
type SortBy = "date" | "pnl" | "rr"

type TradeRecord = {
  id: number
  stock: string
  strategy: string
  status: TradeStatus
  plannedAt: string
  rr: number
  plan: {
    entry: number
    target: number
    stop: number
    thesis: string
  }
  execution?: {
    entry: number
    quantity: number
    time: string
    broker: string
    brokerFees: number
  }
  result?: {
    exit: number
    date: string
    reason: string
    pnl: number
    mae: number
    mfe: number
    mistakes: string[]
    lesson: string
  }
  priceAlertEnabled: boolean
  replay: Array<{ point: string; price: number }>
}

const now = new Date()
const daysAgo = (days: number) => new Date(now.getTime() - days * 24 * 60 * 60 * 1000).toISOString()

const seedTrades: TradeRecord[] = [
  {
    id: 1,
    stock: "NABIL",
    strategy: "Turtle Breakout",
    status: "closed",
    plannedAt: daysAgo(3),
    rr: 2.1,
    plan: { entry: 548, target: 580, stop: 532, thesis: "Breakout with volume expansion" },
    execution: { entry: 550, quantity: 300, time: daysAgo(2), broker: "ABC Securities", brokerFees: 450 },
    result: {
      exit: 578,
      date: daysAgo(1),
      reason: "Target Hit",
      pnl: 8400,
      mae: -2.4,
      mfe: 6.8,
      mistakes: ["Late Entry"],
      lesson: "Follow trigger as soon as volume confirmation appears.",
    },
    priceAlertEnabled: true,
    replay: [
      { point: "D-5", price: 530 },
      { point: "D-4", price: 538 },
      { point: "D-3", price: 548 },
      { point: "D-2", price: 554 },
      { point: "D-1", price: 572 },
      { point: "Now", price: 578 },
    ],
  },
  {
    id: 2,
    stock: "NTC",
    strategy: "Dividend Capture",
    status: "active",
    plannedAt: daysAgo(4),
    rr: 1.5,
    plan: { entry: 918, target: 950, stop: 895, thesis: "Pre-dividend momentum setup" },
    execution: { entry: 920, quantity: 120, time: daysAgo(3), broker: "XYZ Brokers", brokerFees: 320 },
    priceAlertEnabled: true,
    replay: [
      { point: "D-5", price: 902 },
      { point: "D-4", price: 915 },
      { point: "D-3", price: 920 },
      { point: "D-2", price: 928 },
      { point: "D-1", price: 926 },
      { point: "Now", price: 931 },
    ],
  },
  {
    id: 3,
    stock: "UPPER",
    strategy: "Support Bounce",
    status: "planned",
    plannedAt: daysAgo(2),
    rr: 1.9,
    plan: { entry: 240, target: 258, stop: 231, thesis: "Retest of weekly support, bullish reversal candle" },
    priceAlertEnabled: true,
    replay: [
      { point: "D-5", price: 248 },
      { point: "D-4", price: 244 },
      { point: "D-3", price: 241 },
      { point: "D-2", price: 239 },
      { point: "D-1", price: 242 },
      { point: "Now", price: 243 },
    ],
  },
  {
    id: 4,
    stock: "NIFRA",
    strategy: "Sector Rotation",
    status: "closed",
    plannedAt: daysAgo(13),
    rr: 2.4,
    plan: { entry: 322, target: 355, stop: 308, thesis: "Capital rotation into finance index leaders" },
    execution: { entry: 325, quantity: 500, time: daysAgo(12), broker: "ABC Securities", brokerFees: 410 },
    result: {
      exit: 312,
      date: daysAgo(9),
      reason: "Stop Loss Hit",
      pnl: -6500,
      mae: -4.3,
      mfe: 1.2,
      mistakes: ["Oversized Risk", "No Stop Discipline"],
      lesson: "Position size violated risk plan; cut size next time.",
    },
    priceAlertEnabled: false,
    replay: [
      { point: "D-5", price: 320 },
      { point: "D-4", price: 327 },
      { point: "D-3", price: 324 },
      { point: "D-2", price: 318 },
      { point: "D-1", price: 314 },
      { point: "Now", price: 312 },
    ],
  },
  {
    id: 5,
    stock: "SCB",
    strategy: "Support Bounce",
    status: "planned",
    plannedAt: daysAgo(10),
    rr: 2.0,
    plan: { entry: 610, target: 655, stop: 588, thesis: "Compression near monthly demand zone" },
    priceAlertEnabled: true,
    replay: [
      { point: "D-5", price: 622 },
      { point: "D-4", price: 615 },
      { point: "D-3", price: 611 },
      { point: "D-2", price: 607 },
      { point: "D-1", price: 609 },
      { point: "Now", price: 608 },
    ],
  },
]

const statusTabs: Array<{ key: "all" | TradeStatus; label: string }> = [
  { key: "all", label: "All" },
  { key: "active", label: "Active" },
  { key: "closed", label: "Closed" },
  { key: "planned", label: "Planned" },
]

const mistakeTone: Record<string, string> = {
  "Late Entry": "bg-amber-100 text-amber-700",
  "No Stop Discipline": "bg-red-100 text-red-700",
  "Oversized Risk": "bg-rose-100 text-rose-700",
  "Emotional Exit": "bg-fuchsia-100 text-fuchsia-700",
}

function toWizardDraft(trade: TradeRecord): Partial<TradeDraft> {
  return {
    stockSymbol: trade.stock,
    strategy: trade.strategy,
    plannedEntryPrice: String(trade.plan.entry),
    targetPrice: String(trade.plan.target),
    stopLossPrice: String(trade.plan.stop),
    thesis: trade.plan.thesis,
    actualEntryPrice: trade.execution ? String(trade.execution.entry) : "",
    quantity: trade.execution ? String(trade.execution.quantity) : "",
    entryTime: trade.execution ? trade.execution.time.slice(0, 16) : "",
    broker: trade.execution?.broker ?? "",
    brokerFees: trade.execution ? String(trade.execution.brokerFees) : "",
    exitPrice: trade.result ? String(trade.result.exit) : "",
    exitDate: trade.result ? trade.result.date.slice(0, 10) : "",
    exitReason: trade.result?.reason ?? "",
    lessonLearned: trade.result?.lesson ?? "",
  }
}

function computeStatusFromDraft(draft: TradeDraft): TradeStatus {
  if (draft.exitPrice && draft.exitDate) return "closed"
  if (draft.actualEntryPrice && draft.quantity && draft.entryTime) return "active"
  return "planned"
}

function isExpiredPlan(trade: TradeRecord) {
  if (trade.status !== "planned") return false
  const plannedTime = new Date(trade.plannedAt).getTime()
  return Date.now() - plannedTime > 7 * 24 * 60 * 60 * 1000
}

function inDateRange(dateIso: string, range: DateRangeFilter) {
  if (range === "all") return true
  const dateMs = new Date(dateIso).getTime()
  const days = range === "7d" ? 7 : range === "30d" ? 30 : 90
  return Date.now() - dateMs <= days * 24 * 60 * 60 * 1000
}

export function TradesPage() {
  const [trades, setTrades] = useState<TradeRecord[]>(() => {
    const raw = localStorage.getItem("trades_records_v1")
    if (!raw) return seedTrades
    try {
      return JSON.parse(raw) as TradeRecord[]
    } catch {
      return seedTrades
    }
  })
  const [activeTab, setActiveTab] = useState<"all" | TradeStatus>("all")
  const [strategyFilter, setStrategyFilter] = useState("all")
  const [stockFilter, setStockFilter] = useState("")
  const [pnlFilter, setPnlFilter] = useState<PnlFilter>("all")
  const [dateRange, setDateRange] = useState<DateRangeFilter>("all")
  const [sortBy, setSortBy] = useState<SortBy>("date")
  const [selectedTradeId, setSelectedTradeId] = useState<number | null>(null)
  const [selectedIds, setSelectedIds] = useState<number[]>([])
  const [wizardOpen, setWizardOpen] = useState(false)
  const [wizardMode, setWizardMode] = useState<"create" | "edit">("edit")
  const [wizardInitialStep, setWizardInitialStep] = useState<0 | 1 | 2>(0)
  const [wizardTradeId, setWizardTradeId] = useState<number | null>(null)
  const [visibleCount, setVisibleCount] = useState(30)
  const swipeStartRef = useRef<{ id: number | null; x: number }>({ id: null, x: 0 })
  const isMobile = useIsMobile()

  const { pullDistance, isRefreshing } = usePullToRefresh({
    enabled: isMobile,
    onRefresh: () => {
      setTrades((prev) => [...prev])
    },
  })

  useEffect(() => {
    localStorage.setItem("trades_records_v1", JSON.stringify(trades))
  }, [trades])

  useEffect(() => {
    setVisibleCount(30)
  }, [activeTab, strategyFilter, stockFilter, pnlFilter, dateRange, sortBy])

  const strategies = useMemo(() => Array.from(new Set(trades.map((t) => t.strategy))), [trades])

  const filteredTrades = useMemo(() => {
    let result = [...trades]

    if (activeTab !== "all") result = result.filter((trade) => trade.status === activeTab)
    if (strategyFilter !== "all") result = result.filter((trade) => trade.strategy === strategyFilter)
    if (stockFilter.trim()) result = result.filter((trade) => trade.stock.toLowerCase().includes(stockFilter.trim().toLowerCase()))
    if (dateRange !== "all") {
      result = result.filter((trade) => {
        const referenceDate = trade.result?.date ?? trade.execution?.time ?? trade.plannedAt
        return inDateRange(referenceDate, dateRange)
      })
    }

    if (pnlFilter !== "all") {
      result = result.filter((trade) => {
        const pnl = trade.result?.pnl ?? 0
        return pnlFilter === "win" ? pnl > 0 : pnl < 0
      })
    }

    result.sort((a, b) => {
      if (sortBy === "date") {
        const aDate = new Date(a.result?.date ?? a.execution?.time ?? a.plannedAt).getTime()
        const bDate = new Date(b.result?.date ?? b.execution?.time ?? b.plannedAt).getTime()
        return bDate - aDate
      }

      if (sortBy === "pnl") {
        return (b.result?.pnl ?? 0) - (a.result?.pnl ?? 0)
      }

      return b.rr - a.rr
    })

    return result
  }, [trades, activeTab, strategyFilter, stockFilter, dateRange, pnlFilter, sortBy])

  const selectedTrade = trades.find((t) => t.id === selectedTradeId) ?? null
  const wizardSeedTrade = trades.find((t) => t.id === wizardTradeId) ?? null

  const plannedTrades = trades.filter((t) => t.status === "planned")
  const visibleTrades = useMemo(
    () => (filteredTrades.length > visibleCount ? filteredTrades.slice(0, visibleCount) : filteredTrades),
    [filteredTrades, visibleCount],
  )

  function onCardTouchStart(tradeId: number, x: number) {
    swipeStartRef.current = { id: tradeId, x }
  }

  function onCardTouchEnd(trade: TradeRecord, x: number) {
    if (swipeStartRef.current.id !== trade.id) return
    const deltaX = x - swipeStartRef.current.x
    if (deltaX > 70) {
      openEditWizard(trade, 2)
    } else if (deltaX < -70) {
      openEditWizard(trade, trade.status === "planned" ? 1 : 0)
    }
    swipeStartRef.current = { id: null, x: 0 }
  }

  function renderTradeCard(trade: TradeRecord) {
    const expired = isExpiredPlan(trade)
    const status = expired ? "expired" : trade.status

    return (
      <article
        key={trade.id}
        className="rounded-2xl border border-mist/70 bg-white/90 p-4 shadow-panel transition hover:-translate-y-0.5"
        onTouchStart={(e) => onCardTouchStart(trade.id, e.touches[0]?.clientX ?? 0)}
        onTouchEnd={(e) => onCardTouchEnd(trade, e.changedTouches[0]?.clientX ?? 0)}
      >
        <div className="mb-2 flex items-center justify-between gap-2">
          <div>
            <p className="font-display text-lg font-bold text-ink">{trade.stock}</p>
            <p className="text-xs text-slate">{new Date(trade.plannedAt).toLocaleDateString()}</p>
          </div>
          <input
            type="checkbox"
            checked={selectedIds.includes(trade.id)}
            onChange={() => toggleSelect(trade.id)}
            className="h-4 w-4 accent-ink"
          />
        </div>

        <div className="mb-3 flex flex-wrap gap-2">
          <Badge tone="neutral">{trade.strategy}</Badge>
          <Badge tone={status === "closed" ? "gain" : status === "active" ? "neutral" : "loss"}>{status}</Badge>
        </div>

        <div className="grid grid-cols-2 gap-2 text-sm">
          <div>
            <p className="text-xs uppercase tracking-wide text-slate">Entry</p>
            <p className="font-semibold text-ink">Rs. {trade.execution?.entry ?? trade.plan.entry}</p>
          </div>
          <div>
            <p className="text-xs uppercase tracking-wide text-slate">Exit</p>
            <p className="font-semibold text-ink">{trade.result ? `Rs. ${trade.result.exit}` : "-"}</p>
          </div>
          <div>
            <p className="text-xs uppercase tracking-wide text-slate">P&L</p>
            <PriceDisplay amount={trade.result?.pnl ?? 0} showSign size="sm" />
          </div>
          <div>
            <p className="text-xs uppercase tracking-wide text-slate">R:R</p>
            <p className="font-semibold text-ink">{trade.rr.toFixed(2)}</p>
          </div>
        </div>

        {isMobile ? <p className="mt-2 text-[11px] text-slate/70">Swipe right: Sell, swipe left: Edit</p> : null}

        <div className="mt-3 flex items-center gap-2">
          <Button variant="secondary" className="flex-1" onClick={() => setSelectedTradeId(trade.id)}>
            View Detail
          </Button>
          <Button variant="ghost" onClick={() => openEditWizard(trade, trade.status === "planned" ? 1 : 0)}>
            <Pencil className="h-4 w-4" />
          </Button>
        </div>
      </article>
    )
  }

  function toggleSelect(id: number) {
    setSelectedIds((prev) => (prev.includes(id) ? prev.filter((item) => item !== id) : [...prev, id]))
  }

  function selectAllVisible() {
    const visibleIds = filteredTrades.map((trade) => trade.id)
    const allVisibleSelected = visibleIds.every((id) => selectedIds.includes(id))
    setSelectedIds(allVisibleSelected ? selectedIds.filter((id) => !visibleIds.includes(id)) : Array.from(new Set([...selectedIds, ...visibleIds])))
  }

  function openEditWizard(trade: TradeRecord, initialStep: 0 | 1 | 2 = 0) {
    setWizardTradeId(trade.id)
    setWizardInitialStep(initialStep)
    setWizardMode("edit")
    setWizardOpen(true)
  }

  function onWizardSave(draft: TradeDraft) {
    if (!wizardSeedTrade) return

    setTrades((prev) =>
      prev.map((trade) => {
        if (trade.id !== wizardSeedTrade.id) return trade

        const status = computeStatusFromDraft(draft)
        const entry = Number(draft.actualEntryPrice || draft.plannedEntryPrice || trade.plan.entry)
        const qty = Number(draft.quantity || trade.execution?.quantity || 0)
        const exit = Number(draft.exitPrice || 0)
        const pnl = status === "closed" ? (exit - entry) * qty : trade.result?.pnl ?? 0
        const risk = Number(draft.plannedEntryPrice || trade.plan.entry) - Number(draft.stopLossPrice || trade.plan.stop)
        const reward = Number(draft.targetPrice || trade.plan.target) - Number(draft.plannedEntryPrice || trade.plan.entry)

        return {
          ...trade,
          stock: draft.stockSymbol,
          strategy: draft.strategy,
          status,
          rr: risk > 0 ? Number((reward / risk).toFixed(2)) : trade.rr,
          plan: {
            entry: Number(draft.plannedEntryPrice || trade.plan.entry),
            target: Number(draft.targetPrice || trade.plan.target),
            stop: Number(draft.stopLossPrice || trade.plan.stop),
            thesis: draft.thesis,
          },
          execution:
            status !== "planned"
              ? {
                  entry,
                  quantity: qty,
                  time: draft.entryTime || trade.execution?.time || new Date().toISOString(),
                  broker: draft.broker || trade.execution?.broker || "",
                  brokerFees: Number(draft.brokerFees || trade.execution?.brokerFees || 0),
                }
              : undefined,
          result:
            status === "closed"
              ? {
                  exit,
                  date: draft.exitDate || trade.result?.date || new Date().toISOString(),
                  reason: draft.exitReason || trade.result?.reason || "Manual",
                  pnl,
                  mae: trade.result?.mae ?? -1.8,
                  mfe: trade.result?.mfe ?? 4.6,
                  mistakes: trade.result?.mistakes ?? [],
                  lesson: draft.lessonLearned || trade.result?.lesson || "",
                }
              : undefined,
        }
      }),
    )

    setWizardOpen(false)
  }

  function executePlannedTrade(plan: TradeRecord) {
    openEditWizard(plan, 1)
  }

  function removeTrade(id: number) {
    setTrades((prev) => prev.filter((trade) => trade.id !== id))
    setSelectedTradeId((prev) => (prev === id ? null : prev))
    setSelectedIds((prev) => prev.filter((item) => item !== id))
  }

  function exportCsv() {
    const target = selectedIds.length > 0 ? trades.filter((trade) => selectedIds.includes(trade.id)) : filteredTrades
    const rows = [
      ["Stock", "Strategy", "Status", "Planned Entry", "Actual Entry", "Exit", "P&L", "R:R", "Date"],
      ...target.map((trade) => [
        trade.stock,
        trade.strategy,
        isExpiredPlan(trade) ? "expired" : trade.status,
        trade.plan.entry,
        trade.execution?.entry ?? "",
        trade.result?.exit ?? "",
        trade.result?.pnl ?? "",
        trade.rr,
        trade.result?.date ?? trade.execution?.time ?? trade.plannedAt,
      ]),
    ]

    const csv = rows.map((row) => row.map((cell) => `"${String(cell).replaceAll("\"", "\"\"")}"`).join(",")).join("\n")
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" })
    const url = URL.createObjectURL(blob)
    const link = document.createElement("a")
    link.href = url
    link.download = "nepse-trades-report.csv"
    link.click()
    URL.revokeObjectURL(url)
  }

  function printReport() {
    const target = selectedIds.length > 0 ? trades.filter((trade) => selectedIds.includes(trade.id)) : filteredTrades
    const rowsHtml = target
      .map(
        (trade) => `
      <tr>
        <td>${trade.stock}</td>
        <td>${trade.strategy}</td>
        <td>${isExpiredPlan(trade) ? "Expired" : trade.status}</td>
        <td>${trade.execution?.entry ?? trade.plan.entry}</td>
        <td>${trade.result?.exit ?? "-"}</td>
        <td>${trade.result?.pnl ?? "-"}</td>
        <td>${trade.rr}</td>
      </tr>
    `,
      )
      .join("")

    const printWindow = window.open("", "_blank", "width=1000,height=700")
    if (!printWindow) return

    printWindow.document.write(`
      <html>
        <head>
          <title>Trade Report</title>
          <style>
            body { font-family: Arial, sans-serif; padding: 24px; }
            h1 { margin: 0 0 16px; }
            table { width: 100%; border-collapse: collapse; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; font-size: 12px; }
            th { background: #f5f5f5; }
          </style>
        </head>
        <body>
          <h1>NEPSE Trade Report</h1>
          <table>
            <thead>
              <tr>
                <th>Stock</th><th>Strategy</th><th>Status</th><th>Entry</th><th>Exit</th><th>P&L</th><th>R:R</th>
              </tr>
            </thead>
            <tbody>${rowsHtml}</tbody>
          </table>
        </body>
      </html>
    `)

    printWindow.document.close()
    printWindow.focus()
    printWindow.print()
  }

  return (
    <div className="space-y-6">
      <Card>
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h1 className="font-display text-2xl font-bold text-ink">Trade Management</h1>
            <p className="mt-1 text-sm text-slate">Filter, review, replay, and manage your full trading lifecycle.</p>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <Button variant="secondary" onClick={exportCsv}>
              <FileDown className="mr-2 h-4 w-4" />
              Export CSV
            </Button>
            <Button variant="secondary" onClick={printReport}>
              <Printer className="mr-2 h-4 w-4" />
              Print Report
            </Button>
          </div>
        </div>

        <div className="mt-4 flex flex-wrap gap-2">
          {statusTabs.map((tab) => (
            <button
              key={tab.key}
              type="button"
              onClick={() => setActiveTab(tab.key)}
              className={cn(
                "rounded-lg px-3 py-1.5 text-sm font-semibold transition",
                activeTab === tab.key ? "bg-ink text-white" : "bg-slate/10 text-slate hover:bg-slate/20",
              )}
            >
              {tab.label}
            </button>
          ))}
        </div>

        <div className="mt-4 grid gap-3 lg:grid-cols-5">
          <Select value={strategyFilter} onChange={(e) => setStrategyFilter(e.target.value)}>
            <option value="all">All strategies</option>
            {strategies.map((strategy) => (
              <option key={strategy} value={strategy}>
                {strategy}
              </option>
            ))}
          </Select>
          <Select value={dateRange} onChange={(e) => setDateRange(e.target.value as DateRangeFilter)}>
            <option value="all">All dates</option>
            <option value="7d">Last 7 days</option>
            <option value="30d">Last 30 days</option>
            <option value="90d">Last 90 days</option>
          </Select>
          <Input value={stockFilter} onChange={(e) => setStockFilter(e.target.value)} placeholder="Filter by stock" />
          <Select value={pnlFilter} onChange={(e) => setPnlFilter(e.target.value as PnlFilter)}>
            <option value="all">All P&L</option>
            <option value="win">Wins only</option>
            <option value="loss">Losses only</option>
          </Select>
          <Select value={sortBy} onChange={(e) => setSortBy(e.target.value as SortBy)}>
            <option value="date">Sort: Date</option>
            <option value="pnl">Sort: P&L</option>
            <option value="rr">Sort: R:R</option>
          </Select>
        </div>

        <div className="mt-4 flex flex-wrap items-center justify-between gap-2 border-t border-mist/70 pt-3 text-sm text-slate">
          <button type="button" className="inline-flex items-center font-semibold text-ink" onClick={selectAllVisible}>
            <ArrowUpDown className="mr-1 h-3.5 w-3.5" />
            Select/Deselect visible ({selectedIds.length} selected)
          </button>
          <p>{filteredTrades.length} trade(s) matching filters</p>
        </div>

        {isMobile ? (
          <div className="mt-4 space-y-3">
            {isRefreshing ? (
              <p className="inline-flex items-center text-xs font-semibold text-slate">
                <RefreshCw className="mr-1 h-3.5 w-3.5 animate-spin" />
                Refreshing...
              </p>
            ) : pullDistance > 8 ? (
              <p className="text-xs font-semibold text-slate">Pull to refresh...</p>
            ) : null}
            {visibleTrades.map((trade) => renderTradeCard(trade))}
          </div>
        ) : (
          <div className="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">{visibleTrades.map((trade) => renderTradeCard(trade))}</div>
        )}
        {filteredTrades.length > visibleCount ? (
          <div className="mt-3 flex justify-center">
            <Button variant="secondary" onClick={() => setVisibleCount((n) => n + 30)}>
              Load More Trades
            </Button>
          </div>
        ) : null}
      </Card>

      <Card>
        <div className="flex items-center justify-between gap-3">
          <div>
            <h2 className="font-display text-xl font-bold text-ink">Planned Trades</h2>
            <p className="mt-1 text-sm text-slate">Unexecuted plans with alerts and auto-expiry after 7 days.</p>
          </div>
          <Badge tone="neutral">{plannedTrades.length} plans</Badge>
        </div>

        <div className="mt-4 space-y-3">
          {plannedTrades.map((plan) => {
            const expired = isExpiredPlan(plan)
            return (
              <div key={plan.id} className="rounded-xl border border-mist/70 bg-white/90 p-4">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <p className="font-semibold text-ink">{plan.stock}</p>
                    <p className="text-xs text-slate">
                      Planned {new Date(plan.plannedAt).toLocaleDateString()} · Entry alert at Rs. {plan.plan.entry}
                    </p>
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    <Badge tone={expired ? "loss" : "neutral"}>{expired ? "Expired" : "Planned"}</Badge>
                    <Badge tone={plan.priceAlertEnabled ? "gain" : "neutral"}>
                      {plan.priceAlertEnabled ? "Alert On" : "Alert Off"}
                    </Badge>
                    <Button variant="secondary" disabled={expired} onClick={() => executePlannedTrade(plan)}>
                      <Play className="mr-1 h-4 w-4" />
                      Execute Now
                    </Button>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      </Card>

      <AnimatePresence>
        {selectedTrade ? (
          <motion.div
            className="fixed inset-0 z-50 flex items-center justify-center bg-ink/55 p-3"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
          >
            <motion.div
              className="max-h-[92vh] w-full max-w-6xl overflow-auto rounded-2xl bg-white p-5 shadow-panel"
              initial={{ opacity: 0, y: 18 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 18 }}
            >
              <div className="mb-4 flex items-center justify-between gap-3">
                <div>
                  <h3 className="font-display text-2xl font-bold text-ink">{selectedTrade.stock} Trade Detail</h3>
                  <p className="text-sm text-slate">Plan to execution to result breakdown</p>
                </div>
                <button
                  type="button"
                  onClick={() => setSelectedTradeId(null)}
                  className="rounded-lg border border-mist/70 p-2 text-slate"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>

              <div className="grid gap-4 xl:grid-cols-3">
                <Card>
                  <h4 className="font-display text-lg font-bold text-ink">Plan</h4>
                  <p className="mt-2 text-sm text-slate">Strategy: {selectedTrade.strategy}</p>
                  <p className="text-sm text-slate">Entry: Rs. {selectedTrade.plan.entry}</p>
                  <p className="text-sm text-slate">Target: Rs. {selectedTrade.plan.target}</p>
                  <p className="text-sm text-slate">Stop: Rs. {selectedTrade.plan.stop}</p>
                  <p className="mt-2 text-sm text-ink">{selectedTrade.plan.thesis}</p>
                </Card>

                <Card>
                  <h4 className="font-display text-lg font-bold text-ink">Execution</h4>
                  {selectedTrade.execution ? (
                    <>
                      <p className="mt-2 text-sm text-slate">Actual Entry: Rs. {selectedTrade.execution.entry}</p>
                      <p className="text-sm text-slate">Quantity: {selectedTrade.execution.quantity}</p>
                      <p className="text-sm text-slate">Broker: {selectedTrade.execution.broker}</p>
                      <p className="text-sm text-slate">Fees: Rs. {selectedTrade.execution.brokerFees}</p>
                    </>
                  ) : (
                    <p className="mt-2 text-sm text-slate">Not executed yet.</p>
                  )}
                </Card>

                <Card>
                  <h4 className="font-display text-lg font-bold text-ink">Result</h4>
                  {selectedTrade.result ? (
                    <>
                      <p className="mt-2 text-sm text-slate">Exit: Rs. {selectedTrade.result.exit}</p>
                      <p className="text-sm text-slate">Reason: {selectedTrade.result.reason}</p>
                      <p className="text-sm text-slate">
                        P&L: <PriceDisplay amount={selectedTrade.result.pnl} showSign size="sm" />
                      </p>
                      <div className="mt-2 flex items-center gap-2 text-sm">
                        <Badge tone="loss">MAE {selectedTrade.result.mae}%</Badge>
                        <Badge tone="gain">MFE {selectedTrade.result.mfe}%</Badge>
                      </div>
                      <div className="mt-3 flex flex-wrap gap-2">
                        {selectedTrade.result.mistakes.map((mistake) => (
                          <span key={mistake} className={cn("rounded-full px-2 py-1 text-xs font-semibold", mistakeTone[mistake] ?? "bg-slate/10 text-slate")}>{mistake}</span>
                        ))}
                      </div>
                      <p className="mt-3 rounded-lg bg-slate/10 p-2 text-sm text-ink">Lesson: {selectedTrade.result.lesson}</p>
                    </>
                  ) : (
                    <p className="mt-2 text-sm text-slate">Result pending.</p>
                  )}
                </Card>
              </div>

              <Card className="mt-4">
                <div className="mb-3 flex items-center gap-2">
                  <ChartNoAxesCombined className="h-4 w-4 text-slate" />
                  <h4 className="font-display text-lg font-bold text-ink">Visual Trade Replay</h4>
                </div>
                <div className="h-72">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={selectedTrade.replay}>
                      <CartesianGrid strokeDasharray="4 4" stroke="#d9e0ea" />
                      <XAxis dataKey="point" />
                      <YAxis />
                      <Tooltip />
                      <Line dataKey="price" type="monotone" stroke="#003893" strokeWidth={2.5} dot={{ r: 4 }} />
                      <ReferenceLine y={selectedTrade.execution?.entry ?? selectedTrade.plan.entry} stroke="#18745a" strokeDasharray="6 4" label="Entry" />
                      {selectedTrade.result ? (
                        <ReferenceLine y={selectedTrade.result.exit} stroke="#ff6b2c" strokeDasharray="6 4" label="Exit" />
                      ) : null}
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </Card>

              <div className="mt-4 flex flex-wrap justify-end gap-2">
                <Button variant="secondary" onClick={() => openEditWizard(selectedTrade, selectedTrade.status === "planned" ? 1 : 0)}>
                  <Pencil className="mr-1 h-4 w-4" />
                  Edit Trade
                </Button>
                <Button variant="ghost" onClick={() => removeTrade(selectedTrade.id)}>
                  <Trash2 className="mr-1 h-4 w-4" />
                  Delete
                </Button>
              </div>
            </motion.div>
          </motion.div>
        ) : null}
      </AnimatePresence>

      <AnimatePresence>
        {wizardOpen && wizardSeedTrade ? (
          <motion.div
            className="fixed inset-0 z-50 flex items-center justify-center bg-ink/60 p-3"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
          >
            <motion.div
              className="max-h-[94vh] w-full max-w-4xl overflow-auto rounded-2xl bg-white p-3 sm:p-5"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 20 }}
            >
              <TradeEntryWizard
                mode={wizardMode}
                initialStep={wizardInitialStep}
                initialDraft={toWizardDraft(wizardSeedTrade)}
                onCancel={() => setWizardOpen(false)}
                onSave={onWizardSave}
              />
            </motion.div>
          </motion.div>
        ) : null}
      </AnimatePresence>
    </div>
  )
}
