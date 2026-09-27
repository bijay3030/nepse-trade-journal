import { useEffect, useRef, useState } from "react"
import { Search } from "lucide-react"
import { useQuery } from "@tanstack/react-query"
import api from "../../lib/axios"

export type StockOption = {
  id: number
  symbol: string
  name: string
  sector: string
}

type StockSearchInputProps = {
  onSelect: (stock: StockOption) => void
  selectedStock: StockOption | null
}

export function StockSearchInput({ onSelect, selectedStock }: StockSearchInputProps) {
  const [search, setSearch] = useState(selectedStock?.symbol ?? "")
  const [isOpen, setIsOpen] = useState(false)
  const wrapperRef = useRef<HTMLDivElement | null>(null)

  const { data: stocks, isLoading } = useQuery({
    queryKey: ["stocks", "search", search],
    queryFn: async () => {
      if (!search || search.length < 2) return [] as StockOption[]
      const res = await api.get<StockOption[]>(`/stocks?search=${encodeURIComponent(search)}`)
      return res.data
    },
    enabled: search.length >= 2,
    staleTime: 1000 * 30,
  })

  useEffect(() => {
    setSearch(selectedStock?.symbol ?? "")
  }, [selectedStock])

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (wrapperRef.current && !wrapperRef.current.contains(e.target as Node)) {
        setIsOpen(false)
      }
    }

    document.addEventListener("mousedown", handleClickOutside)
    return () => document.removeEventListener("mousedown", handleClickOutside)
  }, [])

  const handleSelect = (stock: StockOption) => {
    onSelect(stock)
    setSearch(stock.symbol)
    setIsOpen(false)
  }

  return (
    <div ref={wrapperRef} className="relative md:col-span-2">
      <div className="relative">
        <Search className="pointer-events-none absolute left-3 top-1/2 h-5 w-5 -translate-y-1/2 text-slate/55" />
        <input
          type="text"
          value={search}
          onChange={(e) => {
            setSearch(e.target.value.toUpperCase())
            setIsOpen(true)
          }}
          onFocus={() => setIsOpen(true)}
          placeholder="Search NEPSE stocks (e.g., NABIL, NTC)..."
          className="h-11 w-full rounded-xl border border-mist bg-white pl-10 pr-4 text-sm text-ink focus:border-ink/35 focus:outline-none"
        />
      </div>

      {isOpen && (search.length >= 2 || (stocks?.length ?? 0) > 0) && (
        <div className="absolute z-50 mt-1 max-h-60 w-full overflow-auto rounded-xl border border-mist bg-white shadow-panel">
          {isLoading ? (
            <div className="p-4 text-center text-sm text-slate">Searching...</div>
          ) : (stocks?.length ?? 0) === 0 ? (
            <div className="p-4 text-center text-sm text-slate">No stocks found</div>
          ) : (
            stocks?.map((stock) => (
              <button
                key={stock.id}
                type="button"
                onClick={() => handleSelect(stock)}
                className="flex w-full items-center justify-between px-4 py-3 text-left transition hover:bg-slate/5"
              >
                <div>
                  <p className="font-semibold text-ink">{stock.symbol}</p>
                  <p className="text-sm text-slate">{stock.name}</p>
                </div>
                <span className="rounded-full bg-slate/10 px-2 py-1 text-xs text-slate">{stock.sector}</span>
              </button>
            ))
          )}
        </div>
      )}
    </div>
  )
}
