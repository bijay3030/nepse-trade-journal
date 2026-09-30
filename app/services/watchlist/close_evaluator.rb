module Watchlist
  # Runs after the end-of-day sync and judges each setup on the session's close and
  # full-day volume. Intraday alerts react to the last traded price and partial
  # volume; this is the confirmation that many VCP traders wait for.
  class CloseEvaluator
    CONFIRM_VOLUME_MULTIPLE = AlertEvaluator::BREAKOUT_VOLUME_MULTIPLE
    AVERAGE_VOLUME_SESSIONS = AlertEvaluator::AVERAGE_VOLUME_SESSIONS
    STATES = %w[confirmed unconfirmed failed held_zone in_zone below_zone above_zone invalidated].freeze

    def self.call(items = WatchlistItem.tracked)
      new(items).call
    end

    def initialize(items)
      @items = items
    end

    def call
      summary = { evaluated: 0, alerts: 0 }

      @items.includes(:stock).find_each do |item|
        session = item.stock.daily_prices.order(traded_on: :desc).first
        next if session.nil? || item.last_close_on == session.traded_on

        state, relative_volume = judge(item, session)
        alert = build_alert(item, state, session, relative_volume)
        WatchlistItem.transaction do
          item.update!(
            last_close_on: session.traded_on, last_close_state: state,
            last_close_price: session.close_price, last_close_relative_volume: relative_volume
          )
          alert&.save!
        end
        summary[:evaluated] += 1
        summary[:alerts] += 1 if alert
      end

      summary
    end

    private

    def judge(item, session)
      close = session.close_price.to_f
      relative_volume = relative_volume(item.stock, session)
      touched_today = item.touched_zone_on == session.traded_on

      state =
        if close <= item.invalidation_price.to_f
          "invalidated"
        elsif close > item.entry_zone_high.to_f
          "above_zone"
        elsif close >= item.entry_zone_low.to_f
          if Setups::Types.breakout?(item.setup_type)
            relative_volume.to_f >= CONFIRM_VOLUME_MULTIPLE ? "confirmed" : "unconfirmed"
          else
            "held_zone"
          end
        else
          touched_today ? "failed" : "below_zone"
        end
      [ state, relative_volume ]
    end

    def build_alert(item, state, session, relative_volume)
      symbol = item.stock.symbol
      close = format("%.2f", session.close_price.to_f)
      volume = relative_volume ? "#{relative_volume}x its #{AVERAGE_VOLUME_SESSIONS}-day average volume" : "unknown volume"
      pivot = format("%.2f", (item.pivot_price.presence || item.entry_zone_low).to_f)
      kind, message =
        case state
        when "confirmed"
          [ "close_confirmed", "#{symbol} closed at #{close}, above the #{pivot} pivot, on #{volume}. Breakout confirmed at the close." ]
        when "unconfirmed"
          [ "close_unconfirmed", "#{symbol} closed at #{close}, above the #{pivot} pivot, but on #{volume} (below #{CONFIRM_VOLUME_MULTIPLE}x). Not confirmed." ]
        when "failed"
          [ "close_failed", "#{symbol} reached its zone today but closed at #{close}, back below #{format('%.2f', item.entry_zone_low.to_f)}. Breakout failed at the close." ]
        when "held_zone"
          [ "close_in_zone", "#{symbol} closed at #{close}, inside its entry zone, on #{volume}." ]
        end
      return unless kind

      item.alerts.build(user: item.user, kind: kind, message: message, price: session.close_price, relative_volume: relative_volume)
    end

    # The session's full volume against the average of the sessions before it.
    def relative_volume(stock, session)
      volumes = stock.daily_prices.where("traded_on < ?", session.traded_on).order(traded_on: :desc)
        .limit(AVERAGE_VOLUME_SESSIONS).pluck(:volume)
      average = volumes.sum.to_f / volumes.size if volumes.any?
      return unless average&.positive? && session.volume.to_i.positive?

      (session.volume.to_f / average).round(2)
    end
  end
end
