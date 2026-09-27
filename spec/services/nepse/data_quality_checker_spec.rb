require "rails_helper"

RSpec.describe Nepse::DataQualityChecker do
  let!(:stock) { create(:stock, symbol: "NABIL", is_active: true) }

  describe ".call" do
    context "when market data is fully valid" do
      before do
        create(:stock_daily_price, stock: stock, traded_on: Date.parse("2026-09-01"), open_price: 500, high_price: 520, low_price: 490, close_price: 510, volume: 1000)
        create(:stock_daily_price, stock: stock, traded_on: Date.parse("2026-09-02"), open_price: 510, high_price: 530, low_price: 505, close_price: 525, volume: 1500)
      end

      it "reports clean audit status with 0 anomalies" do
        result = described_class.call(start_date: "2026-09-01", end_date: "2026-09-02", symbols: ["NABIL"])

        expect(result[:success]).to be true
        expect(result[:clean]).to be true
        expect(result[:total_anomalies]).to eq(0)
      end
    end

    context "when impossible OHLC or close outside high/low exists" do
      before do
        # Record with high < low and close > high
        create(:stock_daily_price, stock: stock, traded_on: Date.parse("2026-09-01"), open_price: 500, high_price: 480, low_price: 520, close_price: 550)
      end

      it "flags impossible OHLC and close outside boundaries" do
        result = described_class.call(start_date: "2026-09-01", end_date: "2026-09-01", symbols: ["NABIL"])

        expect(result[:clean]).to be false
        expect(result[:anomalies][:impossible_ohlc]).not_to be_empty
        expect(result[:anomalies][:close_outside_high_low]).not_to be_empty
        expect(result[:anomalies][:impossible_ohlc].first[:symbol]).to eq("NABIL")
      end
    end

    context "when negative volume or zero price exists" do
      before do
        record = build(:stock_daily_price, stock: stock, traded_on: Date.parse("2026-09-01"), open_price: 0, high_price: 0, low_price: 0, close_price: 0, volume: -100)
        record.save(validate: false)
      end

      it "flags negative volume and zero price anomalies" do
        result = described_class.call(start_date: "2026-09-01", end_date: "2026-09-01", symbols: ["NABIL"])

        expect(result[:clean]).to be false
        expect(result[:anomalies][:negative_volume]).not_to be_empty
        expect(result[:anomalies][:zero_prices]).not_to be_empty
      end
    end

    context "when missing trading dates exist" do
      before do
        create(:stock_daily_price, stock: stock, traded_on: Date.parse("2026-09-01"), open_price: 500, high_price: 510, low_price: 490, close_price: 505) # Sunday
        # Monday (2026-09-02), Tuesday (2026-09-03) missing
        create(:stock_daily_price, stock: stock, traded_on: Date.parse("2026-09-04"), open_price: 505, high_price: 520, low_price: 500, close_price: 515) # Wednesday
      end

      it "flags missing business trading days in date range" do
        result = described_class.call(start_date: "2026-09-01", end_date: "2026-09-04", symbols: ["NABIL"])

        expect(result[:clean]).to be false
        expect(result[:anomalies][:missing_trading_dates]).not_to be_empty
        missing_info = result[:anomalies][:missing_trading_dates].first
        expect(missing_info[:missing_count]).to eq(2) # Mon & Tue
      end
    end
  end
end
