module Positions
  # Watches open positions against sell rules and records PositionAlerts (one per rule
  # and level/session, so nothing repeats every five minutes). Rule checks, not advice.
  #
  # Live, after each price sync (call):
  #   stop_hit        price at or below the stop
  #   target_reached  price at or above the target
  #   one_r           up one R (the first stop's distance) while the stop is still below
  #                   break-even: the trader may move the stop to break-even
  #   profit_zone     PROFIT_ZONE_PCT above the average price (O'Neil's 20-25% zone)
  # On the close (call(close: true), after the end-of-day sync):
  #   fifty_day_break closed below the 50-day average, from above it, on volume above
  #                   its 50-day average
  #   climax_run      a CLIMAX_ADR+ ADR up day on the highest volume of CLIMAX_VOLUME_SESSIONS
  #                   sessions, CLIMAX_EXTENSION_PCT+ above the 50-day: often near a top
  #   time_stop       TIME_STOP_SESSIONS+ sessions held and still under TIME_STOP_R
  class Monitor
    PROFIT_ZONE_PCT = 20.0
    CLIMAX_ADR = 3.0
    CLIMAX_VOLUME_SESSIONS = 50
    CLIMAX_EXTENSION_PCT = 25.0
    TIME_STOP_SESSIONS = 15
    TIME_STOP_R = 0.5

    def self.call(close: false, positions: Position.open) = new(close: close, positions: positions).call

    def initialize(close:, positions:)
      @close = close
      @positions = positions
    end

    def call
      created = 0
      @positions.includes(:stock, :fills, :user).find_each do |position|
        next unless position.quantity.positive? && position.last_price.positive?

        rules = @close ? close_alerts(position) : live_alerts(position)
        rules.compact.each { |kind, key, message| created += 1 if record(position, kind, key, message) }
      end
      { created: created }
    end

    private

    def live_alerts(position)
      price = position.last_price
      symbol = position.stock.symbol
      [ stop_alert(position, price, symbol), target_alert(position, price, symbol), one_r_alert(position, price, symbol), profit_zone_alert(position, symbol) ]
    end

    def stop_alert(position, price, symbol)
      return unless price <= position.stop_price.to_f

      [ "stop_hit", money(position.stop_price), "#{symbol} is at #{money(price)}, at or below your #{money(position.stop_price)} stop. " \
                                               "Selling at the stop: #{rupees(-position.open_risk)} after costs.#{settlement_note(position)}" ]
    end

    def target_alert(position, price, symbol)
      return unless position.target_price && price >= position.target_price.to_f

      [ "target_reached", money(position.target_price), "#{symbol} reached your #{money(position.target_price)} target at #{money(price)} " \
                                                       "(#{format('%+.1f', position.unrealized_pct.to_f)}%, #{position.r_multiple}R).#{settlement_note(position)}" ]
    end

    def profit_zone_alert(position, symbol)
      return unless position.unrealized_pct.to_f >= PROFIT_ZONE_PCT

      [ "profit_zone", "", "#{symbol} is #{format('%+.1f', position.unrealized_pct)}% above your #{money(position.average_price)} average: " \
                           "the 20-25% zone where O'Neil-style traders take some profit." ]
    end

    def one_r_alert(position, price, symbol)
      r = position.r_multiple
      break_even = position.break_even_price
      return unless r && r >= 1 && break_even && position.stop_price.to_f < break_even

      [ "one_r", "", "#{symbol} is up 1R at #{money(price)} (#{r}R). Your stop is #{money(position.stop_price)}; " \
                     "moving it to break-even (#{money(break_even)}) would make the trade risk-free after costs." ]
    end

    def close_alerts(position)
      bars = position.stock.daily_prices.order(traded_on: :desc).limit(CLIMAX_VOLUME_SESSIONS + 1).to_a.reverse
      today = bars.last
      return [] unless today && bars.size >= 2

      indicator = position.stock.daily_indicators.find_by(traded_on: today.traded_on)
      [ fifty_day_alert(position, bars, indicator), climax_alert(position, bars, indicator), time_stop_alert(position) ]
    end

    def fifty_day_alert(position, bars, indicator)
      today, yesterday = bars.last, bars[-2]
      sma = indicator&.sma_50.to_f
      previous_sma = position.stock.daily_indicators.find_by(traded_on: yesterday.traded_on)&.sma_50.to_f
      return unless sma.positive? && today.close_price.to_f < sma && (previous_sma.zero? || yesterday.close_price.to_f >= previous_sma)

      average = indicator.avg_volume_50.to_f
      return unless average.positive? && today.volume.to_i > average

      [ "fifty_day_break", today.traded_on.iso8601,
        "#{position.stock.symbol} closed at #{money(today.close_price)}, below its 50-day average (#{money(sma)}) " \
        "on #{(today.volume.to_f / average).round(1)}x average volume: a common sell signal for swing trades." ]
    end

    def climax_alert(position, bars, indicator)
      today = bars.last
      adr = Setups::Extension.adr_pct(bars.last(Setups::Extension::ADR_SESSIONS))
      change = Setups::Extension.day_change(bars)
      sma = indicator&.sma_50.to_f
      return unless adr && change && sma.positive?
      return unless change / adr >= CLIMAX_ADR && today.volume.to_i >= bars.map { _1.volume.to_i }.max
      return unless (today.close_price.to_f / sma - 1) * 100 >= CLIMAX_EXTENSION_PCT

      [ "climax_run", today.traded_on.iso8601,
        "#{position.stock.symbol} jumped #{format('%+.1f', change)}% (#{(change / adr).round(1)} ADR) on its heaviest volume in " \
        "#{CLIMAX_VOLUME_SESSIONS} sessions, #{((today.close_price.to_f / sma - 1) * 100).round}% above its 50-day: climax runs often mark a top." ]
    end

    def time_stop_alert(position)
      held = position.stock.daily_prices.where("traded_on > ?", position.opened_on).count
      r = position.r_multiple
      return unless held >= TIME_STOP_SESSIONS && r && r < TIME_STOP_R

      [ "time_stop", "", "#{position.stock.symbol} has gone #{held} sessions at #{r}R (under #{TIME_STOP_R}R): " \
                         "the capital may work better elsewhere." ]
    end

    def settlement_note(position)
      sellable = position.sellable_on
      return "" unless sellable && sellable > Nepse::MarketHours.today

      " The shares bought #{position.last_buy_on.strftime('%-d %b')} settle (T+2) and can be sold from #{sellable.strftime('%-d %b')}."
    end

    def record(position, kind, key, message)
      alert = position.user.position_alerts.create_with(message: message, price: position.last_price)
                      .find_or_create_by(position: position, kind: kind, key: key)
      alert.previously_new_record?
    rescue ActiveRecord::RecordNotUnique
      false
    end

    def money(value) = format("%.2f", value.to_f)
    def rupees(value) = "#{value.negative? ? '-' : ''}Rs #{value.abs.round(2).to_fs(:delimited)}"
  end
end
