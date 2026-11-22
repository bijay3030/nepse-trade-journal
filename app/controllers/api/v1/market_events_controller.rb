module Api
  module V1
    # GET /market_events: company announcements and corporate actions (Events::Sync), rated
    # for the share price, with the book closes ahead and how prices moved around past
    # book closes (Events::BookCloseStudy).
    #   scope   "mine" (watchlist, positions, scanner radar, Strategy Lab list) or "all"
    #   impact  positive / negative / mixed / neutral
    #   kind    one of MarketEvent::KINDS
    #   days    how far back (default 14, at most 90)
    class MarketEventsController < BaseController
      UPCOMING_DAYS = 14

      def index
        today = Nepse::MarketHours.today
        days = params[:days].to_i.clamp(1, 90).nonzero? || 14
        mine = Events::Alerts.my_stock_ids(current_user) | Events::Alerts.lab_stock_ids
        events = MarketEvent.includes(:stock).where(published_on: (today - days)..today).recent
        events = events.where(stock_id: mine.to_a) if params[:scope] == "mine"
        events = events.where(impact: params[:impact]) if MarketEvent::IMPACTS.include?(params[:impact])
        events = events.where(kind: params[:kind]) if MarketEvent::KINDS.include?(params[:kind])
        upcoming = MarketEvent.includes(:stock).where(kind: Events::Alerts::BOOK_CLOSE_KINDS, event_on: today..(today + UPCOMING_DAYS)).order(:event_on)

        render json: {
          as_of: today, days: days,
          events: events.limit(400).map { payload(_1, mine) },
          upcoming: upcoming.map { payload(_1, mine) },
          study: Events::BookCloseStudy.cached
        }
      end

      private

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
