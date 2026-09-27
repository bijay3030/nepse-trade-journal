module MarketContext
  class RegimeEngine
    def self.call(date = nil, config = Configuration.new)
      new(date: date, config: config).evaluate
    end

    def initialize(date: nil, config: Configuration.new)
      @config = config
      @date = date.present? ? to_date(date) : resolve_latest_date
    end

    def evaluate
      index_data = fetch_nepse_index_data
      market_stats = calculate_market_stats
      breadth_stats = calculate_breadth_stats

      regime_status = classify_regime(
        pct_above_sma50: breadth_stats[:pct_stocks_above_sma50],
        ad_ratio: market_stats[:advance_decline_ratio],
        index_trend: index_data[:trend]
      )

      {
        traded_on: @date,
        regime_status: regime_status,
        regime_basis: regime_basis(
          pct_above_sma50: breadth_stats[:pct_stocks_above_sma50],
          ad_ratio: market_stats[:advance_decline_ratio],
          index_trend: index_data[:trend]
        ),
        nepse_index: index_data[:current_value],
        index_change_pct: index_data[:change_percent],
        index_sma20: index_data[:sma20],
        index_sma50: index_data[:sma50],
        index_sma200: index_data[:sma200],
        index_trend: index_data[:trend],
        market_turnover: market_stats[:total_turnover],
        advancing_stocks: market_stats[:advancing],
        declining_stocks: market_stats[:declining],
        unchanged_stocks: market_stats[:unchanged],
        advance_decline_ratio: market_stats[:advance_decline_ratio],
        market_breadth_pct: market_stats[:market_breadth_pct],
        breadth_rating: classify_breadth(market_stats[:market_breadth_pct]),
        total_stocks_audited: breadth_stats[:total_stocks],
        pct_stocks_above_sma50: breadth_stats[:pct_stocks_above_sma50],
        pct_stocks_above_sma200: breadth_stats[:pct_stocks_above_sma200]
      }
    end

    private

    def resolve_latest_date
      StockDailyPrice.maximum(:traded_on) || Date.current
    end

    def fetch_nepse_index_data
      nepse_index = MarketIndex.find_by(symbol: "NEPSE")
      histories = if nepse_index
                    nepse_index.histories.order(traded_on: :desc).limit(200).to_a
      else
                    []
      end

      current_val = histories.first&.index_value&.to_f || nepse_index&.current_value&.to_f || 0.0
      change_pct = histories.first&.change_percent&.to_f || nepse_index&.change_percent&.to_f || 0.0

      values = histories.map { |h| h.index_value.to_f }
      window = @config.index_trend_window
      sma20 = average(values.take(20), 20)
      sma50 = average(values.take(50), 50)
      sma200 = average(values.take(200), 200)
      trend_reference = average(values.take(window), window)

      trend = if trend_reference.nil?
                "sideways"
      elsif current_val >= trend_reference
                "uptrend"
      else
                "downtrend"
      end

      {
        current_value: current_val,
        change_percent: change_pct,
        sma20: sma20,
        sma50: sma50,
        sma200: sma200,
        trend: trend
      }
    end

    def average(values, window)
      return nil if values.size < window

      (values.sum / window.to_f).round(2)
    end

    def calculate_market_stats
      prices = StockDailyPrice.where(traded_on: @date).joins(:stock).merge(Stock.active)

      advancing = 0
      declining = 0
      unchanged = 0
      total_turnover = 0.0

      prices.each do |p|
        total_turnover += turnover_for(p)

        change = p.change_amount.to_f
        if change.positive?
          advancing += 1
        elsif change.negative?
          declining += 1
        else
          unchanged += 1
        end
      end

      ad_ratio = declining.positive? ? (advancing.to_f / declining).round(2) : advancing.to_f
      breadth_pct = if (advancing + declining).positive?
                      ((advancing.to_f / (advancing + declining)) * 100.0).round(2)
      else
                      0.0
      end

      {
        total_turnover: total_turnover.round(2),
        advancing: advancing,
        declining: declining,
        unchanged: unchanged,
        advance_decline_ratio: ad_ratio,
        market_breadth_pct: breadth_pct
      }
    end

    def calculate_breadth_stats
      indicators = StockDailyIndicator.where(traded_on: @date).joins(:stock).merge(Stock.active)
      total_count = indicators.count

      return { total_stocks: 0, pct_stocks_above_sma50: 0.0, pct_stocks_above_sma200: 0.0 } if total_count.zero?

      above_50 = 0
      above_200 = 0

      indicators.find_each do |ind|
        price = ind.stock_daily_price&.close_price&.to_f || ind.stock.last_price.to_f
        above_50 += 1 if ind.sma_50.present? && price >= ind.sma_50.to_f
        above_200 += 1 if ind.sma_200.present? && price >= ind.sma_200.to_f
      end

      {
        total_stocks: total_count,
        pct_stocks_above_sma50: ((above_50.to_f / total_count) * 100.0).round(2),
        pct_stocks_above_sma200: ((above_200.to_f / total_count) * 100.0).round(2)
      }
    end

    def turnover_for(price)
      turnover = price.turnover.to_f
      turnover.positive? ? turnover : (price.close_price.to_f * price.volume.to_f)
    end

    def classify_regime(pct_above_sma50:, ad_ratio:, index_trend:)
      if pct_above_sma50 >= @config.strong_regime_breadth_pct && ad_ratio >= @config.strong_ad_ratio && index_trend == "uptrend"
        "strong"
      elsif pct_above_sma50 < @config.weak_regime_breadth_pct || ad_ratio <= @config.weak_ad_ratio || index_trend == "downtrend"
        "weak"
      else
        "neutral"
      end
    end

    def regime_basis(pct_above_sma50:, ad_ratio:, index_trend:)
      {
        strong_breadth: pct_above_sma50 >= @config.strong_regime_breadth_pct,
        strong_ad_ratio: ad_ratio >= @config.strong_ad_ratio,
        uptrend: index_trend == "uptrend",
        weak_breadth: pct_above_sma50 < @config.weak_regime_breadth_pct,
        weak_ad_ratio: ad_ratio <= @config.weak_ad_ratio,
        downtrend: index_trend == "downtrend"
      }
    end

    def classify_breadth(market_breadth_pct)
      if market_breadth_pct >= @config.strong_regime_breadth_pct
        "strong"
      elsif market_breadth_pct < @config.weak_regime_breadth_pct
        "weak"
      else
        "neutral"
      end
    end

    def to_date(val)
      val.is_a?(Date) ? val : Date.parse(val.to_s)
    end
  end
end
