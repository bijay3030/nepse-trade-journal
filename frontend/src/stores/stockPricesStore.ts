import { create } from "zustand"

export type ConnectionStatus = "idle" | "live" | "polling" | "reconnecting" | "paused"

export type LiveStockPrice = {
  symbol: string
  lastPrice: number
  changePercent: number
  volume: number
  updatedAt: string
  flashDirection: "up" | "down" | null
  flashTs: number
}

type PricePayload = {
  symbol: string
  last_price: number
  change_percent?: number
  volume?: number
  last_updated?: string
}

type StockPricesState = {
  prices: Record<string, LiveStockPrice>
  connectionStatus: ConnectionStatus
  lastUpdatedAt: string | null
  upsertPrices: (payload: PricePayload[]) => void
  setConnectionStatus: (status: ConnectionStatus) => void
  clearPrices: () => void
}

export const useStockPricesStore = create<StockPricesState>((set) => ({
  prices: {},
  connectionStatus: "idle",
  lastUpdatedAt: null,
  upsertPrices: (payload) => {
    const ts = Date.now()

    set((state) => {
      const next = { ...state.prices }
      payload.forEach((item) => {
        const symbol = item.symbol.toUpperCase()
        const previous = next[symbol]
        const lastPrice = Number(item.last_price ?? previous?.lastPrice ?? 0)

        let flashDirection: "up" | "down" | null = null
        if (previous) {
          if (lastPrice > previous.lastPrice) flashDirection = "up"
          if (lastPrice < previous.lastPrice) flashDirection = "down"
        }

        next[symbol] = {
          symbol,
          lastPrice,
          changePercent: Number(item.change_percent ?? previous?.changePercent ?? 0),
          volume: Number(item.volume ?? previous?.volume ?? 0),
          updatedAt: item.last_updated ?? new Date().toISOString(),
          flashDirection,
          flashTs: flashDirection ? ts : previous?.flashTs ?? ts,
        }
      })

      return {
        prices: next,
        lastUpdatedAt: new Date().toISOString(),
      }
    })
  },
  setConnectionStatus: (status) => set({ connectionStatus: status }),
  clearPrices: () => set({ prices: {}, lastUpdatedAt: null }),
}))
