# One run of Backtest::Runner over the stored point-in-time snapshots.
class BacktestRun < ApplicationRecord
  scope :latest_first, -> { order(created_at: :desc) }
end
