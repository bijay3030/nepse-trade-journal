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
