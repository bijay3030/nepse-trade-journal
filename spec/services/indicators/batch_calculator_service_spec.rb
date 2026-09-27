require "rails_helper"

RSpec.describe Indicators::BatchCalculatorService do
  let!(:stock) { create(:stock, symbol: "NABIL", is_active: true) }

  before do
    # Create 25 daily price records for NABIL
    (1..25).each do |i|
      date = Date.parse("2026-01-01") + i.days
      create(
        :stock_daily_price,
        stock: stock,
        traded_on: date,
        open_price: 500 + i,
        high_price: 520 + i,
        low_price: 490 + i,
        close_price: 510 + i,
        volume: 1000 * i
      )
    end
  end

  describe ".call" do
    it "computes indicators and persists StockDailyIndicator records" do
      expect {
        described_class.call(symbols: ["NABIL"], batch_size: 1)
      }.to change(StockDailyIndicator, :count).by(25)

      # Check last record (Bar 25 - date 2026-01-26)
      last_indicator = StockDailyIndicator.find_by(stock: stock, traded_on: Date.parse("2026-01-26"))
      expect(last_indicator).to be_present
      expect(last_indicator.sma_20).to be_present
      expect(last_indicator.ema_20).to be_present
      expect(last_indicator.atr_14).to be_present
      expect(last_indicator.avg_volume_10).to be_present
      expect(last_indicator.rvol).to be_present
      expect(last_indicator.change_pct_20d).to be_present

      # SMA50 & SMA200 must be nil because observations = 25 < 50
      expect(last_indicator.sma_50).to be_nil
      expect(last_indicator.sma_200).to be_nil
    end

    it "skips records that have already been calculated on subsequent runs" do
      # Initial run
      described_class.call(symbols: ["NABIL"])
      expect(StockDailyIndicator.count).to eq(25)

      # Second run (incremental check)
      result = described_class.call(symbols: ["NABIL"], recalculate_all: false)
      expect(result[:success]).to be true
      expect(result[:processed_indicators]).to eq(0) # 0 re-computations
    end
  end
end
