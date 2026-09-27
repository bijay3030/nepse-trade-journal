# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_09_27_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "user_id"
    t.string "auditable_type", null: false
    t.bigint "auditable_id", null: false
    t.string "action", null: false
    t.jsonb "changes_snapshot", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "daily_journal_versions", force: :cascade do |t|
    t.bigint "daily_journal_id", null: false
    t.bigint "user_id"
    t.integer "version_number", null: false
    t.string "mood"
    t.integer "discipline_score"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["daily_journal_id", "version_number"], name: "index_journal_versions_on_journal_and_version", unique: true
    t.index ["daily_journal_id"], name: "index_daily_journal_versions_on_daily_journal_id"
    t.index ["user_id"], name: "index_daily_journal_versions_on_user_id"
  end

  create_table "daily_journals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.date "trade_date"
    t.string "mood"
    t.integer "discipline_score"
    t.text "content"
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_daily_journals_on_deleted_at"
    t.index ["user_id", "trade_date"], name: "index_daily_journals_on_user_id_and_trade_date", unique: true
    t.index ["user_id"], name: "index_daily_journals_on_user_id"
  end

  create_table "holdings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "portfolio_id", null: false
    t.bigint "stock_id", null: false
    t.integer "quantity", default: 0, null: false
    t.decimal "average_buy_price", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "last_buy_date"
    t.index ["portfolio_id", "stock_id"], name: "index_holdings_on_portfolio_id_and_stock_id", unique: true
    t.index ["portfolio_id"], name: "index_holdings_on_portfolio_id"
    t.index ["stock_id"], name: "index_holdings_on_stock_id"
  end

  create_table "market_index_histories", force: :cascade do |t|
    t.bigint "market_index_id", null: false
    t.date "traded_on", null: false
    t.decimal "index_value", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "change_point", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "change_percent", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "turnover", precision: 18, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["market_index_id", "traded_on"], name: "index_market_index_histories_on_market_index_id_and_traded_on", unique: true
    t.index ["market_index_id"], name: "index_market_index_histories_on_market_index_id"
  end

  create_table "market_indices", force: :cascade do |t|
    t.string "name", null: false
    t.string "symbol", null: false
    t.decimal "current_value", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "change_point", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "change_percent", precision: 8, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["symbol"], name: "index_market_indices_on_symbol", unique: true
  end

  create_table "portfolios", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.index ["user_id", "name"], name: "index_portfolios_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_portfolios_on_user_id"
  end

  create_table "stock_company_financials", force: :cascade do |t|
    t.bigint "stock_id", null: false
    t.string "fiscal_year", null: false
    t.string "quarter", null: false
    t.date "reported_on"
    t.decimal "eps", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "pe_ratio", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "book_value", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "pb_ratio", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "roe", precision: 6, scale: 2, default: "0.0", null: false
    t.decimal "net_profit", precision: 18, scale: 2, default: "0.0", null: false
    t.decimal "paid_up_capital", precision: 18, scale: 2, default: "0.0", null: false
    t.decimal "reserve_and_surplus", precision: 18, scale: 2, default: "0.0", null: false
    t.decimal "npl_ratio", precision: 6, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stock_id", "fiscal_year", "quarter"], name: "index_financials_on_stock_fy_quarter", unique: true
    t.index ["stock_id"], name: "index_stock_company_financials_on_stock_id"
  end

  create_table "stock_daily_indicators", force: :cascade do |t|
    t.bigint "stock_id", null: false
    t.bigint "stock_daily_price_id"
    t.date "traded_on", null: false
    t.decimal "sma_20", precision: 12, scale: 2
    t.decimal "sma_50", precision: 12, scale: 2
    t.decimal "sma_150", precision: 12, scale: 2
    t.decimal "sma_200", precision: 12, scale: 2
    t.decimal "ema_20", precision: 12, scale: 2
    t.decimal "ema_50", precision: 12, scale: 2
    t.decimal "atr_14", precision: 12, scale: 2
    t.decimal "atr_percent", precision: 8, scale: 2
    t.bigint "avg_volume_10"
    t.bigint "avg_volume_20"
    t.bigint "avg_volume_50"
    t.decimal "rvol", precision: 8, scale: 2
    t.decimal "high_52w", precision: 12, scale: 2
    t.decimal "low_52w", precision: 12, scale: 2
    t.decimal "pct_below_high_52w", precision: 8, scale: 2
    t.decimal "pct_above_low_52w", precision: 8, scale: 2
    t.decimal "change_pct_1d", precision: 8, scale: 2
    t.decimal "change_pct_20d", precision: 8, scale: 2
    t.decimal "change_pct_50d", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stock_daily_price_id"], name: "index_stock_daily_indicators_on_stock_daily_price_id"
    t.index ["stock_id", "traded_on"], name: "index_stock_daily_indicators_on_stock_id_and_traded_on", unique: true
    t.index ["stock_id"], name: "index_stock_daily_indicators_on_stock_id"
    t.index ["traded_on"], name: "index_stock_daily_indicators_on_traded_on"
  end

  create_table "stock_daily_prices", force: :cascade do |t|
    t.bigint "stock_id", null: false
    t.date "traded_on", null: false
    t.decimal "open_price", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "high_price", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "low_price", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "close_price", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "previous_close", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "change_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "change_percent", precision: 8, scale: 2, default: "0.0", null: false
    t.bigint "volume", default: 0, null: false
    t.decimal "turnover", precision: 18, scale: 2, default: "0.0", null: false
    t.integer "total_trades", default: 0, null: false
    t.decimal "vwap", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stock_id", "traded_on"], name: "index_stock_daily_prices_on_stock_id_and_traded_on", unique: true
    t.index ["stock_id"], name: "index_stock_daily_prices_on_stock_id"
    t.index ["traded_on"], name: "index_stock_daily_prices_on_traded_on"
  end

  create_table "stocks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "symbol", null: false
    t.string "name", null: false
    t.string "sector", null: false
    t.decimal "last_price", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "last_updated", null: false
    t.decimal "change_percent", precision: 8, scale: 2, default: "0.0", null: false
    t.bigint "volume", default: 0, null: false
    t.string "security_type", default: "Equity", null: false
    t.bigint "listed_shares", default: 0, null: false
    t.decimal "paid_up_value", precision: 12, scale: 2, default: "100.0", null: false
    t.decimal "market_cap", precision: 18, scale: 2, default: "0.0", null: false
    t.decimal "high_52w", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "low_52w", precision: 12, scale: 2, default: "0.0", null: false
    t.boolean "is_active", default: true, null: false
    t.text "description"
    t.string "company_website"
    t.index ["is_active"], name: "index_stocks_on_is_active"
    t.index ["sector"], name: "index_stocks_on_sector"
    t.index ["security_type"], name: "index_stocks_on_security_type"
    t.index ["symbol"], name: "index_stocks_on_symbol", unique: true
  end

  create_table "trade_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "trade_plan_id", null: false
    t.decimal "actual_entry_price", precision: 12, scale: 2, null: false
    t.integer "quantity", null: false
    t.datetime "entry_time", null: false
    t.string "broker"
    t.decimal "broker_fees", precision: 12, scale: 2, default: "0.0", null: false
    t.string "order_type"
    t.string "entry_efficiency"
    t.text "notes"
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_trade_executions_on_deleted_at"
    t.index ["trade_plan_id"], name: "index_trade_executions_on_trade_plan_id", unique: true
  end

  create_table "trade_plans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "stock_id", null: false
    t.bigint "trading_strategy_id"
    t.string "status", default: "planned", null: false
    t.string "entry_strategy"
    t.string "analysis_type"
    t.text "entry_trigger_description"
    t.decimal "planned_entry_price", precision: 12, scale: 2
    t.decimal "target_price", precision: 12, scale: 2
    t.decimal "stop_loss_price", precision: 12, scale: 2
    t.decimal "position_size_percent", precision: 6, scale: 2
    t.integer "planned_quantity"
    t.string "expected_hold_duration"
    t.string "market_condition_at_entry"
    t.string "emotional_state_at_entry"
    t.string "sector_trend"
    t.text "news_catalyst"
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_trade_plans_on_deleted_at"
    t.index ["status"], name: "index_trade_plans_on_status"
    t.index ["stock_id"], name: "index_trade_plans_on_stock_id"
    t.index ["trading_strategy_id"], name: "index_trade_plans_on_trading_strategy_id"
    t.index ["user_id"], name: "index_trade_plans_on_user_id"
  end

  create_table "trade_results", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "trade_execution_id", null: false
    t.decimal "exit_price", precision: 12, scale: 2, null: false
    t.datetime "exit_date", null: false
    t.string "exit_reason"
    t.string "exit_efficiency"
    t.decimal "max_price_reached", precision: 12, scale: 2
    t.decimal "min_price_reached", precision: 12, scale: 2
    t.decimal "exit_broker_fees", precision: 12, scale: 2, default: "0.0", null: false
    t.jsonb "mistake_tags", default: [], null: false
    t.text "lesson_learned"
    t.string "emotional_state_at_exit"
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_trade_results_on_deleted_at"
    t.index ["trade_execution_id"], name: "index_trade_results_on_trade_execution_id", unique: true
  end

  create_table "trading_strategies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name", null: false
    t.text "description"
    t.boolean "is_default", default: false, null: false
    t.index ["is_default"], name: "index_trading_strategies_on_is_default"
    t.index ["name"], name: "index_trading_strategies_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "jti", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "watchlist_alerts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "watchlist_item_id", null: false
    t.string "kind", null: false
    t.text "message", null: false
    t.decimal "price", precision: 12, scale: 2
    t.decimal "relative_volume", precision: 8, scale: 2
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "read_at"], name: "index_watchlist_alerts_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_watchlist_alerts_on_user_id"
    t.index ["watchlist_item_id"], name: "index_watchlist_alerts_on_watchlist_item_id"
  end

  create_table "watchlist_items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "stock_id", null: false
    t.bigint "trade_plan_id"
    t.string "setup_type", default: "vcp", null: false
    t.string "status", default: "watching", null: false
    t.string "price_state"
    t.decimal "entry_zone_low", precision: 12, scale: 2, null: false
    t.decimal "entry_zone_high", precision: 12, scale: 2, null: false
    t.decimal "invalidation_price", precision: 12, scale: 2, null: false
    t.decimal "stop_loss_price", precision: 12, scale: 2
    t.decimal "target_price", precision: 12, scale: 2
    t.decimal "pivot_price", precision: 12, scale: 2
    t.decimal "price_at_add", precision: 12, scale: 2
    t.jsonb "setup_snapshot", default: {}, null: false
    t.text "notes"
    t.datetime "last_evaluated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_watchlist_items_on_status"
    t.index ["stock_id"], name: "index_watchlist_items_on_stock_id"
    t.index ["trade_plan_id"], name: "index_watchlist_items_on_trade_plan_id"
    t.index ["user_id", "stock_id"], name: "index_watchlist_items_on_user_id_and_stock_id", unique: true
    t.index ["user_id"], name: "index_watchlist_items_on_user_id"
  end

  add_foreign_key "audit_logs", "users"
  add_foreign_key "daily_journal_versions", "daily_journals"
  add_foreign_key "daily_journal_versions", "users"
  add_foreign_key "daily_journals", "users"
  add_foreign_key "holdings", "portfolios"
  add_foreign_key "holdings", "stocks"
  add_foreign_key "market_index_histories", "market_indices"
  add_foreign_key "portfolios", "users"
  add_foreign_key "stock_company_financials", "stocks"
  add_foreign_key "stock_daily_indicators", "stock_daily_prices"
  add_foreign_key "stock_daily_indicators", "stocks"
  add_foreign_key "stock_daily_prices", "stocks"
  add_foreign_key "trade_executions", "trade_plans"
  add_foreign_key "trade_plans", "stocks"
  add_foreign_key "trade_plans", "trading_strategies"
  add_foreign_key "trade_plans", "users"
  add_foreign_key "trade_results", "trade_executions"
  add_foreign_key "watchlist_alerts", "users"
  add_foreign_key "watchlist_alerts", "watchlist_items", on_delete: :cascade
  add_foreign_key "watchlist_items", "stocks"
  add_foreign_key "watchlist_items", "trade_plans"
  add_foreign_key "watchlist_items", "users"
end
