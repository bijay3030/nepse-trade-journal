module Events
  # Collects company events into market_events, rated by Events::Classifier:
  #
  #   ShareSansar announcements  newest pages until one holds nothing new (at most
  #                              `pages`): results, AGMs, promoter shares, rights,
  #                              mergers, regulatory notices and the rest
  #   Chukul bonus feed          bonus / cash dividend proposals and their book closes
  #   Chukul rights feed         rights issues and their book closes
  #
  # Chukul items are kept for LOOKBACK_DAYS after their announcement or book close and
  # updated when a book-close date appears. Quarterly results are compared with the same
  # quarter of the year before (reports are cumulative, so Q1 with Q1).
  module Sync
    PAGES = 5
    BACKFILL_PAGES = 80
    LOOKBACK_DAYS = 120

    module_function

    def call(pages: PAGES, today: Nepse::MarketHours.today,
             announcements: Nepse::Source::SharesansarAnnouncementsClient.new, chukul: Nepse::Source::ChukulClient.new)
      symbols = Stock.pluck(:symbol, :id).to_h
      {
        announcements: sync_announcements(announcements, pages, today),
        dividends: sync_dividends(chukul.bonus_feed, symbols, today),
        rights: sync_rights(chukul.rights_feed, symbols, today)
      }
    end

    def sync_announcements(client, pages, today)
      matcher = CompanyMatcher.new
      created = 0
      cursor = nil
      pages.times do
        page = client.page(cursor: cursor)
        return { created: created, error: page[:error] } unless page[:success]

        fresh = page[:items].reject { MarketEvent.exists?(source: "sharesansar", external_id: _1[:url]) }
        fresh.reverse_each { |item| created += 1 if store_announcement(item, matcher, today) }
        break if fresh.empty? || page[:next_cursor].blank?

        cursor = page[:next_cursor]
      end
      { created: created }
    end

    def store_announcement(item, matcher, today)
      stock_id = matcher.stock_id(item[:title])
      quarter = item[:title][/(\d)(?:st|nd|rd|th) quarter/i, 1]
      year = item[:title][/fiscal year (\d{4}\/\d{2})/i, 1]
      previous = if stock_id && quarter && year
        MarketEvent.where(stock_id: stock_id, kind: "results").where("data->>'quarter' = ?", quarter)
                   .where("data->>'fiscal_year' < ?", year).order(published_on: :desc).first
      end
      rated = Classifier.title(item[:title], previous_result: previous)
      MarketEvent.create!(stock_id: stock_id, source: "sharesansar", external_id: item[:url], title: item[:title], url: item[:url],
                          published_on: [ item[:published_on], today ].min, **rated.slice(:kind, :impact, :reason, :important), data: rated[:data])
      true
    rescue ActiveRecord::RecordNotUnique
      false
    end

    def sync_dividends(feed, symbols, today)
      return { error: feed[:error] } unless feed[:success]

      count = 0
      Array(feed[:data]).each do |row|
        stock_id = symbols[row["symbol"].to_s.upcase] or next
        announced = date(row["annoucement_date"])
        book_close = date(row["book_close_date"])
        next unless recent?(announced, book_close, today) && plausible?(announced, today)

        rated = Classifier.dividend(bonus: row["bonus"], cash: row["cash"], book_close_on: book_close, year: row["year"])
        what = [ row["bonus"].to_f.positive? ? "#{format('%g', row['bonus'].to_f)}% bonus" : nil,
                 row["cash"].to_f.positive? ? "#{format('%g', row['cash'].to_f)}% cash dividend" : nil ].compact.join(" + ").presence || "no dividend"
        title = "#{row['symbol']}: #{what} for #{row['year']}#{book_close ? ", book close #{book_close.strftime('%-d %b %Y')}" : ''}"
        upsert("chukul_bonus", "#{row['symbol']}:#{row['year']}", stock_id, title, [ announced || book_close, today ].min, book_close,
               rated.merge(data: rated[:data].merge(agm_on: row["agm_date"], year: row["year"])))
        count += 1
      end
      { events: count }
    end

    def sync_rights(feed, symbols, today)
      return { error: feed[:error] } unless feed[:success]

      count = 0
      Array(feed[:data]).each do |row|
        stock_id = symbols[row["symbol"].to_s.upcase] or next
        announced = date(row["annoucement_date"])
        book_close = date(row["book_close_date"])
        next unless recent?(announced, book_close, today) && plausible?(announced, today)

        rated = Classifier.rights(right: row["right"], book_close_on: book_close)
        title = "#{row['symbol']}: #{format('%g', row['right'].to_f)}% rights shares#{book_close ? ", book close #{book_close.strftime('%-d %b %Y')}" : ''}"
        upsert("chukul_rights", "#{row['symbol']}:#{row['year']}:#{row['right']}", stock_id, title, [ announced || book_close || today, today ].min, book_close,
               rated.merge(data: rated[:data].merge(year: row["year"], opening_on: row["opening_date"], closing_on: row["closing_date"])))
        count += 1
      end
      { events: count }
    end

    def upsert(source, external_id, stock_id, title, published_on, event_on, rated)
      event = MarketEvent.find_or_initialize_by(source: source, external_id: external_id)
      event.assign_attributes(stock_id: stock_id, title: title, published_on: event.published_on || published_on, event_on: event_on,
                              **rated.slice(:kind, :impact, :reason, :important, :data))
      event.save! if event.changed?
    end

    def recent?(announced, book_close, today)
      [ announced, book_close ].compact.any? { _1 >= today - LOOKBACK_DAYS }
    end

    # Chukul has a few rows "announced" in the future for old fiscal years: data errors.
    def plausible?(announced, today) = announced.nil? || announced <= today + 1

    def date(value) = value.present? ? (Date.parse(value.to_s) rescue nil) : nil
  end
end
