module Nepse
  module DataProviders
    class Factory
      PROVIDERS = {
        yonepse: YonepseProvider,
        historical: HistoricalDataProvider
      }.freeze

      def self.for(provider_key = nil, **options)
        key = (provider_key || ENV["DEFAULT_MARKET_DATA_PROVIDER"] || :yonepse).to_s.downcase.to_sym
        provider_class = PROVIDERS[key]

        raise ArgumentError, "Unknown market data provider: #{provider_key}" unless provider_class

        provider_class.new(**options)
      end
    end
  end
end
