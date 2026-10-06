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
