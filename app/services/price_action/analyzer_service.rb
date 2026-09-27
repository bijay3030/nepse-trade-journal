module PriceAction
  class AnalyzerService
    def self.call(target, config = Configuration.new)
      new(target, config).analyze
    end

    def initialize(target, config = Configuration.new)
      @config = config
      @records = resolve_records(target)
      @count = @records.size
    end

    def analyze
      return empty_result("Insufficient historical price records") if @count < (@config.swing_sensitivity * 2 + 1)

      current_price = parse_f(record_close(@records.last))
      current_date = record_date(@records.last)

      swing_highs, swing_lows = detect_swings
      structure = classify_structure(swing_highs, swing_lows)
      trend = determine_trend(structure, current_price)

      support_levels = detect_support_zones(swing_lows, current_price)
      resistance_levels = detect_resistance_zones(swing_highs, current_price)

      breakout_info = detect_breakout(current_price, resistance_levels, swing_highs)
      confidence = calculate_confidence(trend, structure, support_levels, resistance_levels)

      {
        symbol: extract_symbol,
        traded_on: current_date,
        current_price: current_price,
        trend: trend,
        structure: structure,
        swing_highs: swing_highs.map { |s| s.slice(:price, :traded_on, :index) },
        swing_lows: swing_lows.map { |s| s.slice(:price, :traded_on, :index) },
        support_levels: support_levels,
        resistance_levels: resistance_levels,
        breakout_level: breakout_info[:breakout_level],
        distance_to_breakout: breakout_info[:distance_to_breakout],
        is_breakout_near: breakout_info[:is_near],
        confidence: confidence
      }
    end

    private

    def resolve_records(target)
      if target.is_a?(Stock)
        target.daily_prices.chronological.to_a
      elsif target.respond_to?(:to_a)
        target.to_a.sort_by { |r| record_date(r) }
      else
        []
      end
    end

    def extract_symbol
      first = @records.first
      return first.stock.symbol if first.respond_to?(:stock) && first.stock.respond_to?(:symbol)
      return first.symbol if first.respond_to?(:symbol)
      return first[:symbol] if first.is_a?(Hash) && first[:symbol]

      "UNKNOWN"
    end

    def detect_swings
      sensitivity = @config.swing_sensitivity
      highs = []
      lows = []

      (sensitivity...(@count - sensitivity)).each do |i|
        current_high = parse_f(record_high(@records[i]))
        current_low = parse_f(record_low(@records[i]))

        window = ((i - sensitivity)..(i + sensitivity)).reject { |idx| idx == i }

        is_high = window.all? { |idx| current_high > parse_f(record_high(@records[idx])) }
        is_low = window.all? { |idx| current_low < parse_f(record_low(@records[idx])) }

        if is_high
          highs << {
            price: current_high,
            traded_on: record_date(@records[i]),
            index: i
          }
        end

        if is_low
          lows << {
            price: current_low,
            traded_on: record_date(@records[i]),
            index: i
          }
        end
      end

      [highs, lows]
    end

    def classify_structure(highs, lows)
      return "insufficient_swings" if highs.size < 2 || lows.size < 2

      last_high = highs.last[:price]
      prev_high = highs[-2][:price]

      last_low = lows.last[:price]
      prev_low = lows[-2][:price]

      if last_high > prev_high && last_low > prev_low
        "higher_high_higher_low"
      elsif last_high < prev_high && last_low < prev_low
        "lower_high_lower_low"
      else
        "mixed"
      end
    end

    def determine_trend(structure, current_price)
      return "sideways" if @count < 20

      sma20 = (@records.last(20).sum { |r| parse_f(record_close(r)) } / 20.0).round(2)

      if structure == "higher_high_higher_low" && current_price >= sma20
        "uptrend"
      elsif structure == "lower_high_lower_low" && current_price <= sma20
        "downtrend"
      else
        "sideways"
      end
    end

    def detect_support_zones(lows, current_price)
      return [] if lows.empty?

      # Filter swing lows at or below current price
      candidates = lows.map { |l| l[:price] }.sort
      clusters = cluster_prices(candidates)

      clusters.filter_map do |cluster|
        avg_level = (cluster.sum / cluster.size.to_f).round(2)
        next if avg_level > current_price * 1.02 # Must be below or near current price

        anchors = lows.select { |l| cluster.include?(l[:price]) }.map { |l| l[:traded_on] }.uniq

        {
          level: avg_level,
          touch_count: cluster.size,
          anchor_dates: anchors,
          type: "support",
          pct_distance: (((current_price - avg_level) / current_price) * 100.0).round(2)
        }
      end.sort_by { |z| (current_price - z[:level]).abs }
    end

    def detect_resistance_zones(highs, current_price)
      return [] if highs.empty?

      candidates = highs.map { |h| h[:price] }.sort
      clusters = cluster_prices(candidates)

      clusters.filter_map do |cluster|
        avg_level = (cluster.sum / cluster.size.to_f).round(2)
        next if avg_level < current_price * 0.98 # Must be above or near current price

        anchors = highs.select { |h| cluster.include?(h[:price]) }.map { |h| h[:traded_on] }.uniq

        {
          level: avg_level,
          touch_count: cluster.size,
          anchor_dates: anchors,
          type: "resistance",
          pct_distance: (((avg_level - current_price) / current_price) * 100.0).round(2)
        }
      end.sort_by { |z| (z[:level] - current_price).abs }
    end

    def cluster_prices(prices)
      return [] if prices.empty?

      tolerance_fraction = @config.sr_tolerance_pct / 100.0
      clusters = []
      current_cluster = [prices.first]

      prices.drop(1).each do |price|
        cluster_avg = current_cluster.sum / current_cluster.size.to_f
        if (price - cluster_avg).abs / cluster_avg <= tolerance_fraction
          current_cluster << price
        else
          clusters << current_cluster
          current_cluster = [price]
        end
      end
      clusters << current_cluster
      clusters
    end

    def detect_breakout(current_price, resistance_zones, swing_highs)
      # Find nearest resistance above current price or recent max swing high
      resistance_above = resistance_zones.select { |r| r[:level] >= current_price }
                                          .sort_by { |r| r[:level] }

      breakout_level = if resistance_above.any?
                         resistance_above.first[:level]
                       elsif swing_highs.any?
                         swing_highs.map { |h| h[:price] }.max
                       else
                         current_price
                       end

      distance = if breakout_level.positive?
                   (((breakout_level - current_price) / current_price) * 100.0).round(2)
                 else
                   0.0
                 end

      is_near = distance.abs <= @config.breakout_tolerance_pct

      {
        breakout_level: breakout_level,
        distance_to_breakout: distance,
        is_near: is_near
      }
    end

    def calculate_confidence(trend, structure, supports, resistances)
      confidence = 0.50

      # Structure clarity bonus
      confidence += 0.20 if %w[higher_high_higher_low lower_high_lower_low].include?(structure)

      # Trend-Structure alignment bonus
      confidence += 0.15 if (trend == "uptrend" && structure == "higher_high_higher_low") ||
                            (trend == "downtrend" && structure == "lower_high_lower_low")

      # Support/Resistance test count bonus
      max_touches = (supports + resistances).map { |z| z[:touch_count] }.max || 0
      confidence += 0.15 if max_touches >= @config.min_sr_touches

      confidence.clamp(0.0, 1.0).round(2)
    end

    def record_date(rec)
      rec.respond_to?(:traded_on) ? rec.traded_on : (rec[:traded_on] || rec[:date])
    end

    def record_close(rec)
      rec.respond_to?(:close_price) ? rec.close_price : (rec[:close_price] || rec[:close])
    end

    def record_high(rec)
      rec.respond_to?(:high_price) ? rec.high_price : (rec[:high_price] || rec[:high])
    end

    def record_low(rec)
      rec.respond_to?(:low_price) ? rec.low_price : (rec[:low_price] || rec[:low])
    end

    def parse_f(val)
      val.to_f
    end

    def empty_result(reason)
      {
        symbol: extract_symbol,
        trend: "unknown",
        structure: "unknown",
        reason: reason,
        swing_highs: [],
        swing_lows: [],
        support_levels: [],
        resistance_levels: [],
        breakout_level: nil,
        distance_to_breakout: nil,
        confidence: 0.0
      }
    end
  end
end
