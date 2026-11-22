import { screen, waitFor, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { vi } from "vitest"

import type { MarketEvent, MarketEventsResponse } from "../features/events/types"
import { renderWithClient } from "../test/renderWithClient"
import { MarketEventsPage } from "./MarketEventsPage"

const { mockGet } = vi.hoisted(() => ({ mockGet: vi.fn() }))
vi.mock("../lib/axios", () => ({ default: { get: mockGet } }))

const event = (overrides: Partial<MarketEvent>): MarketEvent => ({
  id: 1, symbol: "NICA", company: "NIC Asia Bank Limited", sector: "Commercial Banks", mine: false, kind: "rights", impact: "mixed",
  reason: "50% rights shares (1 for every 2 held): dilution.", important: true, title: "NICA: 50% rights shares", url: null, source: "chukul_rights",
  published_on: "2026-11-22", event_on: "2026-11-27", data: { right: 50 }, ...overrides,
})
const response: MarketEventsResponse = {
  as_of: "2026-11-22", from: "2026-11-08", to: "2026-11-22",
  pagination: { page: 1, per: 25, total: 60, pages: 3 },
  events: [
    event({}),
    event({ id: 2, symbol: "SHLB", kind: "results", impact: "negative", mine: true, important: false, reason: "Net loss of Rs 5M in Q1.", title: "Shrijanshil Laghubitta has posted a net loss", url: "https://www.sharesansar.com/announcementdetail/x", source: "sharesansar", event_on: null, published_on: "2026-11-21" }),
  ],
  upcoming: [event({}), event({ id: 3, symbol: "UNL", kind: "cash_dividend", impact: "positive", data: { bonus: 0, cash: 1540 }, event_on: "2026-11-25", mine: true })],
  study: { window: 20, from: "2020-01-01", events: 729, all: { count: 729 }, groups: [
    { key: "bonus_20", label: "Bonus 20% or more", count: 79, run_up_avg: 7.01, run_up_up_pct: 50.6, run_up_excess: 7.77, after_avg: 2.71, after_up_pct: 51.9, after_excess: -2.73 },
  ] },
}

describe("MarketEventsPage", () => {
  beforeEach(() => mockGet.mockReset().mockResolvedValue({ data: response }))

  it("shows book closes ahead, rated events with reasons, and the book close study", async () => {
    renderWithClient(<MarketEventsPage />)

    const ahead = await screen.findByRole("region", { name: "Book closes ahead" })
    expect(ahead).toHaveTextContent("NICAin 5 days50% rights")
    expect(ahead).toHaveTextContent("UNLin 3 days1540% cash")

    const loss = screen.getByRole("article", { name: "SHLB event" })
    expect(loss).toHaveTextContent("BadSHLBQuarterly resultsYour stock")
    expect(loss).toHaveTextContent("Net loss of Rs 5M in Q1.")
    expect(within(loss).getByRole("link", { name: /Shrijanshil/ })).toHaveAttribute("href", "https://www.sharesansar.com/announcementdetail/x")
    expect(screen.getByRole("article", { name: "NICA event" })).toHaveTextContent("MixedNICARightsImportantBook close Fri 27 Nov")

    expect(screen.getByRole("table", { name: "Book close study" })).toHaveTextContent("Bonus 20% or more79+7.0%50.6%+7.8%+2.7%51.9%-2.7%")
  })

  it("asks the API for my stocks and a rating", async () => {
    renderWithClient(<MarketEventsPage />)
    await screen.findByRole("region", { name: "Book closes ahead" })

    await userEvent.click(screen.getByRole("tab", { name: "My stocks" }))
    await waitFor(() => expect(mockGet).toHaveBeenLastCalledWith("/market_events", { params: { scope: "mine" } }))
    await userEvent.click(screen.getByRole("button", { name: "Bad" }))
    await waitFor(() => expect(mockGet).toHaveBeenLastCalledWith("/market_events", { params: { scope: "mine", impact: "negative" } }))
  })

  it("filters by announcement date and stock, and pages through the results", async () => {
    renderWithClient(<MarketEventsPage />)
    await screen.findByRole("region", { name: "Book closes ahead" })

    expect(screen.getByRole("navigation", { name: "Pages" })).toHaveTextContent("Showing 1–25 of 60")
    await userEvent.click(screen.getByRole("button", { name: "Next page" }))
    await waitFor(() => expect(mockGet).toHaveBeenLastCalledWith("/market_events", { params: { page: 2 } }))

    await userEvent.type(screen.getByRole("searchbox", { name: "Stock" }), "nica")
    await waitFor(() => expect(mockGet).toHaveBeenLastCalledWith("/market_events", { params: { q: "nica" } })) // back to page 1

    await userEvent.click(screen.getByRole("button", { name: "30 days" }))
    await waitFor(() => expect(mockGet).toHaveBeenLastCalledWith("/market_events", { params: { q: "nica", from: "2026-10-23", to: "2026-11-22" } }))
    expect(screen.getByLabelText("From")).toHaveValue("2026-10-23")
  })
})
