module Scans
  # Before the open (9 AM Nepal time on trading days): one Telegram message per user
  # with the stocks on their saved scanner filter's radar (Scans::EntryAlerts.on_radar?)
  # whose last close is inside their entry zone, or within NEAR_PCT below it. Levels are
  # the scanner's (the board setup's, else the crossover rule's). Stocks above the zone
  # (chasing) or at / under their stop, and thinly traded ones, are left out.
  module MorningWatch
    NEAR_PCT = 3.0
    # Per group, so the message stays under Telegram's 4,096 characters.
    LIMIT = 10

    module_function

    # { in_zone: [row, ...], near: [[row, % below the zone], ...] }, highest readiness first.
    def watch(scan, signals, volume: false)
      rows = scan[:rows].select do |row|
        row[:levels] && !Array(row[:guards]).include?("thin_volume") && EntryAlerts.on_radar?(row, signals, volume: volume)
      end
      rows = rows.sort_by { [ -row_readiness(_1), _1[:symbol] ] }
      in_zone, near = [], []
      rows.each do |row|
        levels, close = row[:levels], row[:close].to_f
        next if close <= levels[:stop]

        if close.between?(levels[:entry_low], levels[:entry_high])
          in_zone << row
        elsif close < levels[:entry_low] && (gap = (levels[:entry_low] / close - 1) * 100) <= NEAR_PCT
          near << [ row, gap.round(1) ]
        end
      end
      { in_zone: in_zone, near: near, radar: rows.size }
    end

    # { user_id => :sent / :duplicate / :failed }. Only on trading days.
    def deliver(now: Time.current, scan: nil, client: Telegram::Client.new)
      today = Nepse::MarketHours.today(now)
      return {} unless Nepse::MarketHours.trading_wdays.include?(today.wday)

      users = User.where.not(telegram_chat_id: nil).where(telegram_morning_watch: true).where("jsonb_array_length(scanner_alert_signals) > 0")
      return {} unless users.exists?

      scan ||= Cache.scan
      phase = MarketPhase.current(as_of: scan[:as_of])
      users.find_each.to_h do |user|
        next [ user.id, :duplicate ] unless claim(user, today)

        signals = user.scanner_alert_signals & Crossovers::SIGNALS
        groups = watch(scan, signals, volume: user.scanner_alert_volume)
        text = Telegram::Messages.morning_watch(groups, signals, volume: user.scanner_alert_volume, as_of: scan[:as_of], today: today,
                                                phase: phase, live_alerts: user.telegram_scanner_entry_alerts)
        [ user.id, Telegram::Notifier.deliver(user, text, client) ? :sent : :failed ]
      end
    end

    # Marks today's message as sent; false when it already was (e.g. a second run).
    def claim(user, today)
      User.where(id: user.id).where("telegram_morning_watch_sent_on IS NULL OR telegram_morning_watch_sent_on < ?", today)
          .update_all(telegram_morning_watch_sent_on: today) == 1
    end

    def row_readiness(row) = row[:readiness].to_i
  end
end
