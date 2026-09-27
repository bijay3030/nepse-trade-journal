class IngestMarketDataJob < ApplicationJob
  queue_as :default

  def perform(date_string = nil, provider = :yonepse)
    target_date = date_string.present? ? Date.parse(date_string.to_s) : Date.current
    Rails.logger.info("Executing IngestMarketDataJob for date: #{target_date} using provider: #{provider}")

    result = Nepse::MarketDataIngestionService.call(target_date, provider: provider)
    Rails.logger.info("IngestMarketDataJob completed for #{target_date}: #{result.inspect}")
    result
  end
end
