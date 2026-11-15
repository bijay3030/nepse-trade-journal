module Scans
  # The crossover scan and its backtest, cached until the next completed session.
  module Cache
    # Bump when the scan's settings or output change, so a deploy doesn't serve the old ones.
    VERSION = 2

    module_function

    def crossovers
      session = Nepse::MarketHours.sync_window? ? "open" : "closed"
      scan = Rails.cache.fetch([ "scans/crossovers", VERSION, StockDailyPrice.maximum(:traded_on), session ], expires_in: 30.minutes) { Crossovers.call }
      backtest = Rails.cache.fetch([ "scans/crossovers/backtest", VERSION, scan[:as_of] ], expires_in: 12.hours) { CrossoverBacktest.call }
      scan.merge(backtest: backtest)
    end
  end
end
