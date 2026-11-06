import { useQuery } from "@tanstack/react-query"

import api from "../../lib/axios"
import type { CrossoverScan } from "./types"

export function useCrossoverScan() {
  return useQuery({
    queryKey: ["scans", "crossovers"],
    queryFn: async () => (await api.get<CrossoverScan>("/scans/crossovers")).data,
    staleTime: 5 * 60_000,
    retry: 1,
  })
}
