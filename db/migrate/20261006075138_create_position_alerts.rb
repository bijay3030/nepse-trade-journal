class CreatePositionAlerts < ActiveRecord::Migration[8.0]
  def change
    # Sell-rule alerts for open positions (Positions::Monitor). `key` keeps each rule
    # to one alert per level or session, e.g. a stop alert per stop price.
    create_table :position_alerts do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :position, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.string :key, null: false, default: ""
      t.text :message, null: false
      t.decimal :price, precision: 12, scale: 2
      t.datetime :read_at
      t.timestamps
    end
    add_index :position_alerts, %i[position_id kind key], unique: true
    add_index :position_alerts, %i[user_id read_at]
  end
end
