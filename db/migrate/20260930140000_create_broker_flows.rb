class CreateBrokerFlows < ActiveRecord::Migration[8.0]
  def change
    create_table :brokers do |t|
      t.string :broker_no, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :brokers, :broker_no, unique: true

    # Daily floorsheet totals per stock and broker (trades rolled up, ~13k rows a day).
    create_table :stock_broker_flows do |t|
      t.references :stock, null: false, foreign_key: true, index: false
      t.date :traded_on, null: false
      t.string :broker_no, null: false
      t.bigint :buy_quantity, null: false, default: 0
      t.bigint :sell_quantity, null: false, default: 0
      t.decimal :buy_amount, precision: 18, scale: 2, null: false, default: 0
      t.decimal :sell_amount, precision: 18, scale: 2, null: false, default: 0
      t.integer :trades, null: false, default: 0
    end
    add_index :stock_broker_flows, [ :stock_id, :traded_on, :broker_no ], unique: true, name: "index_broker_flows_on_stock_day_broker"
    add_index :stock_broker_flows, :traded_on

    # Broker accumulation summary on the nightly snapshot.
    add_column :stock_setup_snapshots, :flow_state, :string
    add_column :stock_setup_snapshots, :flow_score, :decimal, precision: 8, scale: 2
    add_column :stock_setup_snapshots, :flow, :jsonb, null: false, default: {}
  end
end
