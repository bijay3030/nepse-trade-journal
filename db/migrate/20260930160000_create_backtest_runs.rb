class CreateBacktestRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :backtest_runs do |t|
      t.date :from_date
      t.date :to_date
      t.integer :sessions, null: false, default: 0
      t.jsonb :parameters, null: false, default: {}
      t.jsonb :results, null: false, default: {}
      t.timestamps
    end
  end
end
