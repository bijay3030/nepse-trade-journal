require "rails_helper"

RSpec.describe Scans::History do
  let(:stock) { create(:stock, symbol: "OLDX", security_type: "Equity") }

  before do
    (1..3).each { |i| create(:stock_daily_price, stock: stock, traded_on: Date.new(2025, 10, i + 5), close_price: 200 + i) }
  end

  it "joins archived prices before the regular ones, one stock at a time" do
    StockPriceArchive.create!(stock: stock, traded_on: Date.new(2025, 9, 1), close_price: 150, high_price: 151, low_price: 149, open_price: 150, volume: 10)
    StockPriceArchive.create!(stock: stock, traded_on: Date.new(2025, 10, 6), close_price: 999) # overlaps a regular day: ignored

    yielded = []
    described_class.each_stock(now: Time.zone.parse("2025-10-20 18:00")) { |id, rows| yielded << [ id, rows.map { [ _1[0], _1[3] ] } ] }

    expect(yielded).to eq([ [ stock.id, [ [ Date.new(2025, 9, 1), 150.0 ], [ Date.new(2025, 10, 6), 201.0 ], [ Date.new(2025, 10, 7), 202.0 ], [ Date.new(2025, 10, 8), 203.0 ] ] ] ])
  end

  it "imports history from 2020 up to the day before the first regular price" do
    client = instance_double(Nepse::Source::MerolaganiHistoryClient)
    allow(client).to receive(:fetch).with("OLDX", from: Date.new(2020, 1, 1), to: Date.new(2025, 10, 5)).and_return(
      success: true, bars: [
        { traded_on: Date.new(2020, 1, 2), open_price: 100, high_price: 101, low_price: 99, close_price: 100.5, volume: 1000 },
        { traded_on: Date.new(2025, 10, 5), open_price: 190, high_price: 191, low_price: 189, close_price: 190, volume: 2000 }
      ]
    )

    result = described_class.import!(symbols: [ "OLDX" ], client: client, delay: 0)

    expect(result).to include(stocks: 1, rows: 2)
    expect(StockPriceArchive.where(stock: stock).order(:traded_on).pluck(:traded_on, :close_price).map { [ _1, _2.to_f ] }).to eq([ [ Date.new(2020, 1, 2), 100.5 ], [ Date.new(2025, 10, 5), 190.0 ] ])
    expect(described_class.import!(symbols: [ "OLDX" ], client: client, delay: 0)[:rows]).to eq(2) # idempotent upsert
    expect(StockPriceArchive.count).to eq(2)
  end

  it "records the client's error for a stock without history" do
    client = instance_double(Nepse::Source::MerolaganiHistoryClient, fetch: { success: false, error: "HTTP 503" })

    expect(described_class.import!(symbols: [ "OLDX" ], client: client, delay: 0)).to include(stocks: 0, failed: { "OLDX" => "HTTP 503" })
  end
end
