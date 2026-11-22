class CreateMarketEvents < ActiveRecord::Migration[8.1]
  # Company announcements and corporate actions (Events::Sync), each rated good / bad /
  # neutral / mixed for the share price by Events::Classifier, and who was told on Telegram.
  def change
    create_table :market_events do |t|
      t.references :stock, foreign_key: { on_delete: :cascade }
      t.string :source, null: false
      t.string :external_id, null: false
      t.string :kind, null: false
      t.string :title, null: false
      t.string :url
      t.date :published_on, null: false
      t.date :event_on
      t.jsonb :data, null: false, default: {}
      t.string :impact, null: false, default: "neutral"
      t.string :reason
      t.boolean :important, null: false, default: false
      t.timestamps
    end
    add_index :market_events, %i[source external_id], unique: true
    add_index :market_events, :published_on
    add_index :market_events, :event_on

    create_table :market_event_deliveries do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :market_event, null: false, foreign_key: { on_delete: :cascade }
      # "new" when the event first appears, "book_close" for the reminder before it.
      t.string :reason, null: false, default: "new"
      t.datetime :created_at, null: false
    end
    add_index :market_event_deliveries, %i[user_id market_event_id reason], unique: true, name: "index_market_event_deliveries_once"

    add_column :users, :telegram_event_alerts, :boolean, default: true, null: false
  end
end
