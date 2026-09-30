import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"

import api from "../../lib/axios"
import type { Digest, DigestList, DigestPreferences, DigestSection } from "./types"

export function useDigests() {
  return useQuery({
    queryKey: ["digests"],
    queryFn: async () => (await api.get<DigestList>("/digests")).data,
    staleTime: 60_000,
    retry: 1,
  })
}

/** "latest" or a session date (YYYY-MM-DD). A 404 means no digest yet. */
export function useDigest(date: string) {
  return useQuery({
    queryKey: ["digests", date],
    queryFn: async () => (await api.get<Digest>(`/digests/${date}`)).data,
    staleTime: 60_000,
    retry: false,
  })
}

export function useMarkDigestRead() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: async (date: string) => (await api.post(`/digests/${date}/mark_read`)).data,
    onSuccess: () => void client.invalidateQueries({ queryKey: ["digests"] }),
  })
}

export function useDigestPreferences() {
  return useQuery({
    queryKey: ["digest_preferences"],
    queryFn: async () => (await api.get<DigestPreferences>("/digest_preferences")).data,
    retry: 1,
  })
}

export function useUpdateDigestPreferences() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: async (changes: { enabled?: boolean; sections?: DigestSection[] }) =>
      (await api.patch<DigestPreferences>("/digest_preferences", changes)).data,
    onSuccess: (data) => {
      client.setQueryData(["digest_preferences"], data)
      void client.invalidateQueries({ queryKey: ["digests"] })
    },
  })
}
