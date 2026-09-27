module Vcp
  class DetectionEngine
    def self.call(target, config = Configuration.new)
      new(target, config).detect
    end

    def initialize(target, config = Configuration.new)
      @config = config
      @records = resolve_records(target)
      @count = @records.size
    end

    def detect
      return insufficient_history_result if @count < @config.min_base_duration_bars

      current_price = parse_f(record_close(@records.last))
      current_date = record_date(@records.last)

      base_window = extract_base_window
      prior_bars = base_window.size > 1 ? base_window[0...-1] : base_window
      base_high = base_window.map { |r| parse_f(record_high(r)) }.max
      base_low = prior_bars.map { |r| parse_f(record_low(r)) }.min
      base_duration = base_window.size

      # Check if price has broken down below base low (failed setup)
      if current_price < base_low * 0.98
        return failed_setup_result(base_high, base_low, base_duration, current_price, current_date, "Price broke down below base low")
      end

      # Segment contractions (T1, T2, T3...)
      contractions = segment_contractions(base_window)
      if contractions.empty?
        return no_pattern_result(base_high, base_low, base_duration, current_price, current_date)
      end

      classification = classify_vcp(contractions)
      volume_behavior = analyze_volume_behavior(contractions)

      pivot_level = contractions.last[:high]
      distance_to_pivot = pivot_level.positive? ? (((pivot_level - current_price) / current_price) * 100.0).round(2) : 0.0

      ma_metrics = check_moving_averages(current_price)
      atr_contracting = check_atr_contraction

      price_tightness = contractions.last[:depth_pct]
      score_breakdown, total_score = calculate_setup_quality_score(
        classification: classification,
        contractions: contractions,
        volume_behavior: volume_behavior,
        price_tightness: price_tightness,
        distance_to_pivot: distance_to_pivot,
        above_sma50: ma_metrics[:above_sma50],
        above_sma200: ma_metrics[:above_sma200]
      )

      contraction_text = contractions.map { |c| "#{c[:depth_pct]}%" }.join(" -> ")

      {
        symbol: extract_symbol,
        traded_on: current_date,
        current_price: current_price,
        is_vcp_setup: classification == "contracting_price_and_volume" && total_score >= 60,
        setup_quality_score: total_score,
        classification: classification,
        base_high: base_high,
        base_low: base_low,
        base_duration_bars: base_duration,
        contractions_count: contractions.size,
        contractions: contractions,
        contraction_sequence_text: contraction_text,
        volume_behavior: volume_behavior,
        price_tightness_pct: price_tightness,
        atr_contracting: atr_contracting,
        pivot_level: pivot_level,
        distance_to_pivot_pct: distance_to_pivot,
        is_pivot_near: distance_to_pivot.abs <= @config.pivot_proximity_pct,
        above_sma50: ma_metrics[:above_sma50],
        above_sma200: ma_metrics[:above_sma200],
        score_breakdown: score_breakdown
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

    def extract_base_window
      window_size = [@count, @config.max_base_duration_bars].min
      @records.last(window_size)
    end

    def segment_contractions(window)
      swings = detect_local_swings(window)
      return [] if swings.size < 3

      contractions = []
      # Group swings into High -> Low contraction pairs
      i = 0
      while i < swings.size - 1
        high_swing = swings[i]
        low_swing = swings[i + 1]

        if high_swing[:type] == :high && low_swing[:type] == :low
          high_p = high_swing[:price]
          low_p = low_swing[:price]
          range_p = (high_p - low_p).round(2)
          depth_pct = high_p.positive? ? (((high_p - low_p) / high_p) * 100.0).round(2) : 0.0

          # Calculate total volume in this contraction wave
          sub_window = window[high_swing[:index]..low_swing[:index]] || []
          total_vol = sub_window.sum { |r| parse_i(record_volume(r)) }

          contractions << {
            name: "T#{contractions.size + 1}",
            high: high_p,
            low: low_p,
            range: range_p,
            depth_pct: depth_pct,
            volume: total_vol,
            start_date: high_swing[:traded_on],
            end_date: low_swing[:traded_on]
          }
          i += 2
        else
          i += 1
        end
      end

      contractions
    end

    def detect_local_swings(window)
      sens = @config.swing_sensitivity
      swings = []

      (sens...(window.size - sens)).each do |i|
        high_p = parse_f(record_high(window[i]))
        low_p = parse_f(record_low(window[i]))
        sub_range = ((i - sens)..(i + sens)).reject { |idx| idx == i }

        is_high = sub_range.all? { |idx| high_p > parse_f(record_high(window[idx])) }
        is_low = sub_range.all? { |idx| low_p < parse_f(record_low(window[idx])) }

        if is_high
          swings << { type: :high, price: high_p, index: i, traded_on: record_date(window[i]) }
        end
        if is_low
          swings << { type: :low, price: low_p, index: i, traded_on: record_date(window[i]) }
        end
      end

      swings
    end

    def classify_vcp(contractions)
      return "no_pattern" if contractions.size < @config.min_contractions

      depths = contractions.map { |c| c[:depth_pct] }
      vols = contractions.map { |c| c[:volume] }

      # Highly volatile check
      return "failed_contraction" if depths.any? { |d| d > @config.max_t1_contraction_pct }

      is_price_contracting = depths.each_cons(2).all? { |a, b| a > b }
      is_price_expanding = depths.each_cons(2).all? { |a, b| a < b }

      if is_price_expanding
        "expanding_price"
      elsif is_price_contracting
        if vols.last <= vols.first
          "contracting_price_and_volume"
        else
          "contracting_price_increasing_volume"
        end
      else
        "failed_contraction"
      end
    end

    def analyze_volume_behavior(contractions)
      return "flat" if contractions.empty?

      vols = contractions.map { |c| c[:volume] }
      if vols.each_cons(2).all? { |a, b| a >= b }
        "contracting"
      elsif vols.each_cons(2).all? { |a, b| a <= b }
        "increasing"
      else
        "mixed"
      end
    end

    def check_moving_averages(current_price)
      sma50 = @count >= 50 ? (@records.last(50).sum { |r| parse_f(record_close(r)) } / 50.0).round(2) : nil
      sma200 = @count >= 200 ? (@records.last(200).sum { |r| parse_f(record_close(r)) } / 200.0).round(2) : nil

      {
        above_sma50: sma50.present? && current_price >= sma50,
        above_sma200: sma200.present? && current_price >= sma200
      }
    end

    def check_atr_contraction
      return false if @count < 30

      first_window_tr = @records.first(14).sum { |r| parse_f(record_high(r)) - parse_f(record_low(r)) } / 14.0
      last_window_tr = @records.last(14).sum { |r| parse_f(record_high(r)) - parse_f(record_low(r)) } / 14.0

      last_window_tr < first_window_tr
    end

    def calculate_setup_quality_score(classification:, contractions:, volume_behavior:, price_tightness:, distance_to_pivot:, above_sma50:, above_sma200:)
      scores = {
        trend: 0,
        price_contraction: 0,
        volume_contraction: 0,
        tightness: 0,
        pivot_proximity: 0
      }

      # Trend Alignment (20 pts)
      scores[:trend] += 10 if above_sma50
      scores[:trend] += 10 if above_sma200

      # Price Contraction Sequence (25 pts)
      if classification == "contracting_price_and_volume" || classification == "contracting_price_increasing_volume"
        scores[:price_contraction] += 25
      end

      # Volume Contraction (20 pts)
      if volume_behavior == "contracting"
        scores[:volume_contraction] += 20
      elsif volume_behavior == "mixed"
        scores[:volume_contraction] += 10
      end

      # Tightness (15 pts)
      if price_tightness <= @config.max_final_contraction_pct
        scores[:tightness] += 15
      elsif price_tightness <= @config.max_final_contraction_pct * 1.5
        scores[:tightness] += 8
      end

      # Pivot Proximity (20 pts)
      if distance_to_pivot.abs <= @config.pivot_proximity_pct
        scores[:pivot_proximity] += 20
      elsif distance_to_pivot.abs <= @config.pivot_proximity_pct * 2
        scores[:pivot_proximity] += 10
      end

      total = scores.values.sum.clamp(0, 100)
      [scores, total]
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

    def record_volume(rec)
      rec.respond_to?(:volume) ? rec.volume : (rec[:volume] || 0)
    end

    def parse_f(val)
      val.to_f
    end

    def parse_i(val)
      val.to_i
    end

    def insufficient_history_result
      {
        symbol: extract_symbol,
        is_vcp_setup: false,
        setup_quality_score: 0,
        classification: "insufficient_history",
        reason: "Fewer than required bars (#{@config.min_base_duration_bars})",
        contractions_count: 0,
        contractions: [],
        score_breakdown: { trend: 0, price_contraction: 0, volume_contraction: 0, tightness: 0, pivot_proximity: 0 }
      }
    end

    def failed_setup_result(high, low, duration, current_price, current_date, reason)
      {
        symbol: extract_symbol,
        traded_on: current_date,
        current_price: current_price,
        is_vcp_setup: false,
        setup_quality_score: 0,
        classification: "failed_contraction",
        reason: reason,
        base_high: high,
        base_low: low,
        base_duration_bars: duration,
        contractions_count: 0,
        contractions: [],
        score_breakdown: { trend: 0, price_contraction: 0, volume_contraction: 0, tightness: 0, pivot_proximity: 0 }
      }
    end

    def no_pattern_result(high, low, duration, current_price, current_date)
      {
        symbol: extract_symbol,
        traded_on: current_date,
        current_price: current_price,
        is_vcp_setup: false,
        setup_quality_score: 0,
        classification: "no_pattern",
        base_high: high,
        base_low: low,
        base_duration_bars: duration,
        contractions_count: 0,
        contractions: [],
        score_breakdown: { trend: 0, price_contraction: 0, volume_contraction: 0, tightness: 0, pivot_proximity: 0 }
      }
    end
  end
end
