module Api
  module V1
    class MarketController < BaseController
      def overview
        render json: MarketIndex::Overview.new.call
      end
    end
  end
end
