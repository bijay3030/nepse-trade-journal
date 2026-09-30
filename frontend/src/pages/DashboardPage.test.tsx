import { render, screen } from "@testing-library/react"
import { MemoryRouter } from "react-router-dom"
import { vi } from "vitest"
import { mockMarketOverview, mockScreener } from "../features/screener/mockData"
import { DashboardPage } from "./DashboardPage"

vi.mock("../features/watchlist/api", () => ({
  useWatchlist: () => ({ data: [], isLoading: false, isError: false }),
  useWatchlistAlerts: () => ({ data: { unread_count: 0, alerts: [] } }),
  useSuggestion: () => ({ data: undefined, isLoading: false, isError: false }),
  useAddToWatchlist: () => ({ mutate: vi.fn(), isPending: false, isSuccess: false, isError: false }),
  apiErrorMessage: () => "",
}))

vi.mock("../features/screener/api", () => ({
  useBuyZone: () => ({
    data: { traded_on: "2026-09-28", criteria: { zone_state: "in_zone", min_trend_rules: 5, min_readiness: 60 }, results: [] },
    isLoading: false,
    isError: false,
    refetch: vi.fn(),
  }),
  useMarketOverview: () => ({ data: mockMarketOverview, isLoading: false, isError: false }),
  useScreener: () => ({ data: mockScreener, isLoading: false, isError: false }),
}))

it("shows the market overview and VCP watchlist on the dashboard", () => {
  render(<MemoryRouter><DashboardPage /></MemoryRouter>)
  expect(screen.getByRole("heading", { name: "Market Overview" })).toBeInTheDocument()
  expect(screen.getByRole("heading", { name: "VCP Screener" })).toBeInTheDocument()
  expect(screen.getByRole("table")).toHaveTextContent("NABIL")
  expect(screen.queryByText(/\bBUY\b/)).not.toBeInTheDocument()
})
