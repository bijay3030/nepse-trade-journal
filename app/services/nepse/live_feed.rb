module Nepse
  # Picks a fresh source for the live price sync and records how fresh prices are.
  #
  # During the session the Live Trading page is tried first, then the summary page; for
  # the closing run (after the session) the summary page comes first, since it carries
  # the end-of-day turnover and trades. A source is fresh when its rows are for today and:
  #
  #   - during the session, its "As of" time (when the page gives one) is within
  #     STALE_MINUTES, and
  #   - during the session, the prices have changed within STALE_MINUTES (a page that
  #     keeps showing the same numbers is stale, whatever date it carries).
  #
  # When no source is fresh, nothing is stored and the status says "delayed", so the
  # app shows it and the live alerts wait. Status lives in Rails.cache (`status`).
  module LiveFeed
    STALE_MINUTES = 15
    STATUS_KEY = "nepse/live_feed/status".freeze
    FINGERPRINT_KEY = "nepse/live_feed/fingerprint".freeze

    module_function

    def default_sources(now)
      live = [ :sharesansar_live, Source::SharesansarLiveClient.new ]
      summary = [ :sharesansar_summary, Source::SharesansarMarketClient.new ]
      MarketHours.open?(now) ? [ live, summary ] : [ summary, live ]
    end

    # { fresh:, source:, response:, reasons: { source => why not } }
    def pick(now:, sources:)
      reasons = {}
      sources.each do |name, client|
        response = client.fetch
        why = stale_reason(response, now)
        if why
          reasons[name] = why
          next
        end
        return { fresh: true, source: name, response: response, reasons: reasons }
      end
      { fresh: false, reasons: reasons }
    end

    def stale_reason(response, now)
      return "unavailable: #{response.dig(:error, :message) || response[:error]}" unless response[:success]

      rows = Array(response[:rows])
      return "no prices" if rows.empty?

      today = MarketHours.today(now)
      day = rows.first[:traded_on]
      return "prices are for #{day || 'an unknown day'}, not today" unless day == today
      return unless MarketHours.open?(now)

      if (as_of = response[:as_of]) && now - as_of > STALE_MINUTES.minutes
        return "last updated #{as_of.in_time_zone(MarketHours::TIME_ZONE).strftime('%H:%M')}"
      end
      unchanged = unchanged_since(rows, now)
      "prices unchanged since #{unchanged.in_time_zone(MarketHours::TIME_ZONE).strftime('%H:%M')}" if unchanged && now - unchanged > STALE_MINUTES.minutes
    end

    # When these exact prices were first seen today, if they were seen before (else nil).
    def unchanged_since(rows, now)
      print = Digest::SHA1.hexdigest(rows.map { "#{_1[:symbol]}:#{_1[:last_price]}" }.sort.join(","))
      seen = Rails.cache.read(FINGERPRINT_KEY)
      if seen && seen[:print] == print && seen[:on] == MarketHours.today(now)
        seen[:at]
      else
        Rails.cache.write(FINGERPRINT_KEY, { print: print, at: now, on: MarketHours.today(now) }, expires_in: 1.day)
        nil
      end
    end

    def record(state:, now:, source: nil, as_of: nil, reasons: {})
      previous = Rails.cache.read(STATUS_KEY)
      since = state == previous&.dig(:state) ? previous[:since] : now
      Rails.cache.write(STATUS_KEY, { state: state, source: source, as_of: as_of, checked_at: now, since: since,
                                      last_live_at: state == "live" ? now : previous&.dig(:last_live_at), reasons: reasons }, expires_in: 2.days)
    end

    # { state: "live" | "delayed" | "closed", source:, as_of:, checked_at:, since:, last_live_at: }
    def status(now: Time.current)
      stored = Rails.cache.read(STATUS_KEY)
      return { state: "closed", checked_at: stored&.dig(:checked_at), last_live_at: stored&.dig(:last_live_at) } unless MarketHours.sync_window?(now)

      stored || { state: "unknown" }
    end
  end
end
