import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"

import api from "../../lib/axios"
import type { BuyInput, Portfolio, Position, PositionAlertsResponse } from "./types"

const KEY = ["positions"]

function useInvalidate() {
  const client = useQueryClient()
  // A buy also changes the watchlist item's status.
  return () => Promise.all([client.invalidateQueries({ queryKey: KEY }), client.invalidateQueries({ queryKey: ["watchlist"] })])
}

export function usePositions(status?: "open" | "closed") {
  return useQuery({
    queryKey: [...KEY, status ?? "all"],
    queryFn: async () => (await api.get<Position[]>("/positions", { params: status ? { status } : {} })).data,
    staleTime: 30_000,
    refetchInterval: 60_000,
    retry: 1,
  })
}

export function useRecordBuy() {
  const invalidate = useInvalidate()
  return useMutation({ mutationFn: async (input: BuyInput) => (await api.post<Position>("/positions", input)).data, onSuccess: invalidate })
}

export function useUpdatePosition() {
  const invalidate = useInvalidate()
  return useMutation({
    mutationFn: async ({ id, ...changes }: { id: number; stop_price?: number; target_price?: number | null; notes?: string }) =>
      (await api.patch<Position>(`/positions/${id}`, changes)).data,
    onSuccess: invalidate,
  })
}

export function useRemoveFill() {
  const invalidate = useInvalidate()
  return useMutation({
    mutationFn: async ({ positionId, fillId }: { positionId: number; fillId: number }) => (await api.delete(`/positions/${positionId}/fills/${fillId}`)).data,
    onSuccess: invalidate,
  })
}

const ALERTS_KEY = [...KEY, "alerts"]

export function usePositionAlerts() {
  return useQuery({
    queryKey: ALERTS_KEY,
    queryFn: async () => (await api.get<PositionAlertsResponse>("/position_alerts")).data,
    refetchInterval: 60_000,
    retry: 1,
  })
}

export function useMarkPositionAlertsRead() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: async (ids?: number[]) => (await api.post<{ updated: number }>("/position_alerts/mark_read", ids ? { ids } : {})).data,
    onSuccess: () => client.invalidateQueries({ queryKey: ALERTS_KEY }),
  })
}

export function usePortfolio() {
  return useQuery({
    queryKey: [...KEY, "portfolio"],
    queryFn: async () => (await api.get<Portfolio>("/positions/portfolio")).data,
    staleTime: 30_000,
    refetchInterval: 60_000,
    retry: 1,
  })
}
