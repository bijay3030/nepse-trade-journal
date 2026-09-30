module Flows
  # Imports the floorsheet for recent sessions that are not stored yet. Sessions
  # are the dates in the NEPSE index history (falling back to stock price dates).
  class Backfill
    def self.call(**options) = new(**options).call

    def initialize(sessions: 120, client: Nepse::Source::ChukulClient.new, force: false, delay_seconds: 0.5)
      @sessions = sessions.to_i
      @client = client
      @force = force
      @delay_seconds = delay_seconds.to_f
    end

    def call
      dates = recent_sessions
      dates -= StockBrokerFlow.distinct.pluck(:traded_on) unless @force
      summary = { success: true, imported: [], failed: {} }

      dates.sort.each_with_index do |date, index|
        sleep(@delay_seconds) if index.positive? && @delay_seconds.positive?
        result = FloorsheetImporter.call(date, client: @client)
        result[:success] ? summary[:imported] << date : summary[:failed][date] = result[:error]
      end

      summary
    end

    private

    def recent_sessions
      nepse = MarketIndex.find_by(symbol: "NEPSE")
      dates = nepse&.histories&.order(traded_on: :desc)&.limit(@sessions)&.pluck(:traded_on)
      dates.presence || StockDailyPrice.distinct.order(traded_on: :desc).limit(@sessions).pluck(:traded_on)
    end
  end
end
