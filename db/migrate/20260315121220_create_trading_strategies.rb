class CreateTradingStrategies < ActiveRecord::Migration[8.0]
  def change
    create_table :trading_strategies do |t|
      t.timestamps
    end
  end
end
