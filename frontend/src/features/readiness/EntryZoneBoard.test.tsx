import { screen } from "@testing-library/react"
import { vi } from "vitest"

import { renderWithClient } from "../../test/renderWithClient"
import { EntryZoneBoard } from "./EntryZoneBoard"
import { readinessSnapshot } from "./testData"

const { mockGet } = vi.hoisted(() => ({ mockGet: vi.fn() }))
vi.mock("../../lib/axios", () => ({ default: { get: mockGet, post: vi.fn() } }))

const criteria = { zone_state: "in_zone", min_trend_rules: 5, min_readiness: 60 }

describe("EntryZoneBoard", () => {
  it("lists stocks meeting the criteria with their levels", async () => {
    mockGet.mockImplementation((path: string) =>
      Promise.resolve({
        data: path === "/watchlist_items" ? [] : {
          traded_on: "2026-09-28",
          criteria,
          results: [{ ...readinessSnapshot(), symbol: "KBL", name: "Kumari Bank Limited", sector: "Commercial Banks" }],
        },
      }),
    )
    renderWithClient(<EntryZoneBoard />)

    const card = await screen.findByRole("article", { name: "KBL entry zone" })
    expect(card).toHaveTextContent("Kumari Bank Limited · Commercial Banks")
    expect(card).toHaveTextContent("Zone 221.00–227.63 · invalidation 207.10")
    expect(card).toHaveTextContent("Trend 6/7 · RS 87")
    expect(screen.getByRole("link", { name: "KBL" })).toHaveAttribute("href", "/screener/KBL")
    expect(screen.getByText(/at least 5 of 7 trend rules and readiness 60\+/)).toBeInTheDocument()
  })

  it("explains an empty list", async () => {
    mockGet.mockResolvedValue({ data: { traded_on: "2026-09-28", criteria, results: [] } })
    renderWithClient(<EntryZoneBoard />)

    expect(await screen.findByText("No stocks meet the criteria on this close.")).toBeInTheDocument()
  })
})
