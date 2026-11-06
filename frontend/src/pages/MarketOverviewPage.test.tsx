import { render, screen } from "@testing-library/react"
import { vi } from "vitest"
import { mockMarketOverview } from "../features/screener/mockData"
import { MarketOverviewPage } from "./MarketOverviewPage"

const mockUseMarketOverview = vi.fn()
vi.mock("../features/market/api", () => ({
  useMarketHeatmap: () => ({ data: { as_of: null, stocks: 0, unsized: 0, sectors: [] }, isLoading: false, isError: false, refetch: vi.fn() }),
}))

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

  it("orders sectors from strongest to weakest against NEPSE and puts the heatmap last", () => {
    const [banks, hydro] = mockMarketOverview.sectors
    const sectors = [hydro, { ...banks, sector: "Finance", relative_strength_pct: 0.2, relative_strength_rating: "neutral" as const }, banks]
    mockUseMarketOverview.mockReturnValue({ data: { ...mockMarketOverview, sectors }, isLoading: false, isError: false })
    const { container } = render(<MarketOverviewPage />)

    const names = screen.getAllByRole("heading", { level: 4 }).map((heading) => heading.textContent)
    expect(names).toEqual(["Commercial Banks", "Finance", "Hydropower"])

    const headings = Array.from(container.querySelectorAll("h2, h3")).map((heading) => heading.textContent)
    expect(headings.at(-1)).toBe("Market Heatmap")
  })
})
