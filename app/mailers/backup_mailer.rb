class BackupMailer < ApplicationMailer
  default from: "no-reply@nepse-journal.local"

  def weekly_backup(user, backup_json:, trades_csv:)
    @user = user
    attachments["nepse-backup-#{Date.current}.json"] = {
      mime_type: "application/json",
      content: backup_json
    }
    attachments["nepse-trades-#{Date.current}.csv"] = {
      mime_type: "text/csv",
      content: trades_csv
    }

    mail(to: user.email, subject: "Your Weekly NEPSE Trade Journal Backup")
  end
end
