import { render, screen } from "@testing-library/react"

import type { ReadinessHistoryPoint } from "../screener/types"
import { ReadinessSparkline } from "./ReadinessSparkline"

const point = (day: number, score: number, inBuyZone = false): ReadinessHistoryPoint => ({
  traded_on: `2026-09-${String(day).padStart(2, "0")}`, score, zone_state: inBuyZone ? "in_zone" : "too_early", in_buy_zone: inBuyZone,
})

describe("ReadinessSparkline", () => {
  it("draws the history with the 60 line and dots on entry-zone sessions", () => {
    const { container } = render(<ReadinessSparkline history={[point(1, 40), point(2, 55), point(3, 66, true), point(4, 70, true)]} />)

    expect(screen.getByRole("img", { name: "Readiness over 4 sessions: 40 to 70" })).toBeInTheDocument()
    expect(container.querySelector("polyline")?.getAttribute("stroke")).toBe("#18745a")
    expect(screen.getAllByTestId("entry-zone-day")).toHaveLength(2)
  })

  it("can fit the scale to the history, drawing the 60 line only when it is in range", () => {
    const { container, rerender } = render(<ReadinessSparkline history={[point(1, 40), point(2, 70)]} height={40} fitRange />)
    // 35..75 range: 40 sits near the bottom, 70 near the top.
    const ys = container.querySelector("polyline")?.getAttribute("points")?.split(" ").map((pair) => Number(pair.split(",")[1]))
    expect(ys?.[0]).toBeGreaterThan(30)
    expect(ys?.[1]).toBeLessThan(10)
    expect(container.querySelector("line")).not.toBeNull()

    rerender(<ReadinessSparkline history={[point(1, 20), point(2, 30)]} fitRange />)
    expect(container.querySelector("line")).toBeNull()
  })

  it("colours a falling line amber, can hide dots, and needs two points", () => {
    const { container, rerender } = render(<ReadinessSparkline history={[point(1, 70, true), point(2, 50)]} showDots={false} />)
    expect(container.querySelector("polyline")?.getAttribute("stroke")).toBe("#b7791f")
    expect(screen.queryByTestId("entry-zone-day")).not.toBeInTheDocument()

    rerender(<ReadinessSparkline history={[point(1, 70)]} />)
    expect(container.querySelector("svg")).toBeNull()
  })
})
