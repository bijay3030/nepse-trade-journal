require "rails_helper"

RSpec.describe Scanner::Engine do
  let(:date) { Date.current }

  let(:market_config) do
    MarketContext::Configuration.new(
      medium_liquidity_turnover: 10_000.0,
      high_liquidity_turnover: 1_000_000.0,
      sector_trend_window: 5
    )
  end

  let(:vcp_bars) do
    highs = [ 180, 185, 192, 198, 200, 192, 184, 172, 164, 172, 180, 186, 189, 190, 184, 178, 172, 171, 176, 181, 184, 185, 182, 178, 176, 179, 182, 184 ]
    vols = [ 100, 120, 150, 180, 200, 180, 160, 140, 120, 110, 100, 90, 85, 80, 75, 70, 65, 60, 55, 50, 45, 40, 35, 30, 25, 20, 18, 15 ]

    highs.map.with_index do |high, i|
      low = high - (i < 10 ? 8 : (i < 20 ? 5 : 3))
      close = (high + low) / 2.0
      {
        open: close - 1.0,
        high: high.to_f,
        low: low.to_f,
        close: close,
        volume: vols[i] * 100
      }
    end
  end

  def permissive_config(**overrides)
    Scanner::Configuration.new(
      min_liquidity_rating: "low",
      allowed_trends: nil,
      require_above_sma50: false,
      require_above_sma200: false,
      min_vcp_score: 0.0,
      only_included: false,
      market_config: market_config,
      **overrides
    )
  end

  def uptrend_closes(count: 60, start: 100.0)
    (0...count).map { |i| start + i }
  end

  def create_history(stock, closes:, volume: 2_000, turnover: 2_000_000.0, trades: 50)
    start = date - (closes.size - 1)
    closes.each_with_index do |close, i|
      create(
        :stock_daily_price,
        stock: stock,
        traded_on: start + i,
        open_price: close,
        high_price: close,
        low_price: close,
        close_price: close,
        previous_close: i.zero? ? close : closes[i - 1],
        volume: volume,
        turnover: turnover,
        total_trades: trades
      )
    end
  end

  def create_bars(stock, bars)
    start = date - (bars.size - 1)
    bars.each_with_index do |bar, i|
      create(
        :stock_daily_price,
        stock: stock,
        traded_on: start + i,
        open_price: bar[:open],
        high_price: bar[:high],
        low_price: bar[:low],
        close_price: bar[:close],
        previous_close: i.zero? ? bar[:close] : bars[i - 1][:close],
        volume: bar[:volume],
        turnover: bar[:close].to_f * bar[:volume],
        total_trades: 50
      )
    end
  end

  describe "#scan output" do
    it "returns a fully populated candidate payload" do
      stock = create(:stock, symbol: "HAPPY")
      create_history(stock, closes: uptrend_closes)

      candidate = described_class.call(stocks: [ stock ], date: date, config: permissive_config).first

      expect(candidate[:included]).to be true
      expect(candidate[:symbol]).to eq("HAPPY")
      expect(candidate[:reasons_for_inclusion]).not_to be_empty
      expect(candidate.keys).to include(
        :current_price, :vcp_score, :price_action_state, :trend_state, :volume_state,
        :pivot, :distance_to_pivot, :support, :resistance, :market_regime, :sector,
        :liquidity_metrics, :reasons_for_exclusion
      )
      expect(candidate[:trend_state]).to eq("uptrend")
      expect(candidate[:liquidity_metrics][:rating]).to eq("high")
      expect(candidate[:market_regime]).to be_in(%w[strong neutral weak])
      expect(candidate[:sector]).to eq(stock.sector)
    end

    it "orders included candidates by VCP score as a display convenience" do
      flat_stock = create(:stock, symbol: "FLATONE")
      create_history(flat_stock, closes: uptrend_closes)

      vcp_stock = create(:stock, symbol: "VCPONE")
      create_bars(vcp_stock, vcp_bars)

      included = described_class.call(stocks: [ flat_stock, vcp_stock ], date: date, config: permissive_config)
                              .select { |candidate| candidate[:included] }

      expect(included.map { |candidate| candidate[:symbol] }).to eq(%w[VCPONE FLATONE])
      expect(included.first[:vcp_score]).to be > included.last[:vcp_score]
    end

    it "exposes a decomposable VCP score breakdown" do
      stock = create(:stock, symbol: "DECOMP")
      create_bars(stock, vcp_bars)

      candidate = described_class.call(stocks: [ stock ], date: date, config: permissive_config).first
      breakdown = candidate[:vcp_breakdown]

      expect(breakdown.map { |component| component[:component] }).to contain_exactly(
        "trend", "price_contraction", "volume_contraction", "tightness", "pivot_proximity"
      )
      expect(breakdown.sum { |component| component[:max] }).to eq(100)
      expect(breakdown.sum { |component| component[:score] }).to eq(candidate[:vcp_score])
      expect(candidate[:vcp_score]).to be >= 60
    end

    it "is exposed through Scanner.scan" do
      stock = create(:stock, symbol: "TOPLEVEL")
      create_history(stock, closes: uptrend_closes)

      results = Scanner.scan(stocks: [ stock ], date: date, config: permissive_config)

      expect(results.map { |candidate| candidate[:symbol] }).to eq(%w[TOPLEVEL])
    end
  end

  describe "stage 1 - liquidity" do
    it "removes stocks that do not satisfy minimum liquidity" do
      stock = create(:stock, symbol: "THIN")
      create_history(stock, closes: uptrend_closes, volume: 0, turnover: 0.0, trades: 0)

      candidate = described_class.call(
        stocks: [ stock ], date: date, config: permissive_config(min_liquidity_rating: "medium")
      ).first

      expect(candidate[:included]).to be false
      expect(candidate[:excluded_at_stage]).to eq(:liquidity)
      expect(candidate[:reasons_for_exclusion].first).to match(/Liquidity rating low/)
    end
  end

  describe "stage 2 - trend" do
    it "removes stocks that fail the configured trend conditions" do
      stock = create(:stock, symbol: "DOWNTREND")
      create_history(stock, closes: uptrend_closes(count: 57) + [ 100.0, 90.0, 80.0 ])

      candidate = described_class.call(
        stocks: [ stock ], date: date, config: permissive_config(allowed_trends: %w[uptrend])
      ).first

      expect(candidate[:trend_state]).to eq("downtrend")
      expect(candidate[:included]).to be false
      expect(candidate[:excluded_at_stage]).to eq(:trend)
    end
  end

  describe "stage 3 - price position" do
    it "filters candidates too far below their 52-week high" do
      stock = create(:stock, symbol: "FARHIGH")
      closes = (0...30).map { |i| 100.0 + (i * 5) } + (0...30).map { |i| 245.0 - (i * 5) }
      create_history(stock, closes: closes)

      candidate = described_class.call(
        stocks: [ stock ], date: date, config: permissive_config(max_pct_below_52w_high: 10.0)
      ).first

      expect(candidate[:pct_below_high_52w]).to be > 10.0
      expect(candidate[:excluded_at_stage]).to eq(:price_position)
    end
  end

  describe "stage 4 - VCP" do
    it "removes stocks that do not meet the VCP score threshold" do
      stock = create(:stock, symbol: "NOVCP")
      create_history(stock, closes: uptrend_closes)

      candidate = described_class.call(
        stocks: [ stock ], date: date, config: permissive_config(min_vcp_score: 50.0)
      ).first

      expect(candidate[:vcp_score]).to be < 50.0
      expect(candidate[:excluded_at_stage]).to eq(:vcp)
    end
  end

  describe "stage 5 - price action" do
    it "removes stocks that fail price-action structure requirements" do
      stock = create(:stock, symbol: "NOPA")
      create_history(stock, closes: uptrend_closes)

      candidate = described_class.call(
        stocks: [ stock ], date: date,
        config: permissive_config(allowed_structures: %w[higher_high_higher_low])
      ).first

      expect(candidate[:price_action_state]).to eq("insufficient_swings")
      expect(candidate[:excluded_at_stage]).to eq(:price_action)
    end

    it "attaches support, resistance, and breakout proximity" do
      stock = create(:stock, symbol: "PALEVELS")
      create_bars(stock, vcp_bars)

      candidate = described_class.call(stocks: [ stock ], date: date, config: permissive_config).first

      expect(candidate).to include(:support, :resistance, :breakout_level, :distance_to_breakout, :is_breakout_near)
      expect(candidate[:price_action_state]).to be_present
    end
  end

  describe "stage 6 - market and sector context" do
    it "attaches market regime and sector context" do
      stock = create(:stock, symbol: "CTX", sector: "Commercial Banks")
      create_history(stock, closes: uptrend_closes)

      candidate = described_class.call(stocks: [ stock ], date: date, config: permissive_config).first

      expect(candidate[:market_regime]).to eq(candidate[:market_context][:regime_status])
      expect(candidate[:market_context]).to include(:regime_status, :index_sma20, :advancing_stocks, :market_breadth_pct)
      expect(candidate[:sector_context][:sector]).to eq("Commercial Banks")
    end

    it "can exclude candidates whose market regime is not allowed" do
      stock = create(:stock, symbol: "REGIME")
      create_history(stock, closes: uptrend_closes)

      candidate = described_class.call(
        stocks: [ stock ], date: date, config: permissive_config(allowed_regimes: %w[strong])
      ).first

      expect(candidate[:included]).to be false
      expect(candidate[:excluded_at_stage]).to eq(:context)
      expect(candidate[:reasons_for_exclusion].first).to match(/Market regime/)
    end
  end

  describe "#scan filtering" do
    it "returns only included candidates by default" do
      stock = create(:stock, symbol: "ONLY")
      create_history(stock, closes: uptrend_closes)

      results = described_class.call(stocks: [ stock ], date: date, config: permissive_config(only_included: true))

      expect(results.map { |candidate| candidate[:symbol] }).to eq(%w[ONLY])
    end

    it "caps the number of returned candidates" do
      3.times { |i| create_history(create(:stock, symbol: "CAP#{i}"), closes: uptrend_closes) }

      results = described_class.call(stocks: Stock.active, date: date, config: permissive_config(max_candidates: 2))

      expect(results.size).to eq(2)
    end
  end
end
