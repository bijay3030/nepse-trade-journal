module PaperTrading
  # The paper account for the page: open and closed trades, totals, and the log.
  module Report
    module_function

    def call(user, log_limit: 200)
      trades = PaperTrade.where(user: user).includes(:stock).order(Arel.sql("COALESCE(entry_at, created_at) DESC")).to_a
      closed = trades.select { _1.status == "closed" }
      open = trades.select { _1.status == "open" }
      wins = closed.select { _1.net_pnl.to_f.positive? }
      losses = closed.reject { _1.net_pnl.to_f.positive? }
      {
        enabled: user.paper_trading, quantity: Engine::QUANTITY, slippage_pct: Engine::SLIPPAGE_PCT,
        summary: {
          open: open.size, pending: trades.count { _1.status == "pending" }, closed: closed.size,
          invested: open.sum(&:cost_basis).round(2), open_pnl: open.sum(&:unrealized_pnl).round(2),
          realized_pnl: closed.sum { _1.net_pnl.to_f }.round(2),
          win_rate_pct: closed.empty? ? nil : (wins.size * 100.0 / closed.size).round(1),
          profit_factor: losses.sum { _1.net_pnl.to_f }.zero? ? nil : (wins.sum { _1.net_pnl.to_f } / -losses.sum { _1.net_pnl.to_f }).round(2)
        },
        trades: trades.map { row(_1) },
        log: PaperTradeEvent.where(user: user).includes(:stock).order(at: :desc, id: :desc).limit(log_limit).map do |e|
          { id: e.id, at: e.at, action: e.action, symbol: e.stock.symbol, price: e.price&.to_f, reason: e.reason, trade_id: e.paper_trade_id }
        end
      }
    end

    def row(t)
      {
        id: t.id, symbol: t.stock.symbol, name: t.stock.name, status: t.status, trigger: t.trigger, signal_on: t.signal_on, quantity: t.quantity,
        buy_reason: t.buy_reason, entry_price: t.entry_price&.to_f, entry_at: t.entry_at, buy_costs: t.buy_costs&.to_f,
        stop_price: t.stop_price.to_f, target_price: t.target_price&.to_f, last_price: t.stock.last_price.to_f,
        sellable_on: t.sellable_on, unrealized_pnl: t.status == "open" ? t.unrealized_pnl : nil,
        exit_price: t.exit_price&.to_f, exit_at: t.exit_at, exit_rule: t.exit_rule, sell_reason: t.sell_reason,
        sell_costs: t.sell_costs&.to_f, cgt: t.cgt&.to_f, net_pnl: t.net_pnl&.to_f, return_pct: t.return_pct&.to_f,
        held_days: t.opened_on && ((t.exit_at ? t.exit_at.in_time_zone(Nepse::MarketHours::TIME_ZONE).to_date : Nepse::MarketHours.today) - t.opened_on).to_i
      }
    end
  end
end
