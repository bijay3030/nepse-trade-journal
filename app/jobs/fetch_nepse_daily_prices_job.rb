class FetchNepseDailyPricesJob < ApplicationJob
  queue_as :default

  def perform(date_string = nil)
    target_date = date_string.present? ? Date.parse(date_string) : Date.current
    Rails.logger.info("Executing FetchNepseDailyPricesJob for date: #{target_date}")

    result = Nepse::DailyPriceImporterService.call(target_date)
    Rails.logger.info("FetchNepseDailyPricesJob finished: #{result.inspect}")
  end
end
