require "csv"

module Nepse
  class CsvImporterService
    def self.call(file_or_path, type: "prices")
      new(file_or_path, type: type).import
    end

    def initialize(file_or_path, type: "prices")
      @file_or_path = file_or_path
      @type = type.to_s.downcase
    end

    def import
      content = resolve_content
      return { success: false, error: "Could not read CSV file" } if content.blank?

      rows = CSV.parse(content, headers: true, header_converters: :symbol)
      imported_count = 0
      errors = []

      rows.each_with_index do |row, index|
        symbol = row[:symbol].to_s.upcase.strip
        next if symbol.blank?

        stock = Stock.find_by(symbol: symbol)
        unless stock
          errors << "Row #{index + 2}: Stock symbol '#{symbol}' not found in database."
          next
        end

        if @type == "financials"
          import_financial_row(stock, row, errors, index)
        else
          import_price_row(stock, row, errors, index)
        end
        imported_count += 1
      rescue StandardError => e
        errors << "Row #{index + 2}: #{e.message}"
      end

      { success: errors.empty?, imported: imported_count, errors: errors }
    end

    private

    def resolve_content
      if @file_or_path.respond_to?(:read)
        @file_or_path.read
      elsif @file_or_path.is_a?(String) && File.exist?(@file_or_path)
        File.read(@file_or_path)
      elsif @file_or_path.is_a?(String)
        @file_or_path
      end
    end

    def import_price_row(stock, row, errors, index)
      traded_on = Date.parse(row[:traded_on] || row[:date]) rescue nil
      unless traded_on
        errors << "Row #{index + 2}: Invalid date '#{row[:traded_on] || row[:date]}'"
        return
      end

      close_price = (row[:close_price] || row[:close] || row[:ltp]).to_f
      open_price = (row[:open_price] || row[:open] || close_price).to_f
      high_price = (row[:high_price] || row[:high] || [open_price, close_price].max).to_f
      low_price = (row[:low_price] || row[:low] || [open_price, close_price].min).to_f
      previous_close = (row[:previous_close] || row[:prev_close] || open_price).to_f
      volume = (row[:volume] || row[:qty] || 0).to_i
      turnover = (row[:turnover] || (close_price * volume)).to_f

      record = StockDailyPrice.find_or_initialize_by(stock: stock, traded_on: traded_on)
      record.open_price = open_price
      record.high_price = high_price
      record.low_price = low_price
      record.close_price = close_price
      record.previous_close = previous_close
      record.volume = volume
      record.turnover = turnover
      record.total_trades = (row[:total_trades] || row[:trades] || 0).to_i
      record.save!

      # Update stock current pricing if this is the newest date
      if stock.last_updated.nil? || traded_on >= stock.last_updated.to_date
        stock.update!(
          last_price: close_price,
          volume: volume,
          last_updated: traded_on.to_time
        )
        stock.recalculate_market_cap!
      end
    end

    def import_financial_row(stock, row, errors, index)
      fiscal_year = row[:fiscal_year].to_s.strip
      quarter = row[:quarter].to_s.strip
      if fiscal_year.blank? || quarter.blank?
        errors << "Row #{index + 2}: Fiscal year and quarter are required."
        return
      end

      record = StockCompanyFinancial.find_or_initialize_by(
        stock: stock,
        fiscal_year: fiscal_year,
        quarter: quarter
      )
      record.reported_on = Date.parse(row[:reported_on]) rescue nil
      record.eps = (row[:eps] || 0.0).to_f
      record.pe_ratio = (row[:pe_ratio] || 0.0).to_f
      record.book_value = (row[:book_value] || row[:bvps] || 0.0).to_f
      record.pb_ratio = (row[:pb_ratio] || 0.0).to_f
      record.roe = (row[:roe] || 0.0).to_f
      record.net_profit = (row[:net_profit] || 0.0).to_f
      record.paid_up_capital = (row[:paid_up_capital] || 0.0).to_f
      record.reserve_and_surplus = (row[:reserve_and_surplus] || 0.0).to_f
      record.npl_ratio = (row[:npl_ratio] || 0.0).to_f
      record.save!
    end
  end
end
