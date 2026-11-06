class AddScannerAlertSignalsToUsers < ActiveRecord::Migration[8.0]
  def change
    # The Indicator Scanner filter a user gets Telegram messages for (Scans::Alerts);
    # empty = off.
    add_column :users, :scanner_alert_signals, :jsonb, null: false, default: []
  end
end
