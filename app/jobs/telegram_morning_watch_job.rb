# 9 AM Nepal time: each linked user's saved-filter stocks in or near their entry zone
# (Scans::MorningWatch). Skips days NEPSE doesn't trade.
class TelegramMorningWatchJob < ApplicationJob
  queue_as :default

  def perform
    return unless Telegram::Client.configured?

    results = Scans::MorningWatch.deliver
    Rails.logger.info("TelegramMorningWatchJob: #{results.values.tally.inspect}")
    results
  end
end
