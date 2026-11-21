module Lab
  # The Strategy Lab report, cached until the next completed session. The nightly LabJob
  # refreshes it (and the paper trades); a cold cache computes it without touching them.
  module Cache
    VERSION = 1

    module_function

    def key = [ "lab/report", VERSION, StockDailyPrice.maximum(:traded_on) ]
    def report = Rails.cache.fetch(key, expires_in: 12.hours) { Backtest.call.except(:paper) }
    def write(report) = Rails.cache.write(key, report, expires_in: 12.hours)
  end
end
