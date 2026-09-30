# App-wide key/value settings that must survive restarts.
class AppSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.get(key) = find_by(key: key)&.value

  def self.set(key, value)
    upsert({ key: key, value: value&.to_s, created_at: Time.current, updated_at: Time.current }, unique_by: :key)
  end
end
