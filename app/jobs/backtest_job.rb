# Re-runs the backtest over the stored snapshots (queued after the nightly snapshots).
class BacktestJob < ApplicationJob
  queue_as :heavy

  def perform
    result = Backtest::Runner.call
    Rails.logger.info("BacktestJob: run #{result[:run_id].inspect}")
    # Warm the indicator scan so the first visit after the close is fast, then tell
    # users about new matches for their saved scanner filter.
    Scans::Cache.crossovers
    TelegramScannerJob.perform_later
    GC.start
    result
  end
end
