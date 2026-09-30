import { useQuery } from "@tanstack/react-query"

import api from "../../lib/axios"
import type { MarketHeatmapResponse } from "./types"

// Prices sync every 5 minutes during market hours; a minute is fresh enough.
export function useMarketHeatmap() {
  return useQuery({
    queryKey: ["market", "heatmap"],
    queryFn: async () => (await api.get<MarketHeatmapResponse>("/market/heatmap")).data,
    staleTime: 30_000,
    refetchInterval: 60_000,
    retry: 1,
  })
}
