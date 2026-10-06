module Nepse
  module Reference
    # Latest fundamentals for every active security, one field at a time in
    # priority order: Chukul first, then Merolagani for whatever Chukul lacks.
    #
    # Chukul: EPS, P/E, P/B, book value, net profit, paid-up capital, ROE, ROA and
    # distributable profit per share (can be negative). Dividends paid are in stock_dividends.
    # Merolagani: shares outstanding (Chukul has none), plus any of the above that
    # Chukul could not provide, and the 52-week range when it is still unset.
    # Promoter shares and debentures are skipped: they publish no fundamentals of their own.
    class FundamentalsSync
      SECURITY_TYPES = [ "Equity", "Mutual Fund" ].freeze
      FINANCIAL_FIELDS = %i[eps pe_ratio pb_ratio book_value net_profit paid_up_capital roe roa distributable_profit_per_share growth_rate].freeze

      def self.call(**options)
        new(**options).call
      end

      def initialize(symbols: nil, chukul: Source::ChukulClient.new, merolagani: Source::MerolaganiCompanyClient.new, delay_seconds: 0.3)
        @symbols = Array(symbols).map { _1.to_s.upcase }.presence
        @chukul = chukul
        @merolagani = merolagani
        @delay_seconds = delay_seconds.to_f
      end

      def call
        stocks = Stock.active.where(security_type: SECURITY_TYPES).order(:symbol)
        stocks = stocks.where(symbol: @symbols) if @symbols
        summary = { success: true, stocks: 0, from_chukul: 0, from_merolagani: 0, failed: {} }

        stocks.each_with_index do |stock, index|
          sleep(@delay_seconds) if index.positive? && @delay_seconds.positive?
          sources = sync(stock)
          if sources.empty?
            summary[:failed][stock.symbol] = "no fundamentals from any source"
          else
            summary[:stocks] += 1
            summary[:from_chukul] += 1 if sources.include?("chukul")
            summary[:from_merolagani] += 1 if sources.include?("merolagani")
          end
        rescue StandardError => e
          summary[:failed][stock.symbol] = e.message
        end

        summary
      end

      private

      def sync(stock)
        used = []
        chukul = chukul_details(stock)
        merolagani = @merolagani.details(stock.symbol)
        merolagani = nil unless merolagani[:success]

        Stock.transaction do
          financial = financial_row(stock, chukul, merolagani)
          if financial
            filled = []
            filled << "chukul" if chukul && Provenance.assign(financial, chukul_values(chukul), "chukul").any?
            filled << "merolagani" if merolagani && same_period?(financial, merolagani) && Provenance.assign(financial, missing(financial, merolagani_values(merolagani)), "merolagani").any?
            # Mutual fund pages report NAV, not EPS, so there may be nothing to store.
            if filled.any? || financial.persisted?
              financial.reported_on = Date.current
              financial.save!
              remove_placeholder_rows(stock, financial)
              used.concat(filled)
            end
          end

          used << "merolagani" if merolagani && update_stock_from_merolagani(stock, merolagani)
          used << "chukul" if chukul && update_stock_from_chukul(stock, chukul)
          stock.save! if stock.changed?
          stock.recalculate_market_cap!
        end

        used.uniq
      end

      def chukul_details(stock)
        return unless stock.chukul_sector_id

        response = @chukul.stock_details(stock.symbol, stock.chukul_sector_id)
        data = response[:data] if response[:success]
        data if data.is_a?(Hash) && data["fiscal_year"].present?
      end

      # The row for the reported period: Chukul's period when it has one, else Merolagani's.
      def financial_row(stock, chukul, merolagani)
        fiscal_year, quarter =
          if chukul
            [ chukul["fiscal_year"], chukul["quarter"].to_s.upcase.presence || "Annual" ]
          elsif merolagani && merolagani.dig(:fundamentals, :fiscal_year) != "latest"
            merolagani[:fundamentals].values_at(:fiscal_year, :quarter)
          end
        return unless fiscal_year && StockCompanyFinancial::VALID_QUARTERS.include?(quarter)

        # Not built through the association, or saving the stock would also save an empty row.
        StockCompanyFinancial.find_or_initialize_by(stock: stock, fiscal_year: fiscal_year, quarter: quarter)
      end

      def chukul_values(data)
        {
          eps: data["eps_a"], pe_ratio: data["pe_ratio"], pb_ratio: data["pb_ratio"], book_value: data["net_worth"],
          net_profit: data["net_profit"], paid_up_capital: data["paidup_capital"], roe: data["roe"], roa: data["roa"],
          # Chukul calls this "dps"; it is distributable profit per share, not the dividend paid.
          distributable_profit_per_share: data["dps"], growth_rate: data["growth_rate"]
        }
      end

      def merolagani_values(result)
        result[:fundamentals].slice(:eps, :pe_ratio, :pb_ratio, :book_value)
      end

      def same_period?(financial, merolagani)
        merolagani[:fundamentals].values_at(:fiscal_year, :quarter) == [ financial.fiscal_year, financial.quarter ]
      end

      # Only the fields the higher-priority source left empty.
      def missing(record, values)
        values.select { |field, _value| Provenance.blank?(record.public_send(field)) }
      end

      # Shares outstanding come from Merolagani (Chukul does not publish them).
      def update_stock_from_merolagani(stock, result)
        values = { listed_shares: result.dig(:fundamentals, :listed_shares) }
        values.merge!(high_52w: result[:high_52w]) if stock.high_52w.to_f.zero?
        values.merge!(low_52w: result[:low_52w]) if stock.low_52w.to_f.zero?
        Provenance.assign(stock, values, "merolagani").any?
      end

      # Fallbacks for what Merolagani could not provide.
      def update_stock_from_chukul(stock, data)
        values = {}
        if stock.listed_shares.to_i.zero? && data["core_capital"].to_f.positive?
          values[:listed_shares] = (data["core_capital"].to_f / (stock.paid_up_value.to_f.positive? ? stock.paid_up_value.to_f : 100)).round
        end
        values[:high_52w] = data["fifty_two_max_close"] if stock.high_52w.to_f.zero?
        values[:low_52w] = data["fifty_two_min_close"] if stock.low_52w.to_f.zero?
        Provenance.assign(stock, values, "chukul").any?
      end

      # Older imports stored undated "latest" rows; drop them once a dated row exists.
      def remove_placeholder_rows(stock, financial)
        stock.company_financials.where(fiscal_year: "latest").where.not(id: financial.id).delete_all
      end
    end
  end
end
