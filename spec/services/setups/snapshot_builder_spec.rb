require "rails_helper"

RSpec.describe Setups::SnapshotBuilder do
  let(:day) { Date.new(2026, 9, 28) }
  let(:analysis) { instance_double(Stock::SetupAnalysis, summary: { symbol: "BANK", vcp_score: 80 }, detail: detail) }
  let(:detail) do
    { vcp: { setup_quality_score: 80, is_vcp_setup: true }, price_action: { confidence: 0.7, trend: "uptrend" } }
  end
  let(:context) { instance_double(Watchlist::MarketContext, regime: "neutral", nepse_return: 0.0, sector_returns: { "Commercial Banks" => 3.0 }) }

  def stock_with_history(symbol, closes, turnover: 5_050_000.0)
    stock = create(:stock, symbol: symbol, sector: "Commercial Banks")
    closes.each_with_index do |close, i|
      date = day - (closes.size - 1 - i)
      price = create(:stock_daily_price, stock: stock, traded_on: date, close_price: close, turnover: turnover)
      next unless i == closes.size - 1

      StockDailyIndicator.create!(stock: stock, stock_daily_price: price, traded_on: date, sma_50: close * 0.95, sma_150: close * 0.9,
                                  sma_200: close * 0.85, low_52w: close * 0.6, high_52w: close * 1.05)
    end
    StockDailyIndicator.create!(stock: stock, traded_on: day - 30, sma_200: closes.last * 0.8)
    stock
  end

  before do
    allow(MarketIndex::Overview).to receive(:new).and_return(instance_double(MarketIndex::Overview, call: { regime_status: "neutral" }))
    allow(Watchlist::MarketContext).to receive(:call).and_return(context)
    allow(Stock::SetupAnalysis).to receive(:new).and_return(analysis)
    allow(Watchlist::EntryZoneSuggester).to receive(:call) do |_stock, type, **|
      if type == "vcp"
        { success: true, levels: { entry_zone_low: 195.0, entry_zone_high: 205.0, invalidation_price: 180.0, target_price: 240.0, pivot_price: 195.0 } }
      else
        { success: false, error: "No #{type}" }
      end
    end
  end

  it "stores trend, relative strength, the zone and readiness for each stock" do
    leader = stock_with_history("BANK", Array.new(100) { |i| 100.0 + i * 1.0 }) # ends at 199, inside the zone
    stock_with_history("LAGGARD", Array.new(100) { 150.0 })

    result = described_class.call

    expect(result).to include(success: true, traded_on: day, stocks: 2, in_buy_zone: [ "BANK" ])
    snapshot = leader.setup_snapshots.find_by!(traded_on: day)
    expect(snapshot).to have_attributes(setup_type: "vcp", zone_state: "in_zone", trend_rules_passed: 7, rs_rating: 99, setup_quality: 80, in_buy_zone: true)
    # trend 30 + setup 20 (80% of 25) + neutral market 9 + sector 15 + no flow data 7
    expect(snapshot.readiness_score).to eq(30 + 20 + 9 + 15 + 7)
    expect(snapshot.flow_state).to eq("no_data")
    expect(snapshot.entry_zone_low.to_f).to eq(195.0)
    expect(snapshot.screener_row).to include("symbol" => "BANK")
    expect(snapshot.trend_checks.size).to eq(8)
    expect(snapshot).to have_attributes(guards: [], avg_turnover: 5_050_000, change_pct: 0.51)
  end

  it "keeps a qualifying chart off the board when a tradability guard fails" do
    thin = stock_with_history("THIN", Array.new(100) { |i| 100.0 + i * 1.0 }, turnover: 1_000_000)
    jump = stock_with_history("JUMP", Array.new(99) { |i| 100.0 + i * 0.7 } + [ 200.0 ]) # +18.6% into the zone (limit ±15%)

    result = described_class.call

    expect(result[:in_buy_zone]).to eq([])
    expect(thin.setup_snapshots.sole).to have_attributes(zone_state: "in_zone", guards: [ "thin_volume" ], in_buy_zone: false)
    expect(jump.setup_snapshots.sole).to have_attributes(zone_state: "in_zone", guards: [ "upper_circuit" ], in_buy_zone: false)
    expect(StockSetupSnapshot.held_back_by_guards.count).to eq(2)
  end

  it "stores the extension measures and holds back a stock 4+ ADR above its 50-day" do
    # A steady climb; the 50-day indicator far below the close makes it extended.
    leader = stock_with_history("RUN", Array.new(100) { |i| 100.0 + i * 1.0 })
    leader.daily_indicators.where(traded_on: day).update_all(sma_50: 150.0)

    described_class.call

    snapshot = leader.setup_snapshots.sole
    expect(snapshot.extension).to include("extension_adr" => be > 4, "flags" => include("extended"))
    expect(snapshot).to have_attributes(zone_state: "in_zone", in_buy_zone: false)
    expect(snapshot.guards).to include("extended")
  end

  it "marks a price below invalidation as failed and skips short histories" do
    create(:stock, symbol: "NEW").tap { |s| create(:stock_daily_price, stock: s, traded_on: day) }
    stock_with_history("DROP", Array.new(99) { 150.0 } + [ 170.0 ])

    result = described_class.call

    expect(result[:stocks]).to eq(1)
    expect(StockSetupSnapshot.joins(:stock).find_by!(stocks: { symbol: "DROP" }).zone_state).to eq("failed")
  end

  it "builds a past session from data up to that day only" do
    stock = stock_with_history("BANK", Array.new(100) { |i| 100.0 + i * 1.0 })
    later = day + 1
    create(:stock_daily_price, stock: stock, traded_on: later, close_price: 400.0) # a jump after the as-of date
    expect(Stock::SetupAnalysis).to receive(:new).with(stock, market: anything, as_of: day).and_return(analysis)

    result = described_class.call(as_of: day)

    expect(result[:traded_on]).to eq(day)
    snapshot = stock.setup_snapshots.sole
    expect(snapshot).to have_attributes(traded_on: day, close_price: 199.0, zone_state: "in_zone")
  end

  it "only counts a support pullback for a stock with an RS rating of 70 or more" do
    leader = stock_with_history("LEAD", Array.new(100) { |i| 100.0 + i * 1.0 }) # rises most: RS 99
    laggard = stock_with_history("LAG", Array.new(100) { |i| 100.0 + i * 0.1 }) # rises least: RS 1
    allow(Watchlist::EntryZoneSuggester).to receive(:call) do |stock, type, **|
      next { success: false, error: "No #{type}" } unless type == "pullback"

      close = stock.daily_prices.max_by(&:traded_on).close_price.to_f
      { success: true, levels: { entry_zone_low: close - 1, entry_zone_high: close + 1, invalidation_price: close - 10, target_price: close + 20, pivot_price: nil } }
    end

    detail[:candles] = [ { open: 198.0, high: 200.0, low: 197.0, close: 199.0 } ]
    detail[:price_action][:trend] = "uptrend"

    described_class.call

    expect(leader.setup_snapshots.sole).to have_attributes(setup_type: "pullback", zone_state: "in_zone")
    expect(laggard.setup_snapshots.sole).to have_attributes(setup_type: nil, zone_state: "no_setup")
  end

  it "uses a newer pattern's own quality and prefers a setup in its zone" do
    stock = stock_with_history("BANK", Array.new(100) { |i| 100.0 + i * 1.0 }) # ends at 199
    allow(Watchlist::EntryZoneSuggester).to receive(:call) do |_stock, type, **|
      case type
      when "vcp" # price below this zone: too early
        { success: true, levels: { entry_zone_low: 210.0, entry_zone_high: 216.0, invalidation_price: 190.0, target_price: 250.0, pivot_price: 210.0 } }
      when "ma_pullback" # price inside this zone
        { success: true, levels: { entry_zone_low: 196.0, entry_zone_high: 200.0, invalidation_price: 188.0, target_price: 230.0, pivot_price: nil },
          pattern: { quality: 60, details: {} } }
      else
        { success: false, error: "No #{type}" }
      end
    end

    described_class.call

    expect(stock.setup_snapshots.sole).to have_attributes(setup_type: "ma_pullback", zone_state: "in_zone", setup_quality: 60)
  end
end
