import { isMarketOpen, nextMarketOpen, parseTradingDays, tradingDaysLabel } from "./marketHours"

// Local-field dates standing in for Nepal time. 2026-09-28 is a Monday.
const at = (iso: string) => new Date(`${iso}:00`)

describe("marketHours", () => {
  it("defaults to Monday-Friday and reads overrides", () => {
    expect(parseTradingDays(undefined)).toEqual([1, 2, 3, 4, 5])
    expect(parseTradingDays("0,1,2,3,4")).toEqual([0, 1, 2, 3, 4])
    expect(parseTradingDays("x, 9")).toEqual([1, 2, 3, 4, 5])
    expect(tradingDaysLabel([1, 2, 3, 4, 5])).toBe("Mon-Fri")
  })

  it("is open 11:00-15:00 on trading days only", () => {
    expect(isMarketOpen(at("2026-09-28T11:00"))).toBe(true)
    expect(isMarketOpen(at("2026-09-28T15:00"))).toBe(false)
    expect(isMarketOpen(at("2026-09-27T12:00"))).toBe(false) // Sunday
  })

  it("finds the next open across the weekend", () => {
    expect(nextMarketOpen(at("2026-09-28T09:00"))).toEqual(at("2026-09-28T11:00"))
    expect(nextMarketOpen(at("2026-10-02T16:00"))).toEqual(at("2026-10-05T11:00")) // Fri -> Mon
    expect(nextMarketOpen(at("2026-09-27T12:00"))).toEqual(at("2026-09-28T11:00")) // Sun -> Mon
  })
})
