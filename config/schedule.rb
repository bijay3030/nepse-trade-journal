# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

set :output, "log/cron.log"
set :environment, ENV.fetch("RAILS_ENV", "production")

# Nepali Time (NPT) is UTC+5:45
# 4:00 PM NPT (16:00) corresponds to 10:15 AM UTC (10:15)
every 1.day, at: "10:15 am" do
  runner "FetchNepseDailyPricesJob.perform_now"
end
