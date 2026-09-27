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
end
