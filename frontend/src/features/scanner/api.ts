import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"

import api from "../../lib/axios"
import type { CrossoverChart, CrossoverScan, CrossoverSignal, ScannerAlert } from "./types"

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

const ALERT_KEY = ["scans", "alert"]

export function useScannerAlert() {
  return useQuery({ queryKey: ALERT_KEY, queryFn: async () => (await api.get<ScannerAlert>("/scans/alert")).data, retry: 1 })
}

export function useSaveScannerAlert() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: async (signals: CrossoverSignal[]) => (await api.put<ScannerAlert>("/scans/alert", { signals })).data,
    onSuccess: (data) => client.setQueryData(ALERT_KEY, data),
  })
}
