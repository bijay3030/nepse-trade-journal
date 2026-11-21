class CreateLabPaperTrades < ActiveRecord::Migration[8.1]
  # Strategy Lab candidates recorded on the day they appear, then followed with the same
  # rules as the backtest (Lab::PaperTrades), so a live record builds up.
  def change
    create_table :lab_paper_trades do |t|
      t.references :stock, null: false, foreign_key: { on_delete: :cascade }
      t.string :strategy, null: false
      t.date :signal_on, null: false
      t.jsonb :levels, null: false, default: {}
      t.jsonb :record, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.date :entry_on
      t.decimal :entry_price, precision: 12, scale: 2
      t.date :exit_on
      t.decimal :exit_price, precision: 12, scale: 2
      t.string :exit_reason
      t.decimal :return_pct, precision: 8, scale: 2
      t.decimal :r_multiple, precision: 8, scale: 2
      t.timestamps
    end
    add_index :lab_paper_trades, %i[stock_id strategy signal_on], unique: true
    add_index :lab_paper_trades, :status
  end
end
