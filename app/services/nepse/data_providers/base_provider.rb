module Nepse
  module DataProviders
    class BaseProvider
      def fetch_daily_prices(date = Date.current)
        raise NotImplementedError, "#{self.class.name}#fetch_daily_prices must be implemented"
      end

      def fetch_historical_prices(symbol, start_date: nil, end_date: nil)
        raise NotImplementedError, "#{self.class.name}#fetch_historical_prices must be implemented"
      end

      def fetch_stock_metadata
        raise NotImplementedError, "#{self.class.name}#fetch_stock_metadata must be implemented"
      end

      def fetch_market_summary
        raise NotImplementedError, "#{self.class.name}#fetch_market_summary must be implemented"
      end
    end
  end
end
