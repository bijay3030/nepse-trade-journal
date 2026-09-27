import { Suspense, lazy } from "react"
import { Navigate, Route, Routes } from "react-router-dom"
import { LoadingSpinner } from "./components/ui"
import { PlatformLayout } from "./layouts/PlatformLayout"

const AnalyticsPage = lazy(async () => import("./pages/AnalyticsPage").then((m) => ({ default: m.AnalyticsPage })))
const DashboardPage = lazy(async () => import("./pages/DashboardPage").then((m) => ({ default: m.DashboardPage })))
const JournalPage = lazy(async () => import("./pages/JournalPage").then((m) => ({ default: m.JournalPage })))
const HelpPage = lazy(async () => import("./pages/HelpPage").then((m) => ({ default: m.HelpPage })))
const PortfolioPage = lazy(async () => import("./pages/PortfolioPage").then((m) => ({ default: m.PortfolioPage })))
const SettingsPage = lazy(async () => import("./pages/SettingsPage").then((m) => ({ default: m.SettingsPage })))
const TradeNewPage = lazy(async () => import("./pages/TradeNewPage").then((m) => ({ default: m.TradeNewPage })))
const StocksPage = lazy(async () => import("./pages/StocksPage").then((m) => ({ default: m.StocksPage })))
const TradesPage = lazy(async () => import("./pages/TradesPage").then((m) => ({ default: m.TradesPage })))
const MarketOverviewPage = lazy(async () => import("./pages/MarketOverviewPage").then((m) => ({ default: m.MarketOverviewPage })))
const ScreenerPage = lazy(async () => import("./pages/ScreenerPage").then((m) => ({ default: m.ScreenerPage })))
const StockAnalysisPage = lazy(async () => import("./pages/StockAnalysisPage").then((m) => ({ default: m.StockAnalysisPage })))

function RouteFallback() {
  return (
    <div className="flex h-[50vh] items-center justify-center">
      <LoadingSpinner size="lg" />
    </div>
  )
}

function App() {
  return (
    <Suspense fallback={<RouteFallback />}>
      <Routes>
        <Route path="/" element={<PlatformLayout />}>
          <Route index element={<Navigate to="/dashboard" replace />} />
          <Route path="dashboard" element={<DashboardPage />} />
          <Route path="market" element={<MarketOverviewPage />} />
          <Route path="screener" element={<ScreenerPage />} />
          <Route path="screener/:symbol" element={<StockAnalysisPage />} />
          <Route path="trade/new" element={<TradeNewPage />} />
          <Route path="portfolio" element={<PortfolioPage />} />
          <Route path="trades" element={<TradesPage />} />
          <Route path="stocks" element={<StocksPage />} />
          <Route path="analytics" element={<AnalyticsPage />} />
          <Route path="journal" element={<JournalPage />} />
          <Route path="help" element={<HelpPage />} />
          <Route path="settings" element={<SettingsPage />} />
        </Route>
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </Suspense>
  )
}

export default App
