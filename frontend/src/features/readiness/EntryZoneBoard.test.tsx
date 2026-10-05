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

  it("states the tradability guards and lists charts they held back", async () => {
    mockGet.mockImplementation((path: string) =>
      Promise.resolve({
        data: path === "/watchlist_items" ? [] : {
          traded_on: "2026-09-28",
          criteria: { ...criteria, min_avg_turnover: 2_000_000, circuit_near_pct: 14.5, daily_limit_pct: 15, setup_types: ["vcp", "base_breakout", "ma_pullback"] },
          results: [],
          held_back: [
            { ...readinessSnapshot(), symbol: "THIN", name: "Thin Hydro", sector: "Hydro Power", in_buy_zone: false, guards: ["thin_volume"], avg_turnover: 1_240_000 },
            { ...readinessSnapshot(), symbol: "JUMP", name: "Jump Finance", sector: "Finance", in_buy_zone: false, guards: ["upper_circuit"], change_pct: 9.96 },
          ],
        },
      }),
    )
    renderWithClient(<EntryZoneBoard />)

    const section = await screen.findByRole("region", { name: "Held back by guards" })
    expect(section).toHaveTextContent("Held back by guards (2)")
    expect(section).toHaveTextContent("THIN")
    expect(section).toHaveTextContent("Thin volume")
    expect(section).toHaveTextContent("NPR 1.2M a day")
    expect(section).toHaveTextContent("At upper circuit")
    expect(section).toHaveTextContent("+9.96% on the day")
    expect(screen.getByText(/average turnover NPR 2.0M\+ a day, and a daily move under ±14.5% \(not at the ±15% circuit\)/)).toBeInTheDocument()
    expect(screen.queryByRole("article")).not.toBeInTheDocument()
    expect(screen.getByText(/Setups: VCP breakout, Flat-base breakout, Pullback to a rising average; support pullbacks are shown in the screener but not here/)).toBeInTheDocument()
  })

  it("explains an empty list", async () => {
    mockGet.mockResolvedValue({ data: { traded_on: "2026-09-28", criteria, results: [] } })
    renderWithClient(<EntryZoneBoard />)

    expect(await screen.findByText("No stocks meet the criteria on this close.")).toBeInTheDocument()
  })
})
