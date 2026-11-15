class CreateStockPriceArchives < ActiveRecord::Migration[8.1]
  def change
    # Daily prices older than stock_daily_prices, used only by the Indicator Scanner's
    # track record (Scans::History). Kept apart so the board, indicators, base counts and
    # market direction, which read a stock's full stored history, aren't changed by it.
    create_table :stock_price_archives do |t|
      t.references :stock, null: false, foreign_key: { on_delete: :cascade }
      t.date :traded_on, null: false
      t.decimal :open_price, precision: 12, scale: 2
      t.decimal :high_price, precision: 12, scale: 2
      t.decimal :low_price, precision: 12, scale: 2
      t.decimal :close_price, precision: 12, scale: 2, null: false
      t.bigint :volume
    end
    add_index :stock_price_archives, %i[stock_id traded_on], unique: true
  end
end
