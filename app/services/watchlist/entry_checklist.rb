module Watchlist
  # The conditions to check before entering a watchlist setup. Each check is
  # "pass", "fail", "pending" (not known yet, e.g. no close since adding) or "n/a".
  # It describes the setup against fixed rules; it is not a recommendation.
  class EntryChecklist
    MIN_RISK_REWARD = 2.0

    def self.call(item, context: MarketContext.call)
      new(item, context).call
    end

    def initialize(item, context)
      @item = item
      @context = context
    end

    def call
      checks = [ pattern_check, close_check, volume_check, regime_check, sector_check, risk_reward_check, chasing_check ].compact
      applicable = checks.reject { _1[:status] == "n/a" }
      {
        checks: checks,
        passed: applicable.count { _1[:status] == "pass" },
        total: applicable.size,
        all_passed: applicable.any? && applicable.all? { _1[:status] == "pass" }
      }
    end

    private

    def breakout? = Setups::Types.breakout?(@item.setup_type)

    def pattern_check
      case @item.setup_type
      when "vcp"
        failing = vcp[:qualification_checks].to_a.reject { _1[:passed] }.map { _1[:label] }
        check("pattern", "Qualified VCP", vcp[:is_vcp_setup] ? "pass" : "fail",
              vcp[:is_vcp_setup] ? "Score #{vcp[:setup_quality_score]}, #{vcp[:contraction_sequence_text]}" : "Not met: #{failing.first(3).join('; ').presence || vcp[:classification].to_s.tr('_', ' ')}")
      when "ma_pullback"
        result = Setups::Patterns.ma_pullback(candles)
        detail = result[:success] ? "Near the rising #{result.dig(:details, :anchor)} average (#{result.dig(:details, :anchor_value)})" : result[:error]
        check("pattern", "Uptrend above a rising average", result[:success] ? "pass" : "fail", detail)
      when "base_breakout"
        result = Setups::Patterns.base_breakout(candles)
        detail = result[:success] ? "#{result.dig(:details, :base_sessions)}-session base, #{result.dig(:details, :base_depth_pct)}% deep" : result[:error]
        check("pattern", "Flat base near the 52-week high", result[:success] ? "pass" : "fail", detail)
      else
        trend = price_action[:trend]
        check("pattern", "Price-action trend is up", trend == "uptrend" ? "pass" : "fail", "Trend #{trend || 'unknown'}, structure #{price_action[:structure].to_s.tr('_', ' ')}")
      end
    end

    def close_check
      state = @item.last_close_state
      label = breakout? ? "Closed above the pivot" : "Closed inside the entry zone"
      return check("close", label, "pending", "Judged after the 4 PM close") if state.nil?

      passed = breakout? ? %w[confirmed unconfirmed].include?(state) : state == "held_zone"
      check("close", label, passed ? "pass" : "fail", "#{@item.last_close_on&.strftime('%b %-d')}: closed #{format('%.2f', @item.last_close_price.to_f)} (#{state.tr('_', ' ')})")
    end

    def volume_check
      label = "Volume at least #{CloseEvaluator::CONFIRM_VOLUME_MULTIPLE}x average at the close"
      return check("volume", label, "n/a", "Not used for pullbacks") unless breakout?
      return check("volume", label, "pending", "Judged after the 4 PM close") if @item.last_close_relative_volume.nil?

      ratio = @item.last_close_relative_volume.to_f
      check("volume", label, ratio >= CloseEvaluator::CONFIRM_VOLUME_MULTIPLE ? "pass" : "fail", "#{ratio}x on #{@item.last_close_on&.strftime('%b %-d')}")
    end

    def regime_check
      regime = @context.regime
      check("regime", "Market regime not weak", regime.nil? ? "pending" : (regime == "weak" ? "fail" : "pass"), "Market #{regime || 'unknown'}")
    end

    def sector_check
      sector = @item.stock.sector
      sector_return = @context.sector_returns[sector]
      label = "Sector stronger than NEPSE (#{MarketContext::STRENGTH_SESSIONS} sessions)"
      return check("sector", label, "n/a", "No index for #{sector}") if sector_return.nil? || @context.nepse_return.nil?

      check("sector", label, sector_return > @context.nepse_return ? "pass" : "fail",
            "#{sector} #{signed(sector_return)} vs NEPSE #{signed(@context.nepse_return)}")
    end

    def risk_reward_check
      rr = @item.risk_reward
      label = "Risk:reward at least #{MIN_RISK_REWARD.to_i}R"
      return check("risk_reward", label, "fail", "Set a stop and target") if rr.nil?

      check("risk_reward", label, rr >= MIN_RISK_REWARD ? "pass" : "fail", "#{rr}R")
    end

    def chasing_check
      price = @item.stock.last_price.to_f
      check("not_extended", "Price not above the entry zone", price <= @item.entry_zone_high.to_f ? "pass" : "fail",
            "#{format('%.2f', price)} vs zone high #{format('%.2f', @item.entry_zone_high.to_f)}")
    end

    def check(key, label, status, detail)
      { key: key, label: label, status: status, detail: detail }
    end

    def signed(value) = format("%+.2f%%", value)

    def prices
      @prices ||= @item.stock.daily_prices.order(:traded_on).last(200)
    end

    def vcp
      @vcp ||= Vcp::DetectionEngine.call(prices)
    end

    # The same candle shape Stock::SetupAnalysis produces, for Setups::Patterns.
    def candles
      @candles ||= begin
        indicators = @item.stock.daily_indicators.where(traded_on: prices.map(&:traded_on)).index_by(&:traded_on)
        prices.map do |price|
          indicator = indicators[price.traded_on]
          { traded_on: price.traded_on.iso8601, open: price.open_price.to_f, high: price.high_price.to_f, low: price.low_price.to_f,
            close: price.close_price.to_f, volume: price.volume, sma_20: indicator&.sma_20&.to_f,
            sma_50: indicator&.sma_50&.to_f, sma_200: indicator&.sma_200&.to_f }
        end
      end
    end

    def price_action
      @price_action ||= PriceAction::AnalyzerService.call(prices)
    end
  end
end
