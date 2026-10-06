module Nepse
  module Reference
    # How complete the stored data is, per field, for active securities.
    class CoverageReport
      def self.call = new.call

      def call
        stocks = Stock.active
        equities = stocks.where(security_type: "Equity")
        latest = latest_financials(equities)
        history = StockDailyPrice.where(stock_id: equities.select(:id)).group(:stock_id).count

        {
          active_securities: stocks.count,
          by_security_type: stocks.group(:security_type).count,
          by_sector: stocks.group(:sector).count.sort_by { -_2 }.to_h,
          identity: {
            real_name: stocks.where.not("name = symbol OR name LIKE '% Company'").count,
            known_sector: stocks.where(sector: Sectors::ALIASES.values.uniq).count,
            linked_to_chukul: stocks.where.not(chukul_id: nil).count
          },
          equities: equities.count,
          equity_fields: {
            listed_shares: equities.where("listed_shares > 0").count,
            market_cap: equities.where("market_cap > 0").count,
            high_low_52w: equities.where("high_52w > 0 AND low_52w > 0").count,
            price_history_100_sessions: history.count { _2 >= 100 },
            dividend_history: equities.where(id: StockDividend.select(:stock_id)).count
          },
          equity_fundamentals: %i[eps pe_ratio book_value pb_ratio net_profit roe roa distributable_profit_per_share growth_rate].to_h do |field|
            [ field, latest.count { |row| row.public_send(field).to_f.nonzero? } ]
          end,
          fundamentals_period: latest.map { "#{_1.fiscal_year} #{_1.quarter}" }.tally.sort_by { -_2 }.first(4).to_h,
          field_sources: source_counts(latest),
          eps_growth: eps_growth_coverage(equities),
          indices: MarketIndex.order(:symbol).to_h do |index|
            dates = index.histories.pluck(:traded_on)
            [ index.symbol, { sessions: dates.size, from: dates.min, to: dates.max } ]
          end
        }
      end

      private

      # How many equities have a growth figure, and how many from their own stored history
      # (the same quarter a year earlier), which grows as the weekly sync keeps quarters.
      def eps_growth_coverage(equities)
        results = equities.includes(:company_financials).map { Fundamentals::EpsGrowth.call(_1) }.compact
        { with_growth: results.size, from_reported_history: results.count { _1[:source] == "reported" },
          quarters_stored: StockCompanyFinancial.where(stock_id: equities.select(:id)).where("quarter LIKE 'Q%'").count }
      end

      def latest_financials(equities)
        StockCompanyFinancial.where(stock_id: equities.select(:id)).where.not(fiscal_year: "latest")
          .group_by(&:stock_id).values.map { |rows| rows.max_by { [ _1.reported_on || Date.new(0), _1.fiscal_year, _1.quarter ] } }
      end

      def source_counts(rows)
        rows.flat_map { _1.field_sources.values.map { |meta| meta["source"] } }.tally
      end
    end
  end
end
