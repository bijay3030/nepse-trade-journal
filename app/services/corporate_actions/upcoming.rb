module CorporateActions
  # The next book close (dividend / bonus entitlement date) for each stock.
  module Upcoming
    LOOKAHEAD_DAYS = 45

    module_function

    # { stock_id => { fiscal_year:, book_close_on:, days_until:, cash_percent:, bonus_percent:, agm_on: } }
    def for_stocks(stock_ids, on: Nepse::MarketHours.today)
      StockDividend.where(stock_id: stock_ids, book_close_on: on..(on + LOOKAHEAD_DAYS))
        .order(:book_close_on).group_by(&:stock_id)
        .transform_values { |rows| payload(rows.first, on) }
    end

    def for_stock(stock, on: Nepse::MarketHours.today) = for_stocks([ stock.id ], on: on)[stock.id]

    def payload(dividend, on)
      {
        fiscal_year: dividend.fiscal_year,
        book_close_on: dividend.book_close_on,
        days_until: (dividend.book_close_on - on).to_i,
        cash_percent: dividend.cash_percent&.to_f,
        bonus_percent: dividend.bonus_percent&.to_f,
        agm_on: dividend.agm_on
      }
    end
  end
end
