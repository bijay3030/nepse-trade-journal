import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query"

import api from "../../lib/axios"
import type { SizingResponse, TradingSettings } from "./types"

const SETTINGS_KEY = ["trading_settings"]

export function useTradingSettings() {
  return useQuery({ queryKey: SETTINGS_KEY, queryFn: async () => (await api.get<TradingSettings>("/trading_settings")).data, retry: 1 })
}

export function useUpdateTradingSettings() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: async (changes: Partial<TradingSettings>) => (await api.patch<TradingSettings>("/trading_settings", changes)).data,
    onSuccess: (data) => {
      client.setQueryData(SETTINGS_KEY, data)
      // Sizes on watchlist cards depend on these.
      void client.invalidateQueries({ queryKey: ["watchlist"] })
    },
  })
}

export function usePositionSizing(input: { entry: number; stop: number | null; target?: number | null; quantity?: number }) {
  const { entry, stop, target, quantity } = input
  return useQuery({
    queryKey: ["position_sizing", entry, stop, target ?? null, quantity ?? null],
    queryFn: async () =>
      (await api.get<SizingResponse>("/position_sizing", { params: { entry, stop, target: target ?? undefined, quantity: quantity || undefined } })).data,
    enabled: entry > 0 && stop !== null && stop > 0,
    placeholderData: keepPreviousData,
    staleTime: 60_000,
  })
}
