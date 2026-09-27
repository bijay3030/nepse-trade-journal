class CreateTradePlans < ActiveRecord::Migration[8.0]
  def change
    create_table :trade_plans do |t|
      t.timestamps
    end
  end
end
