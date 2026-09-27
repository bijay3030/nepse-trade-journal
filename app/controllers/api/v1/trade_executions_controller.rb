module Api
  module V1
    class TradeExecutionsController < BaseController
      def create
        plan = current_user.trade_plans.find(params[:trade_plan_id])
        execution = plan.build_trade_execution(execution_params)

        if execution.save
          create_or_update_holding(execution)
          render json: execution, serializer: TradeExecutionSerializer, status: :created
        else
          render json: { errors: execution.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def execution_params
        params.require(:trade_execution).permit(
          :actual_entry_price, :quantity, :entry_time, :broker,
          :broker_fees, :order_type, :entry_efficiency, :notes
        )
      end

      def create_or_update_holding(execution)
        portfolio = current_user.portfolios.first_or_create!(name: "Default")
        holding = portfolio.holdings.find_or_initialize_by(stock: execution.trade_plan.stock)

        total_cost = (holding.average_buy_price * holding.quantity) + execution.total_cost
        total_quantity = holding.quantity + execution.quantity

        holding.update!(
          quantity: total_quantity,
          average_buy_price: total_quantity.zero? ? 0 : (total_cost / total_quantity),
          last_buy_date: execution.entry_time
        )
      end
    end
  end
end
