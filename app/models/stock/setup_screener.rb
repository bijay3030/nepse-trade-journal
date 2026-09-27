class Stock::SetupScreener
  def call
    market = MarketIndex::Overview.new.call
    latest = StockDailyPrice.joins(:stock).merge(Stock.active.where(security_type: "Equity")).maximum(:traded_on)
    stocks = Stock.active.where(security_type: "Equity").includes(:daily_prices, :daily_indicators).order(:symbol)
    results = stocks.filter_map do |stock|
      next unless latest && stock.daily_prices.any? { |price| price.traded_on == latest }

      Stock::SetupAnalysis.new(stock, market: market).summary
    end
    { traded_on: latest&.iso8601, market_regime: market[:regime_status], sectors: results.map { |row| row[:sector] }.uniq.sort, results: results }
  end
end
