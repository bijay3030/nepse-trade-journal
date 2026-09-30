# After the close: bring indicators up to date, rebuild the setup snapshots
# (trend template, relative strength, zones, broker flow, readiness) for the latest
# session, then re-run the backtest so it includes the new session.
class BuildSetupSnapshotsJob < ApplicationJob
  queue_as :default

  def perform
    indicators = Indicators::BatchCalculatorService.call
    result = Setups::SnapshotBuilder.call
    backtest = Backtest::Runner.call if result[:success]
    Rails.logger.info("BuildSetupSnapshotsJob: backtest run #{backtest&.dig(:run_id).inspect}")
    Rails.logger.info("BuildSetupSnapshotsJob: indicators=#{indicators[:processed_indicators]} #{result.except(:failed).inspect} failed=#{result[:failed]&.size}")
    result
  end
end
