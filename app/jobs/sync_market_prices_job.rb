class SyncMarketPricesJob < ApplicationJob
  queue_as :default

  # Runs every few minutes. Outside market hours it does nothing unless forced,
  # which the end-of-day schedule does to record closing prices.
  def perform(force = false)
    unless force || Nepse::MarketHours.sync_window?
      return { success: true, skipped: :market_closed }
    end

    result = Nepse::LivePriceSync.call
    Rails.logger.info("SyncMarketPricesJob finished: #{result.except(:created_symbols, :rejected_symbols).inspect}")
    return result if result[:success] || !force

    Rails.logger.warn("SyncMarketPricesJob: market sync failed, falling back to per-symbol prices")
    fallback = Nepse::DailyPriceImporterService.call
    Nepse::LivePriceSync.publish if fallback[:success]
    fallback
  end
end
