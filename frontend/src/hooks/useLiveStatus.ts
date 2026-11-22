import { useQuery } from "@tanstack/react-query"

import api from "../lib/axios"

/** GET /market/live_status (Nepse::LiveFeed): how fresh the live prices are. */
export type LiveStatus = {
  state: "live" | "delayed" | "closed" | "unknown"
  source?: "sharesansar_live" | "sharesansar_summary" | null
  as_of?: string | null
  checked_at?: string | null
  /** When the current state began. */
  since?: string | null
  last_live_at?: string | null
  reasons?: Record<string, string>
}

export const SOURCE_LABELS: Record<string, string> = { sharesansar_live: "ShareSansar Live Trading", sharesansar_summary: "ShareSansar price table" }

/** Polled every minute while the market is open. */
export function useLiveStatus(enabled: boolean) {
  return useQuery({
    queryKey: ["market", "live-status"],
    queryFn: async () => (await api.get<LiveStatus>("/market/live_status")).data,
    enabled,
    refetchInterval: 60_000,
    staleTime: 30_000,
    retry: false,
  })
}
