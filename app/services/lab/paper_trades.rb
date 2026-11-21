module Lab
  # Paper trading for the Strategy Lab, like opentrader's: each night every new candidate
  # is recorded with its levels, and every unfinished paper trade is re-simulated with the
  # backtest's rules on the data since its signal (pending -> open -> closed, or skipped
  # when the next open was outside the entry range). Nothing is bought or sold.
  module PaperTrades
    module_function

    # Runs the backtest with the active paper trades, stores the updates and today's
    # candidates, and returns the report (cached for the page).
    def refresh!(now: Time.current)
      active = LabPaperTrade.active.to_a.group_by(&:stock_id)
      report = Backtest.call(now: now, paper: active)
      report[:paper].each { |trade, result| apply(trade, result) }
      report[:candidates].each { record(_1) }
      report.except(:paper)
    end

    def record(candidate)
      LabPaperTrade.create_or_find_by!(stock_id: candidate[:stock_id], strategy: candidate[:strategy], signal_on: candidate[:signal_on]) do |trade|
        trade.levels = candidate[:levels]
        trade.record = candidate[:record]
      end
    end

    def apply(trade, result)
      attrs = { status: result[:status].to_s }
      if result[:entry_on]
        attrs.merge!(entry_on: result[:entry_on], entry_price: result[:entry], exit_on: result[:exit_on], exit_price: result[:exit],
                     exit_reason: result[:reason], return_pct: result[:return_pct], r_multiple: result[:r])
      elsif result[:status] == :skipped
        attrs[:exit_reason] = result[:reason]
      end
      trade.update!(attrs)
    end

    # The page's list: newest first, and a summary of the closed ones.
    def overview(limit: 100)
      trades = LabPaperTrade.includes(:stock).order(signal_on: :desc, id: :desc).limit(limit).to_a
      closed = LabPaperTrade.where(status: "closed").pluck(:return_pct).map(&:to_f)
      wins = closed.select(&:positive?)
      losses = closed.reject(&:positive?)
      {
        summary: {
          total: LabPaperTrade.count, open: LabPaperTrade.where(status: "open").count, pending: LabPaperTrade.where(status: "pending").count,
          skipped: LabPaperTrade.where(status: "skipped").count, closed: closed.size,
          win_rate_pct: closed.empty? ? nil : (wins.size * 100.0 / closed.size).round(1),
          avg_return_pct: closed.empty? ? nil : (closed.sum / closed.size).round(2),
          profit_factor: losses.sum.zero? ? nil : (wins.sum / -losses.sum).round(2)
        },
        trades: trades.map do |t|
          {
            id: t.id, symbol: t.stock.symbol, strategy: t.strategy, signal_on: t.signal_on, levels: t.levels, status: t.status,
            entry_on: t.entry_on, entry_price: t.entry_price&.to_f, exit_on: t.exit_on, exit_price: t.exit_price&.to_f,
            exit_reason: t.exit_reason, return_pct: t.return_pct&.to_f, r_multiple: t.r_multiple&.to_f
          }
        end
      }
    end
  end
end
