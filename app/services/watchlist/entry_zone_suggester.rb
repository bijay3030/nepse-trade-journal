module Watchlist
  # Suggests an entry zone, invalidation level, stop and target from the same
  # analysis the screener uses.
  #
  # vcp:      buy the breakout, from the pivot up to 3% above it. The setup fails
  #           below the low of the last (tightest) contraction.
  # pullback: buy near the closest support, up to 2% above it. The setup fails
  #           3% below support.
  # The target is the nearest resistance above the zone, or 2R when there is none.
  class EntryZoneSuggester
    BREAKOUT_ZONE_PCT = 3.0
    PULLBACK_ZONE_PCT = 2.0
    SUPPORT_BREAK_PCT = 3.0
    DEFAULT_REWARD_MULTIPLE = 2.0

    # Pass `analysis:` (a Stock::SetupAnalysis#detail hash) to reuse one already computed.
    def self.call(stock, setup_type, market: nil, analysis: nil)
      new(stock, setup_type, market: market, analysis: analysis).call
    end

    def initialize(stock, setup_type, market: nil, analysis: nil)
      @stock = stock
      @setup_type = setup_type.to_s
      @market = market
      @analysis = analysis
      @precomputed = !analysis.nil?
    end

    def call
      return failure("Unknown setup type #{@setup_type.inspect}") unless WatchlistItem::SETUP_TYPES.include?(@setup_type)
      return failure("#{@stock.symbol} has no price history to analyse yet") if analysis[:candles].blank?

      levels = @setup_type == "vcp" ? vcp_levels : pullback_levels
      return levels if levels[:success] == false

      { success: true, setup_type: @setup_type, levels: levels, snapshot: snapshot }
    end

    private

    def vcp_levels
      vcp = analysis[:vcp]
      pivot = vcp[:pivot_level].to_f
      return failure("No VCP pivot found for #{@stock.symbol}. Try a pullback setup or enter levels manually.") unless pivot.positive?

      last_low = Array(vcp[:contractions]).last&.dig(:low).to_f
      invalidation = last_low.positive? && last_low < pivot ? last_low : pivot * 0.93
      build_levels(zone_low: pivot, zone_high: pivot * (1 + BREAKOUT_ZONE_PCT / 100), invalidation: invalidation, pivot: pivot)
    end

    def pullback_levels
      price = current_price
      supports = Array(analysis.dig(:price_action, :support_levels))
      support = supports.map { |zone| zone[:level].to_f }.select { |level| level.positive? && level <= price }.max
      support ||= supports.map { |zone| zone[:level].to_f }.select(&:positive?).min
      return failure("No support level found for #{@stock.symbol}. Try a VCP setup or enter levels manually.") unless support

      build_levels(
        zone_low: support,
        zone_high: support * (1 + PULLBACK_ZONE_PCT / 100),
        invalidation: support * (1 - SUPPORT_BREAK_PCT / 100),
        pivot: nil
      )
    end

    def build_levels(zone_low:, zone_high:, invalidation:, pivot:)
      risk = zone_low - invalidation
      resistance = Array(analysis.dig(:price_action, :resistance_levels))
        .map { |zone| zone[:level].to_f }
        .select { |level| level > zone_high && (level - zone_low) >= risk }
        .min
      target = resistance || zone_low + risk * DEFAULT_REWARD_MULTIPLE

      {
        entry_zone_low: zone_low.round(2),
        entry_zone_high: zone_high.round(2),
        invalidation_price: invalidation.round(2),
        stop_loss_price: invalidation.round(2),
        target_price: target.round(2),
        target_basis: resistance ? "resistance" : "#{DEFAULT_REWARD_MULTIPLE.to_i}R",
        pivot_price: pivot&.round(2)
      }
    end

    def snapshot
      vcp = analysis[:vcp]
      action = analysis[:price_action]
      {
        analysed_on: analysis[:candles].last[:traded_on],
        price: current_price,
        setup_state: analysis[:setup_state],
        vcp_score: vcp[:setup_quality_score],
        is_vcp_setup: vcp[:is_vcp_setup] || false,
        contractions_count: vcp[:contractions_count],
        contraction_sequence: vcp[:contraction_sequence_text],
        volume_behavior: vcp[:volume_behavior],
        pivot: vcp[:pivot_level],
        trend: action[:trend],
        structure: action[:structure],
        nearest_support: Array(action[:support_levels]).first&.dig(:level),
        nearest_resistance: Array(action[:resistance_levels]).first&.dig(:level),
        market_regime: analysis.dig(:market, :regime_status)
      }
    end

    # With a precomputed analysis, its close is used, so a past-date analysis never
    # sees today's live price. Otherwise the live price, falling back to the close.
    def current_price
      return analysis[:current_price].to_f if @precomputed

      live = @stock.last_price.to_f
      live.positive? ? live : analysis[:current_price].to_f
    end

    def analysis
      @analysis ||= Stock::SetupAnalysis.new(@stock, market: @market || MarketIndex::Overview.new.call).detail
    end

    def failure(message)
      { success: false, error: message }
    end
  end
end
