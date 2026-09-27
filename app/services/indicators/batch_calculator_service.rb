module Indicators
  class BatchCalculatorService
    DEFAULT_LOOKBACK_BARS = 260
    DEFAULT_BATCH_SIZE = 20

    def self.call(symbols: nil, lookback_bars: DEFAULT_LOOKBACK_BARS, batch_size: DEFAULT_BATCH_SIZE, recalculate_all: false)
      new(
        symbols: symbols,
        lookback_bars: lookback_bars,
        batch_size: batch_size,
        recalculate_all: recalculate_all
      ).calculate
    end

    def initialize(symbols: nil, lookback_bars: DEFAULT_LOOKBACK_BARS, batch_size: DEFAULT_BATCH_SIZE, recalculate_all: false)
      @symbols = Array(symbols).map { |s| s.to_s.strip.upcase }.reject(&:blank?)
      @lookback_bars = [lookback_bars.to_i, 50].max
      @batch_size = [batch_size.to_i, 1].max
      @recalculate_all = recalculate_all
    end

    def calculate
      target_stocks = scoped_stocks
      total_stocks = target_stocks.count
      return empty_result("No active stocks found for calculation") if total_stocks.zero?

      Rails.logger.info("Starting Indicators::BatchCalculatorService for #{total_stocks} stocks (Lookback: #{@lookback_bars} bars)...")

      processed_stocks = 0
      processed_indicators = 0
      failed_stocks = []

      target_stocks.find_in_batches(batch_size: @batch_size).with_index(1) do |batch, batch_num|
        total_batches = (total_stocks.to_f / @batch_size).ceil
        Rails.logger.info("Processing Indicator Batch #{batch_num}/#{total_batches}...")

        batch.each do |stock|
          stock_result = calculate_for_stock(stock)
          if stock_result[:success]
            processed_stocks += 1
            processed_indicators += stock_result[:count]
          else
            failed_stocks << { symbol: stock.symbol, error: stock_result[:error] }
          end
        end
      end

      Rails.logger.info("Completed Indicators::BatchCalculatorService: #{processed_stocks}/#{total_stocks} stocks, #{processed_indicators} indicator records created/updated.")

      {
        success: true,
        total_stocks: total_stocks,
        processed_stocks: processed_stocks,
        processed_indicators: processed_indicators,
        failed_stocks: failed_stocks
      }
    rescue StandardError => e
      Rails.logger.error("Indicators::BatchCalculatorService fatal exception: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      { success: false, error: e.message, processed_stocks: 0, processed_indicators: 0 }
    end

    private

    def scoped_stocks
      scope = Stock.active
      scope = scope.where(symbol: @symbols) if @symbols.any?
      scope.order(:id)
    end

    def calculate_for_stock(stock)
      prices = stock.daily_prices.chronological
      prices = prices.last(@lookback_bars) unless @recalculate_all
      return { success: true, count: 0 } if prices.empty?

      indicator_metrics = CalculatorService.calculate_series(prices)
      return { success: true, count: 0 } if indicator_metrics.empty?

      # Find existing indicator dates for incremental skipping if not recalculating all
      existing_dates = if @recalculate_all
                         Set.new
                       else
                         Set.new(stock.daily_indicators.between_dates(prices.first.traded_on, prices.last.traded_on).pluck(:traded_on))
                       end

      created_or_updated = 0

      Stock.transaction do
        indicator_metrics.each do |metric|
          next if metric[:traded_on].nil?
          next if existing_dates.include?(metric[:traded_on]) && !@recalculate_all

          record = StockDailyIndicator.find_or_initialize_by(
            stock: stock,
            traded_on: metric[:traded_on]
          )

          record.assign_attributes(
            stock_daily_price_id: metric[:stock_daily_price_id],
            sma_20: metric[:sma_20],
            sma_50: metric[:sma_50],
            sma_150: metric[:sma_150],
            sma_200: metric[:sma_200],
            ema_20: metric[:ema_20],
            ema_50: metric[:ema_50],
            atr_14: metric[:atr_14],
            atr_percent: metric[:atr_percent],
            avg_volume_10: metric[:avg_volume_10],
            avg_volume_20: metric[:avg_volume_20],
            avg_volume_50: metric[:avg_volume_50],
            rvol: metric[:rvol],
            high_52w: metric[:high_52w],
            low_52w: metric[:low_52w],
            pct_below_high_52w: metric[:pct_below_high_52w],
            pct_above_low_52w: metric[:pct_above_low_52w],
            change_pct_1d: metric[:change_pct_1d],
            change_pct_20d: metric[:change_pct_20d],
            change_pct_50d: metric[:change_pct_50d]
          )

          record.save!
          created_or_updated += 1
        end
      end

      { success: true, count: created_or_updated }
    rescue StandardError => e
      Rails.logger.error("Error calculating indicators for #{stock.symbol}: #{e.message}")
      { success: false, error: e.message, count: 0 }
    end

    def empty_result(msg)
      { success: false, error: msg, processed_stocks: 0, processed_indicators: 0 }
    end
  end
end
