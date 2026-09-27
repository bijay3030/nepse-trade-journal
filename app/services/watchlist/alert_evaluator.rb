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

    def self.call(items = WatchlistItem.tracked)
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
          if item.setup_type == "vcp" && previous == "below_zone"
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

    def breakout_alert(item, price)
      symbol = item.stock.symbol
      pivot = item.pivot_price.presence || item.entry_zone_low
      ratio = relative_volume(item.stock)
      volume_text = ratio ? "#{ratio}x its #{AVERAGE_VOLUME_SESSIONS}-day average volume so far" : "volume not available"

      if ratio && ratio >= BREAKOUT_VOLUME_MULTIPLE
        [ "breakout_confirmed", "#{symbol} broke above the #{fmt(pivot)} pivot at #{fmt(price)} on #{volume_text}.", ratio ]
      else
        [ "breakout_low_volume", "#{symbol} broke above the #{fmt(pivot)} pivot at #{fmt(price)}, but on #{volume_text} (below #{BREAKOUT_VOLUME_MULTIPLE}x). Wait for volume to confirm.", ratio ]
      end
    end

    # Today's volume against the average of the sessions before the latest one.
    def relative_volume(stock)
      latest = stock.daily_prices.maximum(:traded_on)
      return unless latest

      volumes = stock.daily_prices.where("traded_on < ?", latest).order(traded_on: :desc).limit(AVERAGE_VOLUME_SESSIONS).pluck(:volume)
      average = volumes.sum.to_f / volumes.size if volumes.any?
      return unless average&.positive? && stock.volume.to_i.positive?

      (stock.volume.to_f / average).round(2)
    end

    def zone(item)
      "#{fmt(item.entry_zone_low)}-#{fmt(item.entry_zone_high)}"
    end

    def fmt(value)
      format("%.2f", value.to_f)
    end
  end
end
