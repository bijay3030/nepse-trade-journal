class AddSignalsToStockSetupSnapshots < ActiveRecord::Migration[8.0]
  def change
    # Setups::VolumeSignals and Setups::BaseCount: up/down volume, pocket pivot, volume
    # dry-up, base number, and their flags.
    add_column :stock_setup_snapshots, :signals, :jsonb, null: false, default: {}
  end
end
