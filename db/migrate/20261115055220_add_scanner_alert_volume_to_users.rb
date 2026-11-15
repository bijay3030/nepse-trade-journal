class AddScannerAlertVolumeToUsers < ActiveRecord::Migration[8.1]
  def change
    # Whether the saved scanner filter also requires 1.5x average volume on the day the
    # combination began (Scans::Alerts).
    add_column :users, :scanner_alert_volume, :boolean, null: false, default: true
    # EMA 21/50 left the scanner (no better than random in the 2020-26 test).
    reversible do |dir|
      dir.up { execute "UPDATE users SET scanner_alert_signals = scanner_alert_signals - 'ema_21_50'" }
    end
  end
end
