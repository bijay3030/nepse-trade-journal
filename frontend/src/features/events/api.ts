import { keepPreviousData, useQuery } from "@tanstack/react-query"

import api from "../../lib/axios"
import type { MarketEventFilters, MarketEventsResponse } from "./types"

export function useMarketEvents(filters: MarketEventFilters) {
  return useQuery({
    queryKey: ["market-events", filters],
    queryFn: async () => {
      const params = Object.fromEntries(Object.entries(filters).filter(([key, value]) => value !== "" && value !== "all" && !(key === "page" && value === 1)))
      return (await api.get<MarketEventsResponse>("/market_events", { params })).data
    },
    placeholderData: keepPreviousData,
    staleTime: 5 * 60_000,
    retry: 1,
  })
}
