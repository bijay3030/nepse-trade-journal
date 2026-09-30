require "rails_helper"

RSpec.describe Setups::HistoryBuilder do
  let(:nepse) { create(:market_index, symbol: "NEPSE") }
  let(:stock) { create(:stock) }

  before do
    [ Date.new(2026, 9, 24), Date.new(2026, 9, 25), Date.new(2026, 9, 28) ].each do |day|
      create(:market_index_history, market_index: nepse, traded_on: day)
      create(:stock_daily_price, stock: stock, traded_on: day)
    end
    create(:stock_daily_price, stock: create(:stock, symbol: "DEMO"), traded_on: Date.new(2026, 9, 27)) # a Sunday row
  end

  it "uses NEPSE sessions only, skipping stray dates and sessions already built" do
    StockSetupSnapshot.create!(stock: stock, traded_on: Date.new(2026, 9, 25), close_price: 1, zone_state: "too_early")
    built = []
    allow(Setups::SnapshotBuilder).to receive(:call) { |as_of:, **| built << as_of; { success: true } }

    result = described_class.call(sessions: 10)

    expect(built).to eq([ Date.new(2026, 9, 24), Date.new(2026, 9, 28) ])
    expect(result[:built]).to eq(built)
  end
end
