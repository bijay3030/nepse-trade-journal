class AddExtensionToStockSetupSnapshots < ActiveRecord::Migration[8.0]
  def change
    # Setups::Extension: ADR%, extension from the 50-day in ADRs, day move in ADRs,
    # breakout age and the resulting flags.
    add_column :stock_setup_snapshots, :extension, :jsonb, null: false, default: {}
  end
end
