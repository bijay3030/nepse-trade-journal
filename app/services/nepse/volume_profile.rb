module Nepse
  # How much of a day's volume has normally traded by each minute of the session,
  # so a breakout at 11:45 isn't judged on three-quarters of an hour of volume.
  #
  # Learned from the running volumes recorded at each price sync (record!) over the
  # last SESSIONS sessions: for every sample, volume so far / that day's final volume,
  # taken as the median per 15-minute slot across stocks and days. Until there are
  # MIN_SESSIONS of samples, DEFAULT_CURVE is used: a rough front-loaded shape (busy
  # open, steadier afterwards), replaced by NEPSE's own data as it builds up.
  module VolumeProfile
    SESSIONS = 20
    MIN_SESSIONS = 5
    MIN_SAMPLES = 30
    SLOT = 15
    SESSION_MINUTES = (MarketHours::CLOSE_MINUTE - MarketHours::OPEN_MINUTE)
    # Too little of the day has traded to project before this.
    MIN_MINUTE = 15
    KEEP_DAYS = 45
    DEFAULT_CURVE = [ [ 0, 0.0 ], [ 15, 0.14 ], [ 30, 0.22 ], [ 60, 0.35 ], [ 90, 0.46 ], [ 120, 0.56 ],
                      [ 150, 0.66 ], [ 180, 0.76 ], [ 210, 0.87 ], [ 240, 1.0 ] ].freeze

    module_function

    # Minutes since the open, or nil outside the session.
    def session_minute(time = Time.current)
      local = time.in_time_zone(MarketHours::TIME_ZONE)
      return unless MarketHours.trading_wdays.include?(local.wday)

      minute = local.hour * 60 + local.min - MarketHours::OPEN_MINUTE
      minute if minute.between?(0, SESSION_MINUTES)
    end

    # Saves every active stock's running volume for this moment (during the session only).
    def record!(time = Time.current)
      minute = session_minute(time)
      return 0 unless minute

      day = MarketHours.today(time)
      now = Time.current
      rows = Stock.active.where("volume > 0").pluck(:id, :volume).map do |id, volume|
        { stock_id: id, traded_on: day, minute: minute, volume: volume, created_at: now, updated_at: now }
      end
      StockIntradayVolume.upsert_all(rows, unique_by: :index_intraday_volumes_unique) if rows.any?
      StockIntradayVolume.where(traded_on: ...(day - KEEP_DAYS)).delete_all
      rows.size
    end

    # [[minute, share of the day's volume], ...] and where it came from.
    def curve
      Rails.cache.fetch("nepse:volume_profile:#{MarketHours.today}", expires_in: 1.hour) { build }
    end

    def build
      days = StockIntradayVolume.distinct.order(traded_on: :desc).where(traded_on: ...MarketHours.today).limit(SESSIONS).pluck(:traded_on)
      return { source: "default", sessions: days.size, points: DEFAULT_CURVE } if days.size < MIN_SESSIONS

      finals = StockDailyPrice.where(traded_on: days).where("volume > 0").pluck(:stock_id, :traded_on, :volume).to_h { |s, d, v| [ [ s, d ], v.to_f ] }
      shares = Hash.new { |h, k| h[k] = [] }
      StockIntradayVolume.where(traded_on: days).pluck(:stock_id, :traded_on, :minute, :volume).each do |stock_id, day, minute, volume|
        final = finals[[ stock_id, day ]] or next
        share = volume / final
        # A stale volume from the day before shows up as a share far above 1.
        shares[minute / SLOT * SLOT] << share if share.between?(0, 1.05)
      end

      # Each slot's median describes the middle of the slot.
      learned = shares.select { |_, values| values.size >= MIN_SAMPLES }.sort.map { |slot, values| [ slot + SLOT / 2, median(values) ] }
      return { source: "default", sessions: days.size, points: DEFAULT_CURVE } if learned.size < 4

      # Cumulative volume never falls, and the close is the whole day.
      running = 0.0
      points = ([ [ 0, 0.0 ] ] + learned).map { |minute, share| [ minute, running = [ running, [ share, 1.0 ].min ].max ] }
      points << [ SESSION_MINUTES, 1.0 ] unless points.last.first == SESSION_MINUTES
      { source: "learned", sessions: days.size, points: points }
    end

    # The share of the day's volume normally traded by `minute` (interpolated).
    def share_at(minute, points = curve[:points])
      return 1.0 if minute >= SESSION_MINUTES

      lower, upper = points.each_cons(2).find { |(a, _), (b, _)| minute.between?(a, b) } || [ points.last, points.last ]
      return upper.last if upper.first == lower.first

      lower.last + (upper.last - lower.last) * (minute - lower.first) / (upper.first - lower.first).to_f
    end

    # Today's volume projected to the close, or nil when it's too early to tell.
    # After the session (or outside it) the volume is already the day's total.
    def projected(volume_so_far, time = Time.current)
      minute = session_minute(time)
      return volume_so_far.to_f if minute.nil? || minute >= SESSION_MINUTES
      return if minute < MIN_MINUTE

      share = share_at(minute)
      share.positive? ? volume_so_far / share : nil
    end

    # Today's volume against the 50-session average, projected to the close while
    # the market is open. Nil outside the session or without volume.
    def pace(stock, time = Time.current, sessions: 50)
      minute = session_minute(time)
      return unless minute && stock.volume.to_i.positive? && stock.last_updated && MarketHours.today(stock.last_updated) == MarketHours.today(time)

      volumes = stock.daily_prices.where("traded_on < ?", MarketHours.today(time)).order(traded_on: :desc).limit(sessions).pluck(:volume)
      average = volumes.sum.to_f / volumes.size if volumes.any?
      projection = projected(stock.volume.to_i, time)
      {
        so_far: stock.volume.to_i, minute: minute, average: average&.round, projected: projection&.round,
        ratio: projection && average&.positive? ? (projection / average).round(2) : nil,
        curve: curve.slice(:source, :sessions)
      }
    end

    def median(values)
      sorted = values.sort
      mid = sorted.size / 2
      sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
    end
  end
end
