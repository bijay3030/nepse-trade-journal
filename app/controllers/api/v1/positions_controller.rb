module Api
  module V1
    class PositionsController < BaseController
      before_action :set_position, only: %i[show update destroy_fill]

      def index
        positions = current_user.positions.includes(:stock, :fills).order(status: :desc, created_at: :desc)
        positions = positions.where(status: params[:status]) if Position::STATUSES.include?(params[:status])
        render json: positions, each_serializer: PositionSerializer
      end

      def show
        render json: @position, serializer: PositionSerializer
      end

      # Records a buy: opens a position, or adds to the open one for the stock.
      def create
        item = current_user.watchlist_items.find(params[:watchlist_item_id]) if params[:watchlist_item_id].present?
        stock = item&.stock || Stock.active.find_by!(symbol: params[:symbol].to_s.upcase)
        position = Positions::Recorder.buy(
          user: current_user, stock: stock, watchlist_item: item,
          price: params.require(:price), quantity: params.require(:quantity),
          traded_on: params[:traded_on].presence || Nepse::MarketHours.today
        )
        render json: position, serializer: PositionSerializer, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      def update
        if @position.update(params.permit(:stop_price, :target_price, :notes))
          render json: @position, serializer: PositionSerializer
        else
          render json: { error: @position.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      # Removes a mistaken fill; the position goes away with its last fill.
      def destroy_fill
        position = Positions::Recorder.remove_fill(@position.fills.find(params[:fill_id]))
        position ? render(json: position, serializer: PositionSerializer) : head(:no_content)
      end

      private

      def set_position
        @position = current_user.positions.includes(:stock, :fills).find(params[:id])
      end
    end
  end
end
