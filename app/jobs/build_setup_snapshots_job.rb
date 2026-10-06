# After the close: bring indicators up to date, rebuild the setup snapshots
# (trend template, relative strength, zones, broker flow, readiness) for the latest
# session, then queue the backtest re-run (a job of its own, so its memory peak doesn't
# stack on this one's on a small host), each user's daily digest, and Telegram
# messages for stocks new on the board.
class BuildSetupSnapshotsJob < ApplicationJob
  queue_as :heavy

  def perform
    indicators = Indicators::BatchCalculatorService.call
    result = Setups::SnapshotBuilder.call
    if result[:success]
      BacktestJob.perform_later
      BuildDailyDigestsJob.perform_later
      TelegramBoardJob.perform_later
    end
    Rails.logger.info("BuildSetupSnapshotsJob: indicators=#{indicators[:processed_indicators]} #{result.except(:failed).inspect} failed=#{result[:failed]&.size}")
    result
  end
end
