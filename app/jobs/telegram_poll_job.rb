# Every minute: reads the bot's new messages to link ("/start <code>") or unlink ("/stop") chats.
class TelegramPollJob < ApplicationJob
  queue_as :default

  def perform
    return unless Telegram::Client.configured?

    Telegram::Linker.poll
  rescue Telegram::Error => e
    Rails.logger.warn("TelegramPollJob: #{e.message}")
    nil
  end
end
