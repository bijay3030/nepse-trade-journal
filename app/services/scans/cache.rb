module Scans
  # The crossover scan and its backtest, cached until the next completed session.
  module Cache
    module_function

    def crossovers
      session = Nepse::MarketHours.sync_window? ? "open" : "closed"
      scan = Rails.cache.fetch([ "scans/crossovers", StockDailyPrice.maximum(:traded_on), session ], expires_in: 30.minutes) { Crossovers.call }
      backtest = Rails.cache.fetch([ "scans/crossovers/backtest", scan[:as_of] ], expires_in: 12.hours) { CrossoverBacktest.call }
      scan.merge(backtest: backtest)
    end
  end
end
