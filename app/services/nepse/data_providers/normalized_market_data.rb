module Nepse
  module DataProviders
    class NormalizedMarketData
      attr_reader :symbol, :company_name, :sector, :security_type, :is_active,
                  :traded_on, :open_price, :high_price, :low_price, :close_price,
                  :previous_close, :change_amount, :change_percent, :volume,
                  :turnover, :total_trades, :high_52w, :low_52w, :raw_payload

      def initialize(attributes = {})
        @symbol = attributes[:symbol].to_s.strip.upcase
        @company_name = attributes[:company_name].to_s.strip
        @sector = attributes[:sector].presence || "Others"
        @security_type = attributes[:security_type].presence || "Equity"
        @is_active = attributes.fetch(:is_active, true)

        @traded_on = attributes[:traded_on].is_a?(Date) ? attributes[:traded_on] : (Date.parse(attributes[:traded_on].to_s) rescue Date.current)
        @close_price = parse_decimal(attributes[:close_price] || attributes[:last_price])
        @open_price = parse_decimal(attributes[:open_price], fallback: @close_price)
        @high_price = parse_decimal(attributes[:high_price], fallback: [@open_price, @close_price].max)
        @low_price = parse_decimal(attributes[:low_price], fallback: [@open_price, @close_price].min)

        @previous_close = parse_decimal(attributes[:previous_close], fallback: @close_price)
        @change_amount = parse_decimal(attributes[:change_amount], fallback: (@close_price - @previous_close).round(2))
        @change_percent = parse_decimal(attributes[:change_percent], fallback: calculate_change_percent)

        @volume = parse_integer(attributes[:volume])
        @turnover = parse_decimal(attributes[:turnover], fallback: (@close_price * @volume).round(2))
        @total_trades = parse_integer(attributes[:total_trades])

        @high_52w = parse_decimal(attributes[:high_52w])
        @low_52w = parse_decimal(attributes[:low_52w])
        @raw_payload = attributes[:raw_payload] || {}
      end

      def valid?
        symbol.present? && close_price.positive?
      end

      def stock_attributes
        {
          symbol: symbol,
          name: company_name.presence || symbol,
          sector: sector,
          security_type: security_type,
          is_active: is_active,
          last_price: close_price,
          change_percent: change_percent,
          volume: volume,
          last_updated: Time.current
        }.tap do |attrs|
          attrs[:high_52w] = high_52w if high_52w.positive?
          attrs[:low_52w] = low_52w if low_52w.positive?
        end
      end

      def daily_price_attributes
        {
          traded_on: traded_on,
          open_price: open_price,
          high_price: high_price,
          low_price: low_price,
          close_price: close_price,
          previous_close: previous_close,
          change_amount: change_amount,
          change_percent: change_percent,
          volume: volume,
          turnover: turnover,
          total_trades: total_trades
        }
      end

      private

      def parse_decimal(value, fallback: 0.0)
        return fallback if value.nil? || value.to_s.strip == "-" || value.to_s.strip.empty?

        cleaned = value.to_s.delete(",").delete("% ").strip
        BigDecimal(cleaned)
      rescue ArgumentError, TypeError
        BigDecimal(fallback.to_s)
      end

      def parse_integer(value, fallback: 0)
        return fallback if value.nil? || value.to_s.strip == "-" || value.to_s.strip.empty?

        cleaned = value.to_s.delete(",").strip
        cleaned.to_i
      rescue ArgumentError, TypeError
        fallback
      end

      def calculate_change_percent
        return 0.0 if previous_close.nil? || previous_close.zero?

        (((close_price - previous_close) / previous_close) * 100).round(2)
      end
    end
  end
end
