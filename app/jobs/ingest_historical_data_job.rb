class IngestHistoricalDataJob < ApplicationJob
  queue_as :default

  def perform(start_date_string = nil, end_date_string = nil, symbols = nil, batch_size = 20, provider = :historical)
    start_date = start_date_string.present? ? Date.parse(start_date_string.to_s) : 365.days.ago.to_date
    end_date = end_date_string.present? ? Date.parse(end_date_string.to_s) : Date.current

    Rails.logger.info("Executing IngestHistoricalDataJob: #{start_date} to #{end_date}, provider: #{provider}")

    result = Nepse::HistoricalDataIngestionService.call(
      start_date: start_date,
      end_date: end_date,
      symbols: symbols,
      batch_size: batch_size,
      provider: provider
    )

    Rails.logger.info("IngestHistoricalDataJob completed: #{result.inspect}")
    result
  end
end
