module Nepse
  class MarketDataIngestionService
    def self.call(date = Date.current, provider: :yonepse, custom_provider: nil)
      new(date: date, provider: provider, custom_provider: custom_provider).ingest
    end

    def initialize(date: Date.current, provider: :yonepse, custom_provider: nil)
      @date = date.is_a?(Date) ? date : (Date.parse(date.to_s) rescue Date.current)
      @provider_instance = custom_provider || DataProviders::Factory.for(provider)
    end

    def ingest
      fetch_result = @provider_instance.fetch_daily_prices(@date)

      unless fetch_result[:success]
        Rails.logger.error("MarketDataIngestionService failed: #{fetch_result[:error]}")
        return {
          success: false,
          date: @date,
          error: fetch_result[:error],
          processed_count: 0,
          failed_count: 0
        }
      end

      records = fetch_result[:records] || []
      processed_count = 0
      failed_records = []

      records.each do |normalized|
        persisted = persist_record(normalized)
        if persisted
          processed_count += 1
        else
          failed_records << normalized.symbol
        end
      end

      Rails.logger.info("MarketDataIngestionService completed for #{@date}: #{processed_count} processed, #{failed_records.size} failed.")

      {
        success: true,
        date: @date,
        processed_count: processed_count,
        failed_count: failed_records.size,
        failed_symbols: failed_records
      }
    rescue StandardError => e
      Rails.logger.error("MarketDataIngestionService unhandled exception: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      {
        success: false,
        date: @date,
        error: e.message,
        processed_count: 0,
        failed_count: 0
      }
    end

    private

    def persist_record(normalized)
      return false unless normalized.valid?

      Stock.transaction do
        stock = Stock.find_or_initialize_by(symbol: normalized.symbol)
        stock.assign_attributes(normalized.stock_attributes)

        if stock.high_52w.zero? || normalized.close_price > stock.high_52w
          stock.high_52w = normalized.close_price
        end

        if stock.low_52w.zero? || normalized.close_price < stock.low_52w
          stock.low_52w = normalized.close_price
        end

        stock.save!
        stock.recalculate_market_cap! if stock.respond_to?(:recalculate_market_cap!)

        daily_price = StockDailyPrice.find_or_initialize_by(
          stock: stock,
          traded_on: normalized.traded_on
        )
        daily_price.assign_attributes(normalized.daily_price_attributes)
        daily_price.save!
      end

      true
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid => e
      Rails.logger.error("MarketDataIngestionService failed to persist record for #{normalized.symbol}: #{e.message}")
      false
    end
  end
end
