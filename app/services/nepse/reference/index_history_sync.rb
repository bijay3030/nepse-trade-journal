module Nepse
  module Reference
    # Daily history for the NEPSE index and the sector sub-indices. Chukul first;
    # Merolagani fills only sessions Chukul does not have.
    class IndexHistorySync
      NEPSE = { symbol: "NEPSE", name: "NEPSE Index", sector: nil, merolagani: "NEPSE" }.freeze

      def self.indices
        [ NEPSE ] + Sectors::INDICES.map do |symbol, (sector, merolagani)|
          { symbol: symbol, name: "#{sector} Index", sector: sector, merolagani: merolagani }
        end
      end

      def self.call(**options)
        new(**options).call
      end

      def initialize(days: 365, chukul: Source::ChukulClient.new, merolagani: Source::MerolaganiHistoryClient.new, to: Date.current)
        @days = days.to_i
        @chukul = chukul
        @merolagani = merolagani
        @to = to
      end

      def call
        summary = { success: true, indices: {}, failed: {} }

        self.class.indices.each do |definition|
          bars = {}
          chukul = @chukul.history(definition[:symbol], from: @to - @days, to: @to)
          Array(chukul[:bars]).each { |bar| bars[bar[:traded_on]] = bar.merge(source: "chukul") } if chukul[:success]

          if definition[:merolagani]
            fallback = @merolagani.fetch(definition[:merolagani], from: @to - @days, to: @to)
            Array(fallback[:bars]).each do |bar|
              bars[bar[:traded_on]] ||= { traded_on: bar[:traded_on], close: bar[:close_price], turnover: 0.0, source: "merolagani" }
            end
          end

          if bars.empty?
            summary[:failed][definition[:symbol]] = chukul[:error] || "no history"
            next
          end

          summary[:indices][definition[:symbol]] = store(definition, bars.values.sort_by { _1[:traded_on] })
        end

        summary
      end

      private

      def store(definition, bars)
        index = MarketIndex.find_or_initialize_by(symbol: definition[:symbol])
        index.assign_attributes(name: definition[:name], sector: definition[:sector])

        # Change is measured from the stored session just before the first new bar.
        previous = index.persisted? ? index.histories.where("traded_on < ?", bars.first[:traded_on]).order(traded_on: :desc).pick(:index_value)&.to_f : nil
        now = Time.current
        rows = bars.map do |bar|
          change = previous ? (bar[:close] - previous).round(2) : 0.0
          row = {
            traded_on: bar[:traded_on], index_value: bar[:close].round(2), change_point: change,
            change_percent: previous.to_f.positive? ? ((change / previous) * 100).round(2) : 0.0,
            turnover: bar[:turnover].to_f.round(2), created_at: now, updated_at: now
          }
          previous = bar[:close]
          row
        end

        latest = rows.last
        index.assign_attributes(
          current_value: latest[:index_value], change_point: latest[:change_point], change_percent: latest[:change_percent],
          source: bars.last[:source]
        )

        MarketIndex.transaction do
          index.save!
          MarketIndexHistory.upsert_all(
            rows.map { _1.merge(market_index_id: index.id) },
            unique_by: %i[market_index_id traded_on],
            update_only: %i[index_value change_point change_percent turnover]
          )
        end

        { sessions: rows.size, from_merolagani: bars.count { _1[:source] == "merolagani" }, latest: latest[:traded_on] }
      end
    end
  end
end
