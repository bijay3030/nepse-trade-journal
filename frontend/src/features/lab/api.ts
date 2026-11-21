import { useQuery } from "@tanstack/react-query"
import axios from "axios"

import api from "../../lib/axios"
import type { LabReport, StockBacktest } from "./types"

export function useLab() {
  return useQuery({
    queryKey: ["lab"],
    queryFn: async () => (await api.get<LabReport>("/lab")).data,
    staleTime: 5 * 60_000,
    retry: 1,
  })
}

/** One stock's strategy backtest; the API answers 404 / 422 with an { error } message. */
export function useStockBacktest(symbol: string | null) {
  return useQuery({
    queryKey: ["lab", "stock", symbol],
    queryFn: async () => (await api.get<StockBacktest>(`/lab/stocks/${encodeURIComponent(symbol as string)}`)).data,
    enabled: Boolean(symbol),
    staleTime: 10 * 60_000,
    retry: (count, error) => count < 1 && !(axios.isAxiosError(error) && [404, 422].includes(error.response?.status ?? 0)),
  })
}

export function useEquitySymbols() {
  return useQuery({
    queryKey: ["stocks", "equity-symbols"],
    queryFn: async () => (await api.get<Array<{ symbol: string; name: string }>>("/stocks", { params: { security_type: "Equity" } })).data,
    staleTime: 60 * 60_000,
  })
}
