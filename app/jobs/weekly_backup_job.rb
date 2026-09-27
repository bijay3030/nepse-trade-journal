class WeeklyBackupJob < ApplicationJob
  queue_as :default

  def perform
    User.find_each do |user|
      exporter = DataManagement::ExportService.new(user)
      backup_hash = exporter.full_backup_hash(include_deleted: true)
      backup_json = JSON.pretty_generate(backup_hash)
      trades_csv = exporter.trades_csv(include_deleted: true)

      BackupMailer.weekly_backup(user, backup_json: backup_json, trades_csv: trades_csv).deliver_later
      DataManagement::CloudBackupService.new(user, backup_json).upload_optional
    end
  end
end
