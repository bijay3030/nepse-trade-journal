module Api
  module V1
    # GET /lab: the Strategy Lab (Lab::Backtest report and the paper trades).
    class LabController < BaseController
      def show
        report = Lab::Cache.report
        render json: report.merge(
          market_phase: Scans::MarketPhase.current(as_of: report[:as_of]),
          paper_trades: Lab::PaperTrades.overview
        )
      end
    end
  end
end
