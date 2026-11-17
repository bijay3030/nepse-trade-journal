import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"

import api from "../../lib/axios"

/** GET /telegram */
export type TelegramStatus = {
  configured: boolean
  linked: boolean
  username: string | null
  /** A connect link was issued and hasn't expired. */
  pending: boolean
  watchlist_alerts: boolean
  board_alerts: boolean
  /** Live: a stock matching the saved scanner filter trades inside its entry zone. */
  scanner_entry_alerts?: boolean
  /** 9 AM on trading days: saved-filter stocks in or near their entry zone. */
  morning_watch?: boolean
  /** After the nightly analysis: the session's market summary. */
  market_summary?: boolean
}

const KEY = ["telegram"]

export function useTelegramStatus() {
  return useQuery({ queryKey: KEY, queryFn: async () => (await api.get<TelegramStatus>("/telegram")).data, retry: 1 })
}

function useTelegramMutation<TVariables = void, TResult extends TelegramStatus = TelegramStatus>(
  request: (variables: TVariables) => Promise<{ data: TResult }>,
) {
  const client = useQueryClient()
  return useMutation({
    mutationFn: async (variables: TVariables) => (await request(variables)).data,
    onSuccess: (data) => client.setQueryData(KEY, data),
  })
}

/** A one-time code (valid 30 minutes) to send to the bot, and a t.me link that carries it. */
export type TelegramLink = TelegramStatus & { link_url: string; code: string; bot_username: string }

export const useTelegramLink = () => useTelegramMutation(() => api.post<TelegramLink>("/telegram/link"))
export const useTelegramCheck = () => useTelegramMutation(() => api.post<TelegramStatus>("/telegram/check"))
export const useTelegramUnlink = () => useTelegramMutation(() => api.delete<TelegramStatus>("/telegram"))
export const useTelegramTest = () => useTelegramMutation(() => api.post<TelegramStatus & { sent: boolean }>("/telegram/test"))
export const useUpdateTelegram = () =>
  useTelegramMutation((changes: { watchlist_alerts?: boolean; board_alerts?: boolean; scanner_entry_alerts?: boolean; morning_watch?: boolean; market_summary?: boolean }) => api.patch<TelegramStatus>("/telegram", changes))
