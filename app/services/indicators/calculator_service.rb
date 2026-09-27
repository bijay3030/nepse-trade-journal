module Indicators
  class CalculatorService
    def self.calculate_series(records)
      new(records).calculate_series
    end

    def self.calculate_for_bar(records, index)
      new(records).calculate_for_bar(index)
    end

    def initialize(records)
      # Ensure records are sorted chronologically
      @records = records.sort_by { |r| record_date(r) }
      @count = @records.size
    end

    def calculate_series
      return [] if @count.zero?

      ema20_series = calculate_ema_series(20)
      ema50_series = calculate_ema_series(50)
      atr14_series = calculate_atr_series(14)

      @records.each_with_index.map do |record, idx|
        calculate_metrics_at(idx, record, ema20_series[idx], ema50_series[idx], atr14_series[idx])
      end
    end

    def calculate_for_bar(index)
      return nil if index < 0 || index >= @count

      ema20_series = calculate_ema_series(20)
      ema50_series = calculate_ema_series(50)
      atr14_series = calculate_atr_series(14)

      calculate_metrics_at(index, @records[index], ema20_series[index], ema50_series[index], atr14_series[index])
    end

    private

    def calculate_metrics_at(idx, record, ema20, ema50, atr14)
      close_price = parse_f(record_close(record))
      volume = parse_i(record_volume(record))

      # Trend (SMAs)
      sma20 = calculate_sma(idx, 20)
      sma50 = calculate_sma(idx, 50)
      sma150 = calculate_sma(idx, 150)
      sma200 = calculate_sma(idx, 200)

      # Volatility
      atr_percent = (atr14 && close_price.positive?) ? ((atr14 / close_price) * 100.0).round(2) : nil

      # Volume
      avg_vol10 = calculate_avg_volume(idx, 10)
      avg_vol20 = calculate_avg_volume(idx, 20)
      avg_vol50 = calculate_avg_volume(idx, 50)
      rvol = (avg_vol20 && avg_vol20.positive?) ? (volume.to_f / avg_vol20).round(2) : nil

      # Price Position (52W / 250 bars)
      lookback_52w = [idx + 1, 250].min
      window_records = @records[(idx - lookback_52w + 1)..idx]
      high_52w = window_records.map { |r| parse_f(record_high(r)) }.max
      low_52w = window_records.map { |r| parse_f(record_low(r)) }.min

      pct_below_high_52w = (high_52w && high_52w.positive?) ? (((high_52w - close_price) / high_52w) * 100.0).round(2) : nil
      pct_above_low_52w = (low_52w && low_52w.positive?) ? (((close_price - low_52w) / low_52w) * 100.0).round(2) : nil

      # Momentum (% Change)
      change_1d = calculate_pct_change(idx, 1)
      change_20d = calculate_pct_change(idx, 20)
      change_50d = calculate_pct_change(idx, 50)

      {
        traded_on: record_date(record),
        stock_daily_price_id: record_id(record),
        sma_20: round_d(sma20),
        sma_50: round_d(sma50),
        sma_150: round_d(sma150),
        sma_200: round_d(sma200),
        ema_20: round_d(ema20),
        ema_50: round_d(ema50),
        atr_14: round_d(atr14),
        atr_percent: atr_percent,
        avg_volume_10: avg_vol10,
        avg_volume_20: avg_vol20,
        avg_volume_50: avg_vol50,
        rvol: rvol,
        high_52w: round_d(high_52w),
        low_52w: round_d(low_52w),
        pct_below_high_52w: pct_below_high_52w,
        pct_above_low_52w: pct_above_low_52w,
        change_pct_1d: change_1d,
        change_pct_20d: change_20d,
        change_pct_50d: change_50d
      }
    end

    def calculate_sma(end_idx, period)
      return nil if end_idx < period - 1

      sum = (end_idx - period + 1..end_idx).sum { |i| parse_f(record_close(@records[i])) }
      sum / period.to_f
    end

    def calculate_ema_series(period)
      ema_series = Array.new(@count, nil)
      return ema_series if @count < period

      # Seed with SMA of first `period` bars
      initial_sma = (0...period).sum { |i| parse_f(record_close(@records[i])) } / period.to_f
      ema_series[period - 1] = initial_sma

      multiplier = 2.0 / (period + 1.0)
      (period...@count).each do |i|
        close_p = parse_f(record_close(@records[i]))
        prev_ema = ema_series[i - 1]
        ema_series[i] = (close_p * multiplier) + (prev_ema * (1.0 - multiplier))
      end

      ema_series
    end

    def calculate_atr_series(period)
      atr_series = Array.new(@count, nil)
      return atr_series if @count < period

      tr_series = Array.new(@count, 0.0)
      @records.each_with_index do |rec, i|
        high_p = parse_f(record_high(rec))
        low_p = parse_f(record_low(rec))

        if i == 0
          tr_series[0] = high_p - low_p
        else
          prev_close = parse_f(record_close(@records[i - 1]))
          tr_series[i] = [
            high_p - low_p,
            (high_p - prev_close).abs,
            (low_p - prev_close).abs
          ].max
        end
      end

      # Initial ATR is SMA of True Range for first `period` bars
      initial_atr = tr_series[0...period].sum / period.to_f
      atr_series[period - 1] = initial_atr

      # Wilder's smoothing
      (period...@count).each do |i|
        prev_atr = atr_series[i - 1]
        atr_series[i] = ((prev_atr * (period - 1)) + tr_series[i]) / period.to_f
      end

      atr_series
    end

    def calculate_avg_volume(end_idx, period)
      return nil if end_idx < period - 1

      sum = (end_idx - period + 1..end_idx).sum { |i| parse_i(record_volume(@records[i])) }
      (sum / period.to_f).round
    end

    def calculate_pct_change(end_idx, lookback)
      return nil if end_idx < lookback

      curr_close = parse_f(record_close(@records[end_idx]))
      past_close = parse_f(record_close(@records[end_idx - lookback]))
      return nil if past_close.zero?

      (((curr_close - past_close) / past_close) * 100.0).round(2)
    end

    def record_date(rec)
      rec.respond_to?(:traded_on) ? rec.traded_on : rec[:traded_on]
    end

    def record_id(rec)
      rec.respond_to?(:id) ? rec.id : rec[:id]
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
      rec.respond_to?(:volume) ? rec.volume : rec[:volume]
    end

    def parse_f(val)
      val.to_f
    end

    def parse_i(val)
      val.to_i
    end

    def round_d(val)
      val&.round(2)
    end
  end
end
