module Api
  module V1
    # Capital and risk limits used for position sizing and portfolio risk.
    class TradingSettingsController < BaseController
      def show
        render json: payload
      end

      def update
        if current_user.update(params.permit(:trading_capital, :risk_per_trade_pct, :max_open_risk_pct, :max_sector_pct))
          render json: payload
        else
          render json: { error: current_user.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      # GET /position_sizing?entry=&stop=&target=&quantity= : the suggested size, plus the
      # costs and outcomes for `quantity` when given (e.g. the quantity typed in a form).
      def sizing
        entry, stop, target = params.values_at(:entry, :stop, :target).map(&:to_f)
        result = current_user.size_position(entry: entry, stop: stop, target: target)
        quantity = params[:quantity].to_i
        if quantity.positive? && entry.positive?
          result = result.merge(for_quantity: Positions::Sizer.details(entry, stop, target, quantity, current_user.trading_capital.to_f))
        end
        render json: result
      end

      private

      def payload
        {
          trading_capital: current_user.trading_capital&.to_f,
          risk_per_trade_pct: current_user.risk_per_trade_pct.to_f,
          max_open_risk_pct: current_user.max_open_risk_pct.to_f,
          max_sector_pct: current_user.max_sector_pct.to_f
        }
      end
    end
  end
end
