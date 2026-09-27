require "rails_helper"

RSpec.describe Nepse::DailyPriceImporterService do
  let!(:stock) { create(:stock, symbol: "NABIL", last_price: 500.0) }

  describe ".call" do
    it "records daily prices for active stocks from NepsePriceService" do
      result = described_class.call(Date.current)
      expect(result[:success]).to be true

      daily_record = StockDailyPrice.find_by(stock: stock, traded_on: Date.current)
      expect(daily_record).to be_present
      expect(daily_record.close_price).to be > 0
    end
  end
end
