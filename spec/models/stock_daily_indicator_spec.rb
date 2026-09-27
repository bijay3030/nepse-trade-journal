require "rails_helper"

RSpec.describe StockDailyIndicator, type: :model do
  let!(:stock) { create(:stock, symbol: "NABIL") }

  describe "validations and summary helpers" do
    it "validates presence of traded_on and uniqueness scope" do
      indicator = described_class.create(stock: stock, traded_on: Date.parse("2026-09-20"), sma_20: 500)
      expect(indicator).to be_valid

      duplicate = described_class.build(stock: stock, traded_on: Date.parse("2026-09-20"), sma_20: 510)
      expect(duplicate).not_to be_valid
    end

    it "provides formatted indicator summary hashes" do
      indicator = described_class.create!(
        stock: stock,
        traded_on: Date.parse("2026-09-20"),
        sma_20: 500.0,
        ema_20: 505.0,
        atr_14: 15.0,
        atr_percent: 3.0,
        avg_volume_10: 10000,
        rvol: 1.5,
        high_52w: 600.0,
        low_52w: 400.0,
        change_pct_1d: 2.5
      )

      expect(indicator.trend_summary[:sma_20]).to eq(500.0)
      expect(indicator.volatility_summary[:atr_14]).to eq(15.0)
      expect(indicator.volume_summary[:avg_volume_10]).to eq(10000)
      expect(indicator.price_position_summary[:high_52w]).to eq(600.0)
      expect(indicator.momentum_summary[:change_pct_1d]).to eq(2.5)
    end
  end
end
