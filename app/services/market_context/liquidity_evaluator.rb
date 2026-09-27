module MarketContext
  class LiquidityEvaluator
    RATING_RANK = { "low" => 0, "medium" => 1, "high" => 2 }.freeze

    def self.call(stock, config = Configuration.new)
      new(stock, config).evaluate
    end

    def self.rating_rank(rating)
      RATING_RANK.fetch(rating.to_s, 0)
    end

    def initialize(stock, config = Configuration.new)
      @stock = stock
      @config = config
    end

    def evaluate
      prices = fetch_prices
      return empty_liquidity_result if prices.empty?

      short = prices.take(@config.liquidity_short_window)
      medium = prices.take(@config.liquidity_medium_window)
      long = prices.take(@config.liquidity_long_window)
      frequency_records = prices.take(@config.trading_frequency_window)

      recent_bar = prices.first
      recent_turnover = turnover_for(recent_bar)

      avg_turn_short = calculate_avg_turnover(short)
      avg_turn_medium = calculate_avg_turnover(medium)
      avg_turn_long = calculate_avg_turnover(long)

      traded_sessions = frequency_records.count { |r| r.volume.to_i.positive? }
      trading_frequency_pct = frequency_records.empty? ? 0.0 : ((traded_sessions.to_f / frequency_records.size) * 100.0).round(2)

      {
        symbol: @stock.symbol,
        recent_turnover: recent_turnover.round(2),
        recent_volume: recent_bar.volume.to_i,
        avg_turnover_10d: avg_turn_short.round(2),
        avg_turnover_20d: avg_turn_medium.round(2),
        avg_turnover_50d: avg_turn_long.round(2),
        avg_turnover_short: avg_turn_short.round(2),
        avg_turnover_medium: avg_turn_medium.round(2),
        avg_turnover_long: avg_turn_long.round(2),
        avg_volume_10d: calculate_avg_volume(short),
        avg_volume_20d: calculate_avg_volume(medium),
        avg_volume_50d: calculate_avg_volume(long),
        avg_volume_short: calculate_avg_volume(short),
        avg_volume_medium: calculate_avg_volume(medium),
        avg_volume_long: calculate_avg_volume(long),
        avg_daily_trades: calculate_avg_trades(frequency_records),
        trading_frequency_pct: trading_frequency_pct,
        traded_sessions: traded_sessions,
        frequency_window: frequency_records.size,
        rating: classify_rating(avg_turn_medium),
        windows: {
          short: @config.liquidity_short_window,
          medium: @config.liquidity_medium_window,
          long: @config.liquidity_long_window,
          frequency: @config.trading_frequency_window
        }
      }
    end

    def passes?(min_rating: "medium", min_trading_frequency_pct: nil, min_avg_daily_trades: nil)
      result = evaluate
      return false if self.class.rating_rank(result[:rating]) < self.class.rating_rank(min_rating)
      return false if min_trading_frequency_pct && result[:trading_frequency_pct] < min_trading_frequency_pct.to_f
      return false if min_avg_daily_trades && result[:avg_daily_trades] < min_avg_daily_trades.to_i

      true
    end

    private

    def fetch_prices
      max_window = [ @config.liquidity_long_window, @config.trading_frequency_window ].max
      @stock.daily_prices.reverse_chronological.limit(max_window).to_a
    end

    def calculate_avg_volume(records)
      return 0 if records.empty?

      (records.sum { |r| r.volume.to_i } / records.size.to_f).round
    end

    def calculate_avg_turnover(records)
      return 0.0 if records.empty?

      (records.sum { |r| turnover_for(r) } / records.size.to_f).round(2)
    end

    def calculate_avg_trades(records)
      return 0 if records.empty?

      (records.sum { |r| r.total_trades.to_i } / records.size.to_f).round
    end

    def turnover_for(record)
      turnover = record.turnover.to_f
      turnover.positive? ? turnover : (record.close_price.to_f * record.volume.to_f)
    end

    def classify_rating(avg_turnover_medium)
      if avg_turnover_medium >= @config.high_liquidity_turnover
        "high"
      elsif avg_turnover_medium >= @config.medium_liquidity_turnover
        "medium"
      else
        "low"
      end
    end

    def empty_liquidity_result
      {
        symbol: @stock.symbol,
        recent_turnover: 0.0,
        recent_volume: 0,
        avg_turnover_10d: 0.0,
        avg_turnover_20d: 0.0,
        avg_turnover_50d: 0.0,
        avg_turnover_short: 0.0,
        avg_turnover_medium: 0.0,
        avg_turnover_long: 0.0,
        avg_volume_10d: 0,
        avg_volume_20d: 0,
        avg_volume_50d: 0,
        avg_volume_short: 0,
        avg_volume_medium: 0,
        avg_volume_long: 0,
        avg_daily_trades: 0,
        trading_frequency_pct: 0.0,
        traded_sessions: 0,
        frequency_window: 0,
        rating: "low",
        windows: {
          short: @config.liquidity_short_window,
          medium: @config.liquidity_medium_window,
          long: @config.liquidity_long_window,
          frequency: @config.trading_frequency_window
        }
      }
    end
  end
end
