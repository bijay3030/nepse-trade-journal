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
      prev_close = price_data[:previous_close] || stock.previous_close_before(@traded_on)
      change_amount = price_data[:change_amount] || (prev_close ? (last_price - prev_close).round(2) : nil)
      change_percent = price_data[:change_percent] || (prev_close.to_f.positive? ? (((last_price - prev_close) / prev_close) * 100).round(2) : nil)

      Stock.transaction do
        stock.apply_live_quote!(price_data.merge(previous_close: prev_close, change_percent: change_percent), traded_on: @traded_on)
        stock_updates = {}
        stock_updates[:name] = price_data[:company_name] if price_data[:company_name].present? && stock.name.blank?
        stock_updates[:high_52w] = last_price if stock.high_52w.zero? || last_price > stock.high_52w
        stock_updates[:low_52w] = last_price if stock.low_52w.zero? || last_price < stock.low_52w
        stock.update!(stock_updates) if stock_updates.any?

        # The per-symbol API often returns only the last traded price. Keep any real
        # values already recorded for the day instead of overwriting them.
        daily_record = StockDailyPrice.find_or_initialize_by(stock: stock, traded_on: @traded_on)
        existing = daily_record.persisted?
        daily_record.open_price = price_data[:open_price] || (existing ? daily_record.open_price : last_price)
        daily_record.high_price = price_data[:high_price] || (existing ? [ daily_record.high_price.to_f, last_price ].max : last_price)
        daily_record.low_price = price_data[:low_price] || (existing ? [ daily_record.low_price.to_f, last_price ].select(&:positive?).min : last_price)
        daily_record.close_price = last_price
        daily_record.previous_close = prev_close || (existing ? daily_record.previous_close : last_price)
        daily_record.change_amount = change_amount unless change_amount.nil?
        daily_record.change_percent = change_percent unless change_percent.nil?
        daily_record.volume = price_data[:volume] unless price_data[:volume].nil?
        daily_record.turnover = price_data[:turnover] || (price_data[:volume] ? (last_price * price_data[:volume]).round(2) : daily_record.turnover)
        daily_record.total_trades = price_data[:total_trades] unless price_data[:total_trades].nil?
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
