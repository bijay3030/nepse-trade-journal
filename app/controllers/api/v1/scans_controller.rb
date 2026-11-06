module Api
  module V1
    # Indicator scans (Scans::Crossovers) with how each signal played out historically
    # (Scans::CrossoverBacktest), cached until the next completed session.
    class ScansController < BaseController
      def crossovers
        render json: Scans::Cache.crossovers
      end

      # GET /scans/crossovers/:symbol: candles, indicator lines and signal episodes.
      def crossover_chart
        stock = Stock.active.find_by!(symbol: params[:symbol].to_s.upcase)
        chart = Scans::Crossovers.chart(stock)
        chart ? render(json: chart) : render(json: { error: "Not enough price history for #{stock.symbol}" }, status: :unprocessable_entity)
      end
    end
  end
end
