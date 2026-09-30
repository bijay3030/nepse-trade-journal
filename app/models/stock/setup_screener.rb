# Screener rows. Reads the nightly snapshots (Setups::SnapshotBuilder) when they
# exist, which is fast; otherwise analyses every stock live.
class Stock::SetupScreener
  READINESS_FIELDS = %i[readiness_score zone_state in_buy_zone rs_rating trend_rules_passed setup_type].freeze

  def call
    snapshot_rows || live_rows
  end

  private

  def snapshot_rows
    traded_on = StockSetupSnapshot.maximum(:traded_on)
    return unless traded_on

    market = MarketIndex::Overview.new.call
    snapshots = StockSetupSnapshot.where(traded_on: traded_on).joins(:stock).merge(Stock.active).includes(:stock).order("stocks.symbol")
    results = snapshots.map { |snapshot| snapshot.screener_row.symbolize_keys.merge(readiness(snapshot)) }
    { traded_on: traded_on.iso8601, market_regime: market[:regime_status], sectors: results.map { |row| row[:sector] }.uniq.sort, results: results }
  end

  def readiness(snapshot)
    snapshot.slice(*READINESS_FIELDS).symbolize_keys.merge(
      entry_zone_low: snapshot.entry_zone_low&.to_f, entry_zone_high: snapshot.entry_zone_high&.to_f,
      invalidation_price: snapshot.invalidation_price&.to_f
    )
  end

  def live_rows
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
