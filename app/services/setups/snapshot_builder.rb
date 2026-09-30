module Setups
  # Builds one StockSetupSnapshot per active equity for the latest session (or a
  # past one with as_of:): relative strength across all stocks, the trend template,
  # the VCP and pullback setups with their zones, broker flow, and the readiness
  # score. Runs after the close. Past sessions use only data up to that day, so the
  # backtest sees what the app would have shown then. (The screener row's liquidity
  # rating is the one field computed from current data; the backtest doesn't use it.)
  class SnapshotBuilder
    MIN_SESSIONS = 60
    SETUP_TYPES = %w[vcp pullback].freeze
    # Which setup represents the stock when both have zones: one in its zone first.
    ZONE_PRIORITY = { "in_zone" => 0, "too_early" => 1, "extended" => 2, "failed" => 3 }.freeze

    def self.call(**options) = new(**options).call

    # stocks: preloaded stocks (with daily_prices and daily_indicators) to reuse
    # across many sessions, as Setups::HistoryBuilder does.
    def initialize(symbols: nil, as_of: nil, stocks: nil)
      @symbols = Array(symbols).map { _1.to_s.upcase }.presence
      @as_of = as_of
      @preloaded = stocks
    end

    def call
      prices = StockDailyPrice.joins(:stock).merge(Stock.active.where(security_type: "Equity"))
      prices = prices.where("traded_on <= ?", @as_of) if @as_of
      traded_on = prices.maximum(:traded_on)
      return { success: false, error: "No stock prices stored" } unless traded_on

      @traded_on = traded_on
      market = MarketIndex::Overview.new.call(as_of: traded_on)
      context = Watchlist::MarketContext.call(as_of: traded_on)
      stocks = eligible_stocks(traded_on)
      ratings = RelativeStrength.ratings(stocks.to_h { [ _1.id, RelativeStrength.score(closes(_1)) ] })
      flows = Flows::AccumulationAnalyzer.for_stocks(stocks.map(&:id), as_of: traded_on)

      summary = { success: true, traded_on: traded_on, stocks: 0, in_buy_zone: [], failed: {} }
      stocks.each do |stock|
        build(stock, traded_on, market, context, ratings, flows[stock.id] || Flows::AccumulationAnalyzer.empty)
        summary[:stocks] += 1
      rescue StandardError => e
        summary[:failed][stock.symbol] = e.message
      end
      summary[:in_buy_zone] = StockSetupSnapshot.where(traded_on: traded_on, in_buy_zone: true).joins(:stock).pluck("stocks.symbol").sort
      summary
    end

    private

    # Stocks with enough history that traded in the latest session.
    def eligible_stocks(traded_on)
      stocks = @preloaded || begin
        scope = Stock.active.where(security_type: "Equity").includes(:daily_prices, :daily_indicators).order(:symbol)
        @symbols ? scope.where(symbol: @symbols).to_a : scope.to_a
      end
      stocks.select do |stock|
        stock.daily_prices.count { _1.traded_on <= traded_on } >= MIN_SESSIONS && stock.daily_prices.any? { _1.traded_on == traded_on }
      end
    end

    # Closes up to the session being built, never later ones.
    def closes(stock) = stock.daily_prices.select { _1.traded_on <= @traded_on }.sort_by(&:traded_on).map(&:close_price)

    def build(stock, traded_on, market, context, ratings, flow)
      close = stock.daily_prices.find { _1.traded_on == traded_on }.close_price.to_f
      indicators = stock.daily_indicators.sort_by(&:traded_on)
      latest = indicators.reverse.find { _1.traded_on <= traded_on }
      month_ago = indicators.select { _1.traded_on < traded_on }.last(22).first

      rs_rating = ratings[stock.id]
      trend = TrendTemplate.call(close: close, indicator: latest, month_ago: month_ago, rs_rating: rs_rating)

      analysis = Stock::SetupAnalysis.new(stock, market: market, as_of: traded_on)
      detail = analysis.detail
      setup = best_setup(stock, detail, close, market)

      readiness = Readiness.call(
        trend_passed: trend[:passed], setup_quality: setup[:quality], regime: context.regime,
        sector_return: context.sector_returns[stock.sector], nepse_return: context.nepse_return,
        flow_score: flow[:score]
      )

      snapshot = StockSetupSnapshot.find_or_initialize_by(stock: stock, traded_on: traded_on)
      snapshot.update!(
        close_price: close,
        trend_rules_passed: trend[:price_rules_passed],
        trend_checks: trend[:checks],
        rs_rating: rs_rating,
        rs_score: RelativeStrength.score(closes(stock)),
        setup_type: setup[:type],
        zone_state: setup[:zone_state],
        setup_quality: setup[:quality],
        readiness_score: readiness[:score],
        readiness_components: readiness[:components],
        in_buy_zone: Readiness.in_buy_zone?(zone_state: setup[:zone_state], price_rules_passed: trend[:price_rules_passed], score: readiness[:score]),
        screener_row: analysis.summary,
        flow_state: flow[:state],
        flow_score: flow[:score],
        flow: flow.except(:daily),
        **setup.fetch(:levels, {})
      )
    end

    # Evaluates both setups and keeps the most actionable one.
    def best_setup(stock, detail, close, market)
      candidates = SETUP_TYPES.filter_map do |type|
        suggestion = Watchlist::EntryZoneSuggester.call(stock, type, market: market, analysis: detail)
        next unless suggestion[:success]

        levels = suggestion[:levels]
        {
          type: type,
          zone_state: zone_state(close, levels),
          quality: quality(type, detail),
          levels: {
            entry_zone_low: levels[:entry_zone_low], entry_zone_high: levels[:entry_zone_high],
            invalidation_price: levels[:invalidation_price], target_price: levels[:target_price],
            pivot_price: levels[:pivot_price],
            distance_to_zone_pct: close.positive? ? (((levels[:entry_zone_low] - close) / close) * 100).round(2) : nil
          }
        }
      end
      return { type: nil, zone_state: "no_setup", quality: 0 } if candidates.empty?

      candidates.min_by { [ ZONE_PRIORITY.fetch(_1[:zone_state]), -_1[:quality] ] }
    end

    def zone_state(close, levels)
      return "failed" if close <= levels[:invalidation_price]
      return "too_early" if close < levels[:entry_zone_low]
      return "in_zone" if close <= levels[:entry_zone_high]

      "extended"
    end

    # 0-100. VCP: its quality score, discounted when the pattern doesn't qualify.
    # Pullback: price-action confidence, halved outside an uptrend.
    def quality(type, detail)
      if type == "vcp"
        score = detail.dig(:vcp, :setup_quality_score).to_i
        detail.dig(:vcp, :is_vcp_setup) ? score : (score * 0.6).round
      else
        confidence = (detail.dig(:price_action, :confidence).to_f * 100).round
        detail.dig(:price_action, :trend) == "uptrend" ? confidence : (confidence * 0.5).round
      end
    end
  end
end
