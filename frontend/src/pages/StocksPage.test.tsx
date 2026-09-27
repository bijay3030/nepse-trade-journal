import { render, screen, waitFor } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { MemoryRouter } from "react-router-dom"
import { vi } from "vitest"
import { useStockPricesStore } from "../stores/stockPricesStore"
import { describePriceAge } from "../lib/priceAge"
import { StocksPage, type StockItem } from "./StocksPage"

const { mockGet, mockPost } = vi.hoisted(() => ({ mockGet: vi.fn(), mockPost: vi.fn() }))
vi.mock("../lib/axios", () => ({ default: { get: mockGet, post: mockPost } }))

const stock = (overrides: Partial<StockItem> = {}): StockItem => ({
  id: 1,
  symbol: "NABIL",
  name: "Nabil Bank Limited",
  sector: "Commercial Banks",
  security_type: "Equity",
  last_price: 515,
  change_percent: 1.25,
  volume: 12000,
  listed_shares: 270569970,
  market_cap: 151519183200,
  high_52w: 568,
  low_52w: 471,
  eps: 30,
  pe_ratio: 16.8,
  book_value: 243.3,
  pb_ratio: 2.3,
  last_updated: "2026-09-20T09:56:16Z",
  ...overrides,
})

function renderPage() {
  return render(
    <MemoryRouter>
      <StocksPage />
    </MemoryRouter>,
  )
}

describe("StocksPage", () => {
  beforeEach(() => {
    mockGet.mockReset()
    mockPost.mockReset()
    useStockPricesStore.getState().clearPrices()
    mockGet.mockImplementation((path: string) =>
      Promise.resolve({ data: path === "/stocks/sectors" ? { sectors: [], security_types: [] } : [stock()] }),
    )
  })

  it("shows when prices were last updated and warns when they are old", async () => {
    renderPage()

    expect(await screen.findByText(/Prices as of/)).toBeInTheDocument()
    expect(screen.getByText("May be out of date")).toBeInTheDocument()
  })

  it("sums market cap numerically when the API sends decimals as strings", async () => {
    const asApi = (item: StockItem) =>
      ({ ...item, last_price: String(item.last_price), change_percent: "0.0", market_cap: `${item.market_cap}.0` }) as unknown as StockItem
    mockGet.mockImplementation((path: string) =>
      Promise.resolve({
        data:
          path === "/stocks/sectors"
            ? { sectors: [], security_types: [] }
            : [asApi(stock({ market_cap: 3219847618 })), asApi(stock({ id: 2, symbol: "NICA", market_cap: 151519183200 }))],
      }),
    )
    renderPage()

    expect(await screen.findByText("NPR 154.74 Billion")).toBeInTheDocument()
    expect(screen.queryByText(/3219847618/)).not.toBeInTheDocument()
  })

  it("syncs from the market endpoint and reports the result", async () => {
    mockPost.mockResolvedValue({ data: { processed: 356, added: ["NEWCO"] } })
    renderPage()

    await userEvent.click(await screen.findByRole("button", { name: /Sync Latest Prices/ }))

    expect(mockPost).toHaveBeenCalledWith("/data_imports/sync_market")
    expect(await screen.findByText("Updated 356 stocks, added 1 new listing.")).toBeInTheDocument()
  })

  it("shows the API error when the sync fails", async () => {
    mockPost.mockRejectedValue({ response: { data: { error: "Could not fetch market prices: HTTP 503" } } })
    renderPage()

    await userEvent.click(await screen.findByRole("button", { name: /Sync Latest Prices/ }))

    expect(await screen.findByRole("alert")).toHaveTextContent("Could not fetch market prices: HTTP 503")
  })

  it("applies newer live prices pushed over the WebSocket", async () => {
    renderPage()
    await screen.findByText(/Prices as of/)

    useStockPricesStore.getState().upsertPrices([
      { symbol: "NABIL", last_price: 569, change_percent: 2.5, volume: 20000, last_updated: new Date().toISOString() },
    ])

    await waitFor(() => expect(screen.queryByText("May be out of date")).not.toBeInTheDocument())
    expect(screen.getAllByText(/569/).length).toBeGreaterThan(0)
  })
})

describe("describePriceAge", () => {
  const now = new Date("2026-09-27T09:00:00Z")

  it("describes recent prices without a stale flag", () => {
    expect(describePriceAge("2026-09-27T08:55:00Z", now)).toMatchObject({ age: "5 min ago", isStale: false })
  })

  it("does not flag Thursday's close as stale over the weekend", () => {
    expect(describePriceAge("2026-09-24T09:15:00Z", now)).toMatchObject({ isStale: false })
  })

  it("flags prices older than a weekend", () => {
    expect(describePriceAge("2026-09-20T09:56:00Z", now)).toMatchObject({ age: "6 days ago", isStale: true })
  })

  it("returns null without a timestamp", () => {
    expect(describePriceAge(null, now)).toBeNull()
  })
})
