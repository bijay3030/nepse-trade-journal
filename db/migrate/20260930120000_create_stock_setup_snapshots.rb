class CreateStockSetupSnapshots < ActiveRecord::Migration[8.0]
  def change
    # One row per stock per session, built after the close: trend template,
    # relative strength, the best setup's zone, and the buy-readiness score.
    create_table :stock_setup_snapshots do |t|
      t.references :stock, null: false, foreign_key: true
      t.date :traded_on, null: false
      t.decimal :close_price, precision: 12, scale: 2, null: false
      t.integer :trend_rules_passed, null: false, default: 0
      t.jsonb :trend_checks, null: false, default: []
      t.integer :rs_rating
      t.decimal :rs_score, precision: 10, scale: 4
      t.string :setup_type
      t.string :zone_state, null: false
      t.decimal :entry_zone_low, precision: 12, scale: 2
      t.decimal :entry_zone_high, precision: 12, scale: 2
      t.decimal :invalidation_price, precision: 12, scale: 2
      t.decimal :target_price, precision: 12, scale: 2
      t.decimal :pivot_price, precision: 12, scale: 2
      t.decimal :distance_to_zone_pct, precision: 8, scale: 2
      t.integer :setup_quality, null: false, default: 0
      t.integer :readiness_score, null: false, default: 0
      t.jsonb :readiness_components, null: false, default: {}
      t.boolean :in_buy_zone, null: false, default: false
      t.jsonb :screener_row, null: false, default: {}
      t.timestamps
    end
    add_index :stock_setup_snapshots, [ :stock_id, :traded_on ], unique: true
    add_index :stock_setup_snapshots, [ :traded_on, :readiness_score ]
    add_index :stock_setup_snapshots, [ :traded_on, :in_buy_zone ]
  end
end
