import { useQuery } from "@tanstack/react-query"

import api from "../../lib/axios"
import type { BacktestRun } from "./types"

export function useBacktest() {
  return useQuery({
    queryKey: ["backtest"],
    queryFn: async () => (await api.get<BacktestRun>("/backtest")).data,
    staleTime: 5 * 60_000,
    retry: false,
  })
}
