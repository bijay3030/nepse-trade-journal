class CreateDailyDigests < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_digests do |t|
      t.references :user, null: false, foreign_key: true
      t.date :traded_on, null: false
      t.jsonb :content, null: false, default: {}
      t.datetime :read_at
      t.timestamps
    end
    add_index :daily_digests, [ :user_id, :traded_on ], unique: true

    add_column :users, :digest_enabled, :boolean, null: false, default: true
    add_column :users, :digest_sections, :jsonb, null: false, default: %w[market entry_zone watchlist]
  end
end
