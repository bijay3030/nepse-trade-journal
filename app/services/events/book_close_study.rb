module Events
  # How prices moved around bonus, cash dividend and rights book closes on NEPSE since
  # 2020, from the stored dividend history (stock_dividends) and Chukul's rights feed,
  # on bonus-adjusted prices (Scans::History), so the adjustment itself isn't a "drop":
  # the moves are what a holder actually made.
  #
  #   before  close WINDOW sessions before the book close -> the last close before it
  #           (the run-up as traders buy for the entitlement)
  #   after   the last close before the book close -> WINDOW sessions later
  #
  # Each is also compared with NEPSE over the same dates (excess). Grouped by bonus size,
  # cash-only dividends and rights issues. Cached for a day.
  module BookCloseStudy
    WINDOW = 20
    FROM = Scans::History::ARCHIVE_FROM

    GROUPS = [
      { key: "bonus_20", label: "Bonus 20% or more" },
      { key: "bonus_10", label: "Bonus 10–20%" },
      { key: "bonus_small", label: "Bonus under 10%" },
      { key: "cash_only", label: "Cash dividend only" },
      { key: "rights", label: "Rights issue" }
    ].freeze

    module_function

    def cached = Rails.cache.fetch([ "events/book_close_study", 1, Nepse::MarketHours.today ], expires_in: 1.day) { call }

    def call(rights_feed: Nepse::Source::ChukulClient.new.rights_feed)
      events = dividend_events + rights_events(rights_feed)
      nepse = Scans::MarketPhase.series.to_h
      nepse_dates = nepse.keys.sort
      samples = []
      events.group_by { _1[:stock_id] }.each do |stock_id, list|
        stock = Stock.find_by(id: stock_id) or next
        rows = Lab::StockReport.history(stock)
        dates = rows.map(&:first)
        closes = rows.map { _1[3] }
        list.each do |event|
          i = dates.bsearch_index { _1 >= event[:book_close_on] } or next
          before = i - 1
          next if before - WINDOW < 0 || before + WINDOW >= closes.size

          run_up = pct(closes[before - WINDOW], closes[before])
          after = pct(closes[before], closes[before + WINDOW])
          samples << event.merge(
            run_up: run_up, after: after,
            run_up_excess: excess(run_up, nepse, nepse_dates, dates[before - WINDOW], dates[before]),
            after_excess: excess(after, nepse, nepse_dates, dates[before], dates[before + WINDOW])
          )
        end
      end
      {
        window: WINDOW, from: FROM, events: samples.size,
        groups: GROUPS.map { |g| g.merge(summary(samples.select { _1[:group] == g[:key] })) },
        all: summary(samples)
      }
    end

    def dividend_events
      StockDividend.joins(:stock).merge(Stock.where(security_type: "Equity")).where(book_close_on: FROM..Nepse::MarketHours.today)
                   .pluck(:stock_id, :book_close_on, :bonus_percent, :cash_percent).filter_map do |stock_id, on, bonus, cash|
        bonus = bonus.to_f
        cash = cash.to_f
        group = if bonus >= 20 then "bonus_20" elsif bonus >= 10 then "bonus_10" elsif bonus.positive? then "bonus_small" elsif cash.positive? then "cash_only" end
        group && { stock_id: stock_id, book_close_on: on, group: group }
      end
    end

    def rights_events(feed)
      return [] unless feed[:success]

      symbols = Stock.where(security_type: "Equity").pluck(:symbol, :id).to_h
      Array(feed[:data]).filter_map do |row|
        on = (Date.parse(row["book_close_date"].to_s) rescue nil)
        id = symbols[row["symbol"].to_s.upcase]
        { stock_id: id, book_close_on: on, group: "rights" } if id && on && on >= FROM && on <= Nepse::MarketHours.today
      end
    end

    def excess(move, nepse, nepse_dates, from, to)
      a = nepse[nepse_dates.reverse.find { _1 <= from }]
      b = nepse[nepse_dates.reverse.find { _1 <= to }]
      a && b ? (move - pct(a, b)).round(2) : nil
    end

    def pct(a, b) = ((b / a - 1) * 100).round(2)

    def summary(samples)
      return { count: 0 } if samples.empty?

      avg = ->(key) { values = samples.filter_map { _1[key] }; values.empty? ? nil : (values.sum / values.size).round(2) }
      up = ->(key) { (samples.count { _1[key].to_f.positive? } * 100.0 / samples.size).round(1) }
      { count: samples.size, run_up_avg: avg.(:run_up), run_up_up_pct: up.(:run_up), run_up_excess: avg.(:run_up_excess),
        after_avg: avg.(:after), after_up_pct: up.(:after), after_excess: avg.(:after_excess) }
    end
  end
end
