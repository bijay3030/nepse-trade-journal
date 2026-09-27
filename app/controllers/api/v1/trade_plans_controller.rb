module Api
  module V1
    class TradePlansController < BaseController
      def index
        plans = current_user.trade_plans.includes(:stock, :trade_execution, :trade_result)
        plans = plans.where(status: params[:status]) if params[:status].present?
        plans = plans.recent

        render json: plans, each_serializer: TradePlanSerializer
      end

      def create
        plan = current_user.trade_plans.build(plan_params)

        if plan.save
          render json: plan, serializer: TradePlanSerializer, status: :created
        else
          render json: { errors: plan.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def show
        plan = current_user.trade_plans.includes(:stock, :trading_strategy, :trade_execution).find(params[:id])
        render json: plan, serializer: TradePlanDetailSerializer
      end

      def destroy
        plan = current_user.trade_plans.find(params[:id])
        plan.soft_delete!(source: "api")
        render json: { deleted: true, id: plan.id }
      end

      private

      def plan_params
        params.require(:trade_plan).permit(
          :stock_id, :trading_strategy_id, :entry_strategy, :analysis_type,
          :entry_trigger_description, :planned_entry_price, :target_price,
          :stop_loss_price, :position_size_percent, :planned_quantity,
          :expected_hold_duration, :market_condition_at_entry, :emotional_state_at_entry,
          :sector_trend, :news_catalyst, :status
        )
      end
    end
  end
end
