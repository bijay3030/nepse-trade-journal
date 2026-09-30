import { useMemo } from "react"
import { useSearchParams } from "react-router-dom"
import { TradeEntryWizard, type TradeDraft } from "../components/trade/TradeEntryWizard"
import { PlanFromSetup } from "../features/watchlist/PlanFromSetup"

export function TradeNewPage() {
  const [searchParams] = useSearchParams()
  const tutorial = searchParams.get("tutorial")
  const watchlistId = Number(searchParams.get("watchlist"))

  const tutorialDraft = useMemo<Partial<TradeDraft> | undefined>(() => {
    if (!tutorial) return undefined

    return {
      stockSymbol: "NABIL",
      strategy: "Turtle Breakout",
      plannedEntryPrice: "550",
      targetPrice: "590",
      stopLossPrice: "535",
      thesis: "Tutorial setup: breakout above resistance with expanding volume.",
    }
  }, [tutorial])

  if (watchlistId > 0) return <PlanFromSetup itemId={watchlistId} />

  return <TradeEntryWizard initialDraft={tutorialDraft} />
}
