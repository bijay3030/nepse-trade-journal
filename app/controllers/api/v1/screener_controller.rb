module Api
  module V1
    class ScreenerController < BaseController
      def index
        render json: Stock::SetupScreener.new.call
      end

      def show
        stock = Stock.active.find_by!(symbol: params[:symbol].upcase)
        market = MarketIndex::Overview.new.call
        render json: Stock::SetupAnalysis.new(stock, market: market).detail
      end
    end
  end
end
