require "rails_helper"

RSpec.describe Nepse::CsvImporterService do
  let!(:stock) { create(:stock, symbol: "NABIL") }

  describe ".call for prices" do
    let(:csv_content) do
      <<~CSV
        symbol,date,open,high,low,close,volume,turnover
        NABIL,2026-07-25,500,520,495,515,5000,2575000
      CSV
    end

    it "imports price rows successfully" do
      result = described_class.call(csv_content, type: "prices")

      expect(result[:success]).to be true
      expect(result[:imported]).to eq(1)

      daily_record = StockDailyPrice.find_by(stock: stock, traded_on: Date.parse("2026-07-25"))
      expect(daily_record).to be_present
      expect(daily_record.close_price).to eq(515.0)
    end
  end

  describe ".call for financials" do
    let(:csv_content) do
      <<~CSV
        symbol,fiscal_year,quarter,eps,pe_ratio,book_value,roe
        NABIL,2080/81,Q4,28.5,18.2,215.0,14.2
      CSV
    end

    it "imports financial rows successfully" do
      result = described_class.call(csv_content, type: "financials")

      expect(result[:success]).to be true
      expect(result[:imported]).to eq(1)

      financial = StockCompanyFinancial.find_by(stock: stock, fiscal_year: "2080/81", quarter: "Q4")
      expect(financial).to be_present
      expect(financial.eps).to eq(28.5)
      expect(financial.book_value).to eq(215.0)
    end
  end
end
