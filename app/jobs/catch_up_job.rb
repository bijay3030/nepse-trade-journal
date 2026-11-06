# Fills in sessions the scheduled jobs missed (Maintenance::CatchUp). Runs shortly
# after the server starts and every hour; does nothing when the data is current.
class CatchUpJob < ApplicationJob
  queue_as :heavy
  limits_concurrency to: 1, key: "catch_up", duration: 3.hours

  def perform
    result = Maintenance::CatchUp.call
    Rails.logger.info("CatchUpJob: #{result.except(:indices).inspect}")
    result
  end
end
