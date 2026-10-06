import { render, screen } from "@testing-library/react"

import type { MarketDirection } from "../screener/types"
import { MarketDirectionCard } from "./MarketDirectionCard"

const base: MarketDirection = {
  state: "uptrend", label: "Uptrend", traded_on: "2026-10-02", distribution_days: 2, distribution_dates: [],
  drawdown_pct: -5.39, rally_day: null, follow_through_on: "2026-07-17", size_factor: 1, threshold_set: "nepse",
  thresholds: { down_pct: 0.5, up_pct: 1.5 },
}

describe("MarketDirectionCard", () => {
  it("describes an uptrend with its distribution days and last follow-through", () => {
    render(<MarketDirectionCard direction={base} />)

    expect(screen.getByLabelText("Market direction")).toHaveTextContent(
      "Market: Uptrend · 2 distribution days in the last 25 sessions · index -5.39% from its high · last follow-through 17 Jul",
    )
    expect(screen.getByText(/closing down 0.5%\+ on higher turnover/)).toBeInTheDocument()
    expect(screen.queryByText(/cautious size/)).not.toBeInTheDocument()
  })

  it("mentions the cautious size and the rally attempt in a correction", () => {
    render(<MarketDirectionCard direction={{ ...base, state: "correction", label: "Correction", rally_day: 2, size_factor: 0.25 }} compact />)

    expect(screen.getByLabelText("Market direction")).toHaveTextContent("rally attempt day 2")
    expect(screen.getByText(/cautious size at 25% of your usual risk/)).toBeInTheDocument()
    expect(screen.queryByText(/closing down/)).not.toBeInTheDocument()
  })
})
