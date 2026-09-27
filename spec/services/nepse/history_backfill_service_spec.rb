require "rails_helper"

RSpec.describe Nepse::HistoryBackfillService do
  let!(:stock) { create(:stock, symbol: "NABIL") }
  let(:client) { instance_double(Nepse::Source::MerolaganiHistoryClient) }
  let(:bars) do
    [
      { traded_on: Date.new(2026, 9, 22), open_price: 560.0, high_price: 566.0, low_price: 559.0, close_price: 565.7, volume: 90_005 },
      { traded_on: Date.new(2026, 9, 24), open_price: 566.0, high_price: 570.0, low_price: 566.0, close_price: 569.0, volume: 70_749 }
    ]
  end

  before { allow(client).to receive(:fetch).and_return({ success: true, bars: bars }) }

  def run
    described_class.call(symbols: [ "NABIL" ], client: client, delay_seconds: 0, to: Date.new(2026, 9, 27))
  end

  it "stores the bars with change figures derived from the previous close" do
    create(:stock_daily_price, stock: stock, traded_on: Date.new(2026, 9, 21), close_price: 560.0)

    expect(run).to include(success: true, stocks: 1, bars: 2)

    latest = StockDailyPrice.find_by!(stock: stock, traded_on: Date.new(2026, 9, 24))
    expect(latest).to have_attributes(close_price: 569.0, previous_close: 565.7, volume: 70_749)
    expect(latest.change_percent.to_f).to eq(0.58)
    expect(StockDailyPrice.find_by!(stock: stock, traded_on: Date.new(2026, 9, 22)).previous_close.to_f).to eq(560.0)
  end

  it "replaces stored rows and drops dates inside the range that had no session" do
    create(:stock_daily_price, stock: stock, traded_on: Date.new(2026, 9, 22), close_price: 515.0, volume: 12_000)
    create(:stock_daily_price, stock: stock, traded_on: Date.new(2026, 9, 23), close_price: 515.0)
    create(:stock_daily_price, stock: stock, traded_on: Date.new(2026, 9, 27), close_price: 571.0)

    expect(run).to include(removed: 1)

    expect(StockDailyPrice.find_by!(stock: stock, traded_on: Date.new(2026, 9, 22)).close_price.to_f).to eq(565.7)
    expect(StockDailyPrice.exists?(stock: stock, traded_on: Date.new(2026, 9, 23))).to be(false)
    expect(StockDailyPrice.find_by!(stock: stock, traded_on: Date.new(2026, 9, 27)).close_price.to_f).to eq(571.0)
  end

  it "records symbols the source could not provide" do
    allow(client).to receive(:fetch).and_return({ success: false, error: "No history" })

    expect(run).to include(stocks: 0, failed: { "NABIL" => "No history" })
  end
end
