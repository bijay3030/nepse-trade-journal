import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"

import api from "../../lib/axios"
import type { BuyInput, Position } from "./types"

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
