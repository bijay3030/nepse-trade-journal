module Flows
  # Broker accumulation from the floorsheet totals.
  #
  # Over a window of recent sessions, net each broker's buying against its selling.
  # Top buyers' share = net quantity of the 5 largest net buyers / volume;
  # top sellers' share = the same for the 5 largest net sellers. The flow score is
  # buyers' share minus sellers' share, in percentage points: positive when a few
  # brokers absorb what many sell (accumulation), negative when a few unload onto
  # many (distribution). The 20-session window sets the state.
  class AccumulationAnalyzer
    WINDOWS = [ 5, 20 ].freeze
    STATE_WINDOW = 20
    TOP_BROKERS = 5
    ACCUMULATION_SCORE = 10.0
    MIN_SESSIONS = 5
    # Below this turnover over the 20-session window (~NPR 1M a day) one client's
    # orders can dominate, so the state stays neutral and the result is marked thin.
    MIN_WINDOW_TURNOVER = 20_000_000

    # Stocks per query in for_stocks: a session has ~12,000 broker rows across the
    # market, so loading every stock at once costs over 100 MB.
    SLICE = 40

    # { stock_id => result } for many stocks, SLICE stocks per query.
    def self.for_stocks(stock_ids, as_of: nil)
      dates = session_dates(as_of)
      return {} if dates.empty?

      names = Broker.pluck(:broker_no, :name).to_h
      Array(stock_ids).each_slice(SLICE).each_with_object({}) do |slice, results|
        rows = StockBrokerFlow.where(stock_id: slice, traded_on: dates)
          .pluck(:stock_id, :traded_on, :broker_no, :buy_quantity, :sell_quantity, :buy_amount, :sell_amount)
        rows.group_by(&:first).each { |stock_id, stock_rows| results[stock_id] = new(stock_rows, dates, names).call }
      end
    end

    def self.call(stock, as_of: nil)
      for_stocks([ stock.id ], as_of: as_of)[stock.id] || empty
    end

    def self.session_dates(as_of)
      scope = StockBrokerFlow.distinct.order(traded_on: :desc)
      scope = scope.where("traded_on <= ?", as_of) if as_of
      scope.limit(WINDOWS.max).pluck(:traded_on)
    end

    def self.empty
      { state: "no_data", score: nil, thin_trading: false, sessions: 0, windows: {}, top_buyers: [], top_sellers: [], daily: [] }
    end

    def initialize(rows, dates, names)
      # rows: [stock_id, traded_on, broker_no, buy_qty, sell_qty, buy_amount, sell_amount]
      @rows = rows
      @dates = dates.sort
      @names = names
    end

    def call
      sessions = @rows.map { _1[1] }.uniq.size
      return self.class.empty.merge(sessions: sessions) if sessions < MIN_SESSIONS

      windows = WINDOWS.to_h { |size| [ size, window(@dates.last(size)) ] }
      main = windows[STATE_WINDOW]
      thin = main[:turnover] < MIN_WINDOW_TURNOVER
      {
        state: thin ? "neutral" : state(main[:score]),
        score: main[:score],
        thin_trading: thin,
        sessions: sessions,
        windows: windows.transform_values { _1.except(:brokers) },
        top_buyers: main[:brokers].first(TOP_BROKERS).select { _1[:net_quantity].positive? },
        top_sellers: main[:brokers].last(TOP_BROKERS).reverse.select { _1[:net_quantity].negative? },
        daily: daily_series(main[:brokers])
      }
    end

    private

    def state(score)
      if score >= ACCUMULATION_SCORE then "accumulation"
      elsif score <= -ACCUMULATION_SCORE then "distribution"
      else "neutral"
      end
    end

    def window(dates)
      rows = @rows.select { dates.include?(_1[1]) }
      volume = rows.sum { _1[3] }.to_f
      turnover = rows.sum { _1[5].to_f }
      brokers = rows.group_by { _1[2] }.map do |broker_no, broker_rows|
        bought = broker_rows.sum { _1[3] }
        sold = broker_rows.sum { _1[4] }
        {
          broker_no: broker_no,
          name: @names[broker_no],
          net_quantity: bought - sold,
          bought: bought,
          sold: sold,
          avg_buy_price: bought.positive? ? (broker_rows.sum { _1[5].to_f } / bought).round(2) : nil,
          avg_sell_price: sold.positive? ? (broker_rows.sum { _1[6].to_f } / sold).round(2) : nil
        }
      end.sort_by { [ -_1[:net_quantity], _1[:broker_no] ] } # broker number breaks ties, for a stable order

      buyers = brokers.first(TOP_BROKERS).sum { [ _1[:net_quantity], 0 ].max }
      sellers = brokers.last(TOP_BROKERS).sum { -[ _1[:net_quantity], 0 ].min }
      buyers_pct = volume.positive? ? (buyers / volume * 100).round(2) : 0.0
      sellers_pct = volume.positive? ? (sellers / volume * 100).round(2) : 0.0
      {
        sessions: dates.size, volume: volume.to_i, turnover: turnover.round,
        top_buyers_pct: buyers_pct, top_sellers_pct: sellers_pct, score: (buyers_pct - sellers_pct).round(2),
        brokers: brokers.map { _1.merge(share_pct: volume.positive? ? (_1[:net_quantity] / volume * 100).round(2) : 0.0) }
      }
    end

    # Per session: net quantity of the window's top buyers and top sellers.
    def daily_series(brokers)
      buyers = brokers.first(TOP_BROKERS).select { _1[:net_quantity].positive? }.map { _1[:broker_no] }
      sellers = brokers.last(TOP_BROKERS).select { _1[:net_quantity].negative? }.map { _1[:broker_no] }
      @dates.last(STATE_WINDOW).map do |date|
        day = @rows.select { _1[1] == date }
        net = ->(numbers) { day.select { numbers.include?(_1[2]) }.sum { _1[3] - _1[4] } }
        { traded_on: date.iso8601, top_buyers_net: net.(buyers), top_sellers_net: net.(sellers), volume: day.sum { _1[3] } }
      end
    end
  end
end
