# 8 AM Nepal time on trading days: each linked user's morning brief (Scans::MorningBrief):
# the Entry zone board, what needs a human look, stocks close to their zone and the saved
# scanner filter. Skips days NEPSE doesn't trade.
class TelegramMorningWatchJob < ApplicationJob
  queue_as :default

  def perform
    return unless Telegram::Client.configured?

    results = Scans::MorningBrief.deliver
    Rails.logger.info("TelegramMorningWatchJob: #{results.values.tally.inspect}")
    results
  end
end
