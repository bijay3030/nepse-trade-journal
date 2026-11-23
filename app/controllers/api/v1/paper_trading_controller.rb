module Api
  module V1
    # GET /paper_trading: the automated paper account (PaperTrading::Report).
    # PATCH /paper_trading: { enabled: true/false } turns automated paper trading on or off.
    class PaperTradingController < BaseController
      def show
        render json: PaperTrading::Report.call(current_user)
      end

      def update
        current_user.update!(paper_trading: ActiveModel::Type::Boolean.new.cast(params[:enabled]))
        render json: PaperTrading::Report.call(current_user)
      end
    end
  end
end
