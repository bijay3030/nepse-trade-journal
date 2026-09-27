class CreateTradeExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :trade_executions do |t|
      t.timestamps
    end
  end
end
