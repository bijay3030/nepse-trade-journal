class CreateStockIntradayVolumes < ActiveRecord::Migration[8.0]
  def change
    # Each stock's running volume at each price sync during the session, to learn
    # how NEPSE's daily volume builds up through the day (Nepse::VolumeProfile).
    create_table :stock_intraday_volumes do |t|
      t.references :stock, null: false, foreign_key: { on_delete: :cascade }
      t.date :traded_on, null: false
      t.integer :minute, null: false # minutes since the 11:00 open
      t.bigint :volume, null: false
      t.timestamps
    end
    add_index :stock_intraday_volumes, %i[stock_id traded_on minute], unique: true, name: "index_intraday_volumes_unique"
    add_index :stock_intraday_volumes, :traded_on
  end
end
