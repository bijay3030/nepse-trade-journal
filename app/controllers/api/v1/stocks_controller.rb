module Api
  module V1
    class StocksController < BaseController
      skip_before_action :authenticate_user!

      def index
        stocks = Stock.active
        stocks = stocks.by_sector(params[:sector]) if params[:sector].present?
        stocks = stocks.by_security_type(params[:security_type]) if params[:security_type].present?

        if params[:search].present?
          query = "%#{params[:search].strip}%"
          stocks = stocks.where("symbol ILIKE ? OR name ILIKE ?", query, query)
        end

        sort_column = allowed_sort_columns.include?(params[:sort_by]) ? params[:sort_by] : "symbol"
        sort_direction = params[:order].to_s.downcase == "desc" ? "desc" : "asc"

        stocks = stocks.order(Arel.sql("#{sort_column} #{sort_direction} NULLS LAST"))

        render json: stocks, each_serializer: StockSerializer
      end

      def show
        stock = Stock.find_by!(symbol: params[:id].to_s.upcase)
        render json: stock, serializer: StockDetailSerializer
      end

      def historical_prices
        stock = Stock.find_by!(symbol: params[:id].to_s.upcase)
        limit = params[:limit].present? ? params[:limit].to_i : 90

        daily_prices = stock.daily_prices.reverse_chronological.limit(limit)

        if params[:start_date].present? && params[:end_date].present?
          daily_prices = stock.daily_prices.between_dates(params[:start_date], params[:end_date]).chronological
        end

        render json: daily_prices, each_serializer: StockDailyPriceSerializer
      end

      def financials
        stock = Stock.find_by!(symbol: params[:id].to_s.upcase)
        financials = stock.company_financials.recent_reports

        render json: financials, each_serializer: StockCompanyFinancialSerializer
      end

      def sectors
        sectors = Stock.distinct.pluck(:sector).compact.reject(&:empty?).sort
        security_types = Stock.distinct.pluck(:security_type).compact.reject(&:empty?).sort
        render json: { sectors: sectors, security_types: security_types }
      end

      def current_prices
        stocks = scoped_stocks_for_prices

        if ActiveModel::Type::Boolean.new.cast(params[:refresh])
          refresh_price_data!(stocks)
        end

        render json: { prices: stocks.map(&:price_payload) }
      end

      private

      def allowed_sort_columns
        %w[symbol name sector security_type last_price change_percent volume market_cap high_52w low_52w]
      end

      def scoped_stocks_for_prices
        symbols = params[:symbols].to_s.split(",").map { |symbol| symbol.strip.upcase }.reject(&:blank?)
        scope = symbols.any? ? Stock.where(symbol: symbols) : Stock.active
        scope.order(:symbol).limit(200)
      end

      def refresh_price_data!(stocks)
        stocks.each do |stock|
          price_data = NepsePriceService.new(stock.symbol).fetch_current
          next unless price_data

          stock.update(
            last_price: price_data[:last_price],
            change_percent: price_data[:change_percent],
            volume: price_data[:volume],
            last_updated: Time.current
          )
          stock.recalculate_market_cap!
        end
      end
    end
  end
end
