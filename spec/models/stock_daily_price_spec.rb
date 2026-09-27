require "rails_helper"

RSpec.describe StockDailyPrice, type: :model do
  let(:stock) { create(:stock) }

  describe "validations" do
    it "is valid with valid attributes" do
      daily_price = build(:stock_daily_price, stock: stock)
      expect(daily_price).to be_valid
    end

    it "requires traded_on date" do
      daily_price = build(:stock_daily_price, stock: stock, traded_on: nil)
      expect(daily_price).not_to be_valid
    end
  end

  describe "callbacks" do
    it "calculates change_amount and change_percent before saving" do
      daily_price = described_class.create!(
        stock: stock,
        traded_on: Date.current,
        open_price: 100,
        high_price: 110,
        low_price: 95,
        close_price: 110,
        previous_close: 100,
        volume: 1000
      )

      expect(daily_price.change_amount).to eq(10.0)
      expect(daily_price.change_percent).to eq(10.0)
    end
  end
end
