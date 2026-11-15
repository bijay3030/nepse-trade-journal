module Scans
  # The crossover scan and its backtest, cached until the next completed session.
  module Cache
    # Bump when the scan's settings or output change, so a deploy doesn't serve the old ones.
    VERSION = 3

    module_function

    # The scan alone (the live entry alerts don't need the backtest).
    def scan
      session = Nepse::MarketHours.sync_window? ? "open" : "closed"
      Rails.cache.fetch([ "scans/crossovers", VERSION, StockDailyPrice.maximum(:traded_on), session ], expires_in: 30.minutes) { Crossovers.call }
    end

    def crossovers
      scan = self.scan
      backtest = Rails.cache.fetch([ "scans/crossovers/backtest", VERSION, scan[:as_of] ], expires_in: 12.hours) { CrossoverBacktest.call }
      scan.merge(backtest: backtest, market_phase: MarketPhase.current(as_of: scan[:as_of]))
    end
  end
end
