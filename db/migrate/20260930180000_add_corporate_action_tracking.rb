class AddCorporateActionTracking < ActiveRecord::Migration[8.0]
  def change
    # When the stock's price history was re-fetched (bonus-adjusted) after this book close.
    add_column :stock_dividends, :history_refreshed_at, :datetime
    # Bonus adjustments applied to the item's levels: [{ fiscal_year, bonus_percent, factor, book_close_on }]
    add_column :watchlist_items, :level_adjustments, :jsonb, null: false, default: []
  end
end
