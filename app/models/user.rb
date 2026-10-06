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
  has_many :telegram_deliveries, dependent: :delete_all
  has_many :positions, dependent: :destroy

  validates :jti, presence: true, uniqueness: true
  validates :trading_capital, numericality: { greater_than: 0 }, allow_nil: true
  validates :risk_per_trade_pct, numericality: { greater_than: 0, less_than_or_equal_to: 10 }
  validates :max_open_risk_pct, numericality: { greater_than: 0, less_than_or_equal_to: 50 }

  # Position size for an entry and stop from the user's capital and risk per trade.
  # Outside an uptrend it adds `cautious`: the size at the market state's share of the
  # usual risk (Setups::MarketDirection), shown alongside, never instead.
  def size_position(entry:, stop:, target: nil, market: Setups::MarketDirection.current)
    result = Positions::Sizer.call(capital: trading_capital, risk_pct: risk_per_trade_pct, entry: entry, stop: stop, target: target)
    factor = market&.dig(:size_factor)
    return result if result[:error] || factor.nil? || factor >= 1

    cautious = Positions::Sizer.call(capital: trading_capital, risk_pct: risk_per_trade_pct.to_f * factor, entry: entry, stop: stop, target: target)
    result.merge(cautious: { state: market[:state], label: market[:label], size_factor: factor,
                             risk_budget: cautious[:risk_budget], quantity: cautious[:quantity].to_i })
  end
end
