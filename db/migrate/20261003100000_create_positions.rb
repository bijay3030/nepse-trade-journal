class CreatePositions < ActiveRecord::Migration[8.0]
  def change
    # A stock the user holds (or held), built from its fills. Quantity and average
    # price are derived from position_fills; stop and target are the user's plan.
    create_table :positions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :stock, null: false, foreign_key: true
      t.references :watchlist_item, foreign_key: { on_delete: :nullify }
      t.string :status, null: false, default: "open"
      t.string :setup_type
      t.decimal :stop_price, precision: 12, scale: 2, null: false
      t.decimal :initial_stop_price, precision: 12, scale: 2, null: false
      t.decimal :target_price, precision: 12, scale: 2
      t.date :closed_on
      t.text :notes
      t.timestamps
    end
    add_index :positions, [ :user_id, :stock_id ], unique: true, where: "status = 'open'", name: "index_positions_one_open_per_stock"

    create_table :position_fills do |t|
      t.references :position, null: false, foreign_key: { on_delete: :cascade }
      t.string :side, null: false
      t.decimal :price, precision: 12, scale: 2, null: false
      t.integer :quantity, null: false
      t.date :traded_on, null: false
      t.timestamps
    end
  end
end
