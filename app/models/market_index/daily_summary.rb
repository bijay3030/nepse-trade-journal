# One session's market summary for the after-close Telegram message: NEPSE's close,
# turnover against the previous session, breadth (including the share of stocks above
# their 50- and 200-day averages), the liquid top movers, the most traded stocks, every
# sector's average move, NEPSE's phase (Scans::MarketPhase), Market Direction and how
# the Entry zone board changed. Built from stored data after the nightly snapshot.
module MarketIndex::DailySummary
  MOVERS = 5

  module_function

  def call(traded_on)
    overview = MarketIndex::Overview.new.call(as_of: traded_on)
    return unless overview[:traded_on] == traded_on.iso8601

    nepse = MarketIndex.find_by(symbol: "NEPSE")
    previous = nepse&.histories&.where(traded_on: ...traded_on)&.order(traded_on: :desc)&.first
    prices = StockDailyPrice.joins(:stock).merge(Stock.active.where(security_type: "Equity")).where(traded_on: traded_on).includes(:stock).to_a
    thin = StockSetupSnapshot.where(traded_on: traded_on).where("guards @> ?", [ "thin_volume" ].to_json).pluck(:stock_id).to_set
    liquid = prices.reject { thin.include?(_1.stock_id) }
    direction = Setups::MarketDirection.call(as_of: traded_on)

    {
      traded_on: traded_on,
      index: overview[:nepse_index], change_pct: overview[:index_change_pct],
      change_points: previous ? (overview[:nepse_index] - previous.index_value.to_f).round(2) : nil,
      turnover: overview[:market_turnover], previous_turnover: previous&.turnover&.to_f,
      advancing: overview[:advancing_stocks], declining: overview[:declining_stocks], unchanged: overview[:unchanged_stocks],
      above50: overview[:pct_stocks_above_sma50], above200: overview[:pct_stocks_above_sma200],
      gainers: movers(liquid.sort_by { -_1.change_percent.to_f }.select { _1.change_percent.to_f.positive? }),
      losers: movers(liquid.sort_by { _1.change_percent.to_f }.select { _1.change_percent.to_f.negative? }),
      most_traded: prices.sort_by { -_1.turnover.to_f }.first(MOVERS).map { { symbol: _1.stock.symbol, turnover: _1.turnover.to_f, change_pct: _1.change_percent.to_f } },
      sectors: overview[:sectors].map { _1.slice(:sector, :sector_performance_pct, :constituents_count) }.sort_by { -_1[:sector_performance_pct] },
      phase: Scans::MarketPhase.current(as_of: traded_on),
      direction: direction && { label: direction[:label], distribution_days: direction[:distribution_days] },
      board: { total: StockSetupSnapshot.where(traded_on: traded_on, in_buy_zone: true).count, joined: StockSetupSnapshot.joined_board(traded_on).count }
    }
  end

  def movers(prices) = prices.first(MOVERS).map { { symbol: _1.stock.symbol, close: _1.close_price.to_f, change_pct: _1.change_percent.to_f } }

  # { user_id => :sent / :duplicate / :failed }. Only for today's session.
  def deliver(traded_on: StockSetupSnapshot.maximum(:traded_on), now: Time.current, client: Telegram::Client.new)
    return {} unless traded_on == Nepse::MarketHours.today(now)

    users = User.where.not(telegram_chat_id: nil).where(telegram_market_summary: true)
    return {} unless users.exists?

    summary = call(traded_on) or return {}
    text = Telegram::Messages.market_summary(summary)
    users.find_each.to_h do |user|
      claimed = User.where(id: user.id).where("telegram_market_summary_sent_on IS NULL OR telegram_market_summary_sent_on < ?", traded_on)
                    .update_all(telegram_market_summary_sent_on: traded_on) == 1
      next [ user.id, :duplicate ] unless claimed
      next [ user.id, :sent ] if Telegram::Notifier.deliver(user, text, client)

      # Not sent: free the session so a later run can try again.
      User.where(id: user.id).update_all(telegram_market_summary_sent_on: user.telegram_market_summary_sent_on)
      [ user.id, :failed ]
    end
  end
end
