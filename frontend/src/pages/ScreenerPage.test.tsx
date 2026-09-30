import { render, screen, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { MemoryRouter, Route, Routes } from "react-router-dom"
import { vi } from "vitest"
import { mockScreener } from "../features/screener/mockData"
import { ScreenerPage } from "./ScreenerPage"

vi.mock("../features/watchlist/api", () => ({
  useWatchlist: () => ({ data: [], isLoading: false, isError: false }),
  useWatchlistAlerts: () => ({ data: { unread_count: 0, alerts: [] } }),
  useSuggestion: () => ({ data: undefined, isLoading: false, isError: false }),
  useAddToWatchlist: () => ({ mutate: vi.fn(), isPending: false, isSuccess: false, isError: false }),
  apiErrorMessage: () => "",
}))

vi.mock("../features/screener/api", () => ({
  useScreener: () => ({ data: mockScreener, isLoading: false, isError: false, refetch: vi.fn() }),
}))

function renderPage() {
  return render(
    <MemoryRouter initialEntries={["/screener"]}>
      <Routes>
        <Route path="/screener" element={<ScreenerPage />} />
        <Route path="/screener/:symbol" element={<p>Analysis route</p>} />
      </Routes>
    </MemoryRouter>,
  )
}

describe("ScreenerPage", () => {
  it.each([
    ["Min VCP Score", "85", "RADHI", "NABIL"],
    ["Liquidity", "low", "HDHPC", "NABIL"],
    ["Trend", "downtrend", "HDHPC", "UPPER"],
    ["Distance to Pivot", "2", "NABIL", "UPPER"],
    ["Market Regime", "weak", "HDHPC", "RADHI"],
  ])("filters by %s", async (label, option, included, excluded) => {
    const user = userEvent.setup()
    renderPage()
    await user.selectOptions(screen.getByRole("combobox", { name: label }), option)
    expect(screen.getByRole("table")).toHaveTextContent(included)
    expect(screen.getByRole("table")).not.toHaveTextContent(excluded)
  })

  it("filters the watchlist and breakout watch with the same controls", async () => {
    const user = userEvent.setup()
    renderPage()
    expect(screen.getByRole("table")).toHaveTextContent("UPPER")
    await user.selectOptions(screen.getByRole("combobox", { name: "Sector" }), "Commercial Banks")
    expect(screen.getByRole("table")).toHaveTextContent("NABIL")
    expect(screen.getByRole("table")).not.toHaveTextContent("UPPER")
    await user.click(screen.getByRole("tab", { name: "Breakout Watch" }))
    expect(screen.getByRole("combobox", { name: "Sector" })).toHaveValue("Commercial Banks")
    expect(screen.getByRole("table")).toHaveTextContent("NABIL")
    expect(screen.getByRole("table")).not.toHaveTextContent("RADHI")
  })

  it("only shows stocks close to the pivot in breakout watch", async () => {
    const user = userEvent.setup()
    renderPage()
    await user.click(screen.getByRole("tab", { name: "Breakout Watch" }))
    const table = screen.getByRole("table")
    expect(table).toHaveTextContent("NABIL")
    expect(table).toHaveTextContent("RADHI")
    expect(table).not.toHaveTextContent("UPPER")
    expect(table).not.toHaveTextContent("HDHPC")
  })

  it("opens analysis from a keyboard-accessible symbol link", async () => {
    const user = userEvent.setup()
    renderPage()
    const row = screen.getByRole("row", { name: /NABIL/ })
    await user.click(within(row).getByRole("link", { name: "NABIL" }))
    expect(screen.getByText("Analysis route")).toBeInTheDocument()
  })
})
