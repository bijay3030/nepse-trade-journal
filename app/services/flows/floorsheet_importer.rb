module Flows
  # Rolls one session's floorsheet (every trade, with buyer and seller broker) up
  # into StockBrokerFlow rows: per stock and broker, the quantity and amount bought
  # and sold. Re-running a day replaces it.
  class FloorsheetImporter
    def self.call(date, client: Nepse::Source::ChukulClient.new) = new(date, client).call

    def initialize(date, client)
      @date = date
      @client = client
    end

    def call
      response = @client.floorsheet(@date)
      return { success: false, date: @date, error: response[:error] } unless response[:success]

      trades = Array(response[:data])
      return { success: false, date: @date, error: "No trades (market closed?)" } if trades.empty?

      rows = aggregate(trades)
      StockBrokerFlow.transaction do
        StockBrokerFlow.where(traded_on: @date).delete_all
        rows.each_slice(5_000) { |slice| StockBrokerFlow.insert_all(slice) }
      end

      { success: true, date: @date, trades: trades.size, rows: rows.size, symbols: rows.map { _1[:stock_id] }.uniq.size }
    end

    private

    def aggregate(trades)
      stock_ids = Stock.pluck(:symbol, :id).to_h
      totals = Hash.new { |hash, key| hash[key] = { buy_quantity: 0, sell_quantity: 0, buy_amount: 0.0, sell_amount: 0.0, trades: 0 } }

      trades.each do |trade|
        stock_id = stock_ids[trade["symbol"].to_s.upcase]
        next unless stock_id

        quantity = trade["quantity"].to_f.round
        amount = trade["amount"].to_f
        buyer = totals[[ stock_id, trade["buyer"].to_s ]]
        buyer[:buy_quantity] += quantity
        buyer[:buy_amount] += amount
        buyer[:trades] += 1
        seller = totals[[ stock_id, trade["seller"].to_s ]]
        seller[:sell_quantity] += quantity
        seller[:sell_amount] += amount
        seller[:trades] += 1
      end

      totals.map do |(stock_id, broker_no), values|
        values.merge(stock_id: stock_id, broker_no: broker_no, traded_on: @date,
                     buy_amount: values[:buy_amount].round(2), sell_amount: values[:sell_amount].round(2))
      end
    end
  end
end
