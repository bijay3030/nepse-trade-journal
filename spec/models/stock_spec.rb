require "rails_helper"

RSpec.describe Stock, type: :model do
  let(:stock) { create(:stock, last_price: 500.0, listed_shares: 10_000_000) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(stock).to be_valid
    end

    it "requires symbol" do
      invalid = build(:stock, symbol: nil)
      expect(invalid).not_to be_valid
    end

    it "requires unique symbol" do
      create(:stock, symbol: "TESTNABIL")
      duplicate = build(:stock, symbol: "TESTNABIL")
      expect(duplicate).not_to be_valid
    end
  end

  describe "associations" do
    it "has daily_prices and company_financials" do
      daily_price = create(:stock_daily_price, stock: stock)
      financial = create(:stock_company_financial, stock: stock)

      expect(stock.daily_prices).to include(daily_price)
      expect(stock.company_financials).to include(financial)
    end
  end

  describe "helper methods" do
    before do
      create(:stock_company_financial, stock: stock, eps: 25.0, pe_ratio: 0.0, book_value: 200.0, pb_ratio: 0.0)
    end

    it "calculates current_eps and current_pe_ratio correctly" do
      expect(stock.current_eps).to eq(25.0)
      expect(stock.current_pe_ratio).to eq(20.0)
    end

    it "calculates current_book_value and current_pb_ratio correctly" do
      expect(stock.current_book_value).to eq(200.0)
      expect(stock.current_pb_ratio).to eq(2.5)
    end

    it "prefers a persisted positive pe_ratio from the latest financial" do
      create(
        :stock_company_financial,
        stock: stock,
        fiscal_year: "2081/82",
        quarter: "Annual",
        reported_on: Date.current + 1,
        eps: 10.0,
        pe_ratio: 18.75
      )

      expect(stock.current_pe_ratio).to eq(18.75)
    end

    it "treats annual reports as later than q4 when report date and fiscal year tie" do
      q4_financial = create(
        :stock_company_financial,
        stock: stock,
        fiscal_year: "2081/82",
        quarter: "Q4",
        reported_on: Date.current + 1,
        pe_ratio: 11.0
      )
      annual_financial = create(
        :stock_company_financial,
        stock: stock,
        fiscal_year: "2081/82",
        quarter: "Annual",
        reported_on: Date.current + 1,
        pe_ratio: 18.75
      )

      expect(stock.latest_financial).to eq(annual_financial)
      expect(stock.latest_financial).not_to eq(q4_financial)
      expect(stock.current_pe_ratio).to eq(18.75)
    end

    it "falls back to a derived pe_ratio when the latest persisted ratio is zero" do
      create(
        :stock_company_financial,
        stock: stock,
        fiscal_year: "2081/82",
        quarter: "Annual",
        reported_on: Date.current + 1,
        eps: 20.0,
        pe_ratio: 0.0
      )

      expect(stock.current_pe_ratio).to eq(25.0)
    end

    it "prefers a persisted positive pb_ratio from the latest financial" do
      create(
        :stock_company_financial,
        stock: stock,
        fiscal_year: "2081/82",
        quarter: "Annual",
        reported_on: Date.current + 1,
        book_value: 100.0,
        pb_ratio: 3.1
      )

      expect(stock.current_pb_ratio).to eq(3.1)
    end

    it "falls back to a derived pb_ratio when the latest persisted ratio is zero" do
      create(
        :stock_company_financial,
        stock: stock,
        fiscal_year: "2081/82",
        quarter: "Annual",
        reported_on: Date.current + 1,
        book_value: 250.0,
        pb_ratio: 0.0
      )

      expect(stock.current_pb_ratio).to eq(2.0)
    end

    it "recalculates market cap" do
      stock.recalculate_market_cap!
      expect(stock.market_cap).to eq(5_000_000_000.0)
    end

    it "does not recalculate market cap when last_price is missing" do
      stock.update!(market_cap: 123.0)
      allow(stock).to receive(:last_price).and_return(nil)

      expect { stock.recalculate_market_cap! }.not_to change { stock.reload.market_cap }
    end
  end

  describe "#apply_live_quote!" do
    let(:stock) { create(:stock, last_price: 500.0, change_percent: 2.0, volume: 8_000) }

    it "updates the price and derives change from the previous close" do
      create(:stock_daily_price, stock: stock, traded_on: Date.current - 1, close_price: 500.0)

      stock.apply_live_quote!({ last_price: 525.0, change_percent: nil, volume: nil })

      expect(stock.reload.last_price.to_f).to eq(525.0)
      expect(stock.change_percent.to_f).to eq(5.0)
      expect(stock.volume).to eq(8_000)
    end

    it "keeps the stored change when there is no previous close to compare with" do
      stock.apply_live_quote!({ last_price: 525.0, change_percent: nil, volume: nil })

      expect(stock.reload.change_percent.to_f).to eq(2.0)
    end

    it "ignores quotes without a usable price" do
      expect(stock.apply_live_quote!({ last_price: nil })).to be(false)
      expect(stock.reload.last_price.to_f).to eq(500.0)
    end
  end
end
