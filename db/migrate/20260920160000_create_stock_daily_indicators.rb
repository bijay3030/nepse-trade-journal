class CreateStockDailyIndicators < ActiveRecord::Migration[8.0]
  def change
    create_table :stock_daily_indicators do |t|
      t.references :stock, null: false, foreign_key: true
      t.references :stock_daily_price, foreign_key: true
      t.date :traded_on, null: false

      # Trend indicators
      t.decimal :sma_20, precision: 12, scale: 2
      t.decimal :sma_50, precision: 12, scale: 2
      t.decimal :sma_150, precision: 12, scale: 2
      t.decimal :sma_200, precision: 12, scale: 2
      t.decimal :ema_20, precision: 12, scale: 2
      t.decimal :ema_50, precision: 12, scale: 2

      # Volatility indicators
      t.decimal :atr_14, precision: 12, scale: 2
      t.decimal :atr_percent, precision: 8, scale: 2

      # Volume indicators
      t.bigint :avg_volume_10
      t.bigint :avg_volume_20
      t.bigint :avg_volume_50
      t.decimal :rvol, precision: 8, scale: 2

      # Price Position indicators
      t.decimal :high_52w, precision: 12, scale: 2
      t.decimal :low_52w, precision: 12, scale: 2
      t.decimal :pct_below_high_52w, precision: 8, scale: 2
      t.decimal :pct_above_low_52w, precision: 8, scale: 2

      # Momentum indicators
      t.decimal :change_pct_1d, precision: 8, scale: 2
      t.decimal :change_pct_20d, precision: 8, scale: 2
      t.decimal :change_pct_50d, precision: 8, scale: 2

      t.timestamps
    end

    add_index :stock_daily_indicators, [:stock_id, :traded_on], unique: true
    add_index :stock_daily_indicators, :traded_on
  end
end
