import { MarketOverviewPage } from "./MarketOverviewPage"
import { ScreenerPage } from "./ScreenerPage"

export function DashboardPage() {
  return (
    <div className="min-w-0 space-y-10">
      <MarketOverviewPage />
      <ScreenerPage />
    </div>
  )
}
