module Scans
  # The 8 AM Telegram brief on trading days, from the latest completed session:
  #
  #   entry zone      stocks passing every board rule (StockSetupSnapshot#in_buy_zone),
  #                   new since the session before first, then by readiness
  #   human look      cross-checks worth a person's eye: a stock on the board, close to
  #                   it, on the watchlist or in a position that has bad or mixed news in
  #                   the last NEWS_DAYS days or a bonus / dividend / rights book close in
  #                   the next BOOK_CLOSE_DAYS days (the price adjusts that day); a watchlist
  #                   stock or position within NEAR_STOP_PCT of (or under) its stop; a
  #                   watchlist stock above its zone (chasing)
  #   close to zone   readiness MIN_READINESS+ stocks within NEAR_PCT below their zone
  #   scanner filter  the saved filter's stocks in or near their zone (Scans::MorningWatch)
  #
  # Rule checks, not advice.
  module MorningBrief
    ZONE_LIMIT = 10
    NEAR_LIMIT = 8
    NEAR_PCT = 3.0
    MIN_READINESS = 60
    NEAR_STOP_PCT = 2.0
    NEWS_DAYS = 5
    BOOK_CLOSE_DAYS = 7

    module_function

    def deliver(now: Time.current, client: Telegram::Client.new)
      today = Nepse::MarketHours.today(now)
      return {} unless Nepse::MarketHours.trading_wdays.include?(today.wday)

      users = User.where.not(telegram_chat_id: nil).where(telegram_morning_watch: true)
      return {} unless users.exists?

      session = StockSetupSnapshot.maximum(:traded_on) or return {}
      market = market_view(session, today)
      users.find_each.to_h do |user|
        next [ user.id, :duplicate ] unless MorningWatch.claim(user, today)

        brief = market.merge(personal(user, market, session, today))
        text = Telegram::Messages.morning_brief(brief, today: today)
        next [ user.id, :sent ] if Telegram::Notifier.deliver(user, text, client)

        User.where(id: user.id).update_all(telegram_morning_watch_sent_on: user.telegram_morning_watch_sent_on)
        [ user.id, :failed ]
      end
    end

    # What is the same for everyone.
    def market_view(session, today)
      snapshots = StockSetupSnapshot.includes(:stock).where(traded_on: session)
      joined = StockSetupSnapshot.joined_board(session).pluck(:stock_id).to_set
      board = snapshots.select(&:in_buy_zone).sort_by { [ joined.include?(_1.stock_id) ? 0 : 1, -_1.readiness_score ] }
      near = snapshots.reject(&:in_buy_zone).select do |s|
        s.readiness_score >= MIN_READINESS && s.entry_zone_low && s.close_price < s.entry_zone_low && gap(s.close_price, s.entry_zone_low) <= NEAR_PCT
      end.sort_by { -_1.readiness_score }
      {
        session: session, board: board, new_ids: joined, near: near,
        phase: MarketPhase.current(as_of: session), direction: Setups::MarketDirection.current&.slice(:label, :distribution_days),
        news: MarketEvent.where(impact: %w[negative mixed], published_on: (today - NEWS_DAYS)..today).where.not(stock_id: nil).recent.to_a.group_by(&:stock_id),
        book_closes: MarketEvent.where(kind: Events::Alerts::BOOK_CLOSE_KINDS, event_on: today..(today + BOOK_CLOSE_DAYS)).order(:event_on).to_a.group_by(&:stock_id)
      }
    end

    # The user's watchlist and positions, the checks for them, and their scanner filter.
    def personal(user, market, session, today)
      closes = StockDailyPrice.where(traded_on: session).pluck(:stock_id, :close_price).to_h { |id, c| [ id, c.to_f ] }
      watch = user.watchlist_items.tracked.includes(:stock).to_a
      positions = Position.where(user: user).open.includes(:stock).to_a
      roles = Hash.new { |h, k| h[k] = [] }
      market[:board].each { roles[_1.stock_id] << "Entry zone" }
      market[:near].each { roles[_1.stock_id] << "close to its zone" }
      watch.each { roles[_1.stock_id] << "watchlist" }
      positions.each { roles[_1.stock_id] << "your position" }
      stocks = Stock.where(id: roles.keys).index_by(&:id)

      looks = []
      roles.each do |stock_id, role|
        label = role.uniq.join(", ")
        # Newest first, one line per kind of news (the same notice is often repeated).
        Array(market[:news][stock_id]).uniq(&:reason).first(2).each do |event|
          looks << { symbol: stocks[stock_id]&.symbol, role: label, text: "#{event.impact == 'negative' ? 'Bad' : 'Mixed'} news #{event.published_on.strftime('%-d %b')}: #{event.reason}" }
        end
        Array(market[:book_closes][stock_id]).first(1).each do |event|
          looks << { symbol: stocks[stock_id]&.symbol, role: label, text: "#{book_close_text(event)} book close #{event.event_on.strftime('%a %-d %b')}: the price adjusts down that day." }
        end
      end
      watch.each do |item|
        close = closes[item.stock_id] or next
        stop = item.stop_loss_price&.to_f
        if stop&.positive? && close <= stop * (1 + NEAR_STOP_PCT / 100)
          looks << { symbol: item.stock.symbol, role: "watchlist",
                     text: close <= stop ? "closed at #{money(close)}, at or under its stop #{money(stop)}." : "closed at #{money(close)}, #{pct(close, stop)}% above its stop #{money(stop)}." }
        elsif item.entry_zone_high && close > item.entry_zone_high.to_f
          looks << { symbol: item.stock.symbol, role: "watchlist", text: "closed at #{money(close)}, #{pct(close, item.entry_zone_high.to_f)}% above your zone (chasing)." }
        end
      end
      positions.each do |position|
        close = closes[position.stock_id] or next
        stop = position.stop_price.to_f
        next unless stop.positive? && close <= stop * (1 + NEAR_STOP_PCT / 100)

        looks << { symbol: position.stock.symbol, role: "your position", text: "closed at #{money(close)}, #{close <= stop ? 'at or under' : "#{pct(close, stop)}% above"} its stop #{money(stop)}." }
      end

      signals = user.scanner_alert_signals & Crossovers::SIGNALS
      filter = signals.any? ? { signals: signals, volume: user.scanner_alert_volume, groups: MorningWatch.watch(Cache.scan, signals, volume: user.scanner_alert_volume) } : nil
      { looks: looks, filter: filter }
    end

    def book_close_text(event)
      data = event.data
      return "#{format('%g', data['right'].to_f)}% rights" if event.kind == "rights"

      parts = []
      parts << "#{format('%g', data['bonus'].to_f)}% bonus" if data["bonus"].to_f.positive?
      parts << "#{format('%g', data['cash'].to_f)}% cash (Rs #{format('%g', data['cash'].to_f)} a share at Rs 100 face value)" if data["cash"].to_f.positive?
      parts.join(" + ").presence || "Dividend"
    end

    def gap(close, zone_low) = (zone_low / close - 1) * 100
    def pct(a, b) = format("%.1f", (a / b - 1) * 100)
    def money(value) = format("%.2f", value)
  end
end
