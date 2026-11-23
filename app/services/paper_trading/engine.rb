module PaperTrading
  # Fully automated paper trading: no real order is ever placed.
  #
  # Buys (QUANTITY shares, one trade per stock at a time):
  #   watchlist alerts   a watchlist stock enters its zone or breaks out on volume
  #                      (WatchlistAlert entered_zone / breakout_confirmed): bought at the
  #                      live price when the alert fires, plus SLIPPAGE_PCT
  #   board              a stock new on Entry zone now after the nightly analysis: a
  #                      pending trade, bought at the next session's first live price
  # Levels: the watchlist item's stop and target, or the board setup's.
  #
  # Sells, all QUANTITY shares, once the shares have settled (T+2):
  #   live               the price at or under the stop (stop_hit) or at or over the target
  #                      (target_reached): sold at the live price less SLIPPAGE_PCT
  #   on the close       Positions::Monitor's close rules: a 50-day break on volume, a
  #                      climax run, the time stop; sold at the close
  # A stop hit before settlement is logged as a hold and sold once the shares settle if
  # the price is still under the stop.
  #
  # Costs: Nepse::Costs on both sides, and capital gains tax on a gain (10%, 7.5% after a
  # year). Every step is logged (PaperTradeEvent) and buys, holds and sells go to Telegram.
  module Engine
    QUANTITY = 10
    SLIPPAGE_PCT = 0.5
    BUY_KINDS = { "entered_zone" => "watchlist_entered_zone", "breakout_confirmed" => "watchlist_breakout" }.freeze

    module_function

    def users = User.where(paper_trading: true)

    # After each fresh live price sync: fill pending board trades, buy on new watchlist
    # alerts, sell on the stop or target.
    def on_live(now: Time.current, client: telegram)
      today = Nepse::MarketHours.today(now)
      fill_pending(today, now, client)
      buy_on_alerts(today, now, client)
      PaperTrade.open.includes(:stock, :user).find_each { check_live_exit(_1, today, now, client) }
    end

    # After the nightly analysis: a pending trade for each stock new on the board.
    def on_board(session, now: Time.current, client: telegram)
      joined = StockSetupSnapshot.joined_board(session).includes(:stock).to_a
      users.find_each do |user|
        joined.each do |snap|
          key = "board:#{session}:#{snap.stock_id}"
          next if PaperTrade.exists?(user: user, trigger_key: key)
          next if active?(user, snap.stock_id, key, snap.stock, now)

          setup = Telegram::Messages::SETUP_LABELS[snap.setup_type] || "setup"
          reason = "New on Entry zone now after the #{session.strftime('%-d %b')} close: #{setup}, readiness #{snap.readiness_score}, " \
                   "trend #{snap.trend_rules_passed}/7, zone #{money(snap.entry_zone_low)}–#{money(snap.entry_zone_high)}. Buying at the next session's first live price."
          create_trade(user, snap.stock, trigger: "board_new", key: key, signal_on: session, reason: reason,
                       stop: snap.invalidation_price, target: snap.target_price, now: now, client: client)
        end
      end
    end

    # After the end-of-day sync: stop/target on the close, then the close-time sell rules.
    def on_close(now: Time.current, client: telegram)
      today = Nepse::MarketHours.today(now)
      PaperTrade.open.includes(:stock, :user).find_each do |trade|
        next unless sellable?(trade, today)

        rule = live_rule(trade) || Positions::Monitor.close_rules(trade).first&.then { |kind, _, message| [ kind, message ] }
        sell(trade, rule[0], rule[1], trade.last_price, now, client, slippage: false) if rule
      end
    end

    def fill_pending(today, now, client)
      PaperTrade.where(status: "pending").includes(:stock, :user).find_each do |trade|
        next unless trade.signal_on < today && fresh?(trade.stock, today)

        buy(trade, trade.last_price, now, client)
      end
    end

    def buy_on_alerts(today, now, client)
      alerts = WatchlistAlert.where(kind: BUY_KINDS.keys, user_id: users.select(:id),
                                    created_at: today.in_time_zone(Nepse::MarketHours::TIME_ZONE).all_day).includes(:user, watchlist_item: :stock)
      alerts.find_each do |alert|
        item = alert.watchlist_item
        user = alert.user
        key = "watchlist_alert:#{alert.id}"
        next if PaperTrade.exists?(user: user, trigger_key: key) || skipped?(user, key)
        next if active?(user, item.stock_id, key, item.stock, now)

        stop = item.stop_loss_price.presence || item.invalidation_price
        word = alert.kind == "entered_zone" ? "entered its zone" : "broke out on volume"
        reason = "Watchlist alert: #{item.stock.symbol} #{word} at #{money(alert.price)} (zone #{money(item.entry_zone_low)}–#{money(item.entry_zone_high)}, " \
                 "stop #{money(stop)}#{item.target_price ? ", target #{money(item.target_price)}" : ''})."
        trade = create_trade(user, item.stock, trigger: BUY_KINDS[alert.kind], key: key, signal_on: today, reason: reason,
                             stop: stop, target: item.target_price, now: now, client: client)
        buy(trade, item.stock.last_price.to_f, now, client) if trade
      end
    end

    def check_live_exit(trade, today, now, client)
      rule = live_rule(trade) or return
      if sellable?(trade, today)
        sell(trade, rule[0], rule[1], trade.last_price, now, client)
      elsif rule[0] == "stop_hit" && !trade.events.where(action: "hold", at: today.in_time_zone(Nepse::MarketHours::TIME_ZONE).all_day).exists?
        log(trade, "hold", trade.last_price, "#{rule[1]} Not sold yet: bought #{trade.opened_on.strftime('%-d %b')}, the shares settle (T+2) " \
                                             "on #{trade.sellable_on.strftime('%-d %b')}. Selling then if still under the stop.", now, client)
      end
    end

    def live_rule(trade)
      price = trade.last_price
      return unless price.positive?

      if price <= trade.stop_price.to_f
        [ "stop_hit", "#{trade.stock.symbol} at #{money(price)}, at or under the #{money(trade.stop_price)} stop." ]
      elsif trade.target_price && price >= trade.target_price.to_f
        [ "target_reached", "#{trade.stock.symbol} at #{money(price)} reached the #{money(trade.target_price)} target." ]
      end
    end

    def buy(trade, price, now, client)
      fill = (price * (1 + SLIPPAGE_PCT / 100)).round(2)
      trade.update!(status: "open", entry_price: fill, entry_at: now, buy_costs: Nepse::Costs.buy_costs(fill * trade.quantity))
      log(trade, "buy", fill, "Bought #{trade.quantity} at #{money(fill)} (live #{money(price)} + #{SLIPPAGE_PCT}% slippage), " \
                              "costs Rs #{money(trade.buy_costs)}. #{trade.buy_reason}", now, client)
    end

    def sell(trade, rule, message, price, now, client, slippage: true)
      fill = (slippage ? price * (1 - SLIPPAGE_PCT / 100) : price).round(2)
      proceeds = Nepse::Costs.net_proceeds(fill, trade.quantity)
      gain = proceeds - trade.cost_basis
      held_days = (Nepse::MarketHours.today(now) - trade.opened_on).to_i
      rate = held_days > Positions::Ledger::LONG_TERM_DAYS ? Positions::Ledger::LONG_TERM_RATE : Positions::Ledger::SHORT_TERM_RATE
      cgt = gain.positive? ? (gain * rate).round(2) : 0
      net = (gain - cgt).round(2)
      trade.update!(status: "closed", exit_price: fill, exit_at: now, exit_rule: rule, sell_reason: message,
                    sell_costs: (fill * trade.quantity - proceeds).round(2), cgt: cgt, net_pnl: net, return_pct: (net / trade.cost_basis * 100).round(2))
      log(trade, "sell", fill, "Sold #{trade.quantity} at #{money(fill)}#{slippage ? " (live less #{SLIPPAGE_PCT}% slippage)" : ' (close)'}: " \
                               "#{message} Net #{net.negative? ? '-' : '+'}Rs #{money(net.abs)} (#{format('%+.2f', trade.return_pct)}%) after costs" \
                               "#{cgt.positive? ? " and Rs #{money(cgt)} tax" : ''}, held #{held_days} days.", now, client)
    end

    def create_trade(user, stock, trigger:, key:, signal_on:, reason:, stop:, target:, now:, client:)
      return log_skip(user, stock, key, "#{stock.symbol} signal skipped: no stop price to trade it with.", now) unless stop.to_f.positive?

      trade = PaperTrade.create!(user: user, stock: stock, trigger: trigger, trigger_key: key, signal_on: signal_on, buy_reason: reason, quantity: QUANTITY,
                                 stop_price: stop, initial_stop_price: stop, target_price: target, status: "pending")
      log(trade, "signal", stock.last_price, reason, now, client)
      trade
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    # Already holding (or waiting to buy) this stock: log the skipped signal once.
    def active?(user, stock_id, key, stock, now)
      existing = PaperTrade.active.find_by(user: user, stock_id: stock_id) or return false
      log_skip(user, stock, key, "#{stock.symbol} signal skipped: already #{existing.status == 'open' ? 'holding' : 'waiting to buy'} it " \
                                 "(since #{existing.signal_on.strftime('%-d %b')}).", now)
      true
    end

    def skipped?(user, key) = PaperTradeEvent.where(user: user, action: "skip").where("data->>'trigger_key' = ?", key).exists?

    def log_skip(user, stock, key, reason, now)
      PaperTradeEvent.create!(user: user, stock: stock, action: "skip", price: stock.last_price, reason: reason, at: now, data: { "trigger_key" => key }) unless skipped?(user, key)
      nil
    end

    def log(trade, action, price, reason, now, client)
      event = PaperTradeEvent.create!(user: trade.user, paper_trade: trade, stock: trade.stock, action: action, price: price, reason: reason, at: now)
      notify(trade.user, event, client) if %w[buy sell hold].include?(action)
      event
    end

    def notify(user, event, client)
      return unless client && user.telegram_chat_id.present?

      Telegram::Notifier.deliver(user, Telegram::Messages.paper_trade(event), client)
    end

    def sellable?(trade, today) = trade.sellable_on.present? && today >= trade.sellable_on
    def fresh?(stock, today) = stock.last_price.to_f.positive? && stock.last_updated&.in_time_zone(Nepse::MarketHours::TIME_ZONE)&.to_date == today
    def telegram = (Telegram::Client.new if Telegram::Client.configured?)
    def money(value) = value.nil? ? "—" : format("%.2f", value.to_f)
  end
end
