# After the close: bring indicators up to date, then rebuild the setup snapshots
# (trend template, relative strength, zones, buy readiness) for the latest session.
class BuildSetupSnapshotsJob < ApplicationJob
  queue_as :default

  def perform
    indicators = Indicators::BatchCalculatorService.call
    result = Setups::SnapshotBuilder.call
    Rails.logger.info("BuildSetupSnapshotsJob: indicators=#{indicators[:processed_indicators]} #{result.except(:failed).inspect} failed=#{result[:failed]&.size}")
    result
  end
end
