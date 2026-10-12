module Maintenance
  # Fills in what the scheduled jobs missed while the app was off (or while a source
  # was down), so the screener never sits on old data:
  #
  #   1. NEPSE index history for the last LOOKBACK days (which sessions happened)
  #   2. stock prices for sessions stored with far fewer stocks than usual
  #      (Merolagani backfill), then indicators
  #   3. floorsheets (broker flows) not stored yet
  #   4. setup snapshots for recent completed sessions that have none, built one
  #      session at a time (point in time, low memory), then the backtest and digest
  #
  # Cheap when nothing is missing: it only reads the database (and syncs the index
  # when a session is due). CatchUpJob runs it after boot and every hour.
  class CatchUp
    LOOKBACK = 15
    # A session counts as stored when it has at least this share of a usual day's rows.
    COMPLETE_SHARE = 0.7
    # Today's prices are final after the 4 PM closing sync; its snapshot after the
    # 4:45 PM nightly build.
    PRICES_FINAL_MINUTE = 16 * 60 + 5
    SNAPSHOT_FINAL_MINUTE = 17 * 60 + 15

    def self.call(**options) = new(**options).call

    def initialize(now: Time.current, sync_indices: true)
      @now = now
      @sync_indices = sync_indices
    end

    def call
      result = { indices: nil, price_sessions: [], flow_sessions: [], snapshot_sessions: [] }
      result[:indices] = Nepse::Reference::IndexHistorySync.call(days: LOOKBACK)[:indices]&.dig("NEPSE") if @sync_indices && index_behind?

      sessions = recent_sessions
      result[:price_sessions] = missing_price_sessions(sessions)
      if result[:price_sessions].any?
        days = (Nepse::MarketHours.today(@now) - result[:price_sessions].min).to_i + 2
        Nepse::HistoryBackfillService.call(days: days)
        Indicators::BatchCalculatorService.call(recalculate_all: true)
      end

      stored_flows = StockBrokerFlow.where(traded_on: sessions).distinct.pluck(:traded_on)
      result[:flow_sessions] = sessions - stored_flows
      Flows::Backfill.call(sessions: sessions.size) if result[:flow_sessions].any?

      result[:snapshot_sessions] = missing_snapshot_sessions(sessions)
      if result[:snapshot_sessions].any?
        Indicators::BatchCalculatorService.call if result[:price_sessions].empty?
        result[:snapshot_sessions].each { |day| Setups::SnapshotBuilder.call(as_of: day) }
        BacktestJob.perform_later
        BuildDailyDigestsJob.perform_later
      end
      result
    end

    # Behind when the latest stored index session is before the latest weekday that
    # should have traded (a holiday just costs one quick sync).
    def index_behind?
      latest = nepse_dates.max
      latest.nil? || latest < expected_session(PRICES_FINAL_MINUTE)
    end

    def recent_sessions
      nepse_dates.select { _1 >= Nepse::MarketHours.today(@now) - LOOKBACK && final?(_1, PRICES_FINAL_MINUTE) }.sort
    end

    def missing_price_sessions(sessions)
      usual = usual_rows
      return [] unless usual

      counts = StockDailyPrice.where(traded_on: sessions).group(:traded_on).count
      sessions.select { counts[_1].to_i < usual * COMPLETE_SHARE }
    end

    # For the screener's banner: the latest snapshot and the completed sessions after it.
    def self.freshness(now: Time.current)
      catch_up = new(now: now, sync_indices: false)
      latest = StockSetupSnapshot.maximum(:traded_on)
      missing = catch_up.missing_snapshot_sessions(catch_up.recent_sessions)
      { snapshot_on: latest, behind_sessions: missing.count { latest.nil? || _1 > latest }, latest_session: [ missing.max, latest ].compact.max }
    end

    # Recent completed sessions without snapshots, including gaps before the latest one
    # (a manual rebuild of today leaves the missed days in between empty).
    def missing_snapshot_sessions(sessions)
      return [] unless StockSetupSnapshot.exists?

      built = StockSetupSnapshot.where(traded_on: sessions).distinct.pluck(:traded_on)
      (sessions - built).select { final?(_1, SNAPSHOT_FINAL_MINUTE) }
    end

    private

    def nepse_dates = MarketIndexHistory.joins(:market_index).where(market_indices: { symbol: "NEPSE" }).where(traded_on: (Nepse::MarketHours.today(@now) - 60)..).pluck(:traded_on)

    # The median rows per session over the last 30 sessions with prices.
    def usual_rows
      counts = StockDailyPrice.where(traded_on: (Nepse::MarketHours.today(@now) - 60)..).group(:traded_on).count.values.sort.last(30)
      counts.empty? ? nil : counts[counts.size / 2]
    end

    def final?(day, minute)
      today = Nepse::MarketHours.today(@now)
      return true if day < today

      local = @now.in_time_zone(Nepse::MarketHours::TIME_ZONE)
      day == today && local.hour * 60 + local.min >= minute
    end

    def expected_session(minute)
      day = Nepse::MarketHours.today(@now)
      day -= 1 until Nepse::MarketHours.trading_wdays.include?(day.wday) && final?(day, minute)
      day
    end
  end
end
