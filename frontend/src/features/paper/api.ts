import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"

import api from "../../lib/axios"
import type { PaperAccount } from "./types"

const KEY = ["paper-trading"]

export function usePaperAccount() {
  return useQuery({ queryKey: KEY, queryFn: async () => (await api.get<PaperAccount>("/paper_trading")).data, refetchInterval: 60_000, retry: 1 })
}

export function useTogglePaperTrading() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: async (enabled: boolean) => (await api.patch<PaperAccount>("/paper_trading", { enabled })).data,
    onSuccess: (data) => client.setQueryData(KEY, data),
  })
}
