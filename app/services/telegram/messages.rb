module Telegram
  # Message text (Telegram HTML). Neutral wording: rule checks, never "buy" or "sell".
  module Messages
    SETUP_LABELS = {
      "vcp" => "VCP breakout", "pullback" => "Pullback to support",
      "ma_pullback" => "Pullback to a rising average", "base_breakout" => "Flat-base breakout",
      "three_weeks_tight" => "3-weeks-tight", "undercut_rally" => "Undercut and rally"
    }.freeze
    GUARD_LABELS = { "thin_volume" => "thin volume", "upper_circuit" => "at the upper circuit", "lower_circuit" => "at the lower circuit", "extended" => "extended above the 50-day", "late_stage_base" => "a late-stage (3rd+) base" }.freeze
    ALERT_TITLES = {
      "entered_zone" => "is in its entry zone",
      "breakout_confirmed" => "broke out into its entry zone on volume",
      "breakout_low_volume" => "broke out into its entry zone, volume not confirmed yet",
      "approaching_zone" => "is approaching its entry zone",
      "pullback_21ema" => "pulled back to its rising 21-day average"
    }.freeze
    BOOK_CLOSE_DAYS = 10
    BOARD_LIMIT = 10
    FOOTER = "<i>Rule checks, not a recommendation.</i>".freeze
    # Telegram's limit is 4,096 characters; leave room for the HTML entities it counts.
    MAX_LENGTH = 3_900

    module_function

    # A tracked stock moved into its zone during the session.
    def watchlist_alert(alert)
      item = alert.watchlist_item
      stock = item.stock
      price = alert.price.to_f.positive? ? alert.price.to_f : stock.last_price.to_f
      snapshot = latest_snapshot(stock)
      lines = [
        "#{WatchlistAlert::EARLY_KINDS.include?(alert.kind) ? '🟡' : '🟢'} <b>#{h(stock.symbol)}</b> #{ALERT_TITLES.fetch(alert.kind)}",
        "Price #{money(price)}#{alert.relative_volume ? " · volume #{alert.relative_volume.to_f}x average" : ''}",
        (alert.message if WatchlistAlert::EARLY_KINDS.include?(alert.kind)),
        "Zone #{money(item.entry_zone_low)}–#{money(item.entry_zone_high)} · stop #{money(item.stop_loss_price.presence || item.invalidation_price)}" \
        "#{item.target_price ? " · target #{money(item.target_price)}" : ''}#{item.risk_reward ? " · R:R #{item.risk_reward}" : ''}",
        context_line(SETUP_LABELS[item.setup_type], snapshot),
        *warnings(stock, snapshot&.guards),
        FOOTER
      ]
      lines.compact.join("\n")
    end

    POSITION_TITLES = {
      "stop_hit" => "🔴 hit your stop", "target_reached" => "🎯 reached your target", "one_r" => "🟢 is up 1R",
      "profit_zone" => "🟢 is in the +20% profit zone", "fifty_day_break" => "🟠 broke its 50-day average",
      "climax_run" => "🟠 made a climax-style run", "time_stop" => "⏳ hasn't moved (time stop)"
    }.freeze

    # A sell rule triggered for an open position.
    def position_alert(alert)
      position = alert.position
      [
        "<b>#{h(position.stock.symbol)}</b> #{POSITION_TITLES.fetch(alert.kind)}",
        h(alert.message),
        "#{position.quantity} shares · average #{money(position.average_price)} · stop #{money(position.stop_price)}" \
        "#{position.target_price ? " · target #{money(position.target_price)}" : ''}",
        FOOTER
      ].join("\n")
    end

    # Stocks that newly met every entry-zone rule on the nightly snapshot.
    def entry_zone_board(snapshots, traded_on)
      shown = snapshots.first(BOARD_LIMIT)
      blocks = shown.map do |snapshot|
        stock = snapshot.stock
        [
          "<b>#{h(stock.symbol)}</b> · #{h(stock.name)}",
          "Close #{money(snapshot.close_price)} · zone #{money(snapshot.entry_zone_low)}–#{money(snapshot.entry_zone_high)} · " \
          "stop #{money(snapshot.invalidation_price)}#{snapshot.target_price ? " · target #{money(snapshot.target_price)}" : ''}" \
          "#{(rr = risk_reward(snapshot)) ? " · R:R #{rr}" : ''}",
          context_line(SETUP_LABELS[snapshot.setup_type], snapshot),
          *warnings(stock, nil)
        ].compact.join("\n")
      end
      more = snapshots.size > shown.size ? "…and #{snapshots.size - shown.size} more in the app." : nil
      header = "📋 <b>New on Entry zone now</b> (#{traded_on.strftime('%b %-d')} close): #{snapshots.size} #{snapshots.size == 1 ? 'stock' : 'stocks'}"
      [ header, *blocks, more, FOOTER ].compact.join("\n\n")
    end

    SCANNER_LABELS = {
      "ema_9_21" => "EMA 9/21 cross", "ema_stack" => "EMA 9 > 21 > 50",
      "hma_up" => "HMA 55 turned up", "alma_cross" => "close above ALMA 21", "aroon_cross" => "Aroon Up over Down", "aroon_strong" => "Aroon Up ≥ 70"
    }.freeze

    # Stocks that newly match a user's saved Indicator Scanner filter (Scans::Alerts).
    def scanner_alert(rows, signals, scan, volume: false)
      shown = rows.first(Scans::Alerts::LIMIT)
      filter = signals.map { SCANNER_LABELS.fetch(_1) }.join(" + ") + (volume ? " on #{Scans::Crossovers::STRONG_VOLUME}x volume" : "")
      lines = shown.map do |row|
        ages = signals.map { |key| "#{SCANNER_LABELS[key]} #{row[:signals][key].zero? ? 'today' : "#{row[:signals][key]}d"}" }.join(", ")
        youngest = signals.min_by { row[:signals][_1] }
        ages += " · volume #{row.dig(:signal_volume, youngest)}x" if row.dig(:signal_volume, youngest)
        change = row[:change_pct] ? " (#{format('%+.2f', row[:change_pct])}%)" : ""
        board = row[:in_buy_zone] ? " · also on Entry zone now" : ""
        "• <b>#{h(row[:symbol])}</b> #{money(row[:close])}#{change} · #{h(ages)} · readiness #{row[:readiness] || '—'}#{board}"
      end
      more = rows.size > shown.size ? "…and #{rows.size - shown.size} more on the Indicator Scanner." : nil
      [
        "📈 <b>Indicator scanner</b> (#{scan[:as_of].strftime('%b %-d')} close): #{rows.size} #{rows.size == 1 ? 'stock newly matches' : 'stocks newly match'} #{h(filter)}",
        lines.join("\n"), more, scanner_track_record(signals, scan[:backtest]), FOOTER
      ].compact.join("\n\n")
    end

    # Live: stocks matching the saved scanner filter that trade inside their entry zone
    # (Scans::EntryAlerts). entries: [[row, live price], ...].
    def scanner_entry(entries, signals, volume: false, at: Time.current)
      filter = signals.map { SCANNER_LABELS.fetch(_1) }.join(" + ") + (volume ? " on #{Scans::Crossovers::STRONG_VOLUME}x volume" : "")
      blocks = entries.first(Scans::Alerts::LIMIT).map do |row, price|
        levels = row[:levels]
        source = levels[:source] == "board_setup" ? "#{SETUP_LABELS.fetch(levels[:setup_type].to_s, 'board setup')} levels" : "crossover-rule levels"
        ages = signals.map do |key|
          ratio = row.dig(:signal_volume, key)
          "#{SCANNER_LABELS[key]} #{row[:signals][key].zero? ? 'today' : "#{row[:signals][key]}d ago"}#{ratio ? " (#{ratio}x vol)" : ''}"
        end
        reward = levels[:target] && price > levels[:stop] ? " · R:R #{((levels[:target] - price) / (price - levels[:stop])).round(2)}" : ""
        [
          "<b>#{h(row[:symbol])}</b> · #{h(row[:name])}",
          "Live #{money(price)} · in entry zone #{money(levels[:entry_low])}–#{money(levels[:entry_high])} · stop #{money(levels[:stop])}" \
          "#{levels[:target] ? " · target #{money(levels[:target])}" : ''}#{reward}",
          "Readiness #{row[:readiness]}/100 · #{source}#{row[:in_buy_zone] ? ' · also on Entry zone now' : ''}",
          h(ages.join(", ")),
          *Array(row[:guards]).map { "⚠️ #{GUARD_LABELS.fetch(_1, _1)}" }
        ].join("\n")
      end
      more = entries.size > Scans::Alerts::LIMIT ? "…and #{entries.size - Scans::Alerts::LIMIT} more on the Indicator Scanner." : nil
      header = "🎯 <b>Entry-ready on your scanner filter</b> (#{at.in_time_zone('Asia/Kathmandu').strftime('%-I:%M %p')}): #{h(filter)}"
      [ header, *blocks, more, FOOTER ].compact.join("\n\n")
    end

    PHASE_LABELS = { "uptrend" => "uptrend", "sideways" => "sideways", "downtrend" => "downtrend" }.freeze

    # 9 AM: the saved filter's stocks in or near their entry zone (Scans::MorningWatch).
    # Shows up to MorningWatch::LIMIT stocks per group, fewer if the text would pass MAX_LENGTH.
    def morning_watch(groups, signals, volume:, as_of:, today:, phase: nil, live_alerts: false, limit: Scans::MorningWatch::LIMIT)
      filter = signals.map { SCANNER_LABELS.fetch(_1) }.join(" + ") + (volume ? " on #{Scans::Crossovers::STRONG_VOLUME}x volume" : "")
      market = phase&.dig(:phase) ? " · NEPSE #{PHASE_LABELS[phase[:phase]]}#{phase[:sessions] ? " for #{phase[:sessions]} sessions" : ''}" : ""
      header = "☀️ <b>Morning watch</b> · #{today.strftime('%a %b %-d')} (levels from the #{as_of&.strftime('%b %-d')} close)\n" \
               "Filter: #{h(filter)}#{market}"
      describe = lambda do |row, gap = nil|
        levels = row[:levels]
        ages = signals.map do |key|
          ratio = row.dig(:signal_volume, key)
          "#{SCANNER_LABELS[key]} #{row[:signals][key].zero? ? 'today' : "#{row[:signals][key]}d"}#{ratio ? " (#{ratio}x vol)" : ''}"
        end
        where = gap ? "#{gap}% below zone" : "zone"
        reward = levels[:target] && row[:close] > levels[:stop] ? " · R:R #{((levels[:target] - row[:close]) / (row[:close] - levels[:stop])).round(2)}" : ""
        "• <b>#{h(row[:symbol])}</b> #{money(row[:close])} · #{where} #{money(levels[:entry_low])}–#{money(levels[:entry_high])} · " \
          "stop #{money(levels[:stop])}#{levels[:target] ? " · target #{money(levels[:target])}" : ''}#{reward}\n" \
          "   readiness #{row[:readiness] || '—'}#{row[:in_buy_zone] ? ' · on Entry zone now' : ''} · #{h(ages.join(', '))}" \
          "#{Array(row[:guards]).map { " · ⚠️ #{GUARD_LABELS.fetch(_1, _1)}" }.join}"
      end
      sections = []
      if groups[:in_zone].any?
        sections << "<b>In entry zone</b> (#{groups[:in_zone].size})\n" + groups[:in_zone].first(limit).map { describe.(_1) }.join("\n") +
                    more_line(groups[:in_zone].size - limit)
      end
      if groups[:near].any?
        sections << "<b>Close to the zone</b> (≤#{Scans::MorningWatch::NEAR_PCT.to_i}% below, #{groups[:near].size})\n" +
                    groups[:near].first(limit).map { |row, gap| describe.(row, gap) }.join("\n") +
                    more_line(groups[:near].size - limit)
      end
      if sections.empty?
        sections << "No stock on your radar is in or within #{Scans::MorningWatch::NEAR_PCT.to_i}% of its entry zone " \
                    "(#{groups[:radar]} #{groups[:radar] == 1 ? 'stock matches' : 'stocks match'} the filter)."
      end
      closing = live_alerts && sections.any? ? "Market opens at 11:00. You'll get a 🎯 message if one trades inside its zone." : "Market opens at 11:00."
      text = [ header, *sections, closing, FOOTER ].join("\n\n")
      return text if text.size <= MAX_LENGTH || limit <= 1

      morning_watch(groups, signals, volume: volume, as_of: as_of, today: today, phase: phase, live_alerts: live_alerts, limit: limit - 1)
    end

    # After the close: the session in numbers (MarketIndex::DailySummary).
    def market_summary(s)
      points = s[:change_points] ? " (#{format('%+.2f', s[:change_points])})" : ""
      turnover = "Turnover NPR #{billions(s[:turnover])} bn"
      turnover += " (#{billions(s[:previous_turnover])} bn the session before)" if s[:previous_turnover].to_f.positive?
      ratio = s[:declining].positive? ? (s[:advancing].to_f / s[:declining]).round(2) : nil
      phase = s.dig(:phase, :phase) ? "NEPSE #{PHASE_LABELS[s[:phase][:phase]]}#{s[:phase][:sessions] ? " for #{s[:phase][:sessions]} sessions" : ''} (20-day vs 50-day average)" : nil
      direction = s[:direction] ? "Market Direction: #{s[:direction][:label]} · #{s[:direction][:distribution_days]} distribution #{s[:direction][:distribution_days] == 1 ? 'day' : 'days'}" : nil
      move = ->(list) { list.map { "#{h(_1[:symbol])} #{format('%+.2f', _1[:change_pct])}%" }.join(", ").presence || "—" }
      sectors = s[:sectors].map { "#{format('%+.2f', _1[:sector_performance_pct])}% #{h(_1[:sector])} (#{_1[:constituents_count]})" }
      [
        "📊 <b>NEPSE #{s[:traded_on].strftime('%a %b %-d')}</b>: #{format('%.2f', s[:index])} #{arrow(s[:change_pct])} #{format('%+.2f', s[:change_pct])}%#{points}\n#{turnover}",
        "<b>Breadth</b>: #{s[:advancing]} up · #{s[:declining]} down · #{s[:unchanged]} unchanged#{ratio ? " (A/D #{ratio})" : ''}\n" \
          "Above 50-day average #{s[:above50].round}% · above 200-day #{s[:above200].round}%",
        [ phase, direction, "Entry zone now: #{s[:board][:total]} #{s[:board][:total] == 1 ? 'stock' : 'stocks'} (#{s[:board][:joined]} new)" ].compact.join("\n"),
        "<b>Top gainers</b> (liquid): #{move.(s[:gainers])}\n<b>Top losers</b> (liquid): #{move.(s[:losers])}\n" \
          "<b>Most traded</b>: #{s[:most_traded].map { "#{h(_1[:symbol])} #{(_1[:turnover] / 1e6).round}M" }.join(', ').presence || '—'}",
        "<b>Sectors</b>\n#{sectors.join("\n")}",
        "<i>Stored data after the nightly analysis. Not advice.</i>"
      ].join("\n\n")
    end

    def arrow(change) = change.to_f.positive? ? "▲" : change.to_f.negative? ? "▼" : "■"
    def billions(value) = format("%.2f", value.to_f / 1e9)

    def more_line(hidden) = hidden.positive? ? "\n…and #{hidden} more on the Indicator Scanner." : ""

    # "Track record (20 sessions after each signal began): ... vs ... for all stock-days."
    def scanner_track_record(signals, backtest)
      stats = backtest&.dig(:signals) or return
      base = stats.dig("all", 20, :avg_return_pct)
      parts = signals.filter_map do |key|
        value = stats.dig(key, 20, :avg_return_pct)
        "#{SCANNER_LABELS[key]} #{format('%+.1f', value)}%" if value
      end
      return if parts.empty? || base.nil?

      "<i>Track record on NEPSE since 2020 (20 sessions after each signal began): #{h(parts.join(', '))} vs #{format('%+.1f', base)}% for all stock-days.</i>"
    end

    def test_message(user)
      "✅ Test message from NEPSE Trade Journal for #{h(user.email)}. Entry-zone messages will arrive here.\n#{FOOTER}"
    end

    def context_line(setup_label, snapshot)
      parts = [ setup_label ]
      if snapshot
        parts << "readiness #{snapshot.readiness_score}/100" << "trend #{snapshot.trend_rules_passed}/7"
        parts << "RS #{snapshot.rs_rating}" if snapshot.rs_rating
      end
      parts.compact.join(" · ").presence
    end

    def warnings(stock, guards)
      lines = Array(guards).map { "⚠️ #{GUARD_LABELS.fetch(_1, _1)}" }
      event = CorporateActions::Upcoming.for_stock(stock)
      if event && event[:days_until] <= BOOK_CLOSE_DAYS && event[:bonus_percent].to_f.positive?
        lines << "⚠️ #{format('%g', event[:bonus_percent])}% bonus book close #{event[:book_close_on].strftime('%b %-d')}: price and levels will be adjusted"
      end
      lines
    end

    def latest_snapshot(stock) = stock.setup_snapshots.order(traded_on: :desc).first

    def risk_reward(snapshot)
      entry, stop, target = snapshot.close_price.to_f, snapshot.invalidation_price.to_f, snapshot.target_price.to_f
      return unless stop.positive? && target.positive? && entry > stop

      ((target - entry) / (entry - stop)).round(2)
    end

    def money(value) = value.nil? ? "—" : format("%.2f", value.to_f)
    def h(text) = ERB::Util.html_escape(text.to_s)
  end
end
