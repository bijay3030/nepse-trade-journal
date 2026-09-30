# Refreshes reference data on a tiered schedule (see config/recurring.yml):
#   "daily"  - securities list, dividends, index history, price history for new
#              listings, broker names and the floorsheet (broker flows)
#   "weekly" - fundamentals (one Merolagani page per security, so it is slow)
class SyncReferenceDataJob < ApplicationJob
  queue_as :default

  def perform(kind = "daily")
    case kind.to_s
    when "daily"
      universe = Nepse::Reference::UniverseSync.call
      if universe[:success] && universe[:created].any?
        Nepse::HistoryBackfillService.call(symbols: universe[:created])
        Indicators::BatchCalculatorService.call(symbols: universe[:created], recalculate_all: true)
      end
      log("universe", universe)
      log("dividends", Nepse::Reference::DividendSync.call)
      # Book-close warnings and bonus adjustments for watchlist levels and price history.
      log("watchlist corporate actions", CorporateActions::WatchlistUpdater.call)
      log("bonus history refresh", CorporateActions::HistoryRefresh.call)
      log("indices", Nepse::Reference::IndexHistorySync.call(days: 14))
      # Floorsheet for any recent sessions not stored yet (normally just today's).
      log("brokers", Flows::BrokerSync.call)
      log("floorsheet", Flows::Backfill.call(sessions: 5))
    when "weekly"
      log("fundamentals", Nepse::Reference::FundamentalsSync.call)
    else
      raise ArgumentError, "Unknown reference data kind #{kind.inspect}"
    end
  end

  private

  def log(step, result)
    Rails.logger.info("SyncReferenceDataJob #{step}: #{result.except(:failed, :none, :skipped).inspect} failed=#{Array(result[:failed]).size}")
    result
  end
end
