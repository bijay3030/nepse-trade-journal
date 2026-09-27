module Nepse
  class StockBasicsSyncService
    DEFAULT_FAILURE_THRESHOLD = 0.5
    DEFAULT_REQUEST_DELAY_SECONDS = 0.25

    def self.call(traded_on: Date.current, market_client: Source::SharesansarMarketClient.new, company_client: Source::MerolaganiCompanyClient.new, fundamentals_failure_threshold: DEFAULT_FAILURE_THRESHOLD, request_delay_seconds: DEFAULT_REQUEST_DELAY_SECONDS)
      new(
        traded_on: traded_on,
        market_client: market_client,
        company_client: company_client,
        fundamentals_failure_threshold: fundamentals_failure_threshold,
        request_delay_seconds: request_delay_seconds
      ).call
    end

    def self.sync_market(traded_on: Date.current, market_client: Source::SharesansarMarketClient.new, company_client: Source::MerolaganiCompanyClient.new, fundamentals_failure_threshold: DEFAULT_FAILURE_THRESHOLD, request_delay_seconds: DEFAULT_REQUEST_DELAY_SECONDS)
      new(
        traded_on: traded_on,
        market_client: market_client,
        company_client: company_client,
        fundamentals_failure_threshold: fundamentals_failure_threshold,
        request_delay_seconds: request_delay_seconds
      ).sync_market
    end

    def self.sync_fundamentals(traded_on: Date.current, market_client: Source::SharesansarMarketClient.new, company_client: Source::MerolaganiCompanyClient.new, fundamentals_failure_threshold: DEFAULT_FAILURE_THRESHOLD, request_delay_seconds: DEFAULT_REQUEST_DELAY_SECONDS)
      new(
        traded_on: traded_on,
        market_client: market_client,
        company_client: company_client,
        fundamentals_failure_threshold: fundamentals_failure_threshold,
        request_delay_seconds: request_delay_seconds
      ).sync_fundamentals
    end

    def initialize(traded_on:, market_client:, company_client:, fundamentals_failure_threshold:, request_delay_seconds:)
      @traded_on = traded_on
      @market_client = market_client
      @company_client = company_client
      @fundamentals_failure_threshold = fundamentals_failure_threshold
      @request_delay_seconds = request_delay_seconds
    end

    def call
      seed_result = Nepse::MasterImporterService.call
      return { success: false, seed: seed_result } unless seed_result[:success]

      market_result = sync_market
      return { success: false, seed: seed_result, market: market_result } unless market_result[:success]

      fundamentals_result = sync_fundamentals
      success = market_result[:success] && fundamentals_result[:success] && !fundamentals_result[:aborted]

      {
        success: success,
        seed: seed_result,
        market: market_result,
        fundamentals: fundamentals_result
      }
    end

    def sync_market
      response = market_client.fetch
      return { success: false, error: response[:error], processed: 0, rejected_symbols: [] } unless response[:success]

      processed = 0
      rejected_symbols = []

      Array(response[:rows]).each do |row|
        stock = Stock.find_by(symbol: row[:symbol].to_s.upcase)
        unless stock
          rejected_symbols << row[:symbol].to_s.upcase
          next
        end

        persist_market_row(stock, row)
        processed += 1
      end

      {
        success: true,
        total_rows: Array(response[:rows]).size,
        processed: processed,
        rejected_symbols: rejected_symbols
      }
    rescue StandardError => e
      Rails.logger.error("Nepse::StockBasicsSyncService market sync error: #{e.message}")
      { success: false, error: e.message, processed: processed || 0, rejected_symbols: rejected_symbols || [] }
    end

    def sync_fundamentals
      stocks = Stock.order(:id).to_a
      total_symbols = stocks.size
      processed = 0
      failed_symbols = []
      aborted = false

      stocks.each_with_index do |stock, index|
        response = company_client.fetch(stock.symbol)

        if response[:success]
          persist_fundamentals(stock, response[:fundamentals] || {})
          processed += 1
        else
          failed_symbols << stock.symbol
          if total_symbols.positive? && (failed_symbols.size.to_f / total_symbols) > fundamentals_failure_threshold
            aborted = true
            break
          end
        end

        next unless request_delay_seconds.to_f.positive?
        next if aborted || index == stocks.length - 1

        sleep(request_delay_seconds)
      end

      {
        success: !aborted,
        total_symbols: total_symbols,
        processed: processed,
        failed_symbols: failed_symbols,
        aborted: aborted
      }
    rescue StandardError => e
      Rails.logger.error("Nepse::StockBasicsSyncService fundamentals sync error: #{e.message}")
      { success: false, error: e.message, processed: processed || 0, failed_symbols: failed_symbols || [], aborted: aborted || false }
    end

    private

    attr_reader :traded_on, :market_client, :company_client, :fundamentals_failure_threshold, :request_delay_seconds

    def persist_market_row(stock, row)
      previous_last_price = stock.last_price.to_f
      last_price = normalized_decimal_value(row[:last_price])
      previous_close = normalized_decimal_value(row[:previous_close])
      volume = normalized_integer_value(row[:volume])
      change_amount = normalized_decimal_value(row[:change_amount])
      change_percent = normalized_decimal_value(row[:change_percent])
      high_52w = normalized_decimal_value(row[:high_52w])
      low_52w = normalized_decimal_value(row[:low_52w])
      open_price = normalized_decimal_value(row[:open_price])
      high_price = normalized_decimal_value(row[:high_price])
      low_price = normalized_decimal_value(row[:low_price])
      close_price = normalized_decimal_value(row[:close_price])
      turnover = normalized_decimal_value(row[:turnover])
      total_trades = normalized_integer_value(row[:total_trades])

      effective_last_price = last_price || previous_last_price
      effective_previous_close = previous_close || effective_last_price
      effective_volume = volume.nil? ? stock.volume : volume
      effective_change_amount = change_amount || (last_price && effective_previous_close ? (effective_last_price - effective_previous_close.to_f).round(2) : nil)
      effective_change_percent = change_percent || (last_price && effective_previous_close ? computed_change_percent(effective_last_price, effective_previous_close) : nil)

      Stock.transaction do
        stock_updates = { last_updated: row[:fetched_at] || Time.current }
        stock_updates[:last_price] = last_price unless last_price.nil?
        stock_updates[:change_percent] = effective_change_percent unless effective_change_percent.nil?
        stock_updates[:volume] = volume unless volume.nil?
        stock_updates[:high_52w] = high_52w unless high_52w.nil?
        stock_updates[:low_52w] = low_52w unless low_52w.nil?
        stock.update!(stock_updates)

        stock.recalculate_market_cap! unless last_price.nil?

        daily_price = StockDailyPrice.find_or_initialize_by(stock: stock, traded_on: row[:traded_on] || traded_on)
        daily_price.open_price = open_price || daily_price.open_price || effective_previous_close
        daily_price.high_price = high_price || daily_price.high_price || [ effective_previous_close.to_f, effective_last_price ].max
        daily_price.low_price = low_price || daily_price.low_price || [ effective_previous_close.to_f, effective_last_price ].min
        daily_price.close_price = close_price || last_price || daily_price.close_price || effective_last_price
        daily_price.previous_close = previous_close || daily_price.previous_close || effective_previous_close
        daily_price.change_amount = effective_change_amount unless effective_change_amount.nil?
        daily_price.change_percent = effective_change_percent unless effective_change_percent.nil?
        daily_price.volume = volume unless volume.nil?
        daily_price.turnover = turnover || daily_price.turnover || (last_price && effective_volume ? (effective_last_price * effective_volume).round(2) : daily_price.turnover)
        daily_price.total_trades = total_trades unless total_trades.nil?
        daily_price.save!
      end
    end

    def persist_fundamentals(stock, fundamentals)
      fiscal_year = fundamentals[:fiscal_year].presence || "latest"
      quarter = fundamentals[:quarter].presence || "Annual"
      sector = normalized_text_value(fundamentals[:sector])
      listed_shares = normalized_integer_value(fundamentals[:listed_shares])
      market_cap = normalized_decimal_value(fundamentals[:market_cap])

      Stock.transaction do
        stock_updates = {}
        stock_updates[:sector] = sector if sector.present?
        stock_updates[:listed_shares] = listed_shares unless listed_shares.nil?
        stock_updates[:market_cap] = market_cap unless market_cap.nil?
        stock.update!(stock_updates) if stock_updates.any?

        financial = StockCompanyFinancial.find_or_initialize_by(stock: stock, fiscal_year: fiscal_year, quarter: quarter)
        financial.reported_on ||= traded_on
        financial.assign_attributes(financial_updates(fundamentals))
        financial.save! if financial.new_record? || financial.changed?

        if market_cap.nil? && !listed_shares.nil? && stock.last_price.to_f.positive?
          stock.recalculate_market_cap!
        end
      end
    end

    def financial_updates(fundamentals)
      updates = {}
      eps = normalized_decimal_value(fundamentals[:eps])
      pe_ratio = normalized_decimal_value(fundamentals[:pe_ratio])
      book_value = normalized_decimal_value(fundamentals[:book_value])
      pb_ratio = normalized_decimal_value(fundamentals[:pb_ratio])

      updates[:eps] = eps unless eps.nil?
      updates[:pe_ratio] = pe_ratio unless pe_ratio.nil?
      updates[:book_value] = book_value unless book_value.nil?
      updates[:pb_ratio] = pb_ratio unless pb_ratio.nil?
      updates
    end

    def normalized_text_value(value)
      text = value.to_s.strip
      return if text.blank? || invalid_placeholder?(text)

      text
    end

    def normalized_integer_value(value)
      return value if value.is_a?(Integer)

      text = value.to_s.delete(",").strip
      return if text.blank? || invalid_placeholder?(text)
      return unless text.match?(/\A\d+\z/)

      text.to_i
    end

    def normalized_decimal_value(value)
      return value.to_f if value.is_a?(Numeric)

      text = value.to_s.delete(",").strip
      return if text.blank? || invalid_placeholder?(text)
      return unless text.match?(/\A-?\d+(?:\.\d+)?\z/)

      text.to_f
    end

    def invalid_placeholder?(value)
      [ "-", "--", "n/a", "na" ].include?(value.to_s.downcase)
    end

    def computed_change_percent(last_price, previous_close)
      return 0.0 if previous_close.to_f.zero?

      (((last_price - previous_close.to_f) / previous_close.to_f) * 100).round(2)
    end
  end
end
