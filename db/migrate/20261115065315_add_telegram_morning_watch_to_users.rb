class AddTelegramMorningWatchToUsers < ActiveRecord::Migration[8.1]
  # The 9 AM Telegram list of saved-filter stocks in or near their entry zone
  # (Scans::MorningWatch); sent_on keeps it to one message a day.
  def change
    add_column :users, :telegram_morning_watch, :boolean, default: true, null: false
    add_column :users, :telegram_morning_watch_sent_on, :date
  end
end
