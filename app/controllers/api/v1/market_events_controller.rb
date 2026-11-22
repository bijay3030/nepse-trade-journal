module Api
  module V1
    # GET /market_events: company announcements and corporate actions (Events::Sync), rated
    # for the share price, with the book closes ahead and how prices moved around past
    # book closes (Events::BookCloseStudy).
    #   scope      "mine" (watchlist, positions, scanner radar, Strategy Lab list) or "all"
    #   impact     positive / negative / mixed / neutral
    #   kind       one of MarketEvent::KINDS
    #   from, to   announcement dates (default: the last 14 days; at most MAX_RANGE_DAYS)
    #   q          a symbol or part of a company's name (or of the announcement)
    #   page, per  pagination (per: at most 100, default 25)
    class MarketEventsController < BaseController
      UPCOMING_DAYS = 14
      DEFAULT_DAYS = 14
      MAX_RANGE_DAYS = 366
      PER_PAGE = 25

      def index
        today = Nepse::MarketHours.today
        to = date_param(:to) || today
        from = date_param(:from) || (to - DEFAULT_DAYS)
        from, to = to, from if from > to
        from = [ from, to - MAX_RANGE_DAYS ].max
        per = params[:per].present? ? params[:per].to_i.clamp(1, 100) : PER_PAGE
        mine = Events::Alerts.my_stock_ids(current_user) | Events::Alerts.lab_stock_ids

        events = MarketEvent.left_joins(:stock).where(published_on: from..to)
        events = events.where(stock_id: mine.to_a) if params[:scope] == "mine"
        events = events.where(impact: params[:impact]) if MarketEvent::IMPACTS.include?(params[:impact])
        events = events.where(kind: params[:kind]) if MarketEvent::KINDS.include?(params[:kind])
        if (query = params[:q].to_s.strip.presence)
          like = "%#{MarketEvent.sanitize_sql_like(query)}%"
          events = events.where("stocks.symbol ILIKE :start OR stocks.name ILIKE :like OR market_events.title ILIKE :like",
                                start: "#{MarketEvent.sanitize_sql_like(query)}%", like: like)
        end
        total = events.count
        pages = [ (total + per - 1) / per, 1 ].max
        page = params[:page].to_i.clamp(1, pages)
        upcoming = MarketEvent.includes(:stock).where(kind: Events::Alerts::BOOK_CLOSE_KINDS, event_on: today..(today + UPCOMING_DAYS)).order(:event_on)

        render json: {
          as_of: today, from: from, to: to,
          pagination: { page: page, per: per, total: total, pages: pages },
          events: events.includes(:stock).order(published_on: :desc, id: :desc).offset((page - 1) * per).limit(per).map { payload(_1, mine) },
          upcoming: upcoming.map { payload(_1, mine) },
          study: Events::BookCloseStudy.cached
        }
      end

      private

      def date_param(name) = (Date.iso8601(params[name].to_s) if params[name].present?) rescue nil

      def payload(event, mine)
        {
          id: event.id, symbol: event.stock&.symbol, company: event.stock&.name, sector: event.stock&.sector, mine: mine.include?(event.stock_id),
          kind: event.kind, impact: event.impact, reason: event.reason, important: event.important, title: event.title,
          url: event.url, source: event.source, published_on: event.published_on, event_on: event.event_on, data: event.data
        }
      end
    end
  end
end
