class CreateMarketIndexArchives < ActiveRecord::Migration[8.1]
  # Index closes before the regular history starts, for the Indicator Scanner's market
  # phase track record (Scans::MarketPhase). Nothing else reads them.
  def change
    create_table :market_index_archives do |t|
      t.references :market_index, null: false, foreign_key: { on_delete: :cascade }
      t.date :traded_on, null: false
      t.decimal :index_value, precision: 12, scale: 2, null: false
    end
    add_index :market_index_archives, %i[market_index_id traded_on], unique: true
  end
end
