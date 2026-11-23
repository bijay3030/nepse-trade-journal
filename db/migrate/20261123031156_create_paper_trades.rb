class CreatePaperTrades < ActiveRecord::Migration[8.1]
  # Fully automated paper trading (PaperTrading::Engine): 10 shares bought on a watchlist
  # zone alert or a stock new on the Entry zone board, sold by the app's sell rules, with
  # NEPSE costs and capital gains tax, and a log of every signal, buy, skip and sell.
  def change
    create_table :paper_trades do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :stock, null: false, foreign_key: { on_delete: :cascade }
      t.string :status, null: false, default: "pending" # pending (waiting for the next session) / open / closed
      t.string :trigger, null: false                    # watchlist_entered_zone / watchlist_breakout / board_new
      t.string :trigger_key, null: false                # one trade per signal
      t.date :signal_on, null: false
      t.text :buy_reason, null: false
      t.integer :quantity, null: false
      t.decimal :stop_price, precision: 12, scale: 2, null: false
      t.decimal :initial_stop_price, precision: 12, scale: 2, null: false
      t.decimal :target_price, precision: 12, scale: 2
      t.decimal :entry_price, precision: 12, scale: 2
      t.datetime :entry_at
      t.decimal :buy_costs, precision: 12, scale: 2
      t.decimal :exit_price, precision: 12, scale: 2
      t.datetime :exit_at
      t.string :exit_rule
      t.text :sell_reason
      t.decimal :sell_costs, precision: 12, scale: 2
      t.decimal :cgt, precision: 12, scale: 2
      t.decimal :net_pnl, precision: 14, scale: 2
      t.decimal :return_pct, precision: 8, scale: 2
      t.timestamps
    end
    add_index :paper_trades, %i[user_id trigger_key], unique: true
    add_index :paper_trades, %i[user_id status]

    create_table :paper_trade_events do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :paper_trade, foreign_key: { on_delete: :cascade }
      t.references :stock, null: false, foreign_key: { on_delete: :cascade }
      t.string :action, null: false # signal / buy / skip / hold / sell
      t.decimal :price, precision: 12, scale: 2
      t.text :reason, null: false
      t.datetime :at, null: false
      t.jsonb :data, null: false, default: {}
    end
    add_index :paper_trade_events, %i[user_id at]

    add_column :users, :paper_trading, :boolean, default: true, null: false
  end
end
