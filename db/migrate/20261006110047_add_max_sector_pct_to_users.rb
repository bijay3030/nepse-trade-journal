class AddMaxSectorPctToUsers < ActiveRecord::Migration[8.0]
  def change
    # Warn when one sector holds more than this share of trading capital.
    add_column :users, :max_sector_pct, :decimal, precision: 5, scale: 2, null: false, default: 30
  end
end
