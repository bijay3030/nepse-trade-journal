# When the server starts with its job worker (bin/dev, or Render), check for sessions
# missed while it was off. CatchUpJob also runs hourly (config/recurring.yml).
Rails.application.config.after_initialize do
  next unless defined?(Rails::Server) && ENV["SOLID_QUEUE_IN_PUMA"].present?

  CatchUpJob.set(wait: 1.minute).perform_later
rescue ActiveRecord::ActiveRecordError => e
  Rails.logger.warn("Catch-up not queued: #{e.message}")
end
