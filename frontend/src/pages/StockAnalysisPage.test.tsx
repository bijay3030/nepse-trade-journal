import { render, screen } from "@testing-library/react"
import { MemoryRouter, Route, Routes } from "react-router-dom"
import { vi } from "vitest"

import { mockStockAnalysis } from "../features/screener/mockData"
import { readinessSnapshot } from "../features/readiness/testData"
import { StockAnalysisPage } from "./StockAnalysisPage"

const mockUseStockAnalysis = vi.fn()

vi.mock("../features/watchlist/api", () => ({
  useWatchlist: () => ({ data: [], isLoading: false, isError: false }),
  useWatchlistAlerts: () => ({ data: { unread_count: 0, alerts: [] } }),
  useSuggestion: () => ({ data: undefined, isLoading: false, isError: false }),
  useAddToWatchlist: () => ({ mutate: vi.fn(), isPending: false, isSuccess: false, isError: false }),
  apiErrorMessage: () => "",
}))

vi.mock("../features/screener/api", () => ({
  useStockAnalysis: (...args: unknown[]) => mockUseStockAnalysis(...args),
}))

function renderPage(route = "/screener/NABIL") {
  return render(
    <MemoryRouter initialEntries={[route]}>
      <Routes>
        <Route path="/screener/:symbol" element={<StockAnalysisPage />} />
      </Routes>
    </MemoryRouter>,
  )
}

function mockSuccess() {
  mockUseStockAnalysis.mockReturnValue({
    data: mockStockAnalysis,
    isLoading: false,
    isError: false,
    refetch: vi.fn(),
  })
}

describe("StockAnalysisPage", () => {
  beforeEach(() => {
    mockUseStockAnalysis.mockReset()
  })

  it("renders symbol, company name, and setup state label", () => {
    mockSuccess()
    renderPage()
    expect(screen.getByText("NABIL")).toBeInTheDocument()
    expect(screen.getByText(/Nabil Bank Limited/)).toBeInTheDocument()
    expect(screen.getByText("Near Pivot")).toBeInTheDocument()
  })

  it("renders volatility contraction rows and sequence percentages", () => {
    mockSuccess()
    renderPage()
    expect(screen.getByText("Volatility Contraction")).toBeInTheDocument()
    expect(screen.getByText("T1")).toBeInTheDocument()
    expect(screen.getByText("T2")).toBeInTheDocument()
    expect(screen.getByText("T3")).toBeInTheDocument()
    expect(screen.getByText("8%")).toBeInTheDocument()
  })

  it("renders all five score breakdown components", () => {
    mockSuccess()
    renderPage()
    expect(screen.getByText("Trend")).toBeInTheDocument()
    expect(screen.getByText("Contraction")).toBeInTheDocument()
    expect(screen.getAllByText("Volume").length).toBeGreaterThan(0)
    expect(screen.getByText("Tightness")).toBeInTheDocument()
    expect(screen.getByText("Pivot proximity")).toBeInTheDocument()
    expect(screen.getAllByText("20/20")).toHaveLength(2)
    expect(screen.getByText("25/25")).toBeInTheDocument()
    expect(screen.getByText("10/20")).toBeInTheDocument()
    expect(screen.getByText("90/100")).toBeInTheDocument()
  })

  it("renders pivot, support level, and market regime chip", () => {
    mockSuccess()
    const { container } = renderPage()
    expect(container.textContent).toMatch(/Pivot/)
    expect(container.textContent).toMatch(/1,193/)
    expect(screen.getByText("Neutral")).toBeInTheDocument()
    expect(screen.getByText("Strong RS")).toBeInTheDocument()
  })

  it("renders loading spinner while fetching", () => {
    mockUseStockAnalysis.mockReturnValue({
      data: undefined,
      isLoading: true,
      isError: false,
      refetch: vi.fn(),
    })
    const { container } = renderPage()
    expect(container.querySelector(".animate-spin")).toBeTruthy()
  })

  it("shows missing price history without rendering empty charts", () => {
    mockUseStockAnalysis.mockReturnValue({ data: { ...mockStockAnalysis, candles: [], vcp: { ...mockStockAnalysis.vcp, contractions: [] } }, isLoading: false, isError: false, refetch: vi.fn() })
    renderPage()
    expect(screen.getByText("No daily prices available")).toBeInTheDocument()
    expect(screen.queryByText("Price & Trend")).not.toBeInTheDocument()
  })

  it("renders error card with retry on failure", () => {
    mockUseStockAnalysis.mockReturnValue({
      data: undefined,
      isLoading: false,
      isError: true,
      refetch: vi.fn(),
    })
    renderPage()
    expect(screen.getByText(/Could not load analysis/)).toBeInTheDocument()
    expect(screen.getByText("Retry")).toBeInTheDocument()
  })

  it("shows entry readiness and uses its zone on the chart when a snapshot exists", () => {
    mockUseStockAnalysis.mockReturnValue({
      data: { ...mockStockAnalysis, readiness: readinessSnapshot() },
      isLoading: false,
      isError: false,
      refetch: vi.fn(),
    })
    renderPage()

    expect(screen.getByRole("img", { name: "Entry readiness 68 of 100" })).toBeInTheDocument()
    expect(screen.getByText(/Entry zone 221.00–227.63, invalidation 207.10, target 250.00 \(from the VCP setup found on 2026-09-28\)/)).toBeInTheDocument()
  })

  it("never renders trading advice words", () => {
    mockUseStockAnalysis.mockReturnValue({ data: { ...mockStockAnalysis, readiness: readinessSnapshot() }, isLoading: false, isError: false, refetch: vi.fn() })
    const { container } = renderPage()
    expect(container.textContent).not.toMatch(/\bBUY\b|\bSELL\b/i)
  })
})
