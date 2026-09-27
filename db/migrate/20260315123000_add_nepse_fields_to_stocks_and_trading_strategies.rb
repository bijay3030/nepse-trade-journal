class AddNepseFieldsToStocksAndTradingStrategies < ActiveRecord::Migration[8.0]
  def change
    change_table :stocks, bulk: true do |t|
      t.string :symbol, null: false
      t.string :name, null: false
      t.string :sector, null: false
      t.decimal :last_price, precision: 12, scale: 2, default: 0, null: false
      t.datetime :last_updated, null: false
    end

    add_index :stocks, :symbol, unique: true
    add_index :stocks, :sector

    change_table :trading_strategies, bulk: true do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :is_default, default: false, null: false
    end

    add_index :trading_strategies, :name, unique: true
    add_index :trading_strategies, :is_default
  end
end
