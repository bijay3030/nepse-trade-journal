namespace :nepse do
  desc "Fetch today's daily floor sheet prices from free endpoints"
  task fetch_daily: :environment do
    puts "Fetching NEPSE daily price data..."
    result = Nepse::DailyPriceImporterService.call
    if result[:success]
      puts "Daily prices processed for #{result[:date]}: #{result[:processed]} records updated. Fallback used: #{result[:fallback_used]}"
    else
      puts "Failed to fetch daily prices: #{result[:error]}"
    end
  end

  desc "Backfill daily price history from Merolagani, then recalculate indicators. Usage: rails \"nepse:backfill_history[365,NABIL NICA]\""
  task :backfill_history, [ :days, :symbols ] => :environment do |_t, args|
    days = (args[:days].presence || Nepse::HistoryBackfillService::DEFAULT_DAYS).to_i
    symbols = args[:symbols].to_s.split(/[\s,]+/).presence
    scope = symbols ? "#{symbols.size} symbols" : "#{Stock.active.count} active stocks"
    puts "Backfilling #{days} days of history for #{scope} (about #{Nepse::HistoryBackfillService::DEFAULT_DELAY_SECONDS}s per stock)..."

    result = Nepse::HistoryBackfillService.call(symbols: symbols, days: days)
    puts "Stocks: #{result[:stocks]}, bars written: #{result[:bars]}, stale rows removed: #{result[:removed]}, failed: #{result[:failed].size}"
    result[:failed].first(10).each { |symbol, error| puts "  #{symbol}: #{error}" }

    puts "Recalculating indicators..."
    indicators = Indicators::BatchCalculatorService.call(symbols: symbols, recalculate_all: true)
    puts "Indicators: #{indicators.except(:errors).inspect}"
  end

  desc "Import stock price or fundamental records from CSV"
  task :import_csv, [ :file_path, :type ] => :environment do |_t, args|
    file_path = args[:file_path]
    type = args[:type] || "prices"

    if file_path.blank?
      puts "Usage: rails nepse:import_csv[path/to/file.csv,prices|financials]"
      next
    end

    puts "Importing #{type} from #{file_path}..."
    result = Nepse::CsvImporterService.call(file_path, type: type)
    if result[:success]
      puts "Successfully imported #{result[:imported]} records!"
    else
      errors = Array(result[:errors]).presence || Array(result[:error]).presence || [ "Unknown error" ]
      puts "Import completed with errors. Imported: #{result[:imported]}. Errors: #{errors.join(', ')}"
    end
  end
end
