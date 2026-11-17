class AddTelegramMarketSummaryToUsers < ActiveRecord::Migration[8.1]
  # The after-close Telegram market summary (MarketIndex::DailySummary); sent_on keeps it
  # to one message per session.
  def change
    add_column :users, :telegram_market_summary, :boolean, default: true, null: false
    add_column :users, :telegram_market_summary_sent_on, :date
  end
end
