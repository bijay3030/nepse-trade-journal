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
  has_many :position_alerts, dependent: :delete_all

  validates :jti, presence: true, uniqueness: true
  validates :trading_capital, numericality: { greater_than: 0 }, allow_nil: true
  validates :risk_per_trade_pct, numericality: { greater_than: 0, less_than_or_equal_to: 10 }
  validates :max_open_risk_pct, numericality: { greater_than: 0, less_than_or_equal_to: 50 }
  validates :max_sector_pct, numericality: { greater_than: 0, less_than_or_equal_to: 100 }

  # Position size for an entry and stop from the user's capital and risk per trade.
  # Outside an uptrend it adds `cautious`: the size at the market state's share of the
  # usual risk (Setups::MarketDirection), shown alongside, never instead.
  def size_position(entry:, stop:, target: nil, market: Setups::MarketDirection.current)
    result = Positions::Sizer.call(capital: trading_capital, risk_pct: risk_per_trade_pct, entry: entry, stop: stop, target: target)
    return result if result[:error]

    result = result.merge(heat: heat_check(entry, stop, target, result))
    factor = market&.dig(:size_factor)
    return result if factor.nil? || factor >= 1

    cautious = Positions::Sizer.call(capital: trading_capital, risk_pct: risk_per_trade_pct.to_f * factor, entry: entry, stop: stop, target: target)
    result.merge(cautious: { state: market[:state], label: market[:label], size_factor: factor,
                             risk_budget: cautious[:risk_budget], quantity: cautious[:quantity].to_i })
  end

  private

  # Portfolio heat if this suggested buy is made, and the largest size that stays within
  # max_open_risk_pct (Positions::Portfolio). Information for the trader; nothing is blocked.
  def heat_check(entry, stop, target, sized)
    risk = positions.open.includes(:stock, :fills).sum(&:open_risk)
    now = Positions::Portfolio.heat_for(self, open_risk: risk)
    after = Positions::Portfolio.heat_for(self, open_risk: risk, extra_risk: sized[:loss_at_stop].to_f)
    room = now[:room].to_f
    fits = if after[:state] != "over" then sized[:quantity].to_i
    elsif room.positive? then Positions::Sizer.call(capital: trading_capital, risk_pct: room / trading_capital.to_f * 100, entry: entry, stop: stop, target: target)[:quantity].to_i
    else 0
    end
    { now_pct: now[:pct], after_pct: after[:pct], limit_pct: now[:limit_pct], state: after[:state], fits_quantity: fits }
  end
end
