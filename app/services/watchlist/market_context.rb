module Watchlist
  # Market-wide inputs for the entry checklist, computed once per request.
  class MarketContext
    STRENGTH_SESSIONS = 20

    attr_reader :regime, :nepse_return, :sector_returns

    def self.call = new

    def initialize
      @regime = MarketIndex::Overview.new.call[:regime_status]
      indices = MarketIndex.includes(:histories).to_a
      @nepse_return = period_return(indices.find { _1.symbol == "NEPSE" })
      @sector_returns = indices.select(&:sector).to_h { [ _1.sector, period_return(_1) ] }
    end

    private

    # Percent change over the last STRENGTH_SESSIONS sessions.
    def period_return(index)
      values = index&.histories&.sort_by(&:traded_on)&.last(STRENGTH_SESSIONS + 1)&.map { _1.index_value.to_f }
      return if values.nil? || values.size < 2 || values.first.zero?

      (((values.last - values.first) / values.first) * 100).round(2)
    end
  end
end
