require "rails_helper"

RSpec.describe Nepse::MarketDataIngestionService do
  let(:date) { Date.parse("2026-09-20") }
  let(:mock_provider) { instance_double(Nepse::DataProviders::BaseProvider) }

  describe ".call" do
    context "successful ingestion" do
      let(:normalized_data) do
        Nepse::DataProviders::NormalizedMarketData.new(
          symbol: "NABIL",
          company_name: "Nabil Bank Limited",
          sector: "Commercial Banks",
          traded_on: date,
          open_price: 500,
          high_price: 530,
          low_price: 495,
          close_price: 525,
          previous_close: 500,
          change_amount: 25,
          change_percent: 5.0,
          volume: 20000,
          turnover: 10500000.0,
          total_trades: 600
        )
      end

      before do
        allow(mock_provider).to receive(:fetch_daily_prices).with(date).and_return(
          success: true,
          records: [normalized_data]
        )
      end

      it "creates Stock and StockDailyPrice records in PostgreSQL" do
        expect {
          described_class.call(date, custom_provider: mock_provider)
        }.to change(Stock, :count).by(1)
         .and change(StockDailyPrice, :count).by(1)

        stock = Stock.find_by(symbol: "NABIL")
        expect(stock).to be_present
        expect(stock.name).to eq("Nabil Bank Limited")
        expect(stock.sector).to eq("Commercial Banks")
        expect(stock.last_price).to eq(525.0)

        daily = StockDailyPrice.find_by(stock: stock, traded_on: date)
        expect(daily).to be_present
        expect(daily.open_price).to eq(500.0)
        expect(daily.high_price).to eq(530.0)
        expect(daily.low_price).to eq(495.0)
        expect(daily.close_price).to eq(525.0)
        expect(daily.volume).to eq(20000)
        expect(daily.turnover).to eq(10500000.0)
      end
    end

    context "duplicate ingestion and idempotency" do
      let(:normalized_data) do
        Nepse::DataProviders::NormalizedMarketData.new(
          symbol: "NTC",
          company_name: "Nepal Telecom",
          sector: "Others",
          traded_on: date,
          open_price: 880,
          high_price: 910,
          low_price: 880,
          close_price: 900,
          volume: 10000
        )
      end

      before do
        allow(mock_provider).to receive(:fetch_daily_prices).with(date).and_return(
          success: true,
          records: [normalized_data]
        )
      end

      it "updates existing records without creating duplicates when run multiple times" do
        # First execution
        described_class.call(date, custom_provider: mock_provider)
        expect(Stock.count).to eq(1)
        expect(StockDailyPrice.count).to eq(1)

        # Second execution (duplicate call)
        expect {
          described_class.call(date, custom_provider: mock_provider)
        }.to change(StockDailyPrice, :count).by(0)

        expect(Stock.count).to eq(1)
        expect(StockDailyPrice.count).to eq(1)

        daily = StockDailyPrice.find_by(traded_on: date)
        expect(daily.close_price).to eq(900.0)
      end
    end

    context "unknown stock symbol" do
      let(:normalized_data) do
        Nepse::DataProviders::NormalizedMarketData.new(
          symbol: "NEWSTOCK",
          company_name: "Brand New Company Ltd",
          sector: "Hydropower",
          traded_on: date,
          close_price: 250,
          volume: 1500
        )
      end

      before do
        allow(mock_provider).to receive(:fetch_daily_prices).with(date).and_return(
          success: true,
          records: [normalized_data]
        )
      end

      it "automatically creates master Stock record for unknown symbol" do
        expect(Stock.find_by(symbol: "NEWSTOCK")).to be_nil

        result = described_class.call(date, custom_provider: mock_provider)

        expect(result[:success]).to be true
        expect(result[:processed_count]).to eq(1)

        new_stock = Stock.find_by(symbol: "NEWSTOCK")
        expect(new_stock).to be_present
        expect(new_stock.name).to eq("Brand New Company Ltd")
        expect(new_stock.sector).to eq("Hydropower")
      end
    end

    context "missing values in provider payload" do
      let(:incomplete_data) do
        Nepse::DataProviders::NormalizedMarketData.new(
          symbol: "AHPC",
          traded_on: date,
          close_price: 340.0,
          open_price: nil,
          high_price: nil,
          low_price: nil,
          volume: nil,
          turnover: nil
        )
      end

      before do
        allow(mock_provider).to receive(:fetch_daily_prices).with(date).and_return(
          success: true,
          records: [incomplete_data]
        )
      end

      it "safely handles missing values with fallback defaults" do
        result = described_class.call(date, custom_provider: mock_provider)

        expect(result[:success]).to be true
        daily = StockDailyPrice.joins(:stock).find_by(stocks: { symbol: "AHPC" }, traded_on: date)
        expect(daily).to be_present
        expect(daily.close_price).to eq(340.0)
        expect(daily.open_price).to eq(340.0) # safely defaulted to close_price
        expect(daily.volume).to eq(0) # safely defaulted to 0
      end
    end

    context "malformed response or API failure" do
      before do
        allow(mock_provider).to receive(:fetch_daily_prices).with(date).and_return(
          success: false,
          error: "API connection refused"
        )
      end

      it "logs error and returns failure result without crashing" do
        result = described_class.call(date, custom_provider: mock_provider)

        expect(result[:success]).to be false
        expect(result[:error]).to eq("API connection refused")
        expect(result[:processed_count]).to eq(0)
      end
    end
  end
end
