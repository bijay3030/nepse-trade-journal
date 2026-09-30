class MarketIndex::Overview
  # as_of: evaluate as of a past session, using only data up to that day.
  def call(as_of: nil)
    index = MarketIndex.find_by(symbol: "NEPSE")
    # Only sessions that also have stock prices, so breadth is never measured on an
    # index-only day (e.g. today's index bar before the stock sync has run).
    priced = StockDailyPrice.all
    priced = priced.where("traded_on <= ?", as_of) if as_of
    last_priced = priced.maximum(:traded_on)
    sessions = index&.histories
    sessions = sessions&.where(traded_on: ..last_priced) if last_priced
    history = sessions&.order(traded_on: :desc)&.limit(200)&.to_a&.reverse || []
    latest = history.last
    return empty_snapshot unless latest

    prices = StockDailyPrice.where(traded_on: latest.traded_on).includes(:stock).select { |price| price.stock.is_active && price.stock.security_type == "Equity" }
    indicators = StockDailyIndicator.where(traded_on: latest.traded_on, stock_id: prices.map(&:stock_id)).index_by(&:stock_id)
    advancing = prices.count { |price| price.change_percent.positive? }
    declining = prices.count { |price| price.change_percent.negative? }
    above50 = prices.count { |price| indicators[price.stock_id]&.sma_50 && price.close_price > indicators[price.stock_id].sma_50 }
    above200 = prices.count { |price| indicators[price.stock_id]&.sma_200 && price.close_price > indicators[price.stock_id].sma_200 }
    breadth = percentage(advancing, prices.size)
    values = history.map { |point| point.index_value.to_f }
    trend = trend_for(values)
    regime = if trend == "uptrend" && breadth >= 55
      "strong"
    elsif trend == "downtrend" && breadth < 45
      "weak"
    else
      "neutral"
    end

    {
      traded_on: latest.traded_on.iso8601, regime_status: regime,
      nepse_index: latest.index_value.to_f, index_change_pct: latest.change_percent.to_f,
      index_sma20: average(values.last(20), minimum: 20), index_sma50: average(values.last(50), minimum: 50),
      index_sma200: average(values.last(200), minimum: 200), index_trend: trend,
      market_turnover: latest.turnover.to_f, advancing_stocks: advancing, declining_stocks: declining,
      unchanged_stocks: prices.size - advancing - declining,
      advance_decline_ratio: declining.zero? ? 0.0 : (advancing.to_f / declining).round(2),
      market_breadth_pct: breadth, breadth_rating: prices.empty? ? "neutral" : rating(breadth), total_stocks_audited: prices.size,
      pct_stocks_above_sma50: percentage(above50, prices.size), pct_stocks_above_sma200: percentage(above200, prices.size),
      index_history: history.last(90).map { |point| { traded_on: point.traded_on.iso8601, value: point.index_value.to_f } },
      sectors: prices.group_by { |price| price.stock.sector }.sort.map { |name, sector_prices| sector_row(name, sector_prices, latest, indicators) }
    }
  end

  private

  def empty_snapshot
    {
      traded_on: nil, regime_status: "neutral", nepse_index: 0, index_change_pct: 0,
      index_sma20: nil, index_sma50: nil, index_sma200: nil, index_trend: "sideways", market_turnover: 0,
      advancing_stocks: 0, declining_stocks: 0, unchanged_stocks: 0, advance_decline_ratio: 0,
      market_breadth_pct: 0, breadth_rating: "neutral", total_stocks_audited: 0,
      pct_stocks_above_sma50: 0, pct_stocks_above_sma200: 0, index_history: [], sectors: []
    }
  end

  def sector_row(name, prices, latest, indicators)
    advancing = prices.count { |price| price.change_percent.positive? }
    declining = prices.count { |price| price.change_percent.negative? }
    change = (prices.sum { |price| price.change_percent.to_f } / prices.size).round(2)
    relative = (change - latest.change_percent.to_f).round(2)
    {
      sector: name, constituents_count: prices.size, advancing_stocks: advancing, declining_stocks: declining,
      sector_performance_pct: change, sector_turnover: prices.sum { |price| price.turnover.to_f },
      relative_strength_pct: relative, relative_strength_rating: rating(relative, positive: 0.5, negative: -0.5),
      sector_trend: change > 0.5 ? "uptrend" : change < -0.5 ? "downtrend" : "sideways",
      pct_above_sma50: percentage(prices.count { |price| indicators[price.stock_id]&.sma_50 && price.close_price > indicators[price.stock_id].sma_50 }, prices.size)
    }
  end

  def percentage(part, total)
    total.zero? ? 0.0 : (part.to_f * 100 / total).round(2)
  end

  def average(values, minimum: 1)
    values.size < minimum ? nil : (values.sum.to_f / values.size).round(2)
  end

  def trend_for(values)
    return "sideways" if values.size < 20

    short = average(values.last(20))
    long = average(values.last(50), minimum: 50)
    reference = long || average(values.first(values.size - 20))
    return "sideways" unless reference

    short > reference * 1.01 ? "uptrend" : short < reference * 0.99 ? "downtrend" : "sideways"
  end

  def rating(value, positive: 55, negative: 45)
    value >= positive ? "strong" : value < negative ? "weak" : "neutral"
  end
end
