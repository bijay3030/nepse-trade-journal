module Nepse
  class DailyPriceImporterService
    def self.call(date = Date.current, symbols: nil)
      new(date: date, symbols: symbols).import
    end

    def initialize(date: Date.current, symbols: nil)
      @traded_on = date
      @symbols = symbols
    end

    def import
      target_stocks = Stock.active
      target_stocks = target_stocks.where(symbol: @symbols) if @symbols.present?

      processed = 0
      failed = 0

      target_stocks.find_each do |stock|
        price_data = NepsePriceService.new(stock.symbol).fetch_current
        if price_data.present?
          record_daily_price(stock, price_data)
          processed += 1
        else
          record_fallback_daily_price(stock)
          failed += 1
        end
      end

      { success: true, date: @traded_on, processed: processed, fallback_used: failed }
    rescue StandardError => e
      Rails.logger.error("Nepse::DailyPriceImporterService error: #{e.message}")
      { success: false, error: e.message }
    end

    private

    def record_daily_price(stock, price_data)
      last_price = price_data[:last_price]
      prev_close = price_data[:previous_close] || (stock.last_price > 0 ? stock.last_price : last_price)
      change_amount = price_data[:change_amount] || (last_price - prev_close).round(2)
      change_percent = price_data[:change_percent] || (prev_close > 0 ? (((last_price - prev_close) / prev_close) * 100).round(2) : 0.0)
      volume = price_data[:volume] || 0
      turnover = price_data[:turnover] || (last_price * volume).round(2)
      total_trades = price_data[:total_trades] || 0

      Stock.transaction do
        # Update Master Stock Table
        stock_updates = {
          last_price: last_price,
          change_percent: change_percent,
          volume: volume,
          last_updated: price_data[:last_updated] || Time.current
        }
        stock_updates[:name] = price_data[:company_name] if price_data[:company_name].present? && stock.name.blank?

        if stock.high_52w.zero? || last_price > stock.high_52w
          stock_updates[:high_52w] = last_price
        end

        if stock.low_52w.zero? || last_price < stock.low_52w
          stock_updates[:low_52w] = last_price
        end

        stock.update!(stock_updates)
        stock.recalculate_market_cap!

        # Record Daily Floor Sheet Record
        daily_record = StockDailyPrice.find_or_initialize_by(stock: stock, traded_on: @traded_on)
        daily_record.open_price = price_data[:open_price] || prev_close
        daily_record.high_price = price_data[:high_price] || [prev_close, last_price].max
        daily_record.low_price = price_data[:low_price] || [prev_close, last_price].min
        daily_record.close_price = last_price
        daily_record.previous_close = prev_close
        daily_record.change_amount = change_amount
        daily_record.change_percent = change_percent
        daily_record.volume = volume
        daily_record.turnover = turnover
        daily_record.total_trades = total_trades
        daily_record.save!
      end
    end

    def record_fallback_daily_price(stock)
      return if stock.last_price.nil? || stock.last_price.zero?

      daily_record = StockDailyPrice.find_or_initialize_by(stock: stock, traded_on: @traded_on)
      return if daily_record.persisted?

      daily_record.open_price = stock.last_price
      daily_record.high_price = stock.last_price
      daily_record.low_price = stock.last_price
      daily_record.close_price = stock.last_price
      daily_record.previous_close = stock.last_price
      daily_record.volume = stock.volume
      daily_record.turnover = (stock.last_price * stock.volume).round(2)
      daily_record.save!
    end
  end
end
