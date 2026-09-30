namespace :nepse do
  namespace :data do
    def print_result(label, result)
      puts "#{label}: #{result.except(:failed, :none, :skipped, :created, :deactivated, :indices).inspect}"
      puts "  added: #{result[:created].size} #{result[:created].first(15).join(' ')}" if result[:created]
      puts "  deactivated: #{result[:deactivated].join(' ')}" if result[:deactivated].present?
      result[:indices]&.each { |symbol, info| puts "  #{symbol}: #{info}" }
      Array(result[:failed]).first(15).each { |symbol, error| puts "  failed #{symbol}: #{error}" }
      puts "  no data: #{result[:none].size}" if result[:none]
    end

    desc "Sync the list of listed securities (names, sectors, types) from Chukul"
    task universe: :environment do
      print_result("Universe", Nepse::Reference::UniverseSync.call)
    end

    desc "Sync fundamentals (Chukul, then Merolagani). Usage: rails \"nepse:data:fundamentals[NABIL NICA]\""
    task :fundamentals, [ :symbols ] => :environment do |_t, args|
      symbols = args[:symbols].to_s.split(/[\s,]+/).presence
      count = symbols&.size || Stock.active.where(security_type: Nepse::Reference::FundamentalsSync::SECURITY_TYPES).count
      puts "Syncing fundamentals for #{count} securities (about 5s each)..."
      print_result("Fundamentals", Nepse::Reference::FundamentalsSync.call(symbols: symbols))
    end

    desc "Sync cash dividend and bonus history (Chukul, then Merolagani)"
    task :dividends, [ :symbols ] => :environment do |_t, args|
      print_result("Dividends", Nepse::Reference::DividendSync.call(symbols: args[:symbols].to_s.split(/[\s,]+/).presence))
    end

    desc "Sync NEPSE and sector index history. Usage: rails \"nepse:data:indices[365]\""
    task :indices, [ :days ] => :environment do |_t, args|
      print_result("Indices", Nepse::Reference::IndexHistorySync.call(days: (args[:days].presence || 365).to_i))
    end

    desc "Import the floorsheet (broker flows) for recent sessions not stored yet. Usage: rails \"nepse:data:floorsheet[120]\""
    task :floorsheet, [ :sessions ] => :environment do |_t, args|
      sessions = (args[:sessions].presence || 120).to_i
      print_result("Brokers", Flows::BrokerSync.call)
      puts "Importing floorsheets for up to #{sessions} sessions (about 3s each)..."
      result = Flows::Backfill.call(sessions: sessions)
      puts "Imported #{result[:imported].size} sessions#{result[:imported].any? ? " (#{result[:imported].min}..#{result[:imported].max})" : ''}; failed #{result[:failed].size}"
      result[:failed].first(10).each { |date, error| puts "  #{date}: #{error}" }
    end

    desc "Rebuild buy-readiness snapshots (indicators first). Usage: rails nepse:data:setups"
    task setups: :environment do
      puts "Recalculating indicators..."
      Indicators::BatchCalculatorService.call
      result = Setups::SnapshotBuilder.call
      puts "Setups for #{result[:traded_on]}: #{result[:stocks]} stocks, in buy zone: #{Array(result[:in_buy_zone]).join(' ').presence || 'none'}"
      Array(result[:failed]).first(10).each { |symbol, error| puts "  failed #{symbol}: #{error}" }
    end

    desc "Print how complete the stored data is"
    task report: :environment do
      puts JSON.pretty_generate(Nepse::Reference::CoverageReport.call)
    end

    desc "Full load: securities, price history for new ones, indices, dividends, fundamentals, floorsheet, setups, then a report"
    task all: :environment do
      universe = Nepse::Reference::UniverseSync.call
      print_result("Universe", universe)
      if universe[:success] && universe[:created].any?
        print_result("History for new listings", Nepse::HistoryBackfillService.call(symbols: universe[:created]))
        Indicators::BatchCalculatorService.call(symbols: universe[:created], recalculate_all: true)
      end
      Rake::Task["nepse:data:indices"].invoke
      Rake::Task["nepse:data:dividends"].invoke
      Rake::Task["nepse:data:fundamentals"].invoke
      Rake::Task["nepse:data:floorsheet"].invoke
      Rake::Task["nepse:data:setups"].invoke
      Rake::Task["nepse:data:report"].invoke
    end
  end
end
