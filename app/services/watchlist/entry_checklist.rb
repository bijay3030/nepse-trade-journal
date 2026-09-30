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

    def vcp? = @item.setup_type == "vcp"

    def pattern_check
      if vcp?
        failing = vcp[:qualification_checks].to_a.reject { _1[:passed] }.map { _1[:label] }
        check("pattern", "Qualified VCP", vcp[:is_vcp_setup] ? "pass" : "fail",
              vcp[:is_vcp_setup] ? "Score #{vcp[:setup_quality_score]}, #{vcp[:contraction_sequence_text]}" : "Not met: #{failing.first(3).join('; ').presence || vcp[:classification].to_s.tr('_', ' ')}")
      else
        trend = price_action[:trend]
        check("pattern", "Price-action trend is up", trend == "uptrend" ? "pass" : "fail", "Trend #{trend || 'unknown'}, structure #{price_action[:structure].to_s.tr('_', ' ')}")
      end
    end

    def close_check
      state = @item.last_close_state
      label = vcp? ? "Closed above the pivot" : "Closed inside the entry zone"
      return check("close", label, "pending", "Judged after the 4 PM close") if state.nil?

      passed = vcp? ? %w[confirmed unconfirmed].include?(state) : state == "held_zone"
      check("close", label, passed ? "pass" : "fail", "#{@item.last_close_on&.strftime('%b %-d')}: closed #{format('%.2f', @item.last_close_price.to_f)} (#{state.tr('_', ' ')})")
    end

    def volume_check
      label = "Volume at least #{CloseEvaluator::CONFIRM_VOLUME_MULTIPLE}x average at the close"
      return check("volume", label, "n/a", "Not used for pullbacks") unless vcp?
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

    def price_action
      @price_action ||= PriceAction::AnalyzerService.call(prices)
    end
  end
end
