require "rails_helper"

RSpec.describe Nepse::LivePriceSync do
  let!(:stock) { create(:stock, symbol: "NABIL", last_price: 540.0, change_percent: 1.5, volume: 1_000) }

  it "broadcasts the latest quotes after a successful sync" do
    expect {
      described_class.call(market_sync: -> { { success: true, processed: 1 } })
    }.to have_broadcasted_to("stock_prices").with { |data|
      expect(data["prices"]).to contain_exactly(include("symbol" => "NABIL", "last_price" => 540.0, "change_percent" => 1.5, "volume" => 1_000))
    }
  end

  it "does not broadcast when the sync fails" do
    expect {
      result = described_class.call(market_sync: -> { { success: false, error: "down" } })
      expect(result).to include(success: false)
    }.not_to have_broadcasted_to("stock_prices")
  end

  describe "choosing a fresh source" do
    let(:zone) { ActiveSupport::TimeZone["Asia/Kathmandu"] }
    let(:now) { zone.parse("2026-11-23 12:40") }
    let(:memory) { ActiveSupport::Cache::MemoryStore.new }
    let(:fresh) { { success: true, as_of: now - 1.minute, rows: [ { symbol: "NABIL", last_price: 551.0, close_price: 551.0, previous_close: 540.0, traded_on: Date.new(2026, 11, 23) } ] } }

    before { allow(Rails).to receive(:cache).and_return(memory) }

    it "stores and pushes prices from a fresh source, and says prices are live" do
      expect {
        result = described_class.call(now: now, sources: [ [ :sharesansar_live, double(fetch: fresh) ] ])
        expect(result).to include(success: true, source: :sharesansar_live)
      }.to have_broadcasted_to("stock_prices")
      expect(stock.reload.last_price.to_f).to eq(551.0)
      expect(Nepse::LiveFeed.status(now: now)).to include(state: "live", source: :sharesansar_live)
    end

    it "stores nothing and holds the alerts when every source is stale" do
      expect(Watchlist::AlertEvaluator).not_to receive(:call)
      stale = fresh.merge(as_of: now - 1.hour)
      expect {
        result = described_class.call(now: now, sources: [ [ :sharesansar_live, double(fetch: stale) ] ])
        expect(result).to include(success: false, stale: true)
      }.not_to have_broadcasted_to("stock_prices")
      expect(stock.reload.last_price.to_f).to eq(540.0)
      expect(Nepse::LiveFeed.status(now: now)).to include(state: "delayed", reasons: { sharesansar_live: "last updated 11:40" })
    end
  end
end
