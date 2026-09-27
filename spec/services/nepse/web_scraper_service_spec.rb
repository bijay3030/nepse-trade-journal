require "rails_helper"

RSpec.describe Nepse::WebScraperService do
  describe ".scrape_market_prices!" do
    it "runs only the market sync path and returns the compatibility payload" do
      market_result = { success: true, processed: 3, rejected_symbols: [ "SKIP" ] }

      allow(Nepse::MasterImporterService).to receive(:call).and_return(success: true, created: 2, updated: 0, total: 2)
      allow(Nepse::StockBasicsSyncService).to receive(:sync_market).and_return(market_result)
      allow(Nepse::StockBasicsSyncService).to receive(:call)

      expect(described_class.scrape_market_prices!).to eq(
        success: true,
        source: "Sharesansar",
        processed: 3,
        created: 0,
        date: Date.current,
        rejected_symbols: [ "SKIP" ]
      )
      expect(Nepse::MasterImporterService).to have_received(:call)
      expect(Nepse::StockBasicsSyncService).to have_received(:sync_market)
      expect(Nepse::StockBasicsSyncService).not_to have_received(:call)
    end

    it "preserves market sync error detail in the compatibility payload" do
      market_result = { success: false, error: "Sharesansar market table not found", processed: 0, rejected_symbols: [] }

      allow(Nepse::MasterImporterService).to receive(:call).and_return(success: true, created: 2, updated: 0, total: 2)
      allow(Nepse::StockBasicsSyncService).to receive(:sync_market).and_return(market_result)

      expect(described_class.scrape_market_prices!).to eq(
        success: false,
        source: "Sharesansar",
        processed: 0,
        created: 0,
        date: Date.current,
        rejected_symbols: [],
        error: "Sharesansar market table not found"
      )
    end
  end

  describe ".scrape_company_fundamentals!" do
    it "delegates to the merolagani company client" do
      client = instance_double(Nepse::Source::MerolaganiCompanyClient)
      result = { success: true, symbol: "NABIL", fundamentals: { eps: 21.5 } }

      allow(Nepse::Source::MerolaganiCompanyClient).to receive(:new).and_return(client)
      allow(client).to receive(:fetch).with("NABIL").and_return(result)

      expect(described_class.scrape_company_fundamentals!("NABIL")).to eq(result)
    end
  end

  describe ".scrape_all_fundamentals!" do
    it "delegates to the fundamentals-only stock basics entrypoint while preserving the compatibility shape" do
      sync_result = {
        success: true,
        total_symbols: 2,
        processed: 2,
        failed_symbols: [],
        aborted: false
      }

      allow(Nepse::StockBasicsSyncService).to receive(:sync_fundamentals).and_return(sync_result)
      allow(Nepse::StockBasicsSyncService).to receive(:call)

      expect(described_class.scrape_all_fundamentals!).to eq(
        total: 2,
        scraped: 2,
        failed_symbols: [],
        success: true
      )
      expect(Nepse::StockBasicsSyncService).to have_received(:sync_fundamentals)
      expect(Nepse::StockBasicsSyncService).not_to have_received(:call)
    end
  end
end
