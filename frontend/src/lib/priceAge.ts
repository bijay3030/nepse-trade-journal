// Thursday's close is still the latest price until Sunday's open, so only flag
// prices as stale once they are older than a normal weekend.
const STALE_AFTER_MS = 3 * 24 * 60 * 60 * 1000

export function describePriceAge(lastUpdated: string | null, now: Date = new Date()) {
  if (!lastUpdated) return null
  const updatedAt = new Date(lastUpdated)
  if (Number.isNaN(updatedAt.getTime())) return null

  const label = updatedAt.toLocaleString("en-US", {
    timeZone: "Asia/Kathmandu",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  })
  const ageMs = Math.max(0, now.getTime() - updatedAt.getTime())
  const minutes = Math.floor(ageMs / 60_000)
  const hours = Math.floor(minutes / 60)
  const days = Math.floor(hours / 24)
  const age =
    minutes < 1 ? "just now" : minutes < 60 ? `${minutes} min ago` : hours < 24 ? `${hours} hr ago` : `${days} day${days === 1 ? "" : "s"} ago`

  return { label, age, isStale: ageMs > STALE_AFTER_MS }
}
