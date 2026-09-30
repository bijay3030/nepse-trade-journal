class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :jwt_authenticatable,
         jwt_revocation_strategy: self

  has_many :trade_plans, dependent: :destroy
  has_many :trade_executions, through: :trade_plans
  has_many :trade_results, through: :trade_executions
  has_many :portfolios, dependent: :destroy
  has_many :daily_journals, dependent: :destroy
  has_many :audit_logs, dependent: :nullify
  has_many :watchlist_items, dependent: :destroy
  has_many :watchlist_alerts, dependent: :delete_all
  has_many :daily_digests, dependent: :delete_all

  validates :jti, presence: true, uniqueness: true
end
