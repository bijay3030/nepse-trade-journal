module Watchlist
  # Compares each tracked item's latest price with its levels after a price sync.
  # Alerts fire only when the price moves into a new state, so a stock sitting in
  # its zone does not alert again every five minutes.
  class AlertEvaluator
    BREAKOUT_VOLUME_MULTIPLE = 1.5
    AVERAGE_VOLUME_SESSIONS = 50
    # Heads-up: within APPROACH_PCT below the zone; it can alert again once the price
    # has been APPROACH_RESET_PCT away.
    APPROACH_PCT = 3.0
    APPROACH_RESET_PCT = 5.0
    # Pullback to a rising 21-day EMA: within EMA_NEAR_PCT of it, after being at least
    # EMA_PULLED_FROM_PCT above it in the last EMA_LOOKBACK sessions, on projected volume
    # under the 50-day average.
    EMA_PERIOD = 21
    EMA_NEAR_PCT = 1.5
    EMA_PULLED_FROM_PCT = 3.0
    EMA_LOOKBACK = 10
    EMA_RISING_SESSIONS = 5
    STATUS_FOR_STATE = {
      "below_zone" => "watching", "in_zone" => "in_zone",
      "extended" => "extended", "invalidated" => "invalidated"
    }.freeze

    def self.call(items = WatchlistItem.awaiting_entry)
      new(items).call
    end

    def initialize(items)
      @items = items
    end

    def call
      alerts = []
      evaluated = 0

      @items.includes(:stock).find_each do |item|
        price = item.stock.last_price.to_f
        next unless price.positive?

        evaluated += 1
        alert = evaluate(item, price)
        alerts << alert if alert
      end

      { evaluated: evaluated, alerts: alerts.size }
    end

    # Also used when an item is created, to record its starting state without alerting.
    def self.initial_state!(item)
      state = item.price_state_for(item.stock.last_price)
      status = WatchlistItem::STICKY_STATUSES.include?(item.status) ? item.status : STATUS_FOR_STATE.fetch(state)
      item.update!(price_state: state, status: status, last_evaluated_at: Time.current)
    end

    private

    def evaluate(item, price)
      previous = item.price_state
      current = item.price_state_for(price)
      updates = { price_state: current, last_evaluated_at: Time.current }
      # Remembered so the end-of-day check can tell a failed breakout from a quiet day.
      updates[:touched_zone_on] = Nepse::MarketHours.today if %w[in_zone extended].include?(current)
      updates[:status] = STATUS_FOR_STATE.fetch(current) unless WatchlistItem::STICKY_STATUSES.include?(item.status)

      updates.merge!(approach_updates(item, current, price))

      alert = nil
      WatchlistItem.transaction do
        alert = build_alert(item, previous, current, price) if previous && previous != current
        alert ||= early_alert(item, current, price)
        item.update!(updates.merge(alert&.kind == "approaching_zone" ? { approach_alerted: true } : {}))
        alert&.save!
      end
      alert
    end

    def approach_updates(item, current, price)
      distance = (item.entry_zone_low.to_f - price) / price * 100
      far = current == "invalidated" || (current == "below_zone" && distance > APPROACH_RESET_PCT)
      far && item.approach_alerted ? { approach_alerted: false } : {}
    end

    # Heads-up alerts while nothing else changed: approaching the zone, or a pullback
    # to the rising 21-day average.
    def early_alert(item, current, price)
      approaching_alert(item, current, price) || ema_pullback_alert(item, current, price)
    end

    def approaching_alert(item, current, price)
      return unless current == "below_zone" && !item.approach_alerted

      distance = (item.entry_zone_low.to_f - price) / price * 100
      return unless distance.positive? && distance <= APPROACH_PCT

      level = Setups::Types.breakout?(item.setup_type) && item.pivot_price ? "its #{fmt(item.pivot_price)} pivot" : "its entry zone (#{zone(item)})"
      item.alerts.build(user: item.user, kind: "approaching_zone", price: price,
                        message: "#{item.stock.symbol} is #{format('%.1f', distance)}% below #{level} at #{fmt(price)}.")
    end

    def ema_pullback_alert(item, current, price)
      return if current == "invalidated"
      return if item.alerts.where(kind: "pullback_21ema").where(created_at: Nepse::MarketHours.today.in_time_zone(Nepse::MarketHours::TIME_ZONE).all_day).exists?

      ema = ema_context(item.stock) or return
      return unless ema[:rising] && ema[:pulled_from] && (price / ema[:value] - 1).abs * 100 <= EMA_NEAR_PCT

      ratio = relative_volume(item.stock)
      return unless ratio && ratio < 1.0

      item.alerts.build(user: item.user, kind: "pullback_21ema", price: price, relative_volume: ratio,
                        message: "#{item.stock.symbol} pulled back to its rising 21-day average (#{fmt(ema[:value])}) at #{fmt(price)} on lighter volume (projected #{ratio}x).")
    end

    # The 21-day EMA of closes before today, whether it's rising, and whether the price
    # was well above it recently. Cached per stock and session.
    def ema_context(stock)
      today = Nepse::MarketHours.today
      Rails.cache.fetch("watchlist:ema21:#{stock.id}:#{today}", expires_in: 12.hours) do
        closes = stock.daily_prices.where("traded_on < ?", today).order(traded_on: :desc).limit(80).pluck(:close_price).reverse.map(&:to_f)
        series = Setups::MovingAverage.ema_series(closes, EMA_PERIOD)
        next if series.size <= [ EMA_RISING_SESSIONS, EMA_LOOKBACK ].max

        recent_closes = closes.last(EMA_LOOKBACK)
        recent_emas = series.last(EMA_LOOKBACK)
        {
          value: series.last, rising: series.last > series[-1 - EMA_RISING_SESSIONS],
          pulled_from: recent_closes.zip(recent_emas).any? { |close, ema| close >= ema * (1 + EMA_PULLED_FROM_PCT / 100) }
        }
      end
    end

    def build_alert(item, previous, current, price)
      symbol = item.stock.symbol
      kind, message, relative_volume =
        case current
        when "invalidated"
          [ "invalidated", "#{symbol} fell to #{fmt(price)}, at or below the #{fmt(item.invalidation_price)} invalidation level. The setup has failed.", nil ]
        when "in_zone"
          if Setups::Types.breakout?(item.setup_type) && previous == "below_zone"
            breakout_alert(item, price)
          else
            [ "entered_zone", "#{symbol} is in its entry zone at #{fmt(price)} (#{zone(item)}).", nil ]
          end
        when "extended"
          [ "extended", "#{symbol} is at #{fmt(price)}, above the entry zone (#{zone(item)}). Buying here means chasing.", nil ]
        end
      return unless kind

      item.alerts.build(user: item.user, kind: kind, message: message, price: price, relative_volume: relative_volume)
    end

    # Volume is judged on the day's projected total (Nepse::VolumeProfile), not the
    # volume so far, so a breakout early in the session isn't called light by default.
    def breakout_alert(item, price)
      stock = item.stock
      head = "#{stock.symbol} broke above the #{fmt(item.pivot_price.presence || item.entry_zone_low)} pivot at #{fmt(price)}"
      ratio = relative_volume(stock)
      circuit = stock.change_percent.to_f >= Setups::Guards.circuit_near_pct ? " It's at the upper circuit, so volume understates demand." : ""

      if ratio.nil?
        [ "breakout_low_volume", "#{head}. It's too early in the session to judge volume; the close will confirm or reject it.#{circuit}", nil ]
      elsif ratio >= BREAKOUT_VOLUME_MULTIPLE
        [ "breakout_confirmed", "#{head} on #{volume_text(stock, ratio)}.#{circuit}", ratio ]
      else
        [ "breakout_low_volume", "#{head}, but on #{volume_text(stock, ratio)} (below #{BREAKOUT_VOLUME_MULTIPLE}x). Wait for volume to confirm.#{circuit}", ratio ]
      end
    end

    def volume_text(stock, ratio)
      minute = Nepse::VolumeProfile.session_minute
      return "#{ratio}x its #{AVERAGE_VOLUME_SESSIONS}-day average volume" unless minute && minute < Nepse::VolumeProfile::SESSION_MINUTES

      clock = (Time.current.in_time_zone(Nepse::MarketHours::TIME_ZONE)).strftime("%-l:%M")
      "a projected #{ratio}x its #{AVERAGE_VOLUME_SESSIONS}-day average volume (#{stock.volume.to_i.to_fs(:delimited)} so far by #{clock})"
    end

    # Today's volume, projected to the close during the session, against the average
    # of the sessions before today. Nil when it's too early in the session to tell.
    def relative_volume(stock)
      today = Nepse::MarketHours.today
      volumes = stock.daily_prices.where("traded_on < ?", today).order(traded_on: :desc).limit(AVERAGE_VOLUME_SESSIONS).pluck(:volume)
      average = volumes.sum.to_f / volumes.size if volumes.any?
      return unless average&.positive? && stock.volume.to_i.positive?

      projected = Nepse::VolumeProfile.projected(stock.volume.to_i)
      projected && (projected / average).round(2)
    end

    def zone(item)
      "#{fmt(item.entry_zone_low)}-#{fmt(item.entry_zone_high)}"
    end

    def fmt(value)
      format("%.2f", value.to_f)
    end
  end
end
