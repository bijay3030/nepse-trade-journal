# After the nightly snapshot: the session's market summary to linked users
# (MarketIndex::DailySummary).
class TelegramMarketSummaryJob < ApplicationJob
  queue_as :default

  def perform
    return unless Telegram::Client.configured?

    results = MarketIndex::DailySummary.deliver
    Rails.logger.info("TelegramMarketSummaryJob: #{results.values.tally.inspect}")
    results
  end
end
