module Watchlist
  # Compares each tracked item's latest price with its levels after a price sync.
  # Alerts fire only when the price moves into a new state, so a stock sitting in
  # its zone does not alert again every five minutes.
  class AlertEvaluator
    BREAKOUT_VOLUME_MULTIPLE = 1.5
    AVERAGE_VOLUME_SESSIONS = 50
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

      alert = nil
      WatchlistItem.transaction do
        item.update!(updates)
        alert = build_alert(item, previous, current, price)&.tap(&:save!) if previous && previous != current
      end
      alert
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
