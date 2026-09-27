module MarketContext
  class SectorAnalyzer
    def self.call(sector, date: nil, config: Configuration.new)
      new(sector, date: date, config: config).evaluate
    end

    def self.for_stock(stock, date: nil, config: Configuration.new)
      new(stock.sector, date: date, config: config).evaluate
    end

    def initialize(sector, date: nil, config: Configuration.new)
      @sector = sector
      @config = config
      @date = date.present? ? to_date(date) : resolve_latest_date
    end

    def evaluate
      return empty_result if @sector.blank?

      constituents = Stock.active.by_sector(@sector).to_a
      return empty_result if constituents.empty?

      dated_prices = prices_for_date(constituents)
      performance = average_change_pct(dated_prices)
      sector_return = average_window_return(constituents)
      market_return = average_window_return(Stock.active.to_a)

      {
        sector: @sector,
        traded_on: @date,
        constituents_count: constituents.size,
        advancing_stocks: dated_prices.count { |p| p.change_amount.to_f.positive? },
        declining_stocks: dated_prices.count { |p| p.change_amount.to_f.negative? },
        unchanged_stocks: dated_prices.count { |p| p.change_amount.to_f.zero? },
        sector_performance_pct: performance,
        sector_turnover: dated_prices.sum { |p| turnover_for(p) }.round(2),
        sector_cumulative_return_pct: sector_return,
        market_cumulative_return_pct: market_return,
        relative_strength_pct: relative_strength(sector_return, market_return),
        relative_strength_rating: classify_relative_strength(relative_strength(sector_return, market_return)),
        sector_trend: classify_trend(sector_return),
        pct_above_sma50: pct_above_sma(constituents, :sma_50),
        pct_above_sma200: pct_above_sma(constituents, :sma_200),
        trend_window: @config.sector_trend_window
      }
    end

    private

    def resolve_latest_date
      StockDailyPrice.maximum(:traded_on) || Date.current
    end

    def prices_for_date(stocks)
      StockDailyPrice.where(traded_on: @date, stock_id: stocks.map(&:id)).to_a
    end

    def average_change_pct(prices)
      return 0.0 if prices.empty?

      (prices.sum { |p| p.change_percent.to_f } / prices.size).round(2)
    end

    def average_window_return(stocks)
      returns = stocks.filter_map { |stock| window_return(stock) }
      return nil if returns.empty?

      (returns.sum / returns.size).round(2)
    end

    def window_return(stock)
      prices = stock.daily_prices.where(traded_on: ..@date)
                    .reverse_chronological.limit(@config.sector_trend_window).to_a.reverse
      first = prices.first
      last = prices.last
      return nil unless first && last

      first_close = first.close_price.to_f
      return nil unless first_close.positive?

      (((last.close_price.to_f - first_close) / first_close) * 100.0).round(2)
    end

    def relative_strength(sector_return, market_return)
      return nil if sector_return.nil? || market_return.nil?

      (sector_return - market_return).round(2)
    end

    def classify_trend(sector_return)
      return "sideways" if sector_return.nil?

      if sector_return >= @config.sector_trend_threshold_pct
        "uptrend"
      elsif sector_return <= -@config.sector_trend_threshold_pct
        "downtrend"
      else
        "sideways"
      end
    end

    def classify_relative_strength(relative_strength_pct)
      return "neutral" if relative_strength_pct.nil?

      if relative_strength_pct >= @config.sector_strong_relative_strength_pct
        "strong"
      elsif relative_strength_pct <= @config.sector_weak_relative_strength_pct
        "weak"
      else
        "neutral"
      end
    end

    def pct_above_sma(stocks, column)
      indicators = StockDailyIndicator.where(traded_on: @date, stock_id: stocks.map(&:id)).to_a
      return 0.0 if indicators.empty?

      above = indicators.count do |indicator|
        reference = indicator.public_send(column)
        reference.present? && reference.to_f.positive? &&
          indicator_price(indicator) >= reference.to_f
      end
      ((above.to_f / indicators.size) * 100.0).round(2)
    end

    def indicator_price(indicator)
      indicator.stock_daily_price&.close_price&.to_f || indicator.stock.last_price.to_f
    end

    def turnover_for(price)
      turnover = price.turnover.to_f
      turnover.positive? ? turnover : (price.close_price.to_f * price.volume.to_f)
    end

    def to_date(val)
      val.is_a?(Date) ? val : Date.parse(val.to_s)
    end

    def empty_result
      {
        sector: @sector,
        traded_on: @date,
        constituents_count: 0,
        advancing_stocks: 0,
        declining_stocks: 0,
        unchanged_stocks: 0,
        sector_performance_pct: 0.0,
        sector_turnover: 0.0,
        sector_cumulative_return_pct: nil,
        market_cumulative_return_pct: nil,
        relative_strength_pct: nil,
        relative_strength_rating: "neutral",
        sector_trend: "sideways",
        pct_above_sma50: 0.0,
        pct_above_sma200: 0.0,
        trend_window: @config.sector_trend_window
      }
    end
  end
end
