class AddTelegramAlerts < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :telegram_chat_id, :string
    add_column :users, :telegram_username, :string
    add_column :users, :telegram_link_token, :string
    add_column :users, :telegram_link_expires_at, :datetime
    add_column :users, :telegram_watchlist_alerts, :boolean, null: false, default: true
    add_column :users, :telegram_board_alerts, :boolean, null: false, default: true
    add_index :users, :telegram_link_token, unique: true
    add_index :users, :telegram_chat_id

    # One message per user, stock, kind and session, so a stock moving in and out of
    # its zone doesn't message again the same day.
    create_table :telegram_deliveries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :stock, null: false, foreign_key: true
      t.string :kind, null: false
      t.date :traded_on, null: false
      t.timestamps
    end
    add_index :telegram_deliveries, [ :user_id, :stock_id, :kind, :traded_on ], unique: true, name: "index_telegram_deliveries_once_per_day"

    # Small app-wide values that must survive restarts, e.g. the bot's update offset.
    create_table :app_settings do |t|
      t.string :key, null: false
      t.string :value
      t.timestamps
    end
    add_index :app_settings, :key, unique: true
  end
end
