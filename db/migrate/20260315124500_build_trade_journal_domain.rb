class BuildTradeJournalDomain < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :jti, null: false
      t.datetime :remember_created_at
      t.datetime :reset_password_sent_at
      t.string :reset_password_token
      t.timestamps null: false
    end

    add_index :users, :email, unique: true
    add_index :users, :jti, unique: true
    add_index :users, :reset_password_token, unique: true

    change_table :stocks, bulk: true do |t|
      t.decimal :change_percent, precision: 8, scale: 2, default: 0, null: false
      t.bigint :volume, default: 0, null: false
    end

    change_table :trade_plans, bulk: true do |t|
      t.references :user, null: false, foreign_key: true
      t.references :stock, null: false, foreign_key: true
      t.references :trading_strategy, foreign_key: true

      t.string :status, null: false, default: "planned"
      t.string :entry_strategy
      t.string :analysis_type
      t.text :entry_trigger_description
      t.decimal :planned_entry_price, precision: 12, scale: 2
      t.decimal :target_price, precision: 12, scale: 2
      t.decimal :stop_loss_price, precision: 12, scale: 2
      t.decimal :position_size_percent, precision: 6, scale: 2
      t.integer :planned_quantity
      t.string :expected_hold_duration
      t.string :market_condition_at_entry
      t.string :emotional_state_at_entry
      t.string :sector_trend
      t.text :news_catalyst
    end

    add_index :trade_plans, :status

    change_table :trade_executions, bulk: true do |t|
      t.references :trade_plan, null: false, foreign_key: true, index: { unique: true }
      t.decimal :actual_entry_price, precision: 12, scale: 2, null: false
      t.integer :quantity, null: false
      t.datetime :entry_time, null: false
      t.string :broker
      t.decimal :broker_fees, precision: 12, scale: 2, default: 0, null: false
      t.string :order_type
      t.string :entry_efficiency
      t.text :notes
    end

    change_table :trade_results, bulk: true do |t|
      t.references :trade_execution, null: false, foreign_key: true, index: { unique: true }
      t.decimal :exit_price, precision: 12, scale: 2, null: false
      t.datetime :exit_date, null: false
      t.string :exit_reason
      t.string :exit_efficiency
      t.decimal :max_price_reached, precision: 12, scale: 2
      t.decimal :min_price_reached, precision: 12, scale: 2
      t.decimal :exit_broker_fees, precision: 12, scale: 2, default: 0, null: false
      t.jsonb :mistake_tags, default: [], null: false
      t.text :lesson_learned
      t.string :emotional_state_at_exit
    end

    change_table :portfolios, bulk: true do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
    end

    add_index :portfolios, [:user_id, :name], unique: true

    change_table :holdings, bulk: true do |t|
      t.references :portfolio, null: false, foreign_key: true
      t.references :stock, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 0
      t.decimal :average_buy_price, precision: 12, scale: 2, null: false, default: 0
      t.datetime :last_buy_date
    end

    add_index :holdings, [:portfolio_id, :stock_id], unique: true
  end
end
