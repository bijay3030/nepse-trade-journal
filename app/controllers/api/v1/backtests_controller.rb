module Api
  module V1
    class BacktestsController < BaseController
      # The latest saved backtest run.
      def latest
        run = BacktestRun.latest_first.first
        return render json: { error: "No backtest yet. Run rails nepse:data:setup_history and rails nepse:data:backtest." }, status: :not_found unless run

        render json: { id: run.id, created_at: run.created_at, from_date: run.from_date, to_date: run.to_date,
                       sessions: run.sessions, parameters: run.parameters, results: run.results }
      end
    end
  end
end
