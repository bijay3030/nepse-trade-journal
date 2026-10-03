class AddTradingSettingsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :trading_capital, :decimal, precision: 15, scale: 2
    add_column :users, :risk_per_trade_pct, :decimal, precision: 5, scale: 2, null: false, default: 1.0
    add_column :users, :max_open_risk_pct, :decimal, precision: 5, scale: 2, null: false, default: 6.0
  end
end
