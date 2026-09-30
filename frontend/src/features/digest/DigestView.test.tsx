import { render, screen, within } from "@testing-library/react"
import { MemoryRouter } from "react-router-dom"

import { DigestView } from "./DigestView"
import { digestFixture } from "./testData"

const renderView = (content = digestFixture().content) => render(<MemoryRouter><DigestView content={content} /></MemoryRouter>)

describe("DigestView", () => {
  it("summarises the market with breadth and sectors", () => {
    renderView()

    expect(screen.getByText("2,605.79")).toBeInTheDocument()
    expect(screen.getByText("-0.91%")).toBeInTheDocument()
    expect(screen.getByText("Weak market")).toBeInTheDocument()
    expect(screen.getByText("48 up · 225 down · 8 unchanged (17.1% breadth)")).toBeInTheDocument()
    expect(screen.getByText("Tradings")).toBeInTheDocument()
    expect(screen.getByText("Investment")).toBeInTheDocument()
  })

  it("lists entry-zone changes with guard reasons and links to each stock", () => {
    renderView()

    const joined = screen.getByRole("region", { name: "Joined the board" })
    expect(joined).toHaveTextContent("KBL")
    expect(joined).toHaveTextContent("VCP breakout · readiness 69 · zone 221.00–227.63 · close 224.00")
    expect(within(joined).getByRole("link", { name: "KBL" })).toHaveAttribute("href", "/screener/KBL")
    const left = screen.getByRole("region", { name: "Left the board" })
    expect(left).toHaveTextContent("SANIMA Too early · 71")
    expect(left).toHaveTextContent("THIN Thin volume · 65")
    expect(screen.getByRole("region", { name: "Held back by guards" })).toHaveTextContent("JUMP (At upper circuit)")
  })

  it("shows watchlist verdicts, alerts and book closes", () => {
    renderView()

    expect(screen.getByRole("region", { name: "End-of-day verdicts" })).toHaveTextContent("NABILHeld the zoneclosed 566.00")
    expect(screen.getByRole("region", { name: "Alerts" })).toHaveTextContent("NABIL entered its entry zone at 560")
    expect(screen.getByRole("region", { name: "Book closes" })).toHaveTextContent("AHPC Oct 3 (in 4 days) · 5% bonus, levels will be adjusted")
  })

  it("leaves out switched-off sections and never uses advice words", () => {
    const { container } = renderView({ traded_on: "2026-09-29", previous_session: null, market: digestFixture().content.market })

    expect(screen.queryByText("Entry zone changes")).not.toBeInTheDocument()
    expect(screen.queryByText("Watchlist status")).not.toBeInTheDocument()
    expect(container.textContent).not.toMatch(/\bBUY\b|\bSELL\b/i)
  })
})
