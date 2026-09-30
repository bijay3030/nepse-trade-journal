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
      every_contraction = all_contractions(base_window)
      contractions = base_contractions(every_contraction)
      if contractions.empty?
        return no_pattern_result(base_high, base_low, base_duration, current_price, current_date)
      end

      classification = classify_vcp(contractions, every_contraction)
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
        score_breakdown: score_breakdown,
        swing_threshold_pct: reversal_pct.round(2),
        qualification_checks: qualification_checks(contractions, ma_metrics)
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

    # Contractions are the pullbacks (swing high -> swing low) of the current base.
    # The base is the most recent run of swings whose highs do not rise by more than
    # max_high_drift_pct, so it starts at the peak the stock is consolidating from.
    def segment_contractions(window)
      base_contractions(all_contractions(window))
    end

    def all_contractions(window)
      pivots = zigzag_pivots(window)
      pivots.each_cons(2).filter_map do |high, low|
        next unless high[:type] == :high && low[:type] == :low

        bars = window[high[:index]..low[:index]] || []
        total_volume = bars.sum { |r| parse_i(record_volume(r)) }
        {
          name: nil,
          high: high[:price],
          low: low[:price],
          range: (high[:price] - low[:price]).round(2),
          depth_pct: high[:price].positive? ? (((high[:price] - low[:price]) / high[:price]) * 100.0).round(2) : 0.0,
          volume: total_volume,
          avg_volume: bars.empty? ? 0 : (total_volume.to_f / bars.size).round,
          bars: bars.size,
          start_date: high[:traded_on],
          end_date: low[:traded_on]
        }
      end
    end

    def base_contractions(contractions)
      return [] if contractions.empty?

      drift = 1 + @config.max_high_drift_pct / 100.0
      start = contractions.size - 1
      start -= 1 while start.positive? && contractions[start][:high] <= contractions[start - 1][:high] * drift
      contractions[start..].each_with_index.map { |c, i| c.merge(name: "T#{i + 1}") }
    end

    # Alternating swing highs and lows, each recorded only once price has reversed by
    # at least zigzag_reversal_pct. An unfinished final decline counts as a swing low
    # once it is deep enough, so a contraction still in progress is included.
    def zigzag_pivots(window)
      return [] if window.size < 3

      threshold = reversal_pct / 100.0
      highs = window.map { |r| parse_f(record_high(r)) }
      lows = window.map { |r| parse_f(record_low(r)) }
      pivots = []

      # Start from the first significant move out of the opening bar.
      mode = nil
      hi_idx = lo_idx = 0
      window.each_index do |i|
        hi_idx = i if highs[i] > highs[hi_idx]
        lo_idx = i if lows[i] < lows[lo_idx]
        if lows[lo_idx].positive? && highs[i] >= lows[lo_idx] * (1 + threshold) && lo_idx < i
          pivots << pivot(:low, lo_idx, lows, window)
          mode = :up
          hi_idx = i
          break
        elsif lows[i] <= highs[hi_idx] * (1 - threshold) && hi_idx < i
          pivots << pivot(:high, hi_idx, highs, window)
          mode = :down
          lo_idx = i
          break
        end
      end
      return [] unless mode

      ((mode == :up ? hi_idx : lo_idx) + 1...window.size).each do |i|
        if mode == :up
          if highs[i] > highs[hi_idx]
            hi_idx = i
          elsif lows[i] <= highs[hi_idx] * (1 - threshold)
            pivots << pivot(:high, hi_idx, highs, window)
            mode = :down
            lo_idx = i
          end
        else
          if lows[i] < lows[lo_idx]
            lo_idx = i
          elsif highs[i] >= lows[lo_idx] * (1 + threshold)
            pivots << pivot(:low, lo_idx, lows, window)
            mode = :up
            hi_idx = i
          end
        end
      end

      # The leg still in progress: a decline deep enough to be a contraction.
      if mode == :down && pivots.last&.dig(:type) == :high && lows[lo_idx] <= pivots.last[:price] * (1 - threshold)
        pivots << pivot(:low, lo_idx, lows, window)
      elsif mode == :up && pivots.last&.dig(:type) == :low && highs[hi_idx] >= pivots.last[:price] * (1 + threshold)
        pivots << pivot(:high, hi_idx, highs, window)
      end

      pivots
    end

    # Reversal needed for a swing: a multiple of this stock's median daily range.
    def reversal_pct
      @reversal_pct ||= begin
        ranges = @records.last(60).filter_map do |r|
          close = parse_f(record_close(r))
          ((parse_f(record_high(r)) - parse_f(record_low(r))) / close) * 100 if close.positive?
        end.sort
        median = ranges.empty? ? 0.0 : ranges[ranges.size / 2]
        (median * @config.zigzag_range_multiple).clamp(@config.zigzag_reversal_pct, @config.zigzag_max_reversal_pct)
      end
    end

    def pivot(type, index, prices, window)
      { type: type, price: prices[index], index: index, traded_on: record_date(window[index]) }
    end

    def classify_vcp(contractions, all = contractions)
      if contractions.size < @config.min_contractions
        depths = all.map { |c| c[:depth_pct] }
        return depths.size >= 2 && depths.each_cons(2).all? { |a, b| a < b } ? "expanding_price" : "no_pattern"
      end
      # Many pullbacks at similar highs is a choppy range, not a contracting base.
      return "no_pattern" if contractions.size > @config.max_contractions

      depths = contractions.map { |c| c[:depth_pct] }
      return "failed_contraction" if depths.first > @config.max_t1_contraction_pct
      # Small pullbacks inside a flat range are not a volatility contraction.
      return "no_pattern" if depths.first < @config.min_t1_contraction_pct || base_bars(contractions) < @config.min_base_duration_bars

      if shrinking?(depths)
        volume_drying_up?(contractions) ? "contracting_price_and_volume" : "contracting_price_increasing_volume"
      elsif depths.each_cons(2).all? { |a, b| a < b }
        "expanding_price"
      else
        "failed_contraction"
      end
    end

    def shrinking?(depths)
      depths.size >= 2 && depths.each_cons(2).all? { |a, b| b <= a * @config.max_depth_ratio }
    end

    # Trading days from the start of the first contraction to the latest bar.
    def base_bars(contractions)
      start = contractions.first[:start_date]
      @records.count { |r| record_date(r) >= start }
    end

    # Average daily volume, so a long contraction is not judged heavier just for lasting longer.
    def volume_drying_up?(contractions)
      contractions.last[:avg_volume] < contractions.first[:avg_volume]
    end

    def analyze_volume_behavior(contractions)
      return "flat" if contractions.empty?

      vols = contractions.map { |c| c[:avg_volume] || c[:volume] }
      if vols.each_cons(2).all? { |a, b| a >= b }
        "contracting"
      elsif vols.each_cons(2).all? { |a, b| a <= b }
        "increasing"
      else
        "mixed"
      end
    end

    # Each rule of a qualified VCP, pass or fail, for display.
    def qualification_checks(contractions, ma_metrics)
      depths = contractions.map { |c| c[:depth_pct] }
      count = contractions.size
      [
        { key: "contraction_count", label: "#{@config.min_contractions}-#{@config.max_contractions} contractions",
          passed: count.between?(@config.min_contractions, @config.max_contractions), detail: "#{count} found" },
        { key: "shrinking", label: "Each contraction at most #{(@config.max_depth_ratio * 100).round}% as deep as the last",
          passed: shrinking?(depths), detail: depths.map { "#{_1}%" }.join(" -> ") },
        { key: "first_depth", label: "First contraction #{@config.min_t1_contraction_pct.round}-#{@config.max_t1_contraction_pct.round}%",
          passed: depths.first.to_f.between?(@config.min_t1_contraction_pct, @config.max_t1_contraction_pct), detail: "#{depths.first}%" },
        { key: "base_length", label: "Base at least #{@config.min_base_duration_bars} trading days",
          passed: count.positive? && base_bars(contractions) >= @config.min_base_duration_bars, detail: count.positive? ? "#{base_bars(contractions)} days" : "n/a" },
        { key: "final_depth", label: "Last contraction at most #{@config.max_final_contraction_pct.round}%",
          passed: depths.last.to_f.positive? && depths.last <= @config.max_final_contraction_pct, detail: "#{depths.last}%" },
        { key: "volume_drying_up", label: "Volume drying up",
          passed: count >= 2 && volume_drying_up?(contractions),
          detail: count >= 2 ? "avg #{contractions.first[:avg_volume]} -> #{contractions.last[:avg_volume]} shares/day" : "n/a" },
        { key: "above_sma50", label: "Price above its 50-day average", passed: ma_metrics[:above_sma50] == true, detail: nil }
      ]
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
