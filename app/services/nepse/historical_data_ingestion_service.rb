module Nepse
  class HistoricalDataIngestionService
    DEFAULT_BATCH_SIZE = 20
    DEFAULT_LOOKBACK_DAYS = 365

    def self.call(start_date: nil, end_date: nil, symbols: nil, batch_size: DEFAULT_BATCH_SIZE, provider: :historical, custom_provider: nil, force_refresh: false)
      new(
        start_date: start_date,
        end_date: end_date,
        symbols: symbols,
        batch_size: batch_size,
        provider: provider,
        custom_provider: custom_provider,
        force_refresh: force_refresh
      ).ingest
    end

    def initialize(start_date: nil, end_date: nil, symbols: nil, batch_size: DEFAULT_BATCH_SIZE, provider: :historical, custom_provider: nil, force_refresh: false)
      @end_date = end_date.present? ? to_date(end_date) : Date.current
      @start_date = start_date.present? ? to_date(start_date) : (@end_date - DEFAULT_LOOKBACK_DAYS.days)
      @symbols = Array(symbols).map { |s| s.to_s.strip.upcase }.reject(&:blank?)
      @batch_size = [batch_size.to_i, 1].max
      @provider_instance = custom_provider || DataProviders::Factory.for(provider)
      @force_refresh = force_refresh
    end

    def ingest
      target_stocks = scoped_stocks
      total_stocks = target_stocks.count
      return empty_result("No target stocks found") if total_stocks.zero?

      Rails.logger.info("Starting HistoricalDataIngestionService: #{@start_date} to #{@end_date}, Total Stocks: #{total_stocks}, Batch Size: #{@batch_size}")

      processed_stocks = 0
      processed_records = 0
      skipped_records = 0
      failed_stocks = []

      target_stocks.find_in_batches(batch_size: @batch_size).with_index(1) do |batch, batch_num|
        total_batches = (total_stocks.to_f / @batch_size).ceil
        Rails.logger.info("Processing Historical Stock Batch #{batch_num}/#{total_batches} (#{batch.size} stocks)...")

        batch.each do |stock|
          stock_result = process_stock_history(stock)

          if stock_result[:success]
            processed_stocks += 1
            processed_records += stock_result[:processed_count]
            skipped_records += stock_result[:skipped_count]
          else
            failed_stocks << { symbol: stock.symbol, error: stock_result[:error] }
            Rails.logger.warn("Historical ingestion failed for #{stock.symbol}: #{stock_result[:error]}")
          end
        end
      end

      Rails.logger.info("Completed HistoricalDataIngestionService: #{processed_stocks}/#{total_stocks} stocks, #{processed_records} records created/updated, #{skipped_records} skipped, #{failed_stocks.size} failures.")

      {
        success: failed_stocks.empty? || processed_stocks.positive?,
        start_date: @start_date,
        end_date: @end_date,
        total_stocks: total_stocks,
        processed_stocks: processed_stocks,
        processed_records: processed_records,
        skipped_records: skipped_records,
        failed_stocks: failed_stocks
      }
    rescue StandardError => e
      Rails.logger.error("HistoricalDataIngestionService fatal exception: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      {
        success: false,
        error: e.message,
        processed_stocks: 0,
        processed_records: 0
      }
    end

    private

    def scoped_stocks
      scope = Stock.active
      scope = scope.where(symbol: @symbols) if @symbols.any?
      scope.order(:id)
    end

    def process_stock_history(stock)
      # Resumability check: find existing dates in range if not force refreshing
      existing_dates = if @force_refresh
                         Set.new
                       else
                         Set.new(stock.daily_prices.between_dates(@start_date, @end_date).pluck(:traded_on))
                       end

      if @provider_instance.respond_to?(:fetch_historical_prices)
        fetch_res = @provider_instance.fetch_historical_prices(stock.symbol, start_date: @start_date, end_date: @end_date)
        return { success: false, error: fetch_res[:error] } unless fetch_res[:success]

        persist_records_for_stock(stock, fetch_res[:records], existing_dates: existing_dates)
      else
        # Date loop fallback if provider only implements single-date fetching
        persist_by_daily_date_loop(stock, existing_dates: existing_dates)
      end
    rescue StandardError => e
      { success: false, error: e.message }
    end

    def persist_records_for_stock(stock, records, existing_dates:)
      processed_count = 0
      skipped_count = 0

      records.each do |normalized|
        next unless normalized.valid?

        if existing_dates.include?(normalized.traded_on) && !@force_refresh
          skipped_count += 1
          next
        end

        persisted = persist_single_daily_price(stock, normalized)
        if persisted
          processed_count += 1
        else
          skipped_count += 1
        end
      end

      { success: true, processed_count: processed_count, skipped_count: skipped_count }
    end

    def persist_by_daily_date_loop(stock, existing_dates:)
      processed_count = 0
      skipped_count = 0

      (@start_date..@end_date).each do |date|
        next if date.saturday? # Skip NPT non-trading Saturday

        if existing_dates.include?(date) && !@force_refresh
          skipped_count += 1
          next
        end

        fetch_res = @provider_instance.fetch_daily_prices(date)
        next unless fetch_res[:success]

        target = fetch_res[:records].find { |r| r.symbol == stock.symbol }
        next unless target&.valid?

        if persist_single_daily_price(stock, target)
          processed_count += 1
        else
          skipped_count += 1
        end
      end

      { success: true, processed_count: processed_count, skipped_count: skipped_count }
    end

    def persist_single_daily_price(stock, normalized)
      Stock.transaction do
        stock_updates = {
          last_price: normalized.close_price,
          volume: normalized.volume,
          last_updated: Time.current
        }
        stock_updates[:high_52w] = normalized.close_price if stock.high_52w.zero? || normalized.close_price > stock.high_52w
        stock_updates[:low_52w] = normalized.close_price if stock.low_52w.zero? || normalized.close_price < stock.low_52w
        stock.update!(stock_updates)

        daily = StockDailyPrice.find_or_initialize_by(stock: stock, traded_on: normalized.traded_on)
        daily.assign_attributes(normalized.daily_price_attributes)
        daily.save!
      end
      true
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
      Rails.logger.error("Failed persisting daily record for #{stock.symbol} on #{normalized.traded_on}: #{e.message}")
      false
    end

    def to_date(val)
      val.is_a?(Date) ? val : Date.parse(val.to_s)
    end

    def empty_result(msg)
      { success: false, error: msg, processed_stocks: 0, processed_records: 0 }
    end
  end
end
