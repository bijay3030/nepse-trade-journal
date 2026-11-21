module Api
  module V1
    # GET /lab: the Strategy Lab (Lab::Backtest report and the paper trades).
    # GET /lab/stocks/:symbol: one stock's strategy backtest (Lab::StockReport).
    class LabController < BaseController
      def show
        report = Lab::Cache.report
        render json: report.merge(
          market_phase: Scans::MarketPhase.current(as_of: report[:as_of]),
          paper_trades: Lab::PaperTrades.overview
        )
      end

      def stock
        report = Lab::StockReport.cached(params[:symbol])
        return render(json: { error: "Unknown stock #{params[:symbol]}" }, status: :not_found) unless report
        return render(json: report, status: :unprocessable_entity) if report[:error]

        render json: report
      end
    end
  end
end
