// NEPSE trades 11:00-15:00 Nepal time. Trading days moved from Sun-Thu to Mon-Fri in
// 2026; override with VITE_NEPSE_TRADING_DAYS (0 = Sunday ... 6 = Saturday), keeping
// it in step with NEPSE_TRADING_DAYS on the backend.
const DEFAULT_TRADING_DAYS = [1, 2, 3, 4, 5]
const OPEN_MINUTE = 11 * 60
const CLOSE_MINUTE = 15 * 60
const DAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

export function parseTradingDays(raw: string | undefined): number[] {
  const days = (raw ?? "")
    .split(",")
    .map((part) => part.trim())
    .filter((part) => /^[0-6]$/.test(part))
    .map(Number)
  return days.length > 0 ? Array.from(new Set(days)).sort() : DEFAULT_TRADING_DAYS
}

export const TRADING_DAYS = parseTradingDays(import.meta.env.VITE_NEPSE_TRADING_DAYS)

export function tradingDaysLabel(days: number[] = TRADING_DAYS) {
  const contiguous = days.every((day, index) => index === 0 || day === days[index - 1] + 1)
  if (contiguous && days.length > 1) return `${DAY_NAMES[days[0]]}-${DAY_NAMES[days[days.length - 1]]}`
  return days.map((day) => DAY_NAMES[day]).join(", ")
}

// `nowNpt` is a Date whose local fields hold the current Nepal time.
export function isMarketOpen(nowNpt: Date, days: number[] = TRADING_DAYS) {
  const minutes = nowNpt.getHours() * 60 + nowNpt.getMinutes()
  return days.includes(nowNpt.getDay()) && minutes >= OPEN_MINUTE && minutes < CLOSE_MINUTE
}

export function nextMarketOpen(nowNpt: Date, days: number[] = TRADING_DAYS) {
  const minutes = nowNpt.getHours() * 60 + nowNpt.getMinutes()
  for (let offset = 0; offset <= 7; offset += 1) {
    const candidate = new Date(nowNpt)
    candidate.setDate(candidate.getDate() + offset)
    candidate.setHours(11, 0, 0, 0)
    if (!days.includes(candidate.getDay())) continue
    if (offset === 0 && minutes >= OPEN_MINUTE) continue
    return candidate
  }
  return nowNpt
}

/** Today's date in Nepal (YYYY-MM-DD), whatever the browser's time zone. */
export function nptToday(now: Date = new Date()) {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Kathmandu", year: "numeric", month: "2-digit", day: "2-digit" }).format(now)
}
