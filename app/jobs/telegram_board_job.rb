# After the nightly snapshot: tells linked users about stocks new on "Entry zone now".
class TelegramBoardJob < ApplicationJob
  queue_as :default

  def perform
    return unless Telegram::Client.configured?

    results = Telegram::Notifier.entry_zone_board
    Rails.logger.info("TelegramBoardJob: #{results.values.tally.inspect}")
    results
  end
end
