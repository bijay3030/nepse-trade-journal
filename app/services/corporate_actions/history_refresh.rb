module CorporateActions
  # After a bonus book close, older stored prices are still pre-bonus while new
  # ones are post-bonus, which looks like a crash to charts, moving averages and
  # pattern detection. Re-fetch the stock's bonus-adjusted history (Merolagani
  # adjusts it) and recalculate its indicators, once per book close. Rights issues
  # (market_events from Chukul's rights feed) are adjusted the same way, and the
  # 2020-2025 archive (Scans::History) is re-fetched too, so backtests see no false drop.
  class HistoryRefresh
    # Wait a session for the source to apply the adjustment; give up after this long.
    WINDOW = (1..10)

    def self.call(on: Nepse::MarketHours.today, history: Nepse::HistoryBackfillService, archive: Scans::History) = new(on, history, archive).call

    def initialize(on, history, archive)
      @on = on
      @history = history
      @archive = archive
    end

    def call
      due = StockDividend.includes(:stock).where("bonus_percent > 0").where(history_refreshed_at: nil)
        .where(book_close_on: (@on - WINDOW.max)..(@on - WINDOW.min))
      rights = MarketEvent.includes(:stock).where(kind: "rights", source: "chukul_rights").where.not(stock_id: nil)
        .where(event_on: (@on - WINDOW.max)..(@on - WINDOW.min)).where("NOT (data ? 'history_refreshed_at')")
      symbols = (due.map { _1.stock.symbol } + rights.map { _1.stock.symbol }).uniq
      return { refreshed: [] } if symbols.empty?

      result = @history.call(symbols: symbols)
      @archive.import!(symbols: symbols)
      Indicators::BatchCalculatorService.call(symbols: symbols, recalculate_all: true)
      failed = Array(result[:failed]).to_h.keys
      due.reject { failed.include?(_1.stock.symbol) }.each { _1.update!(history_refreshed_at: Time.current) }
      rights.reject { failed.include?(_1.stock.symbol) }.each { _1.update!(data: _1.data.merge("history_refreshed_at" => Time.current.iso8601)) }
      { refreshed: symbols - failed, failed: failed }
    end
  end
end
