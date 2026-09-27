import { useEffect, useMemo, useState } from "react"
import { cn } from "../../lib/cn"
import { Badge } from "../ui/Badge"
import { Button } from "../ui/Button"
import { Card } from "../ui/Card"
import { Input } from "../ui/Input"
import { Select } from "../ui/Select"
import { Textarea } from "../ui/Textarea"
import { HelpTooltip } from "../ui/HelpTooltip"
import { StockSearchInput, type StockOption } from "../trades/StockSearchInput"

export type WizardStep = 0 | 1 | 2

export type TradeDraft = {
  stockSymbol: string
  strategy: string
  plannedEntryPrice: string
  targetPrice: string
  stopLossPrice: string
  thesis: string
  actualEntryPrice: string
  quantity: string
  entryTime: string
  broker: string
  brokerFees: string
  orderType: string
  exitPrice: string
  exitDate: string
  exitReason: string
  emotionalStateAtExit: string
  lessonLearned: string
}

type TradeEntryWizardProps = {
  initialDraft?: Partial<TradeDraft>
  initialStep?: WizardStep
  mode?: "create" | "edit"
  onSave?: (draft: TradeDraft) => void
  onCancel?: () => void
  className?: string
}

const stepLabels = ["Plan", "Execute", "Result"]

const baseDraft: TradeDraft = {
  stockSymbol: "",
  strategy: "",
  plannedEntryPrice: "",
  targetPrice: "",
  stopLossPrice: "",
  thesis: "",
  actualEntryPrice: "",
  quantity: "",
  entryTime: "",
  broker: "",
  brokerFees: "",
  orderType: "",
  exitPrice: "",
  exitDate: "",
  exitReason: "",
  emotionalStateAtExit: "",
  lessonLearned: "",
}

export function TradeEntryWizard({
  initialDraft,
  initialStep = 0,
  mode = "create",
  onSave,
  onCancel,
  className,
}: TradeEntryWizardProps) {
  const mergedInitial = useMemo(() => ({ ...baseDraft, ...(initialDraft ?? {}) }), [initialDraft])

  const [step, setStep] = useState<WizardStep>(initialStep)
  const [draft, setDraft] = useState<TradeDraft>(mergedInitial)
  const [selectedStock, setSelectedStock] = useState<StockOption | null>(
    mergedInitial.stockSymbol ? { id: -1, symbol: mergedInitial.stockSymbol, name: mergedInitial.stockSymbol, sector: "" } : null,
  )
  const [submitted, setSubmitted] = useState(false)

  useEffect(() => {
    setStep(initialStep)
    setDraft(mergedInitial)
    setSelectedStock(
      mergedInitial.stockSymbol
        ? { id: -1, symbol: mergedInitial.stockSymbol, name: mergedInitial.stockSymbol, sector: "" }
        : null,
    )
    setSubmitted(false)
  }, [initialStep, mergedInitial])

  const progress = ((step + 1) / stepLabels.length) * 100

  const stepErrors = useMemo(() => {
    if (step === 0) {
      return [draft.stockSymbol, draft.strategy, draft.plannedEntryPrice, draft.targetPrice, draft.stopLossPrice].some(
        (v) => !String(v).trim(),
      )
    }

    if (step === 1) {
      return [draft.actualEntryPrice, draft.quantity, draft.entryTime].some((v) => !String(v).trim())
    }

    return [draft.exitPrice, draft.exitDate, draft.exitReason].some((v) => !String(v).trim())
  }, [step, draft])

  const estimatedPnL = useMemo(() => {
    const qty = Number(draft.quantity || 0)
    const entry = Number(draft.actualEntryPrice || draft.plannedEntryPrice || 0)
    const exit = Number(draft.exitPrice || draft.targetPrice || 0)
    if (!qty || !entry || !exit) return 0
    return (exit - entry) * qty
  }, [draft.quantity, draft.actualEntryPrice, draft.plannedEntryPrice, draft.exitPrice, draft.targetPrice])

  function update<K extends keyof TradeDraft>(key: K, value: TradeDraft[K]) {
    setDraft((prev) => ({ ...prev, [key]: value }))
  }

  function goNext() {
    if (stepErrors) return

    if (step < 2) {
      setStep((prev) => (prev + 1) as WizardStep)
      return
    }

    onSave?.(draft)
    setSubmitted(true)
  }

  function goBack() {
    if (step > 0) setStep((prev) => (prev - 1) as WizardStep)
  }

  function resetAll() {
    setDraft(mergedInitial)
    setStep(initialStep)
    setSubmitted(false)
    setSelectedStock(
      mergedInitial.stockSymbol
        ? { id: -1, symbol: mergedInitial.stockSymbol, name: mergedInitial.stockSymbol, sector: "" }
        : null,
    )
  }

  return (
    <Card className={cn("overflow-hidden", className)}>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="font-display text-xl font-bold text-ink">
            {mode === "edit" ? "Edit Trade Wizard" : "Trade Entry Wizard"}
          </h2>
          <p className="mt-1 text-sm text-slate">Capture complete lifecycle from setup to post-trade review.</p>
        </div>
        <Badge tone="neutral">Step {step + 1} of 3</Badge>
      </div>

      <div className="mt-4 h-2 w-full rounded-full bg-mist/60">
        <div className="h-2 rounded-full bg-ink transition-all duration-500" style={{ width: `${progress}%` }} />
      </div>

      <div className="mt-3 flex gap-2">
        {stepLabels.map((label, idx) => (
          <span
            key={label}
            className={`rounded-lg px-2.5 py-1 text-xs font-bold tracking-wide transition ${
              idx === step ? "bg-ink text-white" : "bg-slate/10 text-slate"
            }`}
          >
            {label}
          </span>
        ))}
      </div>

      <div key={step} className="mt-5 animate-rise">
        {step === 0 && (
          <div className="grid gap-3 md:grid-cols-2">
            <StockSearchInput
              selectedStock={selectedStock}
              onSelect={(stock) => {
                setSelectedStock(stock)
                update("stockSymbol", stock.symbol)
              }}
            />
            <Select value={draft.strategy} onChange={(e) => update("strategy", e.target.value)}>
              <option value="">Select strategy</option>
              <option>Turtle Breakout</option>
              <option>Support Bounce</option>
              <option>Sector Rotation</option>
              <option>Dividend Capture</option>
            </Select>
            <div className="md:col-span-2 rounded-xl border border-mist/70 bg-white/90 p-3 text-xs text-slate">
              <p className="inline-flex items-center gap-1 font-semibold text-ink">
                Strategy Guide
                <HelpTooltip text="See full strategy explanations and examples." link="/help#strategy-examples" />
              </p>
              <p className="mt-1">
                Example: <span className="font-semibold">Turtle Breakout</span> enters on a 20-day high with confirmation volume.
              </p>
            </div>
            <Input
              type="number"
              placeholder="Planned entry price"
              value={draft.plannedEntryPrice}
              onChange={(e) => update("plannedEntryPrice", e.target.value)}
            />
            <Input
              type="number"
              placeholder="Target price"
              value={draft.targetPrice}
              onChange={(e) => update("targetPrice", e.target.value)}
            />
            <Input
              type="number"
              placeholder="Stop loss"
              value={draft.stopLossPrice}
              onChange={(e) => update("stopLossPrice", e.target.value)}
            />
            <Textarea
              className="md:col-span-2"
              placeholder="Entry thesis / trigger confirmation"
              value={draft.thesis}
              onChange={(e) => update("thesis", e.target.value)}
            />
          </div>
        )}

        {step === 1 && (
          <div className="grid gap-3 md:grid-cols-2">
            <Input
              type="number"
              placeholder="Actual entry price"
              value={draft.actualEntryPrice}
              onChange={(e) => update("actualEntryPrice", e.target.value)}
            />
            <Input
              type="number"
              placeholder="Quantity"
              value={draft.quantity}
              onChange={(e) => update("quantity", e.target.value)}
            />
            <Input type="datetime-local" value={draft.entryTime} onChange={(e) => update("entryTime", e.target.value)} />
            <Input placeholder="Broker" value={draft.broker} onChange={(e) => update("broker", e.target.value)} />
            <Input
              type="number"
              placeholder="Broker fees"
              value={draft.brokerFees}
              onChange={(e) => update("brokerFees", e.target.value)}
            />
            <Select value={draft.orderType} onChange={(e) => update("orderType", e.target.value)}>
              <option value="">Order type</option>
              <option>Market</option>
              <option>Limit</option>
              <option>Stop-Limit</option>
            </Select>
          </div>
        )}

        {step === 2 && (
          <div className="grid gap-3 md:grid-cols-2">
            <Input
              type="number"
              placeholder="Exit price"
              value={draft.exitPrice}
              onChange={(e) => update("exitPrice", e.target.value)}
            />
            <Input type="date" value={draft.exitDate} onChange={(e) => update("exitDate", e.target.value)} />
            <Select value={draft.exitReason} onChange={(e) => update("exitReason", e.target.value)}>
              <option value="">Exit reason</option>
              <option>Target Hit</option>
              <option>Stop Loss Hit</option>
              <option>Trend Weakness</option>
              <option>News / Event Risk</option>
            </Select>
            <Select
              value={draft.emotionalStateAtExit}
              onChange={(e) => update("emotionalStateAtExit", e.target.value)}
            >
              <option value="">Emotional state at exit</option>
              <option>Calm</option>
              <option>Confident</option>
              <option>Anxious</option>
              <option>Impulsive</option>
            </Select>
            <Textarea
              className="md:col-span-2"
              placeholder="Lesson learned"
              value={draft.lessonLearned}
              onChange={(e) => update("lessonLearned", e.target.value)}
            />
          </div>
        )}
      </div>

      <div className="mt-5 flex flex-wrap items-center justify-between gap-3 border-t border-mist/70 pt-4">
        <p className="text-sm text-slate">
          Est. P/L: <span className="font-bold text-ink">Rs. {estimatedPnL.toLocaleString()}</span>
        </p>

        <div className="flex gap-2">
          {onCancel ? (
            <Button variant="ghost" onClick={onCancel}>
              Cancel
            </Button>
          ) : null}
          <Button variant="ghost" onClick={resetAll}>
            Reset
          </Button>
          <Button variant="secondary" onClick={goBack} disabled={step === 0}>
            Back
          </Button>
          <Button onClick={goNext} disabled={stepErrors}>
            {step === 2 ? (mode === "edit" ? "Update Trade" : "Save Trade") : "Continue"}
          </Button>
        </div>
      </div>

      {submitted && (
        <div className="mt-4 rounded-xl border border-pine/30 bg-pine/10 p-3 text-sm text-pine">
          Trade captured successfully: {draft.stockSymbol} using {draft.strategy}.
        </div>
      )}
    </Card>
  )
}
