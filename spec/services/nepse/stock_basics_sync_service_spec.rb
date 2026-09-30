require "rails_helper"

RSpec.describe Nepse::StockBasicsSyncService do
  describe ".call" do
    subject(:result) do
      described_class.call(
        traded_on: traded_on,
        market_client: market_client,
        company_client: company_client,
        fundamentals_failure_threshold: fundamentals_failure_threshold,
        request_delay_seconds: request_delay_seconds
      )
    end

    let(:traded_on) { Date.new(2026, 7, 27) }
    let(:market_client) { instance_double(Nepse::Source::SharesansarMarketClient) }
    let(:company_client) { instance_double(Nepse::Source::MerolaganiCompanyClient) }
    let(:fundamentals_failure_threshold) { 0.6 }
    let(:request_delay_seconds) { 0 }

    before do
      allow(Nepse::MasterImporterService).to receive(:call).and_return({ success: true, created: 2, updated: 0, total: 2 })
      allow(market_client).to receive(:fetch).and_return({ success: true, rows: [] })
      allow(company_client).to receive(:fetch).and_return({ success: true, fundamentals: {} })
    end

    it "runs the canonical master import before market sync" do
      expect(Nepse::MasterImporterService).to receive(:call).ordered.and_return({ success: true, created: 1, updated: 0, total: 1 })
      expect(market_client).to receive(:fetch).ordered.and_return({ success: true, rows: [] })

      result
    end

    it "persists market data into stocks and stock_daily_prices and adds new listings" do
      seeded_stock = create(
        :stock,
        symbol: "NABIL",
        last_price: 500.0,
        listed_shares: 100_000,
        high_52w: 600.0,
        low_52w: 400.0
      )

      allow(market_client).to receive(:fetch).and_return(
        {
          success: true,
          rows: [
            {
              symbol: "NABIL",
              open_price: 510.0,
              high_price: 545.0,
              low_price: 505.0,
              close_price: 540.0,
              last_price: 540.0,
              previous_close: 500.0,
              change_amount: 40.0,
              change_percent: 8.0,
              volume: 12_000,
              turnover: 6_480_000.0,
              total_trades: 130,
              high_52w: 650.0,
              low_52w: 390.0,
              traded_on: traded_on,
              fetched_at: Time.zone.parse("2026-07-27 15:00:00")
            },
            {
              symbol: "UNKNOWN",
              open_price: 100.0,
              high_price: 100.0,
              low_price: 100.0,
              close_price: 100.0,
              last_price: 100.0,
              previous_close: 95.0,
              change_amount: 5.0,
              change_percent: 5.26,
              volume: 1_000,
              turnover: 100_000.0,
              total_trades: 5,
              high_52w: 110.0,
              low_52w: 90.0,
              traded_on: traded_on,
              fetched_at: Time.zone.parse("2026-07-27 15:00:00")
            }
          ]
        }
      )

      result

      seeded_stock.reload
      daily_price = StockDailyPrice.find_by!(stock: seeded_stock, traded_on: traded_on)

      expect(seeded_stock.last_price.to_f).to eq(540.0)
      expect(seeded_stock.change_percent.to_f).to eq(8.0)
      expect(seeded_stock.volume).to eq(12_000)
      expect(seeded_stock.high_52w.to_f).to eq(650.0)
      expect(seeded_stock.low_52w.to_f).to eq(390.0)
      expect(daily_price.close_price.to_f).to eq(540.0)
      expect(daily_price.previous_close.to_f).to eq(500.0)
      expect(daily_price.total_trades).to eq(130)
      new_listing = Stock.find_by!(symbol: "UNKNOWN")
      expect(new_listing).to have_attributes(name: "UNKNOWN", sector: "Others", security_type: "Equity", is_active: true)
      expect(new_listing.last_price.to_f).to eq(100.0)
      expect(StockDailyPrice.find_by!(stock: new_listing, traded_on: traded_on).close_price.to_f).to eq(100.0)
      expect(result[:market]).to include(processed: 2, created_symbols: [ "UNKNOWN" ], rejected_symbols: [])
    end

    it "preserves existing stored values when market fields are missing or unparsable" do
      seeded_stock = create(
        :stock,
        symbol: "NABIL",
        last_price: 500.0,
        change_percent: 4.5,
        volume: 12_000,
        listed_shares: 100_000,
        market_cap: 50_000_000.0,
        high_52w: 600.0,
        low_52w: 400.0
      )
      existing_daily_price = create(
        :stock_daily_price,
        stock: seeded_stock,
        traded_on: traded_on,
        open_price: 505.0,
        high_price: 515.0,
        low_price: 495.0,
        close_price: 500.0,
        previous_close: 490.0,
        change_amount: 10.0,
        change_percent: 2.04,
        volume: 9_000,
        turnover: 4_500_000.0,
        total_trades: 80
      )

      allow(market_client).to receive(:fetch).and_return(
        {
          success: true,
          rows: [
            {
              symbol: "NABIL",
              open_price: nil,
              high_price: "--",
              low_price: "N/A",
              close_price: nil,
              last_price: "--",
              previous_close: nil,
              change_amount: nil,
              change_percent: "N/A",
              volume: "--",
              turnover: nil,
              total_trades: "N/A",
              high_52w: "--",
              low_52w: nil,
              traded_on: traded_on,
              fetched_at: Time.zone.parse("2026-07-27 15:00:00")
            }
          ]
        }
      )

      sync_result = result

      seeded_stock.reload
      existing_daily_price.reload

      expect(sync_result[:market]).to include(success: true, processed: 1, rejected_symbols: [])
      expect(seeded_stock.last_price.to_f).to eq(500.0)
      expect(seeded_stock.change_percent.to_f).to eq(4.5)
      expect(seeded_stock.volume).to eq(12_000)
      expect(seeded_stock.market_cap.to_f).to eq(50_000_000.0)
      expect(seeded_stock.high_52w.to_f).to eq(600.0)
      expect(seeded_stock.low_52w.to_f).to eq(400.0)
      expect(existing_daily_price.open_price.to_f).to eq(505.0)
      expect(existing_daily_price.high_price.to_f).to eq(515.0)
      expect(existing_daily_price.low_price.to_f).to eq(495.0)
      expect(existing_daily_price.close_price.to_f).to eq(500.0)
      expect(existing_daily_price.previous_close.to_f).to eq(490.0)
      expect(existing_daily_price.change_amount.to_f).to eq(10.0)
      expect(existing_daily_price.change_percent.to_f).to eq(2.04)
      expect(existing_daily_price.volume).to eq(9_000)
      expect(existing_daily_price.turnover.to_f).to eq(4_500_000.0)
      expect(existing_daily_price.total_trades).to eq(80)
    end

    it "persists fundamentals into stocks and a mutable latest financial snapshot" do
      stock = create(:stock, symbol: "NABIL", sector: "Commercial Banks", listed_shares: 100_000, market_cap: 50_000_000.0)
      existing_financial = create(
        :stock_company_financial,
        stock: stock,
        fiscal_year: "latest",
        quarter: "Annual",
        eps: 21.0,
        pe_ratio: 19.0,
        book_value: 205.0,
        pb_ratio: 2.4
      )

      allow(company_client).to receive(:fetch).with("NABIL").and_return(
        {
          success: true,
          symbol: "NABIL",
          fundamentals: {
            sector: "Commercial Banks",
            listed_shares: 125_000,
            market_cap: 67_500_000.0,
            eps: 22.5,
            pe_ratio: 24.0,
            book_value: 210.0,
            pb_ratio: 2.57,
            fiscal_year: "latest",
            quarter: "Annual"
          }
        }
      )

      expect { result }.not_to change(StockCompanyFinancial, :count)

      stock.reload
      existing_financial.reload

      expect(stock.listed_shares).to eq(125_000)
      expect(stock.market_cap.to_f).to eq(67_500_000.0)
      expect(existing_financial.eps.to_f).to eq(22.5)
      expect(existing_financial.pe_ratio.to_f).to eq(24.0)
      expect(existing_financial.book_value.to_f).to eq(210.0)
      expect(existing_financial.pb_ratio.to_f).to eq(2.57)
      expect(result[:fundamentals]).to include(processed: 1, failed_symbols: [])
    end

    it "recalculates market cap when the source omits it" do
      stock = create(:stock, symbol: "NABIL", last_price: 500.0, listed_shares: 100_000, market_cap: 50_000_000.0)

      allow(market_client).to receive(:fetch).and_return(
        {
          success: true,
          rows: [
            {
              symbol: "NABIL",
              open_price: 500.0,
              high_price: 520.0,
              low_price: 490.0,
              close_price: 550.0,
              last_price: 550.0,
              previous_close: 500.0,
              change_amount: 50.0,
              change_percent: 10.0,
              volume: 10_000,
              turnover: 5_500_000.0,
              total_trades: 100,
              high_52w: 600.0,
              low_52w: 450.0,
              traded_on: traded_on,
              fetched_at: Time.zone.parse("2026-07-27 15:00:00")
            }
          ]
        }
      )

      allow(company_client).to receive(:fetch).with("NABIL").and_return(
        {
          success: true,
          symbol: "NABIL",
          fundamentals: {
            sector: "Commercial Banks",
            listed_shares: 200_000,
            market_cap: nil,
            eps: 20.0,
            pe_ratio: 27.5,
            book_value: 180.0,
            pb_ratio: 3.06,
            fiscal_year: "latest",
            quarter: "Annual"
          }
        }
      )

      result

      expect(stock.reload.market_cap.to_f).to eq(110_000_000.0)
    end

    it "continues after a single-symbol fundamentals failure" do
      create(:stock, symbol: "NABIL")
      create(:stock, symbol: "EBL")

      allow(company_client).to receive(:fetch).with("NABIL").and_return(
        { success: false, symbol: "NABIL", error: { code: :request_failed, message: "timeout" } }
      )
      allow(company_client).to receive(:fetch).with("EBL").and_return(
        {
          success: true,
          symbol: "EBL",
          fundamentals: {
            sector: "Commercial Banks",
            listed_shares: 300_000,
            market_cap: 180_000_000.0,
            eps: 30.0,
            pe_ratio: 20.0,
            book_value: 250.0,
            pb_ratio: 2.4,
            fiscal_year: "latest",
            quarter: "Annual"
          }
        }
      )

      result

      expect(Stock.find_by(symbol: "EBL").company_financials.find_by(fiscal_year: "latest", quarter: "Annual")).to be_present
      expect(result[:fundamentals]).to include(processed: 1, failed_symbols: [ "NABIL" ], aborted: false)
    end

    it "aborts fundamentals when the failure rate crosses the threshold" do
      create(:stock, symbol: "NABIL")
      create(:stock, symbol: "EBL")
      create(:stock, symbol: "SCB")
      allow(market_client).to receive(:fetch).and_return({ success: true, rows: [] })

      allow(company_client).to receive(:fetch).with("NABIL").and_return(
        { success: false, symbol: "NABIL", error: { code: :request_failed, message: "timeout" } }
      )
      allow(company_client).to receive(:fetch).with("EBL").and_return(
        { success: false, symbol: "EBL", error: { code: :request_failed, message: "timeout" } }
      )

      threshold_result = described_class.call(
        traded_on: traded_on,
        market_client: market_client,
        company_client: company_client,
        fundamentals_failure_threshold: 0.5,
        request_delay_seconds: 0
      )

      expect(company_client).not_to have_received(:fetch).with("SCB")
      expect(threshold_result[:success]).to be false
      expect(threshold_result[:fundamentals]).to include(success: false, processed: 0, failed_symbols: [ "NABIL", "EBL" ], aborted: true)
    end

    it "preserves existing stored values when fundamentals data is missing" do
      stock = create(:stock, symbol: "NABIL", sector: "Commercial Banks", listed_shares: 100_000, market_cap: 50_000_000.0)
      financial = create(
        :stock_company_financial,
        stock: stock,
        fiscal_year: "latest",
        quarter: "Annual",
        eps: 18.0,
        pe_ratio: 22.0,
        book_value: 190.0,
        pb_ratio: 2.63
      )

      allow(company_client).to receive(:fetch).with("NABIL").and_return(
        {
          success: true,
          symbol: "NABIL",
          fundamentals: {
            sector: nil,
            listed_shares: nil,
            market_cap: nil,
            eps: nil,
            pe_ratio: nil,
            book_value: nil,
            pb_ratio: nil,
            fiscal_year: "latest",
            quarter: "Annual"
          }
        }
      )

      sync_result = result

      stock.reload
      financial.reload

      expect(sync_result[:fundamentals]).to include(success: true, processed: 1, failed_symbols: [], aborted: false)
      expect(stock.sector).to eq("Commercial Banks")
      expect(stock.listed_shares).to eq(100_000)
      expect(stock.market_cap.to_f).to eq(50_000_000.0)
      expect(financial.eps.to_f).to eq(18.0)
      expect(financial.pe_ratio.to_f).to eq(22.0)
      expect(financial.book_value.to_f).to eq(190.0)
      expect(financial.pb_ratio.to_f).to eq(2.63)
    end

    it "preserves existing stored values when fundamentals data is unparsable" do
      stock = create(:stock, symbol: "NABIL", sector: "Commercial Banks", listed_shares: 100_000, market_cap: 50_000_000.0)
      financial = create(
        :stock_company_financial,
        stock: stock,
        fiscal_year: "latest",
        quarter: "Annual",
        eps: 18.0,
        pe_ratio: 22.0,
        book_value: 190.0,
        pb_ratio: 2.63
      )

      allow(company_client).to receive(:fetch).with("NABIL").and_return(
        {
          success: true,
          symbol: "NABIL",
          fundamentals: {
            sector: "--",
            listed_shares: "N/A",
            market_cap: "--",
            eps: "N/A",
            pe_ratio: "--",
            book_value: "N/A",
            pb_ratio: "--",
            fiscal_year: "latest",
            quarter: "Annual"
          }
        }
      )

      sync_result = result

      stock.reload
      financial.reload

      expect(sync_result[:fundamentals]).to include(success: true, processed: 1, failed_symbols: [], aborted: false)
      expect(stock.sector).to eq("Commercial Banks")
      expect(stock.listed_shares).to eq(100_000)
      expect(stock.market_cap.to_f).to eq(50_000_000.0)
      expect(financial.eps.to_f).to eq(18.0)
      expect(financial.pe_ratio.to_f).to eq(22.0)
      expect(financial.book_value.to_f).to eq(190.0)
      expect(financial.pb_ratio.to_f).to eq(2.63)
    end

    it "waits briefly between fundamentals requests" do
      create(:stock, symbol: "NABIL")
      create(:stock, symbol: "EBL")
      allow(company_client).to receive(:fetch).with("NABIL").and_return(
        { success: false, symbol: "NABIL", error: { code: :request_failed, message: "timeout" } }
      )
      allow(company_client).to receive(:fetch).with("EBL").and_return(
        {
          success: true,
          symbol: "EBL",
          fundamentals: {
            fiscal_year: "latest",
            quarter: "Annual"
          }
        }
      )

      expect_any_instance_of(described_class).to receive(:sleep).with(0.25).once

      described_class.call(
        traded_on: traded_on,
        market_client: market_client,
        company_client: company_client,
        fundamentals_failure_threshold: fundamentals_failure_threshold,
        request_delay_seconds: 0.25
      )
    end
  end

  describe ".sync_market" do
    it "infers the security type of new listings from the symbol" do
      market_client = instance_double(Nepse::Source::SharesansarMarketClient)
      rows = %w[NICAD85/86 SBID83 GBBLPO NEWCO].map do |symbol|
        { symbol: symbol, last_price: 100.0, previous_close: 100.0, traded_on: Date.new(2026, 9, 27) }
      end
      allow(market_client).to receive(:fetch).and_return({ success: true, rows: rows })

      result = described_class.sync_market(traded_on: Date.new(2026, 9, 27), market_client: market_client)

      expect(result).to include(success: true, processed: 4, created_symbols: %w[NICAD85/86 SBID83 GBBLPO NEWCO])
      expect(Stock.where(symbol: rows.map { _1[:symbol] }).pluck(:symbol, :security_type).to_h).to eq(
        "NICAD85/86" => "Debenture",
        "SBID83" => "Debenture",
        "GBBLPO" => "Promoter Share",
        "NEWCO" => "Equity"
      )
    end
  end
end
