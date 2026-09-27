import { render, screen } from "@testing-library/react"
import { vi } from "vitest"
import { mockMarketOverview } from "../features/screener/mockData"
import { MarketOverviewPage } from "./MarketOverviewPage"

const mockUseMarketOverview = vi.fn()
vi.mock("../features/screener/api", () => ({ useMarketOverview: () => mockUseMarketOverview() }))

describe("MarketOverviewPage", () => {
  it("renders the observed index, market breadth and sectors", () => {
    mockUseMarketOverview.mockReturnValue({ data: mockMarketOverview, isLoading: false, isError: false })
    render(<MarketOverviewPage />)
    expect(screen.getByText("Market Overview")).toBeInTheDocument()
    expect(screen.getByText("Commercial Banks")).toBeInTheDocument()
    expect(screen.getByText("123 advancing / 72 declining")).toBeInTheDocument()
  })

  it("shows an honest empty state if no index session exists", () => {
    mockUseMarketOverview.mockReturnValue({ data: { ...mockMarketOverview, traded_on: null, index_history: [], sectors: [] }, isLoading: false, isError: false })
    render(<MarketOverviewPage />)
    expect(screen.getByText(/No market sessions available/)).toBeInTheDocument()
    expect(screen.queryByText("NEPSE Index Trend")).not.toBeInTheDocument()
  })
})
