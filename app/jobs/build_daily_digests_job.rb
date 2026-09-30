# After the nightly snapshots: builds the daily digest for every user who has it on.
class BuildDailyDigestsJob < ApplicationJob
  queue_as :default

  def perform
    built = User.where(digest_enabled: true).find_each.count { Digests::Builder.call(_1) }
    Rails.logger.info("BuildDailyDigestsJob: built #{built} digests")
    built
  end
end
