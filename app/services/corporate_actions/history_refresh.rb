module CorporateActions
  # After a bonus book close, older stored prices are still pre-bonus while new
  # ones are post-bonus, which looks like a crash to charts, moving averages and
  # pattern detection. Re-fetch the stock's bonus-adjusted history (Merolagani
  # adjusts it) and recalculate its indicators, once per book close.
  class HistoryRefresh
    # Wait a session for the source to apply the adjustment; give up after this long.
    WINDOW = (1..10)

    def self.call(on: Nepse::MarketHours.today, history: Nepse::HistoryBackfillService) = new(on, history).call

    def initialize(on, history)
      @on = on
      @history = history
    end

    def call
      due = StockDividend.includes(:stock).where("bonus_percent > 0").where(history_refreshed_at: nil)
        .where(book_close_on: (@on - WINDOW.max)..(@on - WINDOW.min))
      symbols = due.map { _1.stock.symbol }.uniq
      return { refreshed: [] } if symbols.empty?

      result = @history.call(symbols: symbols)
      Indicators::BatchCalculatorService.call(symbols: symbols, recalculate_all: true)
      failed = Array(result[:failed]).to_h.keys
      due.reject { failed.include?(_1.stock.symbol) }.each { _1.update!(history_refreshed_at: Time.current) }
      { refreshed: symbols - failed, failed: failed }
    end
  end
end
