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
          readiness: snapshot && StockSetupSnapshotSerializer.new(snapshot).as_json,
          readiness_history: Setups::ReadinessHistory.for_stock(stock),
          rs_line: Setups::RsLine.call(stock),
          volume_pace: Nepse::VolumeProfile.pace(stock),
          broker_flow: Flows::AccumulationAnalyzer.call(stock),
          corporate_actions: {
            upcoming: CorporateActions::Upcoming.for_stock(stock),
            history: stock.dividends.latest_first.limit(10).map do |dividend|
              { fiscal_year: dividend.fiscal_year, cash_percent: dividend.cash_percent&.to_f, bonus_percent: dividend.bonus_percent&.to_f,
                total_percent: dividend.total_percent&.to_f, book_close_on: dividend.book_close_on, agm_on: dividend.agm_on }
            end
          }
        )
      end

      # Stocks in their buy zone on the latest snapshot (or all, ranked by readiness).
      def buy_zone
        traded_on = StockSetupSnapshot.maximum(:traded_on)
        scope = StockSetupSnapshot.where(traded_on: traded_on).joins(:stock).merge(Stock.active).includes(:stock)
        scope = scope.where(in_buy_zone: true) unless ActiveModel::Type::Boolean.new.cast(params[:all])
        snapshots = scope.order(readiness_score: :desc).limit(200).to_a
        held_back = StockSetupSnapshot.where(traded_on: traded_on).held_back_by_guards.joins(:stock).merge(Stock.active)
                                      .includes(:stock).order(readiness_score: :desc).to_a
        upcoming = CorporateActions::Upcoming.for_stocks((snapshots + held_back).map(&:stock_id))
        @histories = Setups::ReadinessHistory.for_stocks((snapshots + held_back).map(&:stock_id))
        render json: {
          traded_on: traded_on&.iso8601,
          criteria: {
            zone_state: "in_zone", min_trend_rules: Setups::Readiness::MIN_PRICE_RULES, min_readiness: Setups::Readiness::MIN_READINESS,
            setup_types: Setups::Readiness::BOARD_SETUP_TYPES,
            min_avg_turnover: Setups::Guards::MIN_TURNOVER, circuit_near_pct: Setups::Guards.circuit_near_pct(traded_on || Nepse::MarketHours.today),
            daily_limit_pct: Setups::Guards.daily_limit_pct(traded_on || Nepse::MarketHours.today)
          },
          results: snapshots.map { board_row(_1, upcoming) },
          held_back: held_back.map { board_row(_1, upcoming) }
        }
      end

      private

      def board_row(snapshot, upcoming)
        StockSetupSnapshotSerializer.new(snapshot).as_json.merge(
          symbol: snapshot.stock.symbol, name: snapshot.stock.name, sector: snapshot.stock.sector,
          next_book_close: upcoming[snapshot.stock_id],
          readiness_history: @histories.fetch(snapshot.stock_id, [])
        )
      end
    end
  end
end
