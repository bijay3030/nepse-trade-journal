module Api
  module V1
    class TradeResultsController < BaseController
      def create
        execution = current_user.trade_executions.find(params[:trade_execution_id])
        result = execution.build_trade_result(result_params)

        if result.save
          update_holding(execution, result)
          TradeAnalyticsCacheJob.perform_later(current_user)

          render json: result, serializer: TradeResultSerializer, status: :created
        else
          render json: { errors: result.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def result_params
        params.require(:trade_result).permit(
          :exit_price, :exit_date, :exit_reason, :exit_efficiency,
          :max_price_reached, :min_price_reached, :exit_broker_fees,
          :lesson_learned, :emotional_state_at_exit, mistake_tags: []
        )
      end

      def update_holding(execution, _result)
        portfolio = current_user.portfolios.first
        return unless portfolio

        holding = portfolio.holdings.find_by(stock: execution.trade_plan.stock)
        return unless holding

        new_quantity = holding.quantity - execution.quantity

        if new_quantity <= 0
          holding.destroy
        else
          holding.update!(quantity: new_quantity)
        end
      end
    end
  end
end
