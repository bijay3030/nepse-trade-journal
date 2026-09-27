import { useEffect, useMemo, useState } from "react"
import { useQuery, useQueryClient } from "@tanstack/react-query"
import {
  addDays,
  eachDayOfInterval,
  endOfWeek,
  format,
  isSameDay,
  parseISO,
  startOfDay,
  startOfWeek,
  subDays,
  subWeeks,
} from "date-fns"
import { CalendarDays, FileDown, Mic, MicOff, Search } from "lucide-react"
import { Badge, Button, Card, CardBody, CardHeader, LoadingSpinner, Textarea } from "../components/ui"
import { useIsMobile } from "../hooks/useIsMobile"
import { usePullToRefresh } from "../hooks/usePullToRefresh"

type Emotion = "😌" | "😎" | "😰" | "🤩" | "😱" | "😤"

type JournalEntry = {
  id: string
  date: string
  marketCommentary: string
  emotion: Emotion
  disciplineScore: number
  tradesPlanned: number
  tradesTaken: number
  dayPnl: number
  lessonsLearned: string
  tomorrowsPlan: string
  tags: string[]
  createdAt: string
}

type WeeklyReview = {
  period: string
  trades: number
  pnl: number
  winRate: number
  mistakes: string[]
  moodTrend: string
}

const STORAGE_KEY = "journal_entries_v1"
const DEFAULT_EMOTION: Emotion = "😌"
const EMOTIONS: Emotion[] = ["😌", "😎", "😰", "🤩", "😱", "😤"]

function parseTags(...texts: string[]) {
  const matches = texts.flatMap((text) => (text.match(/#[a-zA-Z0-9_]+/g) ?? []).map((tag) => tag.toLowerCase()))
  return Array.from(new Set(matches))
}

function toNumber(value: string) {
  const n = Number(value)
  return Number.isFinite(n) ? n : 0
}

function pnlHeatColor(value: number) {
  const intensity = Math.min(1, Math.abs(value) / 5000)
  if (value > 0) return `rgba(24, 116, 90, ${0.12 + intensity * 0.65})`
  if (value < 0) return `rgba(255, 107, 44, ${0.12 + intensity * 0.65})`
  return "rgba(31, 45, 66, 0.08)"
}

function weekdayName(d: Date) {
  return format(d, "EEE")
}

function inferMoodTrend(entries: JournalEntry[]) {
  if (entries.length < 2) return "Insufficient data"
  const recent = entries.slice(0, Math.min(5, entries.length))
  const optimistic = recent.filter((e) => ["😌", "😎", "🤩"].includes(e.emotion)).length
  const stressed = recent.filter((e) => ["😰", "😱", "😤"].includes(e.emotion)).length
  if (optimistic > stressed) return "Improving confidence"
  if (stressed > optimistic) return "Rising stress markers"
  return "Emotionally balanced"
}

function detectPatterns(entries: JournalEntry[]) {
  if (entries.length === 0) {
    return {
      bestDay: "No pattern yet",
      emotionCorrelation: "No correlation yet",
      disciplineTrend: "No trend yet",
    }
  }

  const byWeekday = new Map<number, { pnl: number; count: number }>()
  entries.forEach((entry) => {
    const day = parseISO(entry.date).getDay()
    const curr = byWeekday.get(day) ?? { pnl: 0, count: 0 }
    byWeekday.set(day, { pnl: curr.pnl + entry.dayPnl, count: curr.count + 1 })
  })

  const best = Array.from(byWeekday.entries())
    .map(([day, agg]) => ({ day, avg: agg.pnl / agg.count }))
    .sort((a, b) => b.avg - a.avg)[0]

  const bestDay = best ? `You trade best on ${format(addDays(startOfWeek(new Date()), best.day), "EEEE")}` : "No pattern yet"

  const emotionalMap = new Map<Emotion, { pnl: number; count: number }>()
  entries.forEach((entry) => {
    const curr = emotionalMap.get(entry.emotion) ?? { pnl: 0, count: 0 }
    emotionalMap.set(entry.emotion, { pnl: curr.pnl + entry.dayPnl, count: curr.count + 1 })
  })

  const bestEmotion = Array.from(emotionalMap.entries())
    .map(([emotion, agg]) => ({ emotion, avg: agg.pnl / agg.count }))
    .sort((a, b) => b.avg - a.avg)[0]

  const emotionCorrelation = bestEmotion
    ? `Best P&L when mood is ${bestEmotion.emotion} (avg Rs. ${Math.round(bestEmotion.avg).toLocaleString()})`
    : "No correlation yet"

  const sorted = [...entries].sort((a, b) => a.date.localeCompare(b.date))
  const firstHalf = sorted.slice(0, Math.floor(sorted.length / 2))
  const secondHalf = sorted.slice(Math.floor(sorted.length / 2))
  const avg = (arr: JournalEntry[]) => (arr.length ? arr.reduce((acc, e) => acc + e.disciplineScore, 0) / arr.length : 0)
  const trendDelta = avg(secondHalf) - avg(firstHalf)
  const disciplineTrend =
    trendDelta > 0.6
      ? "Discipline trend: improving"
      : trendDelta < -0.6
        ? "Discipline trend: deteriorating"
        : "Discipline trend: stable"

  return { bestDay, emotionCorrelation, disciplineTrend }
}

function buildWeeklyReview(entries: JournalEntry[]): WeeklyReview {
  const start = subDays(startOfDay(new Date()), 6)
  const week = entries.filter((entry) => parseISO(entry.date) >= start)
  const trades = week.reduce((acc, e) => acc + e.tradesTaken, 0)
  const pnl = week.reduce((acc, e) => acc + e.dayPnl, 0)
  const wins = week.filter((entry) => entry.dayPnl > 0).length
  const winRate = week.length ? (wins / week.length) * 100 : 0

  const mistakes = Array.from(
    new Set(
      week
        .flatMap((entry) => [...entry.tags, ...parseTags(entry.lessonsLearned)])
        .filter((tag) => tag.includes("mistake") || tag.includes("fomo") || tag.includes("overtrade")),
    ),
  )

  return {
    period: `${format(start, "MMM dd")} - ${format(new Date(), "MMM dd, yyyy")}`,
    trades,
    pnl,
    winRate,
    mistakes: mistakes.length ? mistakes : ["No recurring tagged mistakes"],
    moodTrend: inferMoodTrend(week),
  }
}

async function exportWeeklyReviewPdf(review: WeeklyReview) {
  const { jsPDF } = await import("jspdf")
  const doc = new jsPDF()

  doc.setFontSize(18)
  doc.text("Weekly Trading Review", 14, 18)
  doc.setFontSize(11)
  doc.text(`Period: ${review.period}`, 14, 28)

  doc.text(`Trades: ${review.trades}`, 14, 40)
  doc.text(`P&L: Rs. ${Math.round(review.pnl).toLocaleString()}`, 14, 48)
  doc.text(`Win Rate: ${review.winRate.toFixed(1)}%`, 14, 56)
  doc.text(`Mood Trend: ${review.moodTrend}`, 14, 64)

  doc.text("Mistakes:", 14, 76)
  review.mistakes.forEach((mistake, idx) => {
    doc.text(`- ${mistake}`, 18, 84 + idx * 8)
  })

  doc.save(`weekly-review-${format(new Date(), "yyyy-MM-dd")}.pdf`)
}

export function JournalPage() {
  const queryClient = useQueryClient()
  const [view, setView] = useState<"list" | "calendar">("list")
  const [expandedId, setExpandedId] = useState<string | null>(null)
  const [search, setSearch] = useState("")
  const [isListening, setIsListening] = useState(false)
  const [review, setReview] = useState<WeeklyReview | null>(null)
  const isMobile = useIsMobile()

  const [form, setForm] = useState({
    date: format(new Date(), "yyyy-MM-dd"),
    marketCommentary: "",
    emotion: DEFAULT_EMOTION,
    disciplineScore: 6,
    tradesPlanned: 0,
    tradesTaken: 0,
    dayPnl: 0,
    lessonsLearned: "",
    tomorrowsPlan: "",
  })

  const { data: entries = [], isLoading } = useQuery({
    queryKey: ["journal-entries"],
    queryFn: async () => {
      const raw = localStorage.getItem(STORAGE_KEY)
      if (!raw) return [] as JournalEntry[]
      return (JSON.parse(raw) as JournalEntry[]).sort((a, b) => b.date.localeCompare(a.date))
    },
    staleTime: Infinity,
  })

  const { pullDistance, isRefreshing } = usePullToRefresh({
    enabled: isMobile,
    onRefresh: () => queryClient.invalidateQueries({ queryKey: ["journal-entries"] }),
  })

  useEffect(() => {
    if (!isListening) return

    const SpeechRecognition =
      (window as unknown as { SpeechRecognition?: new () => any; webkitSpeechRecognition?: new () => any }).SpeechRecognition ??
      (window as unknown as { webkitSpeechRecognition?: new () => any }).webkitSpeechRecognition

    if (!SpeechRecognition) {
      setIsListening(false)
      return
    }

    const recognition = new SpeechRecognition()
    recognition.lang = "en-US"
    recognition.interimResults = true
    recognition.continuous = true

    recognition.onresult = (event: any) => {
      let finalTranscript = ""
      for (let i = event.resultIndex; i < event.results.length; i += 1) {
        finalTranscript += event.results[i][0]?.transcript ?? ""
      }
      setForm((prev) => ({ ...prev, marketCommentary: `${prev.marketCommentary} ${finalTranscript}`.trim() }))
    }

    recognition.onerror = () => setIsListening(false)
    recognition.onend = () => setIsListening(false)

    recognition.start()
    return () => recognition.stop()
  }, [isListening])

  const filteredEntries = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return entries

    return entries.filter((entry) => {
      const text = [
        entry.marketCommentary,
        entry.lessonsLearned,
        entry.tomorrowsPlan,
        entry.tags.join(" "),
      ]
        .join(" ")
        .toLowerCase()
      return text.includes(q)
    })
  }, [entries, search])

  const patterns = useMemo(() => detectPatterns(entries), [entries])

  const calendarDays = useMemo(() => {
    const end = endOfWeek(new Date(), { weekStartsOn: 0 })
    const start = startOfWeek(subWeeks(end, 11), { weekStartsOn: 0 })
    return eachDayOfInterval({ start, end })
  }, [])

  const byDate = useMemo(() => {
    const map = new Map<string, JournalEntry>()
    entries.forEach((entry) => map.set(entry.date, entry))
    return map
  }, [entries])

  const saveEntry = () => {
    const tags = parseTags(form.marketCommentary, form.lessonsLearned, form.tomorrowsPlan)
    const next: JournalEntry = {
      id: crypto.randomUUID(),
      date: form.date,
      marketCommentary: form.marketCommentary.trim(),
      emotion: form.emotion,
      disciplineScore: form.disciplineScore,
      tradesPlanned: form.tradesPlanned,
      tradesTaken: form.tradesTaken,
      dayPnl: form.dayPnl,
      lessonsLearned: form.lessonsLearned.trim(),
      tomorrowsPlan: form.tomorrowsPlan.trim(),
      tags,
      createdAt: new Date().toISOString(),
    }

    const nextEntries = [next, ...entries.filter((entry) => !isSameDay(parseISO(entry.date), parseISO(next.date)))]
      .sort((a, b) => b.date.localeCompare(a.date))

    localStorage.setItem(STORAGE_KEY, JSON.stringify(nextEntries))
    queryClient.setQueryData(["journal-entries"], nextEntries)

    setForm((prev) => ({
      ...prev,
      marketCommentary: "",
      lessonsLearned: "",
      tomorrowsPlan: "",
    }))
  }

  const generateWeekly = () => {
    setReview(buildWeeklyReview(entries))
  }

  return (
    <div className="grid gap-5 xl:grid-cols-3">
      <Card className="xl:col-span-2">
        <CardHeader title="Trading Journal" subtitle="Daily reflection, emotion tracking, and execution review" />
        <CardBody>
          <div className="grid gap-3 md:grid-cols-2">
            <label className="block text-sm font-semibold text-slate">
              Date
              <input
                type="date"
                value={form.date}
                onChange={(e) => setForm((prev) => ({ ...prev, date: e.target.value }))}
                className="mt-1 h-11 w-full rounded-xl border border-mist bg-white px-3 text-sm text-ink"
              />
            </label>

            <div className="flex items-end gap-2">
              <Button
                variant={isListening ? "secondary" : "ghost"}
                className="h-11"
                onClick={() => setIsListening((prev) => !prev)}
                type="button"
              >
                {isListening ? <MicOff className="mr-2 h-4 w-4" /> : <Mic className="mr-2 h-4 w-4" />}
                {isListening ? "Stop Voice" : "Voice Input"}
              </Button>
              <p className="text-xs text-slate/80">Optional voice-to-text for commentary</p>
            </div>
          </div>

          <div className="mt-3 space-y-3">
            <Textarea
              placeholder="Market commentary... include #tags like #breakout #mistake"
              value={form.marketCommentary}
              onChange={(e) => setForm((prev) => ({ ...prev, marketCommentary: e.target.value }))}
            />

            <div>
              <p className="mb-2 text-sm font-semibold text-slate">Emotional state</p>
              <div className="flex flex-wrap gap-2">
                {EMOTIONS.map((emotion) => (
                  <button
                    key={emotion}
                    type="button"
                    onClick={() => setForm((prev) => ({ ...prev, emotion }))}
                    className={
                      form.emotion === emotion
                        ? "rounded-xl bg-ink px-3 py-2 text-lg text-white"
                        : "rounded-xl border border-mist bg-white px-3 py-2 text-lg"
                    }
                  >
                    {emotion}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <div className="mb-1 flex items-center justify-between text-sm font-semibold text-slate">
                <span>Discipline Score</span>
                <span>{form.disciplineScore}/10</span>
              </div>
              <input
                type="range"
                min={1}
                max={10}
                value={form.disciplineScore}
                onChange={(e) => setForm((prev) => ({ ...prev, disciplineScore: toNumber(e.target.value) }))}
                className="w-full"
              />
            </div>

            <div className="grid gap-3 sm:grid-cols-3">
              <label className="text-sm font-semibold text-slate">
                Trades planned
                <input
                  type="number"
                  min={0}
                  value={form.tradesPlanned}
                  onChange={(e) => setForm((prev) => ({ ...prev, tradesPlanned: toNumber(e.target.value) }))}
                  className="mt-1 h-11 w-full rounded-xl border border-mist bg-white px-3 text-sm text-ink"
                />
              </label>
              <label className="text-sm font-semibold text-slate">
                Trades taken
                <input
                  type="number"
                  min={0}
                  value={form.tradesTaken}
                  onChange={(e) => setForm((prev) => ({ ...prev, tradesTaken: toNumber(e.target.value) }))}
                  className="mt-1 h-11 w-full rounded-xl border border-mist bg-white px-3 text-sm text-ink"
                />
              </label>
              <label className="text-sm font-semibold text-slate">
                Day P&L (Rs)
                <input
                  type="number"
                  value={form.dayPnl}
                  onChange={(e) => setForm((prev) => ({ ...prev, dayPnl: toNumber(e.target.value) }))}
                  className="mt-1 h-11 w-full rounded-xl border border-mist bg-white px-3 text-sm text-ink"
                />
              </label>
            </div>

            <Textarea
              placeholder="Lessons learned... #mistake #fomo"
              value={form.lessonsLearned}
              onChange={(e) => setForm((prev) => ({ ...prev, lessonsLearned: e.target.value }))}
            />
            <Textarea
              placeholder="Tomorrow's plan..."
              value={form.tomorrowsPlan}
              onChange={(e) => setForm((prev) => ({ ...prev, tomorrowsPlan: e.target.value }))}
            />
          </div>

          <div className="mt-4 flex flex-wrap gap-2">
            <Button onClick={saveEntry}>Save Journal Entry</Button>
            <Button variant="secondary" onClick={generateWeekly}>
              Generate Weekly Review
            </Button>
            {review ? (
              <Button variant="ghost" onClick={() => exportWeeklyReviewPdf(review)}>
                <FileDown className="mr-2 h-4 w-4" />
                Export PDF
              </Button>
            ) : null}
          </div>
        </CardBody>
      </Card>

      <Card>
        <CardHeader title="Insights" subtitle="Pattern detection from your entries" />
        <CardBody className="space-y-3">
          <div className="rounded-xl border border-mist/70 bg-white/80 p-3">
            <p className="text-sm font-semibold text-ink">{patterns.bestDay}</p>
          </div>
          <div className="rounded-xl border border-mist/70 bg-white/80 p-3">
            <p className="text-sm font-semibold text-ink">{patterns.emotionCorrelation}</p>
          </div>
          <div className="rounded-xl border border-mist/70 bg-white/80 p-3">
            <p className="text-sm font-semibold text-ink">{patterns.disciplineTrend}</p>
          </div>

          {review ? (
            <div className="rounded-xl border border-ink/20 bg-ink/5 p-3">
              <p className="text-sm font-semibold text-ink">Weekly Review ({review.period})</p>
              <ul className="mt-2 space-y-1 text-sm text-slate">
                <li>Trades: {review.trades}</li>
                <li>P&L: Rs. {Math.round(review.pnl).toLocaleString()}</li>
                <li>Win rate: {review.winRate.toFixed(1)}%</li>
                <li>Mood trend: {review.moodTrend}</li>
              </ul>
              <div className="mt-2 flex flex-wrap gap-1">
                {review.mistakes.map((m) => (
                  <Badge key={m} variant="neutral">
                    {m}
                  </Badge>
                ))}
              </div>
            </div>
          ) : (
            <p className="text-xs text-slate/75">Generate weekly review to see stats and export PDF.</p>
          )}
        </CardBody>
      </Card>

      <Card className="xl:col-span-3">
        <CardHeader
          title="Journal Archive"
          subtitle="Toggle between list and calendar heatmap; search full text and #hashtags"
        />
        <CardBody>
          <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
            <div className="flex gap-2">
              <Button variant={view === "list" ? "primary" : "ghost"} onClick={() => setView("list")}>List</Button>
              <Button variant={view === "calendar" ? "primary" : "ghost"} onClick={() => setView("calendar")}>
                <CalendarDays className="mr-2 h-4 w-4" />
                Calendar
              </Button>
            </div>

            <label className="relative flex w-full max-w-sm items-center">
              <Search className="pointer-events-none absolute left-3 h-4 w-4 text-slate/60" />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search entries, notes, #tags"
                className="h-11 w-full rounded-xl border border-mist bg-white pl-9 pr-3 text-sm"
              />
            </label>
          </div>

          {isMobile ? (
            <p className="mb-2 text-xs font-semibold text-slate/75">
              {isRefreshing ? "Refreshing..." : pullDistance > 8 ? "Pull to refresh..." : ""}
            </p>
          ) : null}

          {isLoading ? (
            <div className="flex h-40 items-center justify-center">
              <LoadingSpinner />
            </div>
          ) : view === "calendar" ? (
            <div>
              <div className="mb-2 grid grid-cols-7 gap-1 text-center text-[11px] font-semibold uppercase tracking-[0.12em] text-slate/70">
                {Array.from({ length: 7 }, (_, i) => weekdayName(addDays(startOfWeek(new Date(), { weekStartsOn: 0 }), i))).map((d) => (
                  <span key={d}>{d}</span>
                ))}
              </div>
              <div className="grid grid-cols-7 gap-1">
                {calendarDays.map((day) => {
                  const key = format(day, "yyyy-MM-dd")
                  const entry = byDate.get(key)
                  return (
                    <button
                      key={key}
                      type="button"
                      onClick={() => entry && setExpandedId((prev) => (prev === entry.id ? null : entry.id))}
                      className="h-10 rounded-md border border-white/60 text-[10px] font-semibold"
                      style={{ background: pnlHeatColor(entry?.dayPnl ?? 0) }}
                      title={entry ? `${key} | Rs. ${entry.dayPnl}` : key}
                    >
                      {format(day, "d")}
                    </button>
                  )
                })}
              </div>
            </div>
          ) : (
            <div className="space-y-2">
              {filteredEntries.map((entry) => {
                const expanded = expandedId === entry.id
                return (
                  <div key={entry.id} className="rounded-xl border border-mist/70 bg-white/80 p-3">
                    <button
                      type="button"
                      onClick={() => setExpandedId((prev) => (prev === entry.id ? null : entry.id))}
                      className="flex w-full items-center justify-between gap-2 text-left"
                    >
                      <div>
                        <p className="font-display text-lg font-bold text-ink">{format(parseISO(entry.date), "EEE, MMM dd yyyy")}</p>
                        <p className="text-sm text-slate">
                          {entry.emotion} · Discipline {entry.disciplineScore}/10 · P&L Rs. {Math.round(entry.dayPnl).toLocaleString()}
                        </p>
                        <p className="mt-1 text-sm text-slate/85 line-clamp-2">{entry.marketCommentary || "No commentary"}</p>
                      </div>
                      <span className="text-xs font-semibold text-ink/70">{expanded ? "Collapse" : "Expand"}</span>
                    </button>

                    {expanded ? (
                      <div className="mt-3 grid gap-3 md:grid-cols-2">
                        <div>
                          <p className="text-xs font-semibold uppercase tracking-[0.12em] text-slate/70">Market Commentary</p>
                          <p className="mt-1 text-sm text-ink">{entry.marketCommentary || "-"}</p>
                        </div>
                        <div>
                          <p className="text-xs font-semibold uppercase tracking-[0.12em] text-slate/70">Lessons Learned</p>
                          <p className="mt-1 text-sm text-ink">{entry.lessonsLearned || "-"}</p>
                        </div>
                        <div>
                          <p className="text-xs font-semibold uppercase tracking-[0.12em] text-slate/70">Tomorrow's Plan</p>
                          <p className="mt-1 text-sm text-ink">{entry.tomorrowsPlan || "-"}</p>
                        </div>
                        <div>
                          <p className="text-xs font-semibold uppercase tracking-[0.12em] text-slate/70">Tags</p>
                          <div className="mt-1 flex flex-wrap gap-1">
                            {entry.tags.length > 0 ? (
                              entry.tags.map((tag) => (
                                <Badge key={tag} variant="neutral">
                                  {tag}
                                </Badge>
                              ))
                            ) : (
                              <span className="text-sm text-slate/75">No tags</span>
                            )}
                          </div>
                        </div>
                      </div>
                    ) : null}
                  </div>
                )
              })}

              {filteredEntries.length === 0 ? (
                <div className="rounded-xl border border-dashed border-mist/80 p-6 text-center text-sm text-slate">
                  No entries found for this search.
                </div>
              ) : null}
            </div>
          )}
        </CardBody>
      </Card>
    </div>
  )
}
