import { SOURCE_LABELS, useLiveStatus } from "../hooks/useLiveStatus"
const clock = (iso?: string | null) => (iso ? new Date(iso).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) : null)

// During the session: whether prices are live, and when they're delayed, why and since when.
export function LiveStatusNotice() {
  const { data } = useLiveStatus(true)
  if (!data || data.state === "closed" || data.state === "unknown") return null
  if (data.state === "live") {
    return (
      <p className="mt-2 text-xs text-pine" aria-label="Price status">
        ● Live prices from {SOURCE_LABELS[data.source ?? ""] ?? "the market"}{data.as_of ? `, as of ${clock(data.as_of)}` : ""}
      </p>
    )
  }
  const reasons = Object.values(data.reasons ?? {})
  return (
    <div className="mt-3 rounded-xl border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900" role="status" aria-label="Price status">
      <b>Live prices are delayed</b>{data.since ? ` since ${clock(data.since)}` : ""}.{" "}
      {data.last_live_at ? `Prices shown are from ${clock(data.last_live_at)}. ` : ""}
      Watchlist, position and scanner alerts wait until fresh prices arrive.
      {reasons.length > 0 && <span className="block text-xs text-amber-800">{reasons.join(" · ")}</span>}
    </div>
  )
}
