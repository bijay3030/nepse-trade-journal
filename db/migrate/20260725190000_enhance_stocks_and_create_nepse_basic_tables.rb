class EnhanceStocksAndCreateNepseBasicTables < ActiveRecord::Migration[8.0]
  def change
    # 1. Enhance stocks table with basic fundamental metadata
    change_table :stocks, bulk: true do |t|
      t.string :security_type, default: "Equity", null: false
      t.bigint :listed_shares, default: 0, null: false
      t.decimal :paid_up_value, precision: 12, scale: 2, default: 100.0, null: false
      t.decimal :market_cap, precision: 18, scale: 2, default: 0.0, null: false
      t.decimal :high_52w, precision: 12, scale: 2, default: 0.0, null: false
      t.decimal :low_52w, precision: 12, scale: 2, default: 0.0, null: false
      t.boolean :is_active, default: true, null: false
      t.text :description
      t.string :company_website
    end

    add_index :stocks, :security_type
    add_index :stocks, :is_active

    # 2. Historical Daily OHLCV Prices
    create_table :stock_daily_prices do |t|
      t.references :stock, null: false, foreign_key: true
      t.date :traded_on, null: false
      t.decimal :open_price, precision: 12, scale: 2, default: 0.0, null: false
      t.decimal :high_price, precision: 12, scale: 2, default: 0.0, null: false
      t.decimal :low_price, precision: 12, scale: 2, default: 0.0, null: false
      t.decimal :close_price, precision: 12, scale: 2, default: 0.0, null: false
      t.decimal :previous_close, precision: 12, scale: 2, default: 0.0, null: false
      t.decimal :change_amount, precision: 12, scale: 2, default: 0.0, null: false
      t.decimal :change_percent, precision: 8, scale: 2, default: 0.0, null: false
      t.bigint :volume, default: 0, null: false
      t.decimal :turnover, precision: 18, scale: 2, default: 0.0, null: false
      t.integer :total_trades, default: 0, null: false
      t.decimal :vwap, precision: 12, scale: 2, default: 0.0, null: false

      t.timestamps
    end

    add_index :stock_daily_prices, [:stock_id, :traded_on], unique: true
    add_index :stock_daily_prices, :traded_on

    # 3. Company Quarterly & Annual Financial Fundamentals
    create_table :stock_company_financials do |t|
      t.references :stock, null: false, foreign_key: true
      t.string :fiscal_year, null: false
      t.string :quarter, null: false
      t.date :reported_on
      t.decimal :eps, precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :pe_ratio, precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :book_value, precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :pb_ratio, precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :roe, precision: 6, scale: 2, default: 0.0, null: false
      t.decimal :net_profit, precision: 18, scale: 2, default: 0.0, null: false
      t.decimal :paid_up_capital, precision: 18, scale: 2, default: 0.0, null: false
      t.decimal :reserve_and_surplus, precision: 18, scale: 2, default: 0.0, null: false
      t.decimal :npl_ratio, precision: 6, scale: 2, default: 0.0, null: false

      t.timestamps
    end

    add_index :stock_company_financials, [:stock_id, :fiscal_year, :quarter], unique: true, name: "index_financials_on_stock_fy_quarter"

    # 4. Market Indices Master
    create_table :market_indices do |t|
      t.string :name, null: false
      t.string :symbol, null: false
      t.decimal :current_value, precision: 12, scale: 2, default: 0.0, null: false
      t.decimal :change_point, precision: 12, scale: 2, default: 0.0, null: false
      t.decimal :change_percent, precision: 8, scale: 2, default: 0.0, null: false

      t.timestamps
    end

    add_index :market_indices, :symbol, unique: true

    # 5. Market Index Histories
    create_table :market_index_histories do |t|
      t.references :market_index, null: false, foreign_key: true
      t.date :traded_on, null: false
      t.decimal :index_value, precision: 12, scale: 2, default: 0.0, null: false
      t.decimal :change_point, precision: 12, scale: 2, default: 0.0, null: false
      t.decimal :change_percent, precision: 8, scale: 2, default: 0.0, null: false
      t.decimal :turnover, precision: 18, scale: 2, default: 0.0, null: false

      t.timestamps
    end

    add_index :market_index_histories, [:market_index_id, :traded_on], unique: true
  end
end
