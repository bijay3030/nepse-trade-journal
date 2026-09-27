namespace :nepse do
  desc "Seed all NEPSE listed stocks into the database"
  task seed_stocks: :environment do
    puts "[Seed] Importing NEPSE master stocks..."
    result = Nepse::MasterImporterService.call

    if result[:success]
      puts "[Seed] Created: #{result[:created]}, Updated: #{result[:updated]}, Total: #{result[:total]}"
    else
      error_message = result[:error] || result[:message] || "NEPSE stock seed failed"
      puts "[Seed] Failed: #{error_message}"
      raise error_message
    end
  end

  desc "Fetch latest daily prices for all NEPSE stocks from external API"
  task fetch_prices: :environment do
    puts "Fetching daily prices for #{Stock.active.count} stocks from external API..."
    result = Nepse::DailyPriceImporterService.call
    puts "Import Complete! Processed: #{result[:processed]}, Fallbacks: #{result[:fallback_used]}"
  end

  desc "Sync latest market data from Sharesansar"
  task sync_market: [ :environment, :seed_stocks ] do
    puts "[Market: Sharesansar] Syncing stock market data..."

    result = Nepse::StockBasicsSyncService.sync_market

    if result[:success]
      puts "[Market: Sharesansar] Processed: #{result[:processed]}, Rejected: #{result[:rejected_symbols].size}, Total Rows: #{result[:total_rows]}"
    else
      puts "[Market: Sharesansar] Failed: #{result[:error]}"
    end
  end

  desc "Sync stock fundamentals from Merolagani"
  task sync_fundamentals: [ :environment, :seed_stocks ] do
    puts "[Fundamentals: Merolagani] Syncing company fundamentals..."

    result = Nepse::StockBasicsSyncService.sync_fundamentals(
      traded_on: Date.current,
      market_client: Nepse::Source::SharesansarMarketClient.new,
      company_client: Nepse::Source::MerolaganiCompanyClient.new,
      fundamentals_failure_threshold: Nepse::StockBasicsSyncService::DEFAULT_FAILURE_THRESHOLD,
      request_delay_seconds: Nepse::StockBasicsSyncService::DEFAULT_REQUEST_DELAY_SECONDS
    )

    if result[:success]
      puts "[Fundamentals: Merolagani] Processed: #{result[:processed]}, Failed: #{result[:failed_symbols].size}, Total Symbols: #{result[:total_symbols]}"
    else
      puts "[Fundamentals: Merolagani] Failed: #{result[:error] || 'aborted due to failure threshold'}"
    end
  end

  desc "Sync NEPSE stock basics from Sharesansar and Merolagani"
  task sync_stock_basics: [ :environment, :seed_stocks ] do
    result = Nepse::StockBasicsSyncService.call
    market_result = result[:market] || {}
    fundamentals_result = result[:fundamentals] || {}

    puts "[Market: Sharesansar] Syncing stock market data..."
    if market_result[:success]
      puts "[Market: Sharesansar] Processed: #{market_result[:processed]}, Rejected: #{market_result[:rejected_symbols].size}, Total Rows: #{market_result[:total_rows]}"
    else
      puts "[Market: Sharesansar] Failed: #{market_result[:error]}"
    end

    if result[:success] || result.key?(:fundamentals)
      puts "[Fundamentals: Merolagani] Syncing company fundamentals..."

      if fundamentals_result[:success]
        puts "[Fundamentals: Merolagani] Processed: #{fundamentals_result[:processed]}, Failed: #{fundamentals_result[:failed_symbols].size}, Total Symbols: #{fundamentals_result[:total_symbols]}"
      else
        puts "[Fundamentals: Merolagani] Failed: #{fundamentals_result[:error] || 'aborted due to failure threshold'}"
      end
    end
  end

  desc "Compatibility alias for sync_market"
  task scrape_market: :sync_market

  desc "Compatibility alias for sync_fundamentals"
  task scrape_fundamentals: :sync_fundamentals

  desc "Compatibility alias for sync_stock_basics"
  task scrape_all: :sync_stock_basics do
    puts "NEPSE stock basics sync complete."
  end

  desc "Seed all stocks and fetch their current live prices"
  task sync_all: [ :seed_stocks, :fetch_prices ] do
    puts "NEPSE stocks and daily prices fully synchronized."
  end
end
