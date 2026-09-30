module Api
  module V1
    class MarketController < BaseController
      def overview
        render json: MarketIndex::Overview.new.call
      end

      def heatmap
        render json: MarketIndex::Heatmap.new.call
      end
    end
  end
end
