import { useEffect, useMemo, useState } from "react"
import api from "../lib/axios"
import { useStockPricesStore } from "../stores/stockPricesStore"

const EMPTY_SYMBOLS: string[] = []

type MarketSnapshot = {
  isOpen: boolean
  statusLabel: "Open" | "Closed"
  nextOpenIn: string
}

type ServerPrice = {
  symbol: string
  last_price: number
  change_percent?: number
  volume?: number
  last_updated?: string
}

let socket: WebSocket | null = null
let pollingTimer: number | null = null
let reconnectTimer: number | null = null
let consumerCount = 0
const trackedSymbols = new Set<string>()

function parseNptNow() {
  return new Date(new Date().toLocaleString("en-US", { timeZone: "Asia/Kathmandu" }))
}

function nextMarketOpen(nowNpt: Date) {
  const day = nowNpt.getDay()
  const minutes = nowNpt.getHours() * 60 + nowNpt.getMinutes()

  const next = new Date(nowNpt)
  next.setHours(11, 0, 0, 0)

  const isTradingDay = day >= 0 && day <= 4 // Sun-Thu

  if (isTradingDay && minutes < 11 * 60) return next

  if (day >= 0 && day <= 3) {
    next.setDate(next.getDate() + 1)
    return next
  }

  if (day === 4 && minutes >= 15 * 60) {
    next.setDate(next.getDate() + 3) // Thu -> Sun
    return next
  }

  if (day === 5) {
    next.setDate(next.getDate() + 2) // Fri -> Sun
    return next
  }

  if (day === 6) {
    next.setDate(next.getDate() + 1) // Sat -> Sun
    return next
  }

  return next
}

function formatCountdown(target: Date, now: Date) {
  const diffMs = Math.max(0, target.getTime() - now.getTime())
  const total = Math.floor(diffMs / 1000)
  const hours = Math.floor(total / 3600)
  const mins = Math.floor((total % 3600) / 60)
  const secs = total % 60

  if (hours > 0) return `${hours}h ${mins}m ${secs}s`
  return `${mins}m ${secs}s`
}

function getMarketSnapshot(): MarketSnapshot {
  const now = parseNptNow()
  const day = now.getDay()
  const minutes = now.getHours() * 60 + now.getMinutes()
  const isTradingDay = day >= 0 && day <= 4 // Sun-Thu
  const isOpen = isTradingDay && minutes >= 11 * 60 && minutes < 15 * 60

  if (isOpen) {
    return {
      isOpen: true,
      statusLabel: "Open",
      nextOpenIn: "",
    }
  }

  const nextOpen = nextMarketOpen(now)
  return {
    isOpen: false,
    statusLabel: "Closed",
    nextOpenIn: formatCountdown(nextOpen, now),
  }
}

function cableUrl() {
  const fromEnv = import.meta.env.VITE_CABLE_URL
  if (fromEnv) return fromEnv

  const apiBase = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3000/api/v1"
  const base = new URL(apiBase)
  const protocol = base.protocol === "https:" ? "wss:" : "ws:"
  return `${protocol}//${base.host}/cable`
}

async function pollPrices(refresh = false) {
  const symbols = Array.from(trackedSymbols)
  const params = new URLSearchParams()
  if (symbols.length > 0) params.set("symbols", symbols.join(","))
  if (refresh) params.set("refresh", "true")

  const query = params.toString()
  const path = query ? `/stocks/current_prices?${query}` : "/stocks/current_prices"
  const response = await api.get<{ prices: ServerPrice[] }>(path)
  useStockPricesStore.getState().upsertPrices(response.data.prices)
}

function clearTimers() {
  if (pollingTimer) {
    window.clearInterval(pollingTimer)
    pollingTimer = null
  }
  if (reconnectTimer) {
    window.clearInterval(reconnectTimer)
    reconnectTimer = null
  }
}

function stopSocket() {
  if (socket) {
    socket.close()
    socket = null
  }
}

function startPolling() {
  if (pollingTimer) return

  useStockPricesStore.getState().setConnectionStatus("polling")
  pollPrices().catch(() => {
    useStockPricesStore.getState().setConnectionStatus("reconnecting")
  })

  pollingTimer = window.setInterval(() => {
    pollPrices().catch(() => {
      useStockPricesStore.getState().setConnectionStatus("reconnecting")
    })
  }, 30_000)
}

function startReconnectLoop() {
  if (reconnectTimer) return

  reconnectTimer = window.setInterval(() => {
    connectWebSocket()
  }, 10_000)
}

function connectWebSocket() {
  if (socket && (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING)) {
    return
  }

  try {
    socket = new WebSocket(cableUrl())
  } catch (_error) {
    useStockPricesStore.getState().setConnectionStatus("reconnecting")
    startPolling()
    startReconnectLoop()
    return
  }

  socket.onopen = () => {
    useStockPricesStore.getState().setConnectionStatus("live")

    socket?.send(
      JSON.stringify({
        command: "subscribe",
        identifier: JSON.stringify({ channel: "StockPricesChannel" }),
      }),
    )

    if (pollingTimer) {
      window.clearInterval(pollingTimer)
      pollingTimer = null
    }

    if (reconnectTimer) {
      window.clearInterval(reconnectTimer)
      reconnectTimer = null
    }
  }

  socket.onmessage = (event) => {
    try {
      const payload = JSON.parse(event.data)
      const prices = payload?.message?.prices
      if (Array.isArray(prices) && prices.length > 0) {
        useStockPricesStore.getState().upsertPrices(prices)
        useStockPricesStore.getState().setConnectionStatus("live")
      }
    } catch (_error) {
      // Ignore protocol pings and malformed messages.
    }
  }

  socket.onerror = () => {
    useStockPricesStore.getState().setConnectionStatus("reconnecting")
  }

  socket.onclose = () => {
    socket = null
    useStockPricesStore.getState().setConnectionStatus("reconnecting")
    startPolling()
    startReconnectLoop()
  }
}

function ensureDataFlow(isMarketOpen: boolean) {
  if (!isMarketOpen) {
    clearTimers()
    stopSocket()
    useStockPricesStore.getState().setConnectionStatus("paused")
    return
  }

  connectWebSocket()
}

export function useStockPrices(symbols: string[] = EMPTY_SYMBOLS) {
  const [market, setMarket] = useState<MarketSnapshot>(() => getMarketSnapshot())
  const prices = useStockPricesStore((state) => state.prices)
  const connectionStatus = useStockPricesStore((state) => state.connectionStatus)
  const lastUpdatedAt = useStockPricesStore((state) => state.lastUpdatedAt)

  const normalizedSymbols = useMemo(
    () => Array.from(new Set(symbols.map((symbol) => symbol.trim().toUpperCase()).filter(Boolean))),
    [symbols],
  )
  const normalizedSymbolsKey = normalizedSymbols.join(",")

  useEffect(() => {
    const interval = window.setInterval(() => {
      setMarket(getMarketSnapshot())
    }, 1000)

    return () => window.clearInterval(interval)
  }, [])

  useEffect(() => {
    consumerCount += 1
    normalizedSymbols.forEach((symbol) => trackedSymbols.add(symbol))
    ensureDataFlow(market.isOpen)

    return () => {
      normalizedSymbols.forEach((symbol) => trackedSymbols.delete(symbol))
      consumerCount -= 1

      if (consumerCount <= 0) {
        clearTimers()
        stopSocket()
        useStockPricesStore.getState().setConnectionStatus("idle")
        consumerCount = 0
      }
    }
  }, [normalizedSymbolsKey])

  useEffect(() => {
    ensureDataFlow(market.isOpen)
  }, [market.isOpen])

  const refresh = async () => {
    try {
      await pollPrices(true)
      if (market.isOpen && (!socket || socket.readyState !== WebSocket.OPEN)) {
        useStockPricesStore.getState().setConnectionStatus("polling")
      }
    } catch (_error) {
      useStockPricesStore.getState().setConnectionStatus("reconnecting")
    }
  }

  return {
    prices,
    connectionStatus,
    lastUpdatedAt,
    market,
    refresh,
    getPrice: (symbol: string) => prices[symbol.toUpperCase()],
  }
}
