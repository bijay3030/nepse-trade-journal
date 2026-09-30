import { screen } from "@testing-library/react"
import { vi } from "vitest"

import { renderWithClient } from "../../test/renderWithClient"
import { changeBand } from "./colors"
import { MarketHeatmap } from "./MarketHeatmap"

const { mockGet } = vi.hoisted(() => ({ mockGet: vi.fn() }))
vi.mock("../../lib/axios", () => ({ default: { get: mockGet, post: vi.fn() } }))

const heatmap = {
  as_of: "2026-09-30T09:30:00Z",
  stocks: 3,
  unsized: 2,
  sectors: [
    {
      sector: "Commercial Banks", market_cap: 400, change_percent: 1.25, advancing: 1, declining: 1,
      stocks: [
        { symbol: "NABIL", name: "Nabil Bank", last_price: 500, change_percent: 2, market_cap: 300 },
        { symbol: "KBL", name: "Kumari Bank", last_price: 200, change_percent: -1, market_cap: 100 },
      ],
    },
    {
      sector: "Hydropower", market_cap: 200, change_percent: 4, advancing: 1, declining: 0,
      stocks: [{ symbol: "UPPER", name: "Upper Tamakoshi", last_price: 180, change_percent: 4, market_cap: 200 }],
    },
  ],
}

describe("MarketHeatmap", () => {
  it("draws a tile per stock, grouped by sector, linking to its analysis", async () => {
    mockGet.mockResolvedValue({ data: heatmap })
    renderWithClient(<MarketHeatmap />)

    const nabil = await screen.findByRole("link", { name: "NABIL +2.00%" })
    expect(nabil).toHaveAttribute("href", "/screener/NABIL")
    expect(nabil).toHaveStyle({ backgroundColor: "#18745a" })
    expect(screen.getByRole("link", { name: "KBL -1.00%" })).toHaveStyle({ backgroundColor: "#f3a1a1" })
    expect(screen.getByRole("region", { name: "Commercial Banks +1.25%" })).toBeInTheDocument()
    expect(screen.getByRole("region", { name: "Hydropower +4.00%" })).toBeInTheDocument()
    expect(screen.getByText("3 stocks · 2 without market cap not shown")).toBeInTheDocument()
    expect(screen.getByText(/Tile size: market cap · colour: day change/)).toBeInTheDocument()
  })

  it("explains an empty map", async () => {
    mockGet.mockResolvedValue({ data: { as_of: null, stocks: 0, unsized: 0, sectors: [] } })
    renderWithClient(<MarketHeatmap />)

    expect(await screen.findByText(/No stock prices with market cap yet/)).toBeInTheDocument()
  })

  it("bands the day change from red to green with a flat middle", () => {
    expect(changeBand(-4).label).toBe("≤ −3%")
    expect(changeBand(-0.2).label).toBe("Flat")
    expect(changeBand(0.25).label).toBe("Flat")
    expect(changeBand(0.3).label).toBe("0 to 1.5%")
    expect(changeBand(3).label).toBe("≥ 3%")
  })
})
