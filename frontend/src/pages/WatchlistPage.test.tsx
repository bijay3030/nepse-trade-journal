import { screen, waitFor, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { vi } from "vitest"

import { watchlistItem } from "../features/watchlist/testData"
import { renderWithClient } from "../test/renderWithClient"
import { WatchlistPage } from "./WatchlistPage"

const { mockGet, mockPost, mockPatch, mockDelete } = vi.hoisted(() => ({
  mockGet: vi.fn(), mockPost: vi.fn(), mockPatch: vi.fn(), mockDelete: vi.fn(),
}))
vi.mock("../lib/axios", () => ({ default: { get: mockGet, post: mockPost, patch: mockPatch, delete: mockDelete } }))

const alerts = {
  unread_count: 1,
  alerts: [
    { id: 1, watchlist_item_id: 7, symbol: "NABIL", kind: "breakout_confirmed", message: "NABIL broke above the 570.00 pivot at 575.00 on 1.8x its 50-day average volume so far.", price: 575, relative_volume: 1.8, read_at: null, created_at: new Date().toISOString() },
  ],
}

function mockApi(items = [watchlistItem()]) {
  mockGet.mockImplementation((path: string) =>
    Promise.resolve({ data: path === "/watchlist_alerts" ? alerts : items }),
  )
}

describe("WatchlistPage", () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mockApi()
    mockPost.mockResolvedValue({ data: { updated: 1 } })
    mockPatch.mockResolvedValue({ data: watchlistItem({ status: "archived" }) })
  })

  it("shows each setup's levels, state and snapshot", async () => {
    renderWithClient(<WatchlistPage />)

    const card = await screen.findByRole("article", { name: "NABIL setup" })
    expect(within(card).getByText("Watching")).toBeInTheDocument()
    expect(within(card).getByText("570.00–587.10")).toBeInTheDocument()
    expect(within(card).getByText("548.00", { selector: ".text-ember" })).toBeInTheDocument()
    expect(within(card).getByText("3.18R")).toBeInTheDocument()
    expect(within(card).getByText(/0.88% below the zone/)).toBeInTheDocument()
    expect(within(card).getByText(/VCP score 72/)).toBeInTheDocument()
    expect(within(card).getByRole("link", { name: /Create plan/ })).toHaveAttribute("href", "/trade/new?watchlist=7")
  })

  it("lists alerts and marks them read", async () => {
    renderWithClient(<WatchlistPage />)

    expect(await screen.findByText(/broke above the 570.00 pivot/)).toBeInTheDocument()
    expect(screen.getByText("1 new")).toBeInTheDocument()

    await userEvent.click(screen.getByRole("button", { name: "Mark all read" }))
    expect(mockPost).toHaveBeenCalledWith("/watchlist_alerts/mark_read", {})
  })

  it("archives a setup and saves edited levels", async () => {
    renderWithClient(<WatchlistPage />)

    await userEvent.click(await screen.findByRole("button", { name: /Archive/ }))
    expect(mockPatch).toHaveBeenCalledWith("/watchlist_items/7", { status: "archived" })

    await userEvent.click(screen.getByRole("button", { name: /Edit levels/ }))
    const low = screen.getByLabelText("Zone low")
    await userEvent.clear(low)
    await userEvent.type(low, "572")
    await userEvent.click(screen.getByRole("button", { name: "Save levels" }))

    await waitFor(() =>
      expect(mockPatch).toHaveBeenCalledWith("/watchlist_items/7", expect.objectContaining({ entry_zone_low: 572, invalidation_price: 548, notes: "Tight T3 on drying volume" })),
    )
  })

  it("shows the API's reason when edited levels are rejected", async () => {
    mockPatch.mockRejectedValue({ response: { data: { error: "Invalidation price must be below the entry zone" } } })
    renderWithClient(<WatchlistPage />)

    await userEvent.click(await screen.findByRole("button", { name: /Edit levels/ }))
    await userEvent.click(screen.getByRole("button", { name: "Save levels" }))

    expect(await screen.findByRole("alert")).toHaveTextContent("Invalidation price must be below the entry zone")
  })

  it("offers to reset an invalidated setup instead of planning it", async () => {
    mockApi([watchlistItem({ status: "invalidated", price_state: "invalidated", current_price: 540 })])
    renderWithClient(<WatchlistPage />)

    expect(await screen.findByRole("button", { name: /Reset setup/ })).toBeInTheDocument()
    expect(screen.queryByRole("link", { name: /Create plan/ })).not.toBeInTheDocument()
  })

  it("explains how to add stocks when the list is empty", async () => {
    mockApi([])
    renderWithClient(<WatchlistPage />)

    expect(await screen.findByText("Nothing tracked yet.")).toBeInTheDocument()
    expect(screen.getByRole("link", { name: "VCP Screener" })).toHaveAttribute("href", "/screener")
  })
})
