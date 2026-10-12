import { render, screen } from "@testing-library/react"

import { FreshnessBanner } from "./FreshnessBanner"
import { LiveStatus } from "./LiveStatus"

const live = (lastPrice: number, updatedAt = "2026-10-12T07:30:00Z") => ({
  symbol: "NABIL", lastPrice, changePercent: 1.2, volume: 1000, updatedAt, flashDirection: null, flashTs: 0,
})

describe("LiveStatus", () => {
  const zone = { snapshotOn: "2026-10-09", zoneLow: 500, zoneHigh: 515, stop: 470 }

  it("places today's live price against the snapshot's zone", () => {
    const { rerender } = render(<LiveStatus live={live(510)} {...zone} />)
    expect(screen.getByLabelText("Live price")).toHaveTextContent("Live 510.00 (+1.20%) · in the zone now")

    rerender(<LiveStatus live={live(490)} {...zone} />)
    expect(screen.getByLabelText("Live price")).toHaveTextContent("2.0% below the zone")

    rerender(<LiveStatus live={live(530)} {...zone} />)
    expect(screen.getByLabelText("Live price")).toHaveTextContent("2.9% above the zone")

    rerender(<LiveStatus live={live(465)} {...zone} />)
    expect(screen.getByLabelText("Live price")).toHaveTextContent("at or below the stop")
  })

  it("shows nothing when the live price isn't newer than the snapshot", () => {
    const { container } = render(<LiveStatus live={live(510, "2026-10-09T09:00:00Z")} {...zone} />)
    expect(container).toBeEmptyDOMElement()
  })
})

describe("FreshnessBanner", () => {
  it("says how far behind the snapshots are, and hides when current", () => {
    const { rerender, container } = render(<FreshnessBanner freshness={{ snapshot_on: "2026-10-02", behind_sessions: 4, latest_session: "2026-10-09" }} />)
    expect(screen.getByRole("status")).toHaveTextContent("Data as of 2026-10-02: 4 later sessions are not built yet (up to 2026-10-09)")

    rerender(<FreshnessBanner freshness={{ snapshot_on: "2026-10-09", behind_sessions: 0, latest_session: "2026-10-09" }} />)
    expect(container).toBeEmptyDOMElement()
  })
})
