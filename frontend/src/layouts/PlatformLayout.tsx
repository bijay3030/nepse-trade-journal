import { AnimatePresence, motion } from "framer-motion"
import {
  BarChart3,
  BookOpenText,
  Briefcase,
  ChevronDown,
  Clock3,
  Newspaper,
  Wallet,
  HelpCircle,
  LayoutDashboard,
  Activity,
  ScanSearch,
  Menu,
  Plus,
  PlusCircle,
  RefreshCw,
  Settings,
  Sparkles,
  TrendingUp,
  Wifi,
  WifiOff,
  X,
  Bookmark,
  FlaskConical,
} from "lucide-react"
import { useEffect, useRef, useState } from "react"
import { NavLink, Outlet, useLocation, useNavigate } from "react-router-dom"
import { useWatchlistAlerts } from "../features/watchlist/api"
import { useStockPrices } from "../hooks/useStockPrices"
import { tradingDaysLabel } from "../lib/marketHours"
import { cn } from "../lib/cn"

const navItems = [
  { to: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
  { to: "/market", label: "Market Overview", icon: Activity },
  { to: "/digest", label: "Daily Digest", icon: Newspaper },
  { to: "/screener", label: "VCP Screener", icon: ScanSearch },
  { to: "/watchlist", label: "Watchlist", icon: Bookmark },
  { to: "/positions", label: "Positions", icon: Wallet },
  { to: "/trade/new", label: "New Trade", icon: PlusCircle },
  { to: "/portfolio", label: "Portfolio", icon: Briefcase },
  { to: "/trades", label: "Trades", icon: Clock3 },
  { to: "/stocks", label: "Stocks", icon: TrendingUp },
  { to: "/analytics", label: "Analytics", icon: BarChart3 },
  { to: "/backtest", label: "Backtest", icon: FlaskConical },
  { to: "/journal", label: "Journal", icon: BookOpenText },
  { to: "/help", label: "Help", icon: HelpCircle },
  { to: "/settings", label: "Settings", icon: Settings },
] as const

const mobileTabs = [
  { to: "/dashboard", label: "Home", icon: LayoutDashboard },
  { to: "/screener", label: "Screener", icon: ScanSearch },
  { to: "/trade/new", label: "New", icon: PlusCircle },
  { to: "/stocks", label: "Stocks", icon: TrendingUp },
  { to: "/portfolio", label: "Portfolio", icon: Briefcase },
  { to: "/analytics", label: "Analytics", icon: BarChart3 },
] as const

export function PlatformLayout() {
  const [menuOpen, setMenuOpen] = useState(false)
  const [profileOpen, setProfileOpen] = useState(false)
  const [quickActionsOpen, setQuickActionsOpen] = useState(false)
  const [showOnboarding, setShowOnboarding] = useState(false)
  const [onboardingStep, setOnboardingStep] = useState(0)
  const [showShortcuts, setShowShortcuts] = useState(false)
  const [showCommand, setShowCommand] = useState(false)
  const [commandQuery, setCommandQuery] = useState("")
  const profileRef = useRef<HTMLDivElement | null>(null)
  const location = useLocation()
  const navigate = useNavigate()
  const { connectionStatus, market, refresh, lastUpdatedAt } = useStockPrices()
  const unreadAlerts = useWatchlistAlerts().data?.unread_count ?? 0
  const status = market.statusLabel

  useEffect(() => {
    setMenuOpen(false)
    setQuickActionsOpen(false)
  }, [location.pathname])

  useEffect(() => {
    const onOutsideClick = (event: MouseEvent) => {
      if (profileRef.current && !profileRef.current.contains(event.target as Node)) {
        setProfileOpen(false)
      }
    }

    document.addEventListener("mousedown", onOutsideClick)
    return () => document.removeEventListener("mousedown", onOutsideClick)
  }, [])

  useEffect(() => {
    const onboardingKey = "onboarding_seen_v2"
    if (!localStorage.getItem(onboardingKey)) setShowOnboarding(true)

    if (!localStorage.getItem("journal_entries_v1")) {
      localStorage.setItem(
        "journal_entries_v1",
        JSON.stringify([
          {
            id: crypto.randomUUID(),
            date: new Date().toISOString().slice(0, 10),
            marketCommentary: "Sample: Market opened weak then reversed with strong breadth.",
            emotion: "😎",
            disciplineScore: 8,
            tradesPlanned: 3,
            tradesTaken: 2,
            dayPnl: 3200,
            lessonsLearned: "Stayed patient at open #sample #discipline",
            tomorrowsPlan: "Focus on high-relative-strength banking names.",
            tags: ["#sample", "#discipline"],
            createdAt: new Date().toISOString(),
          },
        ]),
      )
    }

    if (!localStorage.getItem("portfolio_holdings_v1")) {
      localStorage.setItem(
        "portfolio_holdings_v1",
        JSON.stringify([
          { id: 1, symbol: "NABIL", qty: 50, avgPrice: 742, alerts: [780], trades: [] },
          { id: 2, symbol: "NTC", qty: 30, avgPrice: 915, alerts: [950], trades: [] },
        ]),
      )
    }
  }, [])

  function closeOnboarding() {
    localStorage.setItem("onboarding_seen_v2", "true")
    setShowOnboarding(false)
    setOnboardingStep(0)
  }

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null
      const isTyping =
        target &&
        (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || (target as HTMLElement).isContentEditable)
      if (isTyping) return

      if (event.key === "/") {
        event.preventDefault()
        setShowCommand(true)
        return
      }

      if (event.key === "N" || event.key === "n") {
        event.preventDefault()
        navigate("/trade/new")
        return
      }

      if (event.key === "J" || event.key === "j") {
        event.preventDefault()
        navigate("/journal")
        return
      }

      if (event.key === "?") {
        event.preventDefault()
        setShowShortcuts(true)
      }
    }

    window.addEventListener("keydown", onKeyDown)
    return () => window.removeEventListener("keydown", onKeyDown)
  }, [navigate])

  const shortcutItems = [
    { key: "/", action: "Open search / command palette" },
    { key: "N", action: "Open New Trade wizard" },
    { key: "J", action: "Open Journal" },
    { key: "?", action: "Show keyboard shortcuts" },
  ]

  const commandItems = [
    { label: "Dashboard", path: "/dashboard" },
    { label: "Market Overview", path: "/market" },
    { label: "Daily Digest", path: "/digest" },
    { label: "VCP Screener", path: "/screener" },
    { label: "Watchlist", path: "/watchlist" },
    { label: "Positions", path: "/positions" },
    { label: "New Trade", path: "/trade/new" },
    { label: "Trades", path: "/trades" },
    { label: "Stocks", path: "/stocks" },
    { label: "Portfolio", path: "/portfolio" },
    { label: "Analytics", path: "/analytics" },
    { label: "Backtest", path: "/backtest" },
    { label: "Journal", path: "/journal" },
    { label: "Help Center", path: "/help" },
    { label: "Settings", path: "/settings" },
  ]

  const filteredCommands = commandItems.filter((item) => item.label.toLowerCase().includes(commandQuery.toLowerCase()))

  return (
    <div className="min-h-screen pb-24 md:pb-0">
      <div className="mx-auto grid min-h-screen w-full max-w-[1600px] md:grid-cols-[260px_1fr]">
        <aside className="hidden border-r border-white/70 bg-ink text-white md:flex md:flex-col">
          <div className="border-b border-white/10 px-5 py-5">
            <p className="font-display text-lg font-bold">NEPSE Trade Journal</p>
            <p className="mt-1 text-xs uppercase tracking-[0.16em] text-white/70">Professional Console</p>
          </div>

          <nav className="flex-1 p-3">
            {navItems.map((item) => {
              const Icon = item.icon
              return (
                <NavLink key={item.to} to={item.to} className="group relative mb-1 block rounded-xl px-3 py-2.5 text-sm font-semibold">
                  {({ isActive }) => (
                    <>
                      {isActive ? (
                        <motion.span
                          layoutId="desktop-active-route"
                          className="absolute inset-0 rounded-xl bg-white/16"
                          transition={{ type: "spring", duration: 0.45 }}
                        />
                      ) : null}
                      <span className="relative flex items-center gap-2.5">
                        <Icon className={cn("h-4 w-4 text-white/70", isActive && "text-white")} />
                        <span>{item.label}</span>
                        {item.to === "/watchlist" && unreadAlerts > 0 ? (
                          <span className="ml-auto rounded-full bg-ember px-2 py-0.5 text-[10px] font-bold text-white" aria-label={`${unreadAlerts} unread alerts`}>
                            {unreadAlerts}
                          </span>
                        ) : null}
                      </span>
                    </>
                  )}
                </NavLink>
              )
            })}
          </nav>
        </aside>

        <div className="flex min-h-screen min-w-0 flex-col">
          <header className="sticky top-0 z-30 border-b border-white/70 bg-white/90 px-4 py-3 backdrop-blur-sm sm:px-6">
            <div className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-2 sm:gap-3">
                <button
                  type="button"
                  className="min-h-[44px] rounded-lg border border-mist/80 p-2 text-slate md:hidden"
                  onClick={() => setMenuOpen((prev) => !prev)}
                >
                  {menuOpen ? <X className="h-4 w-4" /> : <Menu className="h-4 w-4" />}
                </button>
                <h1 className="font-display text-lg font-bold text-ink sm:text-xl">Trading Workspace</h1>
                <span
                  className={cn(
                    "rounded-full px-2.5 py-1 text-xs font-bold uppercase tracking-[0.12em]",
                    status === "Open" ? "bg-pine/15 text-pine" : "bg-ember/15 text-ember",
                  )}
                >
                  Market {status}
                </span>
                <span
                  className={cn(
                    "hidden items-center gap-1 rounded-full px-2.5 py-1 text-xs font-bold uppercase tracking-[0.12em] sm:inline-flex",
                    connectionStatus === "live" && "bg-pine/15 text-pine",
                    connectionStatus === "polling" && "bg-slate/15 text-slate",
                    connectionStatus === "reconnecting" && "bg-amber-100 text-amber-700",
                    connectionStatus === "paused" && "bg-slate/15 text-slate",
                    connectionStatus === "idle" && "bg-slate/15 text-slate",
                  )}
                >
                  {connectionStatus === "live" ? <Wifi className="h-3.5 w-3.5" /> : <WifiOff className="h-3.5 w-3.5" />}
                  {connectionStatus === "live"
                    ? "Live"
                    : connectionStatus === "reconnecting"
                      ? "Reconnecting..."
                      : connectionStatus === "polling"
                        ? "Polling"
                        : connectionStatus === "paused"
                          ? "Paused"
                          : "Idle"}
                </span>
              </div>

              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => void refresh()}
                  className="inline-flex min-h-[44px] items-center gap-1 rounded-xl border border-mist/70 bg-white px-2.5 py-1.5 text-xs font-semibold text-ink hover:bg-slate/10"
                >
                  <RefreshCw className="h-3.5 w-3.5" />
                  Refresh
                </button>

                <div className="relative" ref={profileRef}>
                  <button
                    type="button"
                    className="flex min-h-[44px] items-center gap-2 rounded-xl border border-mist/70 bg-white px-3 py-1.5 text-sm font-semibold text-ink"
                    onClick={() => setProfileOpen((prev) => !prev)}
                  >
                    <span className="inline-flex h-7 w-7 items-center justify-center rounded-full bg-ink text-xs text-white">AS</span>
                    <span className="hidden sm:block">Aarav Shrestha</span>
                    <ChevronDown className="h-4 w-4 text-slate" />
                  </button>

                  <AnimatePresence>
                    {profileOpen ? (
                      <motion.div
                        initial={{ opacity: 0, y: -8 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -8 }}
                        className="absolute right-0 mt-2 w-48 rounded-xl border border-mist/80 bg-white p-2 shadow-panel"
                      >
                        <button className="w-full rounded-lg px-3 py-2 text-left text-sm font-medium text-ink hover:bg-slate/10">Profile</button>
                        <button className="w-full rounded-lg px-3 py-2 text-left text-sm font-medium text-ink hover:bg-slate/10">Preferences</button>
                        <button className="w-full rounded-lg px-3 py-2 text-left text-sm font-medium text-ember hover:bg-ember/10">Sign out</button>
                      </motion.div>
                    ) : null}
                  </AnimatePresence>
                </div>
              </div>
            </div>

            <AnimatePresence>
              {menuOpen ? (
                <motion.nav
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: "auto" }}
                  exit={{ opacity: 0, height: 0 }}
                  className="mt-3 overflow-hidden rounded-xl border border-mist/70 bg-white/95 p-2 md:hidden"
                >
                  {navItems.map((item) => {
                    const Icon = item.icon
                    return (
                      <NavLink
                        key={item.to}
                        to={item.to}
                        className={({ isActive }) =>
                          cn(
                            "mb-1 flex min-h-[44px] items-center gap-2 rounded-lg px-3 py-2 text-sm font-semibold",
                            isActive ? "bg-ink text-white" : "text-ink hover:bg-slate/10",
                          )
                        }
                      >
                        <Icon className="h-4 w-4" />
                        {item.label}
                      </NavLink>
                    )
                  })}
                </motion.nav>
              ) : null}
            </AnimatePresence>

            {!market.isOpen ? (
              <div className="mt-3 rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800">
                Market Closed. Next open in {market.nextOpenIn} ({tradingDaysLabel()}, 11:00-15:00 NPT).
              </div>
            ) : null}

            {lastUpdatedAt ? <p className="mt-2 text-xs text-slate/70">Last update: {new Date(lastUpdatedAt).toLocaleTimeString()}</p> : null}
          </header>

          <main className="min-w-0 flex-1 px-4 py-5 sm:px-6">
            <AnimatePresence mode="wait">
              <motion.div
                key={location.pathname}
                initial={{ opacity: 0, x: 24 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: -16 }}
                transition={{ duration: 0.24, ease: "easeOut" }}
              >
                <Outlet />
              </motion.div>
            </AnimatePresence>
          </main>
        </div>
      </div>

      <nav className="fixed inset-x-0 bottom-0 z-40 border-t border-mist/70 bg-white/95 px-2 py-2 backdrop-blur-sm md:hidden">
        <div className="grid grid-cols-6 gap-1">
          {mobileTabs.map((item) => {
            const Icon = item.icon
            return (
              <NavLink
                key={item.to}
                to={item.to}
                className={({ isActive }) =>
                  cn(
                    "relative flex min-h-[48px] flex-col items-center justify-center rounded-xl px-1 py-2 text-[11px] font-semibold transition",
                    isActive ? "text-ink" : "text-slate",
                  )
                }
              >
                {({ isActive }) => (
                  <>
                    {isActive ? (
                      <motion.span
                        layoutId="mobile-active-route"
                        className="absolute inset-0 rounded-xl bg-slate/10"
                        transition={{ type: "spring", duration: 0.35 }}
                      />
                    ) : null}
                    <span className="relative flex flex-col items-center">
                      <Icon className="mb-1 h-4 w-4" />
                      {item.label}
                    </span>
                  </>
                )}
              </NavLink>
            )
          })}
        </div>
      </nav>

      <div className="fixed bottom-20 right-4 z-50 md:hidden">
        <button
          type="button"
          onClick={() => setQuickActionsOpen((prev) => !prev)}
          className="flex h-14 w-14 items-center justify-center rounded-full bg-ink text-white shadow-panel"
          aria-label="Quick actions"
        >
          {quickActionsOpen ? <X className="h-5 w-5" /> : <Plus className="h-5 w-5" />}
        </button>
      </div>

      <AnimatePresence>
        {quickActionsOpen ? (
          <motion.div
            className="fixed inset-0 z-50 bg-ink/35 md:hidden"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={() => setQuickActionsOpen(false)}
          >
            <motion.div
              className="absolute bottom-0 left-0 right-0 rounded-t-3xl border border-white/70 bg-white p-5"
              initial={{ y: "100%" }}
              animate={{ y: 0 }}
              exit={{ y: "100%" }}
              transition={{ type: "spring", damping: 28, stiffness: 260 }}
              onClick={(e) => e.stopPropagation()}
            >
              <h3 className="font-display text-lg font-bold text-ink">Quick Actions</h3>
              <p className="mt-1 text-sm text-slate">Fast mobile shortcuts</p>
              <div className="mt-4 grid grid-cols-2 gap-2">
                <button type="button" className="min-h-[48px] rounded-xl bg-ink px-3 text-sm font-semibold text-white" onClick={() => navigate("/trade/new")}>
                  New Trade
                </button>
                <button type="button" className="min-h-[48px] rounded-xl border border-mist px-3 text-sm font-semibold text-ink" onClick={() => navigate("/journal")}>
                  Journal Entry
                </button>
                <button type="button" className="min-h-[48px] rounded-xl border border-mist px-3 text-sm font-semibold text-ink" onClick={() => void refresh()}>
                  Refresh
                </button>
                <button type="button" className="min-h-[48px] rounded-xl border border-mist px-3 text-sm font-semibold text-ink" onClick={() => navigate("/portfolio")}>
                  Portfolio
                </button>
              </div>
            </motion.div>
          </motion.div>
        ) : null}
      </AnimatePresence>

      <AnimatePresence>
        {showOnboarding ? (
          <motion.div className="fixed inset-0 z-[60] bg-ink/60 p-4" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
            <div className="mx-auto mt-20 max-w-md rounded-2xl bg-white p-5 shadow-panel">
              <div className="mb-3 inline-flex rounded-xl bg-ink/10 p-2 text-ink">
                <Sparkles className="h-5 w-5" />
              </div>
              <h2 className="font-display text-2xl font-bold text-ink">First-Time Tour</h2>
              <p className="mt-1 text-xs font-semibold uppercase tracking-[0.12em] text-slate">Step {onboardingStep + 1} of 4</p>

              {onboardingStep === 0 ? (
                <p className="mt-3 text-sm text-ink">Welcome. This workspace helps you journal and analyze trades with a single workflow.</p>
              ) : null}
              {onboardingStep === 1 ? (
                <p className="mt-3 text-sm text-ink">
                  <span className="font-semibold">Plan</span>: capture entry logic, risk, and target before execution.
                </p>
              ) : null}
              {onboardingStep === 2 ? (
                <p className="mt-3 text-sm text-ink">
                  <span className="font-semibold">Execute</span>: log real fills, quantity, and broker details.
                </p>
              ) : null}
              {onboardingStep === 3 ? (
                <p className="mt-3 text-sm text-ink">
                  <span className="font-semibold">Review</span>: close trade, capture MAE/MFE, mistakes, and lessons.
                </p>
              ) : null}

              <div className="mt-4 flex flex-wrap justify-end gap-2">
                {onboardingStep === 3 ? (
                  <button
                    type="button"
                    className="min-h-[44px] rounded-xl border border-mist px-4 text-sm font-semibold text-ink"
                    onClick={() => {
                      closeOnboarding()
                      navigate("/trade/new?tutorial=1")
                    }}
                  >
                    Start Tutorial Trade
                  </button>
                ) : null}
                {onboardingStep > 0 ? (
                  <button
                    type="button"
                    className="min-h-[44px] rounded-xl border border-mist px-4 text-sm font-semibold text-ink"
                    onClick={() => setOnboardingStep((step) => Math.max(0, step - 1))}
                  >
                    Back
                  </button>
                ) : null}
                {onboardingStep < 3 ? (
                  <button
                    type="button"
                    className="min-h-[44px] rounded-xl bg-ink px-4 text-sm font-semibold text-white"
                    onClick={() => setOnboardingStep((step) => Math.min(3, step + 1))}
                  >
                    Next
                  </button>
                ) : (
                  <button type="button" className="min-h-[44px] rounded-xl bg-ink px-4 text-sm font-semibold text-white" onClick={closeOnboarding}>
                    Finish
                  </button>
                )}
              </div>
            </div>
          </motion.div>
        ) : null}
      </AnimatePresence>

      <AnimatePresence>
        {showShortcuts ? (
          <motion.div className="fixed inset-0 z-[70] bg-ink/55 p-4" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
            <div className="mx-auto mt-24 max-w-sm rounded-2xl bg-white p-5 shadow-panel">
              <h3 className="font-display text-xl font-bold text-ink">Keyboard Shortcuts</h3>
              <div className="mt-3 space-y-2 text-sm">
                {shortcutItems.map((item) => (
                  <div key={item.key} className="flex items-center justify-between rounded-lg border border-mist/70 px-3 py-2">
                    <span className="text-slate">{item.action}</span>
                    <kbd className="rounded border border-mist bg-slate/10 px-2 py-0.5 font-mono text-xs text-ink">{item.key}</kbd>
                  </div>
                ))}
              </div>
              <div className="mt-4 flex justify-end">
                <button type="button" className="min-h-[44px] rounded-xl border border-mist px-4 text-sm font-semibold text-ink" onClick={() => setShowShortcuts(false)}>
                  Close
                </button>
              </div>
            </div>
          </motion.div>
        ) : null}
      </AnimatePresence>

      <AnimatePresence>
        {showCommand ? (
          <motion.div className="fixed inset-0 z-[70] bg-ink/55 p-4" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
            <div className="mx-auto mt-20 max-w-xl rounded-2xl bg-white p-4 shadow-panel">
              <input
                autoFocus
                value={commandQuery}
                onChange={(e) => setCommandQuery(e.target.value)}
                placeholder="Type to search routes..."
                className="h-11 w-full rounded-xl border border-mist px-3 text-sm text-ink focus:border-ink/40 focus:outline-none"
              />
              <div className="mt-3 max-h-72 overflow-auto">
                {filteredCommands.map((item) => (
                  <button
                    key={item.path}
                    type="button"
                    className="mb-1 flex w-full items-center justify-between rounded-lg px-3 py-2 text-left text-sm hover:bg-slate/10"
                    onClick={() => {
                      navigate(item.path)
                      setShowCommand(false)
                      setCommandQuery("")
                    }}
                  >
                    <span className="font-semibold text-ink">{item.label}</span>
                    <span className="text-xs text-slate">{item.path}</span>
                  </button>
                ))}
                {filteredCommands.length === 0 ? <p className="px-2 py-3 text-sm text-slate">No matching routes.</p> : null}
              </div>
              <div className="mt-3 flex justify-end">
                <button
                  type="button"
                  className="min-h-[40px] rounded-xl border border-mist px-4 text-sm font-semibold text-ink"
                  onClick={() => {
                    setShowCommand(false)
                    setCommandQuery("")
                  }}
                >
                  Close
                </button>
              </div>
            </div>
          </motion.div>
        ) : null}
      </AnimatePresence>
    </div>
  )
}
