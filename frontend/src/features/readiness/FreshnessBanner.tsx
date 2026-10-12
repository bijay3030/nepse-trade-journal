export type Freshness = { snapshot_on: string | null; behind_sessions: number; latest_session: string | null }

// Shown when the nightly snapshots are behind the latest completed session.
export function FreshnessBanner({ freshness }: { freshness?: Freshness | null }) {
  if (!freshness || freshness.behind_sessions === 0 || !freshness.snapshot_on) return null
  return (
    <p className="rounded-xl bg-amber-50 px-4 py-2 text-sm text-amber-900" role="status" aria-label="Data freshness">
      <b>Data as of {freshness.snapshot_on}</b>: {freshness.behind_sessions} later {freshness.behind_sessions === 1 ? "session is" : "sessions are"} not
      built yet (up to {freshness.latest_session}). The app is catching up in the background; this usually takes 15–30 minutes.
    </p>
  )
}
