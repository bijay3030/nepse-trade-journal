class CreateTradeResults < ActiveRecord::Migration[8.0]
  def change
    create_table :trade_results do |t|
      t.timestamps
    end
  end
end
