# After the close (queued by BacktestJob, once the scan is fresh): messages users about
# stocks newly matching their saved Indicator Scanner filter (Scans::Alerts).
class TelegramScannerJob < ApplicationJob
  queue_as :default

  def perform
    return unless Telegram::Client.configured?

    results = Scans::Alerts.deliver
    Rails.logger.info("TelegramScannerJob: #{results.values.tally.inspect}")
    results
  end
end
