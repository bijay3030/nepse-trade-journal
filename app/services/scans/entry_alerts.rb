module Scans
  # Live Telegram messages during the session: a stock that matches a user's saved
  # Indicator Scanner filter is now at a good entry.
  #
  #   on the radar     every saved signal holds; crosses began within WINDOW sessions
  #                    (the two states only need to hold), and with the volume option the
  #                    newest of them began on Crossovers::STRONG_VOLUME x average volume
  #   entry-ready      the live price is inside the row's entry zone (above its stop),
  #                    readiness is MIN_READINESS or more and no BLOCKING_GUARDS apply
  #
  # Checked after each live price update (Nepse::LivePriceSync.publish); each stock is
  # sent at most once per user and session. Rule checks, not advice.
  module EntryAlerts
    WINDOW = 10
    MIN_READINESS = 60
    BLOCKING_GUARDS = %w[thin_volume upper_circuit lower_circuit extended].freeze
    STATES = %w[ema_stack aroon_strong].freeze
    KIND = "scanner_entry"

    module_function

    def on_radar?(row, signals, volume: false)
      return false if signals.empty?

      ages = signals.map { row[:signals][_1] }
      return false if ages.any?(&:nil?)
      return false unless signals.zip(ages).all? { |key, age| STATES.include?(key) || age <= WINDOW }
      return true unless volume

      youngest = signals.min_by { row[:signals][_1] }
      (row.dig(:signal_volume, youngest) || 0) >= Crossovers::STRONG_VOLUME
    end

    def entry_ready?(row, price)
      levels = row[:levels]
      return false unless levels && price&.positive?
      return false if row[:readiness].to_i < MIN_READINESS || (Array(row[:guards]) & BLOCKING_GUARDS).any?

      price > levels[:stop] && price >= levels[:entry_low] && price <= levels[:entry_high]
    end

    # { user_id => :sent / :duplicate / :failed / :none }. Only while the market is open.
    def deliver(now: Time.current, scan: nil, client: Telegram::Client.new)
      return {} unless Nepse::MarketHours.open?(now)

      users = User.where.not(telegram_chat_id: nil).where(telegram_scanner_entry_alerts: true).where("jsonb_array_length(scanner_alert_signals) > 0")
      return {} unless users.exists?

      today = Nepse::MarketHours.today(now)
      scan ||= Cache.scan
      prices = live_prices(today)
      ready = scan[:rows].filter_map { |row| (price = prices[row[:symbol]]) && entry_ready?(row, price) ? [ row, price ] : nil }
      return users.ids.index_with { :none } if ready.empty?

      stocks = Stock.where(symbol: ready.map { _1.first[:symbol] }).index_by(&:symbol)
      users.find_each.to_h do |user|
        signals = user.scanner_alert_signals & Crossovers::SIGNALS
        matches = ready.select { |row, _| on_radar?(row, signals, volume: user.scanner_alert_volume) }
        next [ user.id, :none ] if matches.empty?

        fresh = matches.select { |row, _| (stock = stocks[row[:symbol]]) && TelegramDelivery.claim(user: user, stock: stock, kind: KIND, traded_on: today) }
        next [ user.id, :duplicate ] if fresh.empty?

        text = Telegram::Messages.scanner_entry(fresh, signals, volume: user.scanner_alert_volume, at: now)
        [ user.id, Telegram::Notifier.deliver(user, text, client) ? :sent : :failed ]
      end
    end

    # { symbol => last price } for stocks updated during today's session.
    def live_prices(today)
      Stock.active.where(security_type: "Equity").where(last_updated: today.in_time_zone(Nepse::MarketHours::TIME_ZONE).all_day)
           .where("last_price > 0").pluck(:symbol, :last_price).to_h { |symbol, price| [ symbol, price.to_f ] }
    end
  end
end
