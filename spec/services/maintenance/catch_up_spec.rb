require "rails_helper"

RSpec.describe Maintenance::CatchUp do
  let(:zone) { ActiveSupport::TimeZone["Asia/Kathmandu"] }
  let(:nepse) { MarketIndex.create!(symbol: "NEPSE", name: "NEPSE Index") }
  let(:stocks) { Array.new(10) { create(:stock) } }
  # Mon 5 - Fri 9 Oct 2026.
  let(:sessions) { (5..9).map { Date.new(2026, 10, _1) } }

  def stock_rows(day, count) = stocks.first(count).each { create(:stock_daily_price, stock: _1, traded_on: day) }

  before do
    sessions.each { nepse.histories.create!(traded_on: _1, index_value: 2600, turnover: 4e9) }
    allow(Nepse::Reference::IndexHistorySync).to receive(:call).and_return({ indices: {} })
    allow(Nepse::HistoryBackfillService).to receive(:call).and_return({})
    allow(Indicators::BatchCalculatorService).to receive(:call).and_return({})
    allow(Flows::Backfill).to receive(:call).and_return({})
    allow(Setups::SnapshotBuilder).to receive(:call).and_return({ success: true })
  end

  def run(at) = described_class.call(now: zone.parse(at))

  it "backfills sessions stored with far fewer stocks than usual, then the snapshots after the latest" do
    sessions.each { |day| stock_rows(day, [ 7, 8 ].include?(day.day) ? 3 : 10) }
    sessions.each { |day| StockBrokerFlow.create!(stock: stocks.first, traded_on: day, broker_no: 1) }
    StockSetupSnapshot.create!(stock: stocks.first, traded_on: Date.new(2026, 10, 6), close_price: 1, zone_state: "no_setup")

    result = run("2026-10-12 10:00") # Monday morning: Friday is the last complete session

    expect(result[:price_sessions]).to eq([ Date.new(2026, 10, 7), Date.new(2026, 10, 8) ])
    expect(Nepse::HistoryBackfillService).to have_received(:call).with(days: 7)
    expect(result[:snapshot_sessions]).to eq([ Date.new(2026, 10, 7), Date.new(2026, 10, 8), Date.new(2026, 10, 9) ])
    expect(Setups::SnapshotBuilder).to have_received(:call).with(as_of: Date.new(2026, 10, 9))
    expect(result[:flow_sessions]).to be_empty
    expect(Nepse::Reference::IndexHistorySync).not_to have_received(:call) # Friday is stored
  end

  it "does nothing when every session is stored, and waits for today's nightly build" do
    nepse.histories.create!(traded_on: Date.new(2026, 10, 12), index_value: 2600, turnover: 4e9)
    (sessions + [ Date.new(2026, 10, 12) ]).each do |day|
      stock_rows(day, 10)
      StockBrokerFlow.create!(stock: stocks.first, traded_on: day, broker_no: 1)
    end
    StockSetupSnapshot.create!(stock: stocks.first, traded_on: Date.new(2026, 10, 9), close_price: 1, zone_state: "no_setup")

    expect(run("2026-10-12 16:30")).to include(price_sessions: [], flow_sessions: [], snapshot_sessions: [])
    expect(run("2026-10-12 17:30")[:snapshot_sessions]).to eq([ Date.new(2026, 10, 12) ])
  end

  it "syncs the index when a weekday session is missing, and backfills missing floorsheets" do
    sessions.each { stock_rows(_1, 10) }
    run("2026-10-13 18:00") # Tuesday evening: Mon 12 and Tue 13 aren't stored

    expect(Nepse::Reference::IndexHistorySync).to have_received(:call).with(days: 15)
    expect(Flows::Backfill).to have_received(:call).with(sessions: 5)
  end
end

RSpec.describe Maintenance::CatchUp, ".freshness" do
  it "reports the latest snapshot and how many completed sessions came after it" do
    nepse = MarketIndex.create!(symbol: "NEPSE", name: "NEPSE Index")
    stock = create(:stock)
    (5..9).each { nepse.histories.create!(traded_on: Date.new(2026, 10, _1), index_value: 2600) }
    StockSetupSnapshot.create!(stock: stock, traded_on: Date.new(2026, 10, 6), close_price: 1, zone_state: "no_setup")

    result = described_class.freshness(now: ActiveSupport::TimeZone["Asia/Kathmandu"].parse("2026-10-12 10:00"))

    expect(result).to eq(snapshot_on: Date.new(2026, 10, 6), behind_sessions: 3, latest_session: Date.new(2026, 10, 9))
  end
end
