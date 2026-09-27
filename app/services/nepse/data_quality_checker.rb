module Nepse
  class DataQualityChecker
    def self.call(start_date: nil, end_date: nil, symbols: nil)
      new(start_date: start_date, end_date: end_date, symbols: symbols).audit
    end

    def initialize(start_date: nil, end_date: nil, symbols: nil)
      @start_date = start_date.present? ? to_date(start_date) : 365.days.ago.to_date
      @end_date = end_date.present? ? to_date(end_date) : Date.current
      @symbols = Array(symbols).map { |s| s.to_s.strip.upcase }.reject(&:blank?)
    end

    def audit
      target_stocks = scoped_stocks
      anomalies = {
        impossible_ohlc: [],
        negative_volume: [],
        zero_prices: [],
        duplicate_records: [],
        close_outside_high_low: [],
        missing_trading_dates: []
      }

      total_records_checked = 0

      target_stocks.find_each do |stock|
        prices = stock.daily_prices.between_dates(@start_date, @end_date).order(:traded_on)
        total_records_checked += prices.size

        # Check duplicates
        check_duplicates(stock, anomalies[:duplicate_records])

        # Check records for OHLC & volume anomalies
        prices.each do |record|
          check_ohlc_integrity(stock, record, anomalies)
          check_volume_integrity(stock, record, anomalies[:negative_volume])
          check_zero_prices(stock, record, anomalies[:zero_prices])
        end

        # Check missing trading dates (Sun-Thu)
        check_missing_dates(stock, prices, anomalies[:missing_trading_dates])
      end

      total_anomalies = anomalies.values.sum(&:size)
      clean = total_anomalies.zero?

      {
        success: true,
        clean: clean,
        start_date: @start_date,
        end_date: @end_date,
        stocks_checked: target_stocks.count,
        records_checked: total_records_checked,
        total_anomalies: total_anomalies,
        anomalies: anomalies
      }
    end

    private

    def scoped_stocks
      scope = Stock.active
      scope = scope.where(symbol: @symbols) if @symbols.any?
      scope
    end

    def check_ohlc_integrity(stock, record, anomalies)
      open_p = record.open_price.to_f
      high_p = record.high_price.to_f
      low_p = record.low_price.to_f
      close_p = record.close_price.to_f

      if high_p < low_p || open_p > high_p || open_p < low_p
        anomalies[:impossible_ohlc] << {
          stock_id: stock.id,
          symbol: stock.symbol,
          record_id: record.id,
          traded_on: record.traded_on,
          open: open_p, high: high_p, low: low_p, close: close_p,
          issue: "High is less than Low or Open is outside High/Low range"
        }
      end

      if close_p > high_p || close_p < low_p
        anomalies[:close_outside_high_low] << {
          stock_id: stock.id,
          symbol: stock.symbol,
          record_id: record.id,
          traded_on: record.traded_on,
          close: close_p, high: high_p, low: low_p,
          issue: "Close price is outside High-Low boundaries"
        }
      end
    end

    def check_volume_integrity(stock, record, anomaly_list)
      if record.volume.negative? || record.turnover.negative?
        anomaly_list << {
          stock_id: stock.id,
          symbol: stock.symbol,
          record_id: record.id,
          traded_on: record.traded_on,
          volume: record.volume,
          turnover: record.turnover.to_f,
          issue: "Negative volume or turnover detected"
        }
      end
    end

    def check_zero_prices(stock, record, anomaly_list)
      if record.close_price.to_f <= 0 || record.high_price.to_f <= 0 || record.low_price.to_f <= 0
        anomaly_list << {
          stock_id: stock.id,
          symbol: stock.symbol,
          record_id: record.id,
          traded_on: record.traded_on,
          close: record.close_price.to_f,
          high: record.high_price.to_f,
          low: record.low_price.to_f,
          issue: "Zero or negative price detected on active record"
        }
      end
    end

    def check_duplicates(stock, anomaly_list)
      duplicates = stock.daily_prices.between_dates(@start_date, @end_date)
                        .group(:traded_on)
                        .having("COUNT(id) > 1")
                        .count

      duplicates.each do |traded_on, count|
        anomaly_list << {
          stock_id: stock.id,
          symbol: stock.symbol,
          traded_on: traded_on,
          count: count,
          issue: "Duplicate records for same stock and date"
        }
      end
    end

    def check_missing_dates(stock, prices, anomaly_list)
      return if prices.empty?

      existing_dates = Set.new(prices.map(&:traded_on))
      min_date = prices.first.traded_on
      max_date = prices.last.traded_on

      missing = []
      (min_date..max_date).each do |date|
        next if date.friday? || date.saturday? # NEPSE weekend days (Friday/Saturday)
        next if existing_dates.include?(date)

        missing << date
      end

      return if missing.empty?

      anomaly_list << {
        stock_id: stock.id,
        symbol: stock.symbol,
        missing_count: missing.size,
        missing_dates_sample: missing.take(5),
        issue: "Missing business trading days between #{min_date} and #{max_date}"
      }
    end

    def to_date(val)
      val.is_a?(Date) ? val : Date.parse(val.to_s)
    end
  end
end
