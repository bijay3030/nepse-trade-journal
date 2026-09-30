import { useQuery } from "@tanstack/react-query"

import api from "../../lib/axios"
import type { BuyZoneResponse, MarketOverview, ScreenerResponse, StockAnalysis } from "./types"

export function useMarketOverview() {
  return useQuery({
    queryKey: ["market", "overview"],
    queryFn: async () => (await api.get<MarketOverview>("/market/overview")).data,
    staleTime: 30_000,
    retry: 1,
  })
}

export function useScreener() {
  return useQuery({
    queryKey: ["screener"],
    queryFn: async () => (await api.get<ScreenerResponse>("/screener")).data,
    staleTime: 30_000,
    retry: 1,
  })
}

export function useStockAnalysis(symbol: string) {
  return useQuery({
    queryKey: ["screener", "analysis", symbol],
    queryFn: async () =>
      (await api.get<StockAnalysis>(`/screener/${encodeURIComponent(symbol)}`)).data,
    staleTime: 30_000,
    retry: 1,
    enabled: symbol.length > 0,
  })
}

export function useBuyZone() {
  return useQuery({
    queryKey: ["screener", "buy_zone"],
    queryFn: async () => (await api.get<BuyZoneResponse>("/screener/buy_zone")).data,
    staleTime: 60_000,
    retry: 1,
  })
}
