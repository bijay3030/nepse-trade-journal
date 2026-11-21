import { useQuery } from "@tanstack/react-query"

import api from "../../lib/axios"
import type { LabReport } from "./types"

export function useLab() {
  return useQuery({
    queryKey: ["lab"],
    queryFn: async () => (await api.get<LabReport>("/lab")).data,
    staleTime: 5 * 60_000,
    retry: 1,
  })
}
