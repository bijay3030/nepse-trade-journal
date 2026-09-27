import { Card, CardBody, CardHeader } from "../components/ui"

const faqs = [
  {
    id: "pnl",
    q: "How is P&L calculated?",
    a: "Net P&L = (Exit Price - Entry Price) x Quantity - (Entry Fees + Exit Fees). Open trades show unrealized P&L using latest market price.",
  },
  {
    id: "mae-mfe",
    q: "What is MAE/MFE?",
    a: "MAE (Maximum Adverse Excursion) is the worst drawdown during the trade. MFE (Maximum Favorable Excursion) is the best unrealized gain reached before exit.",
  },
  {
    id: "stop-loss",
    q: "How to set good stop losses?",
    a: "Place stops where your setup is invalidated (structure break), not at arbitrary percentages. Keep risk per trade consistent and position-size from stop distance.",
  },
  {
    id: "nepse-hours",
    q: "NEPSE market hours reminder",
    a: "Market hours are Sunday to Thursday, 11:00 to 15:00 NPT. Real-time updates pause when market is closed.",
  },
]

export function HelpPage() {
  return (
    <div className="space-y-5">
      <Card>
        <CardHeader title="Help Center" subtitle="Guides, FAQ, and tutorials for better trade journaling." />
        <CardBody className="grid gap-3 md:grid-cols-2">
          <a id="workflow" className="rounded-xl border border-mist/70 bg-white/90 p-4" href="#workflow">
            <h3 className="font-display text-lg font-bold text-ink">Plan → Execute → Review</h3>
            <p className="mt-1 text-sm text-slate">Document setup, execution quality, and post-trade learning in one lifecycle.</p>
          </a>
          <a id="expectancy" className="rounded-xl border border-mist/70 bg-white/90 p-4" href="#expectancy">
            <h3 className="font-display text-lg font-bold text-ink">What is Expectancy?</h3>
            <p className="mt-1 text-sm text-slate">Expectancy is average P&L per trade over time. Positive expectancy means your process has edge.</p>
          </a>
          <a id="strategy-examples" className="rounded-xl border border-mist/70 bg-white/90 p-4 md:col-span-2" href="#strategy-examples">
            <h3 className="font-display text-lg font-bold text-ink">Strategy Explanations with Examples</h3>
            <p className="mt-1 text-sm text-slate">Turtle Breakout: buy 20-day high with volume. Support Bounce: buy confirmed rejection at key support. Sector Rotation: shift into leading sector strength.</p>
          </a>
        </CardBody>
      </Card>

      <Card>
        <CardHeader title="FAQ" />
        <CardBody className="space-y-3">
          {faqs.map((item) => (
            <article key={item.id} id={item.id} className="rounded-xl border border-mist/70 bg-white/90 p-4">
              <h4 className="font-semibold text-ink">{item.q}</h4>
              <p className="mt-1 text-sm text-slate">{item.a}</p>
            </article>
          ))}
        </CardBody>
      </Card>

      <Card>
        <CardHeader title="Video Tutorials" subtitle="Placeholder embeds for onboarding videos" />
        <CardBody className="grid gap-4 md:grid-cols-2">
          <div className="rounded-xl border border-mist/70 bg-white/90 p-3">
            <p className="mb-2 text-sm font-semibold text-ink">How to plan your first trade</p>
            <iframe
              className="aspect-video w-full rounded-lg"
              src="https://www.youtube.com/embed/dQw4w9WgXcQ"
              title="How to plan your first trade"
              loading="lazy"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
              allowFullScreen
            />
          </div>
          <div className="rounded-xl border border-mist/70 bg-white/90 p-3">
            <p className="mb-2 text-sm font-semibold text-ink">Understanding your analytics</p>
            <iframe
              className="aspect-video w-full rounded-lg"
              src="https://www.youtube.com/embed/ysz5S6PUM-U"
              title="Understanding your analytics"
              loading="lazy"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
              allowFullScreen
            />
          </div>
        </CardBody>
      </Card>
    </div>
  )
}
