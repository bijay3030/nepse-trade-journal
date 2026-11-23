module Nepse
  # Pulls the latest market table and pushes the updated quotes to connected
  # browsers over the StockPricesChannel.
  class LivePriceSync
    CHANNEL = "stock_prices".freeze

    # Stores and pushes prices from the freshest source (Nepse::LiveFeed). When no source
    # is fresh nothing is stored or pushed, so watchlist, position and scanner alerts don't
    # act on old prices; the status says the prices are delayed. market_sync replaces the
    # whole step (tests and callers with their own source).
    def self.call(now: Time.current, sources: nil, market_sync: nil)
      return legacy(market_sync) if market_sync

      pick = LiveFeed.pick(now: now, sources: sources || LiveFeed.default_sources(now))
      unless pick[:fresh]
        LiveFeed.record(state: "delayed", now: now, reasons: pick[:reasons])
        return { success: false, stale: true, error: "No fresh prices", reasons: pick[:reasons] }
      end

      response = pick[:response]
      result = StockBasicsSyncService.new(traded_on: response[:rows].first[:traded_on], market_client: Fixed.new(response),
                                          company_client: nil, fundamentals_failure_threshold: 0, request_delay_seconds: 0).sync_market
      LiveFeed.record(state: "live", now: now, source: pick[:source], as_of: response[:as_of], reasons: pick[:reasons]) if result[:success]
      publish if result[:success]
      result.merge(source: pick[:source], as_of: response[:as_of])
    end

    def self.legacy(market_sync)
      result = market_sync.call
      publish if result[:success]
      result
    end

    # Hands StockBasicsSyncService an answer already fetched.
    Fixed = Struct.new(:response) do
      def fetch = response
    end

    # Runs after any price update: records the running volumes (for the volume
    # pace), checks watchlist levels and scanner entries, then pushes quotes.
    def self.publish
      Nepse::VolumeProfile.record!
      Watchlist::AlertEvaluator.call
      Positions::Monitor.call
      scanner_entries
      paper_trading
      broadcast
    end

    # Paper trading follows the same fresh prices; a failure here must not stop the quotes.
    def self.paper_trading
      PaperTrading::Engine.on_live
    rescue StandardError => e
      Rails.logger.warn("Paper trading (live) failed: #{e.class}: #{e.message}")
    end

    # A failure here must not stop the quotes going out.
    def self.scanner_entries
      Scans::EntryAlerts.deliver if Telegram::Client.configured?
    rescue StandardError => e
      Rails.logger.warn("Scanner entry alerts failed: #{e.class}: #{e.message}")
    end

    def self.broadcast
      ActionCable.server.broadcast(
        CHANNEL,
        { prices: Stock.active.order(:symbol).map(&:quote_payload), broadcasted_at: Time.current }
      )
    end
  end
end
