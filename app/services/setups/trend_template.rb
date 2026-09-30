module Setups
  # Mark Minervini's trend template: the conditions of a stage-2 uptrend.
  # Seven price rules from the stored moving averages, plus relative strength.
  module TrendTemplate
    MIN_RS_RATING = 70

    module_function

    # indicator: latest StockDailyIndicator; month_ago: the one ~21 sessions earlier.
    def call(close:, indicator:, month_ago:, rs_rating:)
      close = close.to_f
      sma50, sma150, sma200 = indicator&.sma_50&.to_f, indicator&.sma_150&.to_f, indicator&.sma_200&.to_f
      low52, high52 = indicator&.low_52w.to_f, indicator&.high_52w.to_f
      prior200 = month_ago&.sma_200&.to_f

      checks = [
        rule("above_long_mas", "Price above the 150- and 200-day averages", sma150 && sma200 && close > sma150 && close > sma200,
             sma150 && sma200 ? "#{fmt(close)} vs #{fmt(sma150)} / #{fmt(sma200)}" : "Not enough history"),
        rule("ma150_above_ma200", "150-day average above the 200-day", sma150 && sma200 && sma150 > sma200,
             sma150 && sma200 ? "#{fmt(sma150)} vs #{fmt(sma200)}" : "Not enough history"),
        rule("ma200_rising", "200-day average rising for a month", sma200 && prior200 && sma200 > prior200,
             sma200 && prior200 ? "#{fmt(prior200)} -> #{fmt(sma200)}" : "Not enough history"),
        rule("ma50_above_long", "50-day average above the 150- and 200-day", sma50 && sma150 && sma200 && sma50 > sma150 && sma50 > sma200,
             sma50 ? "50-day #{fmt(sma50)}" : "Not enough history"),
        rule("above_ma50", "Price above the 50-day average", sma50 && close > sma50, sma50 ? "#{fmt(close)} vs #{fmt(sma50)}" : "Not enough history"),
        rule("above_52w_low", "At least 30% above the 52-week low", low52.positive? && close >= low52 * 1.3,
             low52.positive? ? "#{pct(close, low52)} above #{fmt(low52)}" : "Not enough history"),
        rule("near_52w_high", "Within 25% of the 52-week high", high52.positive? && close >= high52 * 0.75,
             high52.positive? ? "#{pct(high52, close)} below #{fmt(high52)}" : "Not enough history"),
        rule("rs_rating", "Relative strength #{MIN_RS_RATING} or higher", rs_rating && rs_rating >= MIN_RS_RATING,
             rs_rating ? "RS #{rs_rating}" : "Not enough history")
      ]

      { checks: checks, price_rules_passed: checks.first(7).count { _1[:passed] }, passed: checks.count { _1[:passed] } }
    end

    def rule(key, label, passed, detail)
      { key: key, label: label, passed: passed ? true : false, detail: detail }
    end

    def fmt(value) = format("%.2f", value)

    # How far a is above b, in percent.
    def pct(a, b) = "#{(((a - b) / b) * 100).round(1)}%"
  end
end
