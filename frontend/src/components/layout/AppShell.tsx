import type { ReactNode } from "react"

export function AppShell({ children }: { children: ReactNode }) {
  return (
    <div className="mx-auto flex min-h-screen w-full max-w-7xl flex-col px-4 py-6 sm:px-6 lg:px-8">
      <header className="mb-6 rounded-2xl border border-white/70 bg-white/80 p-5 shadow-panel backdrop-blur-sm">
        <p className="font-display text-xs font-bold uppercase tracking-[0.22em] text-slate">NEPSE Trade Journal</p>
        <div className="mt-2 flex flex-wrap items-center justify-between gap-4">
          <h1 className="font-display text-3xl font-extrabold text-ink sm:text-4xl">Trade Analytics Command Deck</h1>
          <span className="rounded-full bg-ember/15 px-3 py-1 text-xs font-bold uppercase tracking-[0.14em] text-ember">
            Beta
          </span>
        </div>
      </header>
      <main>{children}</main>
    </div>
  )
}
