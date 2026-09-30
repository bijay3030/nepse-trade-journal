class AddGuardsToStockSetupSnapshots < ActiveRecord::Migration[8.0]
  def change
    add_column :stock_setup_snapshots, :avg_turnover, :decimal, precision: 18, scale: 2
    add_column :stock_setup_snapshots, :change_pct, :decimal, precision: 8, scale: 2
    add_column :stock_setup_snapshots, :guards, :jsonb, default: [], null: false
  end
end
