import { render, screen } from "@testing-library/react"
import { MemoryRouter } from "react-router-dom"
import { vi } from "vitest"
import { mockMarketOverview, mockScreener } from "../features/screener/mockData"
import { DashboardPage } from "./DashboardPage"

vi.mock("../features/screener/api", () => ({
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
