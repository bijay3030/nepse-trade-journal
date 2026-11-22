# Hourly: collects company announcements and corporate actions (Events::Sync), then
# tells users on Telegram (Events::Alerts).
class MarketEventsJob < ApplicationJob
  queue_as :default

  def perform(pages: Events::Sync::PAGES)
    result = Events::Sync.call(pages: pages)
    alerts = Telegram::Client.configured? ? Events::Alerts.deliver : {}
    Events::BookCloseStudy.cached # warm the page's study once a day
    Rails.logger.info("MarketEventsJob: #{result.inspect} alerts=#{alerts.values.tally.inspect}")
    result.merge(alerts: alerts)
  end
end
