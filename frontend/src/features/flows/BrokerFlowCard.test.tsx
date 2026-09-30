import { render, screen, within } from "@testing-library/react"

import type { BrokerFlow } from "../screener/types"
import { BrokerFlowCard } from "./BrokerFlowCard"

const flow: BrokerFlow = {
  state: "accumulation",
  score: 18.4,
  sessions: 20,
  windows: {
    "5": { sessions: 5, volume: 300_000, top_buyers_pct: 41.2, top_sellers_pct: 20.5, score: 20.7 },
    "20": { sessions: 20, volume: 1_200_000, top_buyers_pct: 38.1, top_sellers_pct: 19.7, score: 18.4 },
  },
  top_buyers: [{ broker_no: "58", name: "Naasa Securities", net_quantity: 120_500, bought: 150_000, sold: 29_500, avg_buy_price: 221.35, avg_sell_price: 224.1, share_pct: 10.04 }],
  top_sellers: [{ broker_no: "33", name: null, net_quantity: -60_000, bought: 5_000, sold: 65_000, avg_buy_price: 219.0, avg_sell_price: 223.8, share_pct: -5.0 }],
  daily: [
    { traded_on: "2026-09-25", top_buyers_net: 8000, top_sellers_net: -4000, volume: 50_000 },
    { traded_on: "2026-09-28", top_buyers_net: 12000, top_sellers_net: -3000, volume: 60_000 },
  ],
}

describe("BrokerFlowCard", () => {
  it("shows the state, score, windows and top brokers", () => {
    const { container } = render(<BrokerFlowCard flow={flow} />)

    expect(screen.getByText("Accumulation")).toBeInTheDocument()
    expect(screen.getByText("+18.40")).toBeInTheDocument()
    expect(screen.getByText("38.1% of volume")).toBeInTheDocument()
    expect(screen.getByText("20.5% of volume")).toBeInTheDocument()

    const buyers = screen.getByText("Top net buyers").parentElement as HTMLElement
    expect(within(buyers).getByText("Naasa Securities")).toBeInTheDocument()
    expect(within(buyers).getByText("120,500")).toBeInTheDocument()
    expect(within(buyers).getByText("221.35")).toBeInTheDocument()

    const sellers = screen.getByText("Top net sellers").parentElement as HTMLElement
    expect(within(sellers).getByText("#33")).toBeInTheDocument()
    expect(within(sellers).getByText("223.80")).toBeInTheDocument()
    expect(container.textContent).not.toMatch(/\bBUY\b|\bSELL\b/i)
  })

  it("warns about thin trading", () => {
    render(<BrokerFlowCard flow={{ ...flow, state: "neutral", thin_trading: true }} />)

    expect(screen.getByText(/Thin trading: under NPR 20M changed hands in 20 sessions/)).toBeInTheDocument()
  })

  it("explains when there is not enough floorsheet data", () => {
    render(<BrokerFlowCard flow={{ ...flow, state: "no_data", score: null, sessions: 3, windows: {}, top_buyers: [], top_sellers: [], daily: [] }} />)

    expect(screen.getByText(/Not enough floorsheet data yet \(3 of 5 sessions\)/)).toBeInTheDocument()
  })
})
