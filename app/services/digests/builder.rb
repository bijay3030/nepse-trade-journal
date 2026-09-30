module Digests
  # The end-of-day digest for one user and session, from data already stored by the
  # nightly jobs. Sections follow the user's settings:
  #
  #   market      NEPSE close and change, regime, breadth, best and worst sectors
  #   entry_zone  stocks that joined or left "Entry zone now" since the previous
  #               snapshot session, and charts held back by the tradability guards
  #   watchlist   today's end-of-day verdicts, alerts raised during the session, and
  #               bonus/cash book closes due within 10 days for tracked stocks
  #
  # Rebuilding the same session replaces the content and keeps whether it was read.
  class Builder
    BOOK_CLOSE_DAYS = 10
    SECTOR_COUNT = 3

    def self.call(user, traded_on: nil) = new(user, traded_on).call

    def initialize(user, traded_on)
      @user = user
      sessions = StockSetupSnapshot.distinct.order(traded_on: :desc)
      sessions = sessions.where(traded_on: ..traded_on) if traded_on
      @traded_on, @previous = sessions.limit(2).pluck(:traded_on)
    end

    def call
      return unless @traded_on

      sections = @user.digest_sections & DailyDigest::SECTIONS
      content = { traded_on: @traded_on.iso8601, previous_session: @previous&.iso8601 }
      content[:market] = market if sections.include?("market")
      content[:entry_zone] = entry_zone if sections.include?("entry_zone")
      content[:watchlist] = watchlist if sections.include?("watchlist")

      digest = @user.daily_digests.find_or_initialize_by(traded_on: @traded_on)
      digest.update!(content: content)
      digest
    end

    private

    def market
      overview = MarketIndex::Overview.new.call(as_of: @traded_on)
      sectors = overview[:sectors].reject { MarketIndex::Heatmap::EXCLUDED_SECTORS.include?(_1[:sector]) }.sort_by { -_1[:sector_performance_pct] }
      slim = ->(row) { { sector: row[:sector], change_pct: row[:sector_performance_pct] } }
      {
        index_on: overview[:traded_on], nepse_index: overview[:nepse_index], index_change_pct: overview[:index_change_pct],
        regime: overview[:regime_status], advancing: overview[:advancing_stocks], declining: overview[:declining_stocks],
        unchanged: overview[:unchanged_stocks], breadth_pct: overview[:market_breadth_pct],
        best_sectors: sectors.first(SECTOR_COUNT).map(&slim), worst_sectors: sectors.last(SECTOR_COUNT).reverse.map(&slim)
      }
    end

    def entry_zone
      today = StockSetupSnapshot.where(traded_on: @traded_on).joins(:stock).merge(Stock.active).includes(:stock).index_by(&:stock_id)
      before = @previous ? StockSetupSnapshot.where(traded_on: @previous, in_buy_zone: true).pluck(:stock_id).to_set : Set.new
      on_board = today.values.select(&:in_buy_zone)

      {
        count: on_board.size,
        joined: on_board.reject { before.include?(_1.stock_id) }.sort_by { -_1.readiness_score }.map { board_row(_1) },
        left: before.filter_map { today[_1] }.reject(&:in_buy_zone).sort_by { _1.stock.symbol }.map do |snapshot|
          { symbol: snapshot.stock.symbol, zone_state: snapshot.zone_state, readiness: snapshot.readiness_score, guards: snapshot.guards }
        end,
        held_back: StockSetupSnapshot.where(traded_on: @traded_on).held_back_by_guards.joins(:stock).merge(Stock.active)
                                     .order("stocks.symbol").pluck("stocks.symbol", :guards).map { |symbol, guards| { symbol: symbol, guards: guards } }
      }
    end

    def board_row(snapshot)
      {
        symbol: snapshot.stock.symbol, name: snapshot.stock.name, sector: snapshot.stock.sector, readiness: snapshot.readiness_score,
        setup_type: snapshot.setup_type, close: snapshot.close_price.to_f,
        entry_zone_low: snapshot.entry_zone_low&.to_f, entry_zone_high: snapshot.entry_zone_high&.to_f
      }
    end

    def watchlist
      items = @user.watchlist_items.tracked.includes(:stock).to_a
      upcoming = CorporateActions::Upcoming.for_stocks(items.map(&:stock_id), on: @traded_on)
      {
        tracked: items.size,
        verdicts: items.select { _1.last_close_on == @traded_on }.sort_by { _1.stock.symbol }.map do |item|
          { symbol: item.stock.symbol, setup_type: item.setup_type, state: item.last_close_state, close: item.last_close_price&.to_f }
        end,
        alerts: @user.watchlist_alerts.where(created_at: session_day).includes(watchlist_item: :stock).recent.map do |alert|
          { symbol: alert.watchlist_item.stock.symbol, kind: alert.kind, message: alert.message }
        end,
        book_closes: items.filter_map do |item|
          event = upcoming[item.stock_id]
          next unless event && event[:days_until] <= BOOK_CLOSE_DAYS

          { symbol: item.stock.symbol, book_close_on: event[:book_close_on].iso8601, days_until: event[:days_until],
            bonus_percent: event[:bonus_percent], cash_percent: event[:cash_percent] }
        end.sort_by { _1[:days_until] }
      }
    end

    # The session's calendar day in Nepal time.
    def session_day
      zone = ActiveSupport::TimeZone["Asia/Kathmandu"]
      zone.local(@traded_on.year, @traded_on.month, @traded_on.day).all_day
    end
  end
end
