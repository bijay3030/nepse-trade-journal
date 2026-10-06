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
    return result unless force

    unless result[:success]
      Rails.logger.warn("SyncMarketPricesJob: market sync failed, falling back to per-symbol prices")
      result = Nepse::DailyPriceImporterService.call
      Nepse::LivePriceSync.publish if result[:success]
    end

    # The forced run is the end-of-day one: judge each setup on the close.
    result = result.merge(close: Watchlist::CloseEvaluator.call, positions: Positions::Monitor.call(close: true)) if result[:success]
    result
  end
end
