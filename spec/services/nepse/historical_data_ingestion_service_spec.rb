require "rails_helper"

RSpec.describe Nepse::HistoricalDataIngestionService do
  let!(:stock1) { create(:stock, symbol: "NABIL", is_active: true) }
  let!(:stock2) { create(:stock, symbol: "NTC", is_active: true) }

  let(:start_date) { Date.parse("2026-09-01") }
  let(:end_date) { Date.parse("2026-09-05") }
  let(:mock_provider) { instance_double(Nepse::DataProviders::BaseProvider) }

  describe ".call" do
    let(:nabil_rec1) do
      Nepse::DataProviders::NormalizedMarketData.new(
        symbol: "NABIL",
        traded_on: Date.parse("2026-09-01"),
        open_price: 500, high_price: 520, low_price: 490, close_price: 510, volume: 1000
      )
    end

    let(:ntc_rec1) do
      Nepse::DataProviders::NormalizedMarketData.new(
        symbol: "NTC",
        traded_on: Date.parse("2026-09-01"),
        open_price: 880, high_price: 900, low_price: 870, close_price: 890, volume: 2000
      )
    end

    before do
      allow(mock_provider).to receive(:respond_to?).with(:fetch_historical_prices).and_return(true)
      allow(mock_provider).to receive(:fetch_historical_prices).with("NABIL", start_date: start_date, end_date: end_date).and_return(
        success: true, records: [nabil_rec1]
      )
      allow(mock_provider).to receive(:fetch_historical_prices).with("NTC", start_date: start_date, end_date: end_date).and_return(
        success: true, records: [ntc_rec1]
      )
    end

    it "processes stocks in batches and imports records into PostgreSQL" do
      result = described_class.call(
        start_date: start_date,
        end_date: end_date,
        batch_size: 1,
        custom_provider: mock_provider
      )

      expect(result[:success]).to be true
      expect(result[:processed_stocks]).to eq(2)
      expect(result[:processed_records]).to eq(2)

      expect(StockDailyPrice.find_by(stock: stock1, traded_on: Date.parse("2026-09-01"))).to be_present
      expect(StockDailyPrice.find_by(stock: stock2, traded_on: Date.parse("2026-09-01"))).to be_present
    end

    it "is resumable and skips dates already present in PostgreSQL" do
      # Pre-create NABIL daily price on 2026-09-01
      create(:stock_daily_price, stock: stock1, traded_on: Date.parse("2026-09-01"), close_price: 510)

      result = described_class.call(
        start_date: start_date,
        end_date: end_date,
        batch_size: 2,
        custom_provider: mock_provider,
        force_refresh: false
      )

      expect(result[:success]).to be true
      expect(result[:skipped_records]).to be >= 1
      expect(result[:processed_records]).to eq(1) # Only NTC processed
    end

    it "handles individual stock failure without killing the entire import job" do
      allow(mock_provider).to receive(:fetch_historical_prices).with("NABIL", start_date: start_date, end_date: end_date).and_return(
        success: false, error: "Network disconnect"
      )

      result = described_class.call(
        start_date: start_date,
        end_date: end_date,
        batch_size: 1,
        custom_provider: mock_provider
      )

      expect(result[:processed_stocks]).to eq(1) # NTC succeeded
      expect(result[:failed_stocks].size).to eq(1)
      expect(result[:failed_stocks].first[:symbol]).to eq("NABIL")
    end
  end
end
