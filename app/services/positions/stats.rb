module Positions
  # Results across closed positions: win rate and net P&L after costs and CGT, average R
  # and expectancy, and how often the plan was followed (of the reviewed trades).
  module Stats
    module_function

    def call(positions)
      rows = positions.map { |p| { net: p.realized[:net], tax: p.realized[:tax], r: p.closed_r_multiple, plan: p.review_plan_followed, days: p.days_held } }
      return { closed: 0 } if rows.empty?

      wins = rows.select { _1[:net].positive? }
      losses = rows.reject { _1[:net].positive? }
      rs = rows.filter_map { _1[:r] }
      reviewed = rows.filter_map { _1[:plan] }
      {
        closed: rows.size,
        win_rate_pct: (wins.size * 100.0 / rows.size).round(1),
        net_pnl: rows.sum { _1[:net] }.round(2), tax_paid: rows.sum { _1[:tax] }.round(2),
        avg_win: wins.empty? ? nil : (wins.sum { _1[:net] } / wins.size).round(2),
        avg_loss: losses.empty? ? nil : (losses.sum { _1[:net] } / losses.size).round(2),
        expectancy: (rows.sum { _1[:net] } / rows.size).round(2),
        avg_r: rs.empty? ? nil : (rs.sum / rs.size).round(2),
        avg_days_held: (rows.sum { _1[:days] }.to_f / rows.size).round(1),
        reviewed: reviewed.size,
        plan_followed_pct: reviewed.empty? ? nil : (reviewed.count("yes") * 100.0 / reviewed.size).round(1)
      }
    end
  end
end
