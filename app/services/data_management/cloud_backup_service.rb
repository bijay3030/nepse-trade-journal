module DataManagement
  class CloudBackupService
    def initialize(user, backup_json)
      @user = user
      @backup_json = backup_json
    end

    def upload_optional
      provider = ENV["BACKUP_CLOUD_PROVIDER"].to_s.downcase
      return :skipped if provider.blank?

      case provider
      when "google_drive"
        upload_to_google_drive
      when "dropbox"
        upload_to_dropbox
      else
        Rails.logger.warn("Unsupported backup provider: #{provider}")
        :unsupported
      end
    end

    private

    def upload_to_google_drive
      Rails.logger.info("Google Drive backup placeholder for user=#{@user.id}")
      :google_drive_placeholder
    end

    def upload_to_dropbox
      Rails.logger.info("Dropbox backup placeholder for user=#{@user.id}")
      :dropbox_placeholder
    end
  end
end
