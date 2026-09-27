class CreateWatchlistItemsAndAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :watchlist_items do |t|
      t.references :user, null: false, foreign_key: true
      t.references :stock, null: false, foreign_key: true
      t.references :trade_plan, foreign_key: true
      t.string :setup_type, null: false, default: "vcp"
      t.string :status, null: false, default: "watching"
      t.string :price_state
      t.decimal :entry_zone_low, precision: 12, scale: 2, null: false
      t.decimal :entry_zone_high, precision: 12, scale: 2, null: false
      t.decimal :invalidation_price, precision: 12, scale: 2, null: false
      t.decimal :stop_loss_price, precision: 12, scale: 2
      t.decimal :target_price, precision: 12, scale: 2
      t.decimal :pivot_price, precision: 12, scale: 2
      t.decimal :price_at_add, precision: 12, scale: 2
      t.jsonb :setup_snapshot, null: false, default: {}
      t.text :notes
      t.datetime :last_evaluated_at
      t.timestamps
    end
    add_index :watchlist_items, [ :user_id, :stock_id ], unique: true
    add_index :watchlist_items, :status

    create_table :watchlist_alerts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :watchlist_item, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.text :message, null: false
      t.decimal :price, precision: 12, scale: 2
      t.decimal :relative_volume, precision: 8, scale: 2
      t.datetime :read_at
      t.timestamps
    end
    add_index :watchlist_alerts, [ :user_id, :read_at ]
  end
end
