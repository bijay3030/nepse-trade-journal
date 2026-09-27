import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { useEffect } from "react"

import api from "../../lib/axios"
import { useStockPricesStore } from "../../stores/stockPricesStore"
import type { AlertsResponse, LevelInput, SetupType, Suggestion, WatchlistItem } from "./types"

const WATCHLIST_KEY = ["watchlist"] as const
const ALERTS_KEY = ["watchlist", "alerts"] as const

export function apiErrorMessage(error: unknown, fallback = "Something went wrong. Check that the Rails API is running.") {
  const data = (error as { response?: { data?: { error?: string } } } | null)?.response?.data
  return data?.error || fallback
}

// Watchlist prices and alerts change after each price sync, so refetch whenever
// new prices arrive over the WebSocket (or polling).
function useRefetchOnPriceUpdate() {
  const queryClient = useQueryClient()
  const lastUpdatedAt = useStockPricesStore((state) => state.lastUpdatedAt)
  useEffect(() => {
    if (lastUpdatedAt) void queryClient.invalidateQueries({ queryKey: WATCHLIST_KEY })
  }, [lastUpdatedAt, queryClient])
}

export function useWatchlist(includeArchived = false) {
  useRefetchOnPriceUpdate()
  return useQuery({
    queryKey: [...WATCHLIST_KEY, "items", includeArchived],
    queryFn: async () =>
      (await api.get<WatchlistItem[]>("/watchlist_items", { params: includeArchived ? { include_archived: true } : {} })).data,
    staleTime: 15_000,
    retry: 1,
  })
}

export function useWatchlistAlerts() {
  useRefetchOnPriceUpdate()
  return useQuery({
    queryKey: ALERTS_KEY,
    queryFn: async () => (await api.get<AlertsResponse>("/watchlist_alerts")).data,
    refetchInterval: 60_000,
    retry: 1,
  })
}

export function useSuggestion(symbol: string, setupType: SetupType, enabled: boolean) {
  return useQuery({
    queryKey: [...WATCHLIST_KEY, "suggestion", symbol, setupType],
    queryFn: async () => {
      try {
        return (await api.get<Suggestion>("/watchlist_items/suggestion", { params: { symbol, setup_type: setupType } })).data
      } catch (error) {
        // The API answers 422 with an explanation when no levels can be suggested.
        const data = (error as { response?: { status?: number; data?: Suggestion } }).response
        if (data?.status === 422 && data.data) return data.data
        throw error
      }
    },
    enabled: enabled && symbol.length > 0,
    staleTime: 60_000,
    retry: false,
  })
}

function useInvalidateWatchlist() {
  const queryClient = useQueryClient()
  return () => queryClient.invalidateQueries({ queryKey: WATCHLIST_KEY })
}

export function useAddToWatchlist() {
  const invalidate = useInvalidateWatchlist()
  return useMutation({
    mutationFn: async (input: { symbol: string; setup_type: SetupType; notes?: string } & LevelInput) =>
      (await api.post<WatchlistItem>("/watchlist_items", input)).data,
    onSuccess: invalidate,
  })
}

export function useUpdateWatchlistItem() {
  const invalidate = useInvalidateWatchlist()
  return useMutation({
    mutationFn: async ({ id, ...input }: { id: number; notes?: string; status?: "watching" | "archived" } & LevelInput) =>
      (await api.patch<WatchlistItem>(`/watchlist_items/${id}`, input)).data,
    onSuccess: invalidate,
  })
}

export function useRemoveWatchlistItem() {
  const invalidate = useInvalidateWatchlist()
  return useMutation({
    mutationFn: async (id: number) => (await api.delete(`/watchlist_items/${id}`)).data,
    onSuccess: invalidate,
  })
}

export function useCreatePlanFromSetup() {
  const invalidate = useInvalidateWatchlist()
  return useMutation({
    mutationFn: async ({ id, ...input }: {
      id: number
      planned_entry_price?: number
      stop_loss_price?: number
      target_price?: number
      planned_quantity?: number
      thesis?: string
      strategy?: string
    }) => (await api.post<{ trade_plan_id: number; watchlist_item: WatchlistItem }>(`/watchlist_items/${id}/trade_plan`, input)).data,
    onSuccess: invalidate,
  })
}

export function useMarkAlertsRead() {
  const invalidate = useInvalidateWatchlist()
  return useMutation({
    mutationFn: async (ids?: number[]) => (await api.post<{ updated: number }>("/watchlist_alerts/mark_read", ids ? { ids } : {})).data,
    onSuccess: invalidate,
  })
}
