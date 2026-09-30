import { screen, waitFor } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { vi } from "vitest"

import { renderWithClient } from "../../test/renderWithClient"
import { AddToWatchlistButton } from "./AddToWatchlist"
import { watchlistItem } from "./testData"

const { mockGet, mockPost } = vi.hoisted(() => ({ mockGet: vi.fn(), mockPost: vi.fn() }))
vi.mock("../../lib/axios", () => ({ default: { get: mockGet, post: mockPost } }))

const vcpSuggestion = {
  success: true, symbol: "NABIL", current_price: 565, setup_type: "vcp",
  levels: { entry_zone_low: 570, entry_zone_high: 587.1, invalidation_price: 548, stop_loss_price: 548, target_price: 640, target_basis: "resistance", pivot_price: 570 },
  snapshot: { vcp_score: 72, is_vcp_setup: true, contraction_sequence: "12% -> 7% -> 4%", trend: "uptrend", market_regime: "bullish", analysed_on: "2026-09-24" },
}

describe("AddToWatchlistButton", () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockGet.mockImplementation((path: string, config?: { params?: { setup_type?: string } }) => {
      if (path === "/watchlist_items") return Promise.resolve({ data: [] })
      if (config?.params?.setup_type === "pullback") {
        return Promise.reject({ response: { status: 422, data: { success: false, symbol: "NABIL", current_price: 565, error: "No support level found for NABIL." } } })
      }
      return Promise.resolve({ data: vcpSuggestion })
    })
    mockPost.mockResolvedValue({ data: watchlistItem() })
  })

  it("prefills suggested levels and adds the stock", async () => {
    // After the add, the watchlist includes NABIL, which swaps the button for a link.
    let added = false
    const fallback = mockGet.getMockImplementation()!
    mockGet.mockImplementation((path: string, config?: object) =>
      path === "/watchlist_items" ? Promise.resolve({ data: added ? [watchlistItem()] : [] }) : fallback(path, config),
    )
    mockPost.mockImplementation(() => {
      added = true
      return Promise.resolve({ data: watchlistItem() })
    })
    renderWithClient(<AddToWatchlistButton symbol="NABIL" />)

    await userEvent.click(await screen.findByRole("button", { name: "Add NABIL to watchlist" }))
    await waitFor(() => expect(screen.getByLabelText("Zone low")).toHaveValue(570))
    // Portalled to <body>, so a scrolling table around the button can't misplace it.
    expect(screen.getByRole("dialog").parentElement?.parentElement).toBe(document.body)
    expect(screen.getByText("12% -> 7% -> 4%")).toBeInTheDocument()
    expect(screen.getByText("3.18R")).toBeInTheDocument()
    expect(screen.queryByText(/Not a qualified VCP/)).not.toBeInTheDocument()

    await userEvent.type(screen.getByLabelText(/Notes/), "Tight T3")
    await userEvent.click(screen.getByRole("button", { name: "Add to watchlist" }))

    expect(mockPost).toHaveBeenCalledWith("/watchlist_items", expect.objectContaining({
      symbol: "NABIL", setup_type: "vcp", notes: "Tight T3", entry_zone_low: 570, entry_zone_high: 587.1, invalidation_price: 548, target_price: 640,
    }))
    expect(await screen.findByText("NABIL is on your watchlist.")).toBeInTheDocument()
    expect(await screen.findByRole("link", { name: /On watchlist/ })).toBeInTheDocument()
  })

  it("explains when a setup has no suggestion and lets levels be entered by hand", async () => {
    renderWithClient(<AddToWatchlistButton symbol="NABIL" />)

    await userEvent.click(await screen.findByRole("button", { name: "Add NABIL to watchlist" }))
    await userEvent.click(screen.getByRole("radio", { name: /Pullback to support/ }))

    expect(await screen.findByText(/No support level found for NABIL. Enter the levels yourself below./)).toBeInTheDocument()
    expect(screen.getByLabelText("Zone low")).toHaveValue(null)
    expect(screen.getByRole("button", { name: "Add to watchlist" })).toBeDisabled()
  })

  it("warns when the pattern does not qualify as a VCP", async () => {
    mockGet.mockImplementation((path: string) =>
      Promise.resolve({ data: path === "/watchlist_items" ? [] : { ...vcpSuggestion, snapshot: { ...vcpSuggestion.snapshot, vcp_score: 35, is_vcp_setup: false } } }),
    )
    renderWithClient(<AddToWatchlistButton symbol="NABIL" />)

    await userEvent.click(await screen.findByRole("button", { name: "Add NABIL to watchlist" }))

    expect(await screen.findByText(/Not a qualified VCP yet \(score 35/)).toBeInTheDocument()
  })

  it("offers all four setup types and shows what a flat-base breakout found", async () => {
    mockGet.mockImplementation((path: string, config?: { params?: { setup_type?: string } }) => {
      if (path === "/watchlist_items") return Promise.resolve({ data: [] })
      if (config?.params?.setup_type === "base_breakout") {
        return Promise.resolve({ data: { ...vcpSuggestion, setup_type: "base_breakout", pattern: { quality: 85, details: { base_sessions: 31, base_depth_pct: 8 } } } })
      }
      return Promise.resolve({ data: vcpSuggestion })
    })
    renderWithClient(<AddToWatchlistButton symbol="NABIL" />)

    await userEvent.click(await screen.findByRole("button", { name: "Add NABIL to watchlist" }))
    expect(screen.getAllByRole("radio")).toHaveLength(4)
    await userEvent.click(screen.getByRole("radio", { name: /Flat-base breakout/ }))

    expect(await screen.findByText("31-session base, 8% deep")).toBeInTheDocument()
  })

  it("links to the watchlist when the stock is already tracked", async () => {
    mockGet.mockResolvedValue({ data: [watchlistItem()] })
    renderWithClient(<AddToWatchlistButton symbol="NABIL" />)

    expect(await screen.findByRole("link", { name: /On watchlist/ })).toHaveAttribute("href", "/watchlist")
  })
})
