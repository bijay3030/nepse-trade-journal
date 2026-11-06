require "rails_helper"

RSpec.describe Scans::Crossovers do
  def series(closes)
    { dates: closes.each_index.map { Date.new(2026, 1, 1) + _1 }, close: closes,
      ema9: Indicators::Trend.ema(closes, 9), ema21: Indicators::Trend.ema(closes, 21), ema50: Indicators::Trend.ema(closes, 50),
      hma: Indicators::Trend.hma(closes, 21), alma: Indicators::Trend.alma(closes, 9),
      aroon_up: Array.new(closes.size), aroon_down: Array.new(closes.size) }
  end

  # 60 sessions falling from 160 to 101, then 6 sessions rising.
  let(:turn) { series(Array.new(60) { 160.0 - _1 } + Array.new(6) { 105.0 + _1 * 4 }) }

  it "reports how many sessions ago a signal began, and nil when it doesn't hold" do
    expect(described_class.latest_age(turn, "alma_cross")).to be_between(0, 5)
    expect(described_class.latest_age(turn, "hma_up")).to be_between(0, 5)
    expect(described_class.latest_age(turn, "ema_21_50")).to be_nil # the slower averages haven't crossed yet
    expect(described_class.latest_age(series(Array.new(80) { 200.0 - _1 }), "ema_stack")).to be_nil
  end

  it "counts a run that held since the indicators began, but no onset for it" do
    rising = series(Array.new(80) { 100.0 + _1 })

    # EMA 50 has its first value on bar 49; the stack holds from then to bar 79.
    expect(described_class.latest_age(rising, "ema_stack")).to eq(30)
    expect(described_class.onsets(rising, "ema_stack")).to be_empty # not a signal event for the backtest
  end

  it "counts an onset when the condition switches on after being off" do
    v = series(Array.new(60) { 160.0 - _1 } + Array.new(40) { 101.0 + _1 * 3 })
    onset = described_class.onsets(v, "ema_9_21")

    expect(onset.size).to eq(1)
    expect(described_class.latest_age(v, "ema_9_21")).to eq(99 - onset.first)
  end

  it "scans stored prices for completed sessions with each stock's latest snapshot" do
    stock = create(:stock, symbol: "RISE", security_type: "Equity")
    days = (1..90).map { Date.new(2026, 6, 1) + _1 }
    days.each_with_index { |day, i| create(:stock_daily_price, stock: stock, traded_on: day, close_price: 100 + i, high_price: 101 + i, low_price: 99 + i) }
    StockSetupSnapshot.create!(stock: stock, traded_on: days.last, close_price: 189, zone_state: "in_zone", readiness_score: 77, in_buy_zone: true)

    result = described_class.call(now: Time.zone.parse("2026-09-30 12:00"))

    row = result[:rows].sole
    expect(row).to include(symbol: "RISE", close: 189.0, readiness: 77, in_buy_zone: true)
    expect(row[:signals]).to include("ema_stack" => Integer, "aroon_strong" => Integer, "hma_up" => Integer)
    expect(row[:values][:aroon_up]).to eq(100.0)
    expect(result[:as_of]).to eq(days.last)
  end

  it "lists each run of a signal: where it began, where it ended and the change in between" do
    # Down, up, down, up: the 9/21 cross happens twice; the second run is still on.
    closes = Array.new(40) { 200.0 - _1 } + Array.new(25) { 161.0 + _1 * 2 } + Array.new(25) { 209.0 - _1 * 2 } + Array.new(20) { 161.0 + _1 * 3 }
    v = series(closes)
    episodes = described_class.episodes(v, "ema_9_21")

    expect(episodes.size).to eq(2)
    expect(episodes.first).to include(open: false, end_on: be_a(Date), end_price: be_a(Float))
    expect(episodes.first[:sessions]).to eq(described_class.ends(v, "ema_9_21").first - described_class.onsets(v, "ema_9_21").first)
    expect(episodes.last).to include(open: true, end_on: nil)
    expect(episodes.last[:change_pct]).to be_positive
  end

  it "builds a stock's chart: candles, indicator lines and episodes" do
    stock = create(:stock, symbol: "RISE", security_type: "Equity")
    (1..90).each { |i| create(:stock_daily_price, stock: stock, traded_on: Date.new(2026, 6, 1) + i, open_price: 99 + i, close_price: 100 + i, high_price: 101 + i, low_price: 98 + i, volume: 1000) }

    chart = described_class.chart(stock, now: Time.zone.parse("2026-09-30 12:00"))

    expect(chart[:candles].size).to eq(90)
    expect(chart[:candles].last).to include(close: 190.0, open: 189.0, volume: 1000)
    expect(chart[:lines][:ema9].size).to eq(90)
    expect(chart[:lines][:ema50].compact.size).to eq(41)
    expect(chart[:episodes].keys).to match_array(described_class::SIGNALS)
    expect(described_class.chart(create(:stock), now: Time.current)).to be_nil
  end
end
