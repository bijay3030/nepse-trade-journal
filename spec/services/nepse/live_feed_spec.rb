require "rails_helper"

RSpec.describe Nepse::LiveFeed do
  let(:zone) { ActiveSupport::TimeZone["Asia/Kathmandu"] }
  let(:open_time) { zone.parse("2026-11-23 12:40") } # Monday, market open
  let(:today) { Date.new(2026, 11, 23) }
  let(:memory) { ActiveSupport::Cache::MemoryStore.new }

  before { allow(Rails).to receive(:cache).and_return(memory) }

  def response(day: today, as_of: open_time - 2.minutes, price: 550.0, success: true)
    { success: success, as_of: as_of, rows: [ { symbol: "NABIL", last_price: price, traded_on: day } ] }
  end

  def source(name, answer) = [ name, double(fetch: answer) ]

  it "takes the first source with today's prices updated in the last 15 minutes" do
    pick = described_class.pick(now: open_time, sources: [ source(:live, response), source(:summary, response) ])
    expect(pick).to include(fresh: true, source: :live)
  end

  it "skips a source showing another day, an old time stamp or an error, and says why" do
    pick = described_class.pick(now: open_time, sources: [
      source(:live, response(as_of: open_time - 40.minutes)),
      source(:summary, response(day: today - 3, as_of: nil)),
      source(:other, response(success: false).merge(error: { message: "HTTP 503" }))
    ])
    expect(pick[:fresh]).to be(false)
    expect(pick[:reasons]).to eq(live: "last updated 12:00", summary: "prices are for 2026-11-20, not today", other: "unavailable: HTTP 503")
  end

  it "treats prices that haven't changed for 15 minutes as stale, even with a fresh time stamp" do
    expect(described_class.pick(now: open_time, sources: [ source(:live, response) ])).to include(fresh: true)
    expect(described_class.pick(now: open_time + 10.minutes, sources: [ source(:live, response(as_of: open_time + 9.minutes)) ])).to include(fresh: true)
    stale = described_class.pick(now: open_time + 20.minutes, sources: [ source(:live, response(as_of: open_time + 19.minutes)) ])
    expect(stale).to include(fresh: false, reasons: { live: "prices unchanged since 12:40" })
    expect(described_class.pick(now: open_time + 25.minutes, sources: [ source(:live, response(as_of: open_time + 24.minutes, price: 551.0)) ])).to include(fresh: true)
  end

  it "accepts today's prices after the close without time checks (the closing run)" do
    after_close = zone.parse("2026-11-23 16:00")
    expect(described_class.pick(now: after_close, sources: [ source(:summary, response(as_of: nil)) ])).to include(fresh: true)
  end

  it "records the status, keeping when the current state began" do
    described_class.record(state: "live", now: open_time, source: :live, as_of: open_time)
    described_class.record(state: "delayed", now: open_time + 20.minutes, reasons: { live: "x" })
    described_class.record(state: "delayed", now: open_time + 25.minutes, reasons: { live: "x" })

    allow(Nepse::MarketHours).to receive(:sync_window?).and_return(true)
    expect(described_class.status).to include(state: "delayed", since: open_time + 20.minutes, last_live_at: open_time)
    allow(Nepse::MarketHours).to receive(:sync_window?).and_return(false)
    expect(described_class.status).to include(state: "closed", last_live_at: open_time)
  end
end
