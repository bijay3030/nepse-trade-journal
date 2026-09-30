# Refreshes reference data on a tiered schedule (see config/recurring.yml):
#   "daily"  - securities list, dividends, index history, and price history for new listings
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
      log("indices", Nepse::Reference::IndexHistorySync.call(days: 14))
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
