# Nightly trim of old history (Maintenance::DataRetention).
class DataRetentionJob < ApplicationJob
  queue_as :heavy

  def perform
    result = Maintenance::DataRetention.call
    Rails.logger.info("DataRetentionJob: #{result.inspect}")
    result
  end
end
