module Setups
  # Builds setup snapshots for past sessions, as the app would have seen them on
  # each day, so the backtest has point-in-time signals. Skips sessions already built.
  class HistoryBuilder
    def self.call(**options) = new(**options).call

    # Real trading sessions: NEPSE index dates that have stock prices. A stray price
    # row (e.g. a demo stock dated on a weekend) must not become a session.
    def self.sessions
      index_dates = MarketIndex.find_by(symbol: "NEPSE")&.histories&.pluck(:traded_on) || []
      (index_dates & StockDailyPrice.distinct.pluck(:traded_on)).sort
    end

    def initialize(sessions: 120, force: false)
      @sessions = sessions.to_i
      @force = force
    end

    def call
      dates = self.class.sessions.last(@sessions)
      dates -= StockSetupSnapshot.distinct.pluck(:traded_on) unless @force

      # Load every stock's full history once and reuse it for each session.
      stocks = Stock.active.where(security_type: "Equity").includes(:daily_prices, :daily_indicators).order(:symbol).to_a
      summary = { success: true, built: [], failed: {} }
      dates.each do |date|
        result = SnapshotBuilder.call(as_of: date, stocks: stocks)
        result[:success] ? summary[:built] << date : summary[:failed][date] = result[:error]
      end
      summary
    end
  end
end
