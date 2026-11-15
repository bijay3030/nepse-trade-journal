class AddTelegramScannerEntryAlertsToUsers < ActiveRecord::Migration[8.1]
  # Live Telegram messages when a stock matching the saved scanner filter trades inside
  # its entry zone (Scans::EntryAlerts).
  def change
    add_column :users, :telegram_scanner_entry_alerts, :boolean, default: true, null: false
  end
end
