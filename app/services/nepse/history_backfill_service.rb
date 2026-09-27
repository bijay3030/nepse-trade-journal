module Nepse
  # Loads daily price history so VCP and price-action analysis have enough bars.
  #
  # Rows inside the range the source returned are replaced by the source's bars,
  # and stored rows for dates the source has no session for are removed (they come
  # from placeholder or mis-dated imports). Rows after the source's last bar, such as
  # today's live session, are left alone.
  class HistoryBackfillService
    DEFAULT_DAYS = 365
    DEFAULT_DELAY_SECONDS = 0.3

    def self.call(**options)
      new(**options).call
    end

    def initialize(symbols: nil, days: DEFAULT_DAYS, client: Source::MerolaganiHistoryClient.new, delay_seconds: DEFAULT_DELAY_SECONDS, to: Date.current)
      @symbols = Array(symbols).map { _1.to_s.upcase }.presence
      @days = days.to_i
      @client = client
      @delay_seconds = delay_seconds.to_f
      @to = to
    end

    def call
      stocks = Stock.active.order(:symbol)
      stocks = stocks.where(symbol: @symbols) if @symbols
      summary = { success: true, stocks: 0, bars: 0, removed: 0, failed: {} }

      stocks.each_with_index do |stock, index|
        sleep(@delay_seconds) if index.positive? && @delay_seconds.positive?

        response = @client.fetch(stock.symbol, from: @to - @days, to: @to)
        if response[:success] && response[:bars].any?
          written, removed = store(stock, response[:bars])
          summary[:stocks] += 1
          summary[:bars] += written
          summary[:removed] += removed
        else
          summary[:failed][stock.symbol] = response[:error] || "no bars"
        end
      end

      summary
    end

    private

    def store(stock, bars)
      now = Time.current
      previous_close = stock.daily_prices.where("traded_on < ?", bars.first[:traded_on]).order(traded_on: :desc).pick(:close_price)&.to_f

      rows = bars.map do |bar|
        prev = previous_close || bar[:open_price]
        change = (bar[:close_price] - prev).round(2)
        row = bar.merge(
          stock_id: stock.id,
          previous_close: prev.round(2),
          change_amount: change,
          change_percent: prev.positive? ? ((change / prev) * 100).round(2) : 0.0,
          # The source has no turnover, so estimate it from close x volume.
          turnover: (bar[:close_price] * bar[:volume]).round(2),
          created_at: now,
          updated_at: now
        )
        previous_close = bar[:close_price]
        row
      end

      StockDailyPrice.transaction do
        dates = bars.map { _1[:traded_on] }
        removed = stock.daily_prices.where(traded_on: dates.first..dates.last).where.not(traded_on: dates).delete_all
        StockDailyPrice.upsert_all(rows, unique_by: %i[stock_id traded_on], update_only: %i[
          open_price high_price low_price close_price previous_close change_amount change_percent volume turnover
        ])
        [ rows.size, removed ]
      end
    end
  end
end
