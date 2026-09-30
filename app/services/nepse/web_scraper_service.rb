module Nepse
  class WebScraperService
    def self.scrape_market_prices!
      new.scrape_market_prices
    end

    def self.scrape_company_fundamentals!(symbol)
      new.scrape_company_fundamentals(symbol)
    end

    def self.scrape_all_fundamentals!
      new.scrape_all_fundamentals
    end

    def scrape_market_prices
      seed_result = Nepse::MasterImporterService.call
      return { success: false, error: seed_result[:error] || seed_result[:message] } unless seed_result[:success]

      result = Nepse::StockBasicsSyncService.sync_market(
        traded_on: Date.current,
        market_client: Source::SharesansarMarketClient.new,
        company_client: Source::MerolaganiCompanyClient.new,
        fundamentals_failure_threshold: Nepse::StockBasicsSyncService::DEFAULT_FAILURE_THRESHOLD,
        request_delay_seconds: Nepse::StockBasicsSyncService::DEFAULT_REQUEST_DELAY_SECONDS
      )

      response = {
        success: result[:success],
        source: "Sharesansar",
        processed: result[:processed].to_i,
        created: Array(result[:created_symbols]).size,
        date: Date.current,
        rejected_symbols: result[:rejected_symbols] || []
      }

      response[:error] = result[:error] if result[:error].present?
      response
    end

    def scrape_company_fundamentals(symbol)
      Source::MerolaganiCompanyClient.new.fetch(symbol)
    end

    def scrape_all_fundamentals
      result = Nepse::StockBasicsSyncService.sync_fundamentals(
        traded_on: Date.current,
        market_client: Source::SharesansarMarketClient.new,
        company_client: Source::MerolaganiCompanyClient.new,
        fundamentals_failure_threshold: Nepse::StockBasicsSyncService::DEFAULT_FAILURE_THRESHOLD,
        request_delay_seconds: Nepse::StockBasicsSyncService::DEFAULT_REQUEST_DELAY_SECONDS
      )

      {
        total: result[:total_symbols].to_i,
        scraped: result[:processed].to_i,
        failed_symbols: result[:failed_symbols] || [],
        success: result[:success]
      }
    end
  end
end
