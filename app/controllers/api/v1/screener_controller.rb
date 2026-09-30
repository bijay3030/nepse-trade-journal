module Api
  module V1
    class ScreenerController < BaseController
      def index
        render json: Stock::SetupScreener.new.call
      end

      def show
        stock = Stock.active.find_by!(symbol: params[:symbol].upcase)
        market = MarketIndex::Overview.new.call
        snapshot = stock.setup_snapshots.order(traded_on: :desc).first
        render json: Stock::SetupAnalysis.new(stock, market: market).detail.merge(
          readiness: snapshot && StockSetupSnapshotSerializer.new(snapshot).as_json
        )
      end

      # Stocks in their buy zone on the latest snapshot (or all, ranked by readiness).
      def buy_zone
        traded_on = StockSetupSnapshot.maximum(:traded_on)
        scope = StockSetupSnapshot.where(traded_on: traded_on).joins(:stock).merge(Stock.active).includes(:stock)
        scope = scope.where(in_buy_zone: true) unless ActiveModel::Type::Boolean.new.cast(params[:all])
        rows = scope.order(readiness_score: :desc).limit(200).map do |snapshot|
          StockSetupSnapshotSerializer.new(snapshot).as_json.merge(
            symbol: snapshot.stock.symbol, name: snapshot.stock.name, sector: snapshot.stock.sector
          )
        end
        render json: {
          traded_on: traded_on&.iso8601,
          criteria: {
            zone_state: "in_zone", min_trend_rules: Setups::Readiness::MIN_PRICE_RULES, min_readiness: Setups::Readiness::MIN_READINESS
          },
          results: rows
        }
      end
    end
  end
end
