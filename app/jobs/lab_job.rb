# After the nightly backtest: re-runs the Strategy Lab, records new candidates as paper
# trades and moves the open ones on (Lab::PaperTrades).
class LabJob < ApplicationJob
  queue_as :heavy

  def perform
    report = Lab::PaperTrades.refresh!
    Lab::Cache.write(report)
    Rails.logger.info("LabJob: #{report[:candidates].size} candidates")
    GC.start
    report[:candidates].size
  end
end
