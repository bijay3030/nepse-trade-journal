import { useQuery } from "@tanstack/react-query"

import api from "../../lib/axios"
import type { CrossoverChart, CrossoverScan } from "./types"

export function useCrossoverScan() {
  return useQuery({
    queryKey: ["scans", "crossovers"],
    queryFn: async () => (await api.get<CrossoverScan>("/scans/crossovers")).data,
    staleTime: 5 * 60_000,
    retry: 1,
  })
}

export function useCrossoverChart(symbol: string | null) {
  return useQuery({
    queryKey: ["scans", "crossovers", "chart", symbol],
    queryFn: async () => (await api.get<CrossoverChart>(`/scans/crossovers/${encodeURIComponent(symbol as string)}`)).data,
    enabled: Boolean(symbol),
    staleTime: 5 * 60_000,
    retry: 1,
  })
}
