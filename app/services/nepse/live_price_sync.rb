module Nepse
  # Pulls the latest market table and pushes the updated quotes to connected
  # browsers over the StockPricesChannel.
  class LivePriceSync
    CHANNEL = "stock_prices".freeze

    def self.call(market_sync: -> { Nepse::StockBasicsSyncService.sync_market })
      result = market_sync.call
      publish if result[:success]
      result
    end

    # Runs after any price update: records the running volumes (for the volume
    # pace), checks watchlist levels, then pushes quotes.
    def self.publish
      Nepse::VolumeProfile.record!
      Watchlist::AlertEvaluator.call
      broadcast
    end

    def self.broadcast
      ActionCable.server.broadcast(
        CHANNEL,
        { prices: Stock.active.order(:symbol).map(&:quote_payload), broadcasted_at: Time.current }
      )
    end
  end
end
