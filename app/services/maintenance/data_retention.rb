module Maintenance
  # Trims the bulkiest history to what the app reads, for a size-capped database (e.g.
  # Supabase's free 500 MB). Each limit comes from an environment variable and is off
  # when unset, so a local database keeps everything.
  #
  #   RETAIN_FLOW_SESSIONS      broker flows (Flows::AccumulationAnalyzer reads 20)
  #   RETAIN_SNAPSHOT_SESSIONS  setup snapshots (the backtest reads 120)
  #   RETAIN_INTRADAY_DAYS      intraday volume samples (Nepse::VolumeProfile reads 20 sessions)
  #
  # Finished Solid Queue jobs are cleared after a day either way.
  module DataRetention
    module_function

    def call(env: ENV)
      {
        broker_flows: keep_sessions(StockBrokerFlow, env["RETAIN_FLOW_SESSIONS"]),
        setup_snapshots: keep_sessions(StockSetupSnapshot, env["RETAIN_SNAPSHOT_SESSIONS"]),
        intraday_volumes: keep_days(StockIntradayVolume, env["RETAIN_INTRADAY_DAYS"]),
        finished_jobs: SolidQueue::Job.clear_finished_in_batches(finished_before: 1.day.ago).then { _1.is_a?(Integer) ? _1 : 0 }
      }
    end

    def keep_sessions(model, limit)
      return 0 unless limit.to_i.positive?

      cutoff = model.distinct.order(traded_on: :desc).offset(limit.to_i - 1).limit(1).pick(:traded_on)
      cutoff ? model.where(traded_on: ...cutoff).in_batches(of: 10_000).delete_all : 0
    end

    def keep_days(model, days)
      return 0 unless days.to_i.positive?

      model.where(traded_on: ...(Nepse::MarketHours.today - days.to_i)).delete_all
    end
  end
end
