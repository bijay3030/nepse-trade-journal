module Positions
  # Portfolio heat and concentration for a user's open positions, against their
  # trading capital. A risk-management aid, not advice.
  #
  #   heat     what's lost if every stop is hit (after costs), as % of capital, against
  #            max_open_risk_pct: "ok" under WARN_SHARE of the limit, "near" up to it, "over" above
  #   sectors  market value per sector as % of capital, flagged over max_sector_pct
  #   cash     capital minus what the open positions cost
  class Portfolio
    WARN_SHARE = 0.8

    def self.call(user, positions: nil) = new(user, positions).call

    def initialize(user, positions)
      @user = user
      @positions = (positions || user.positions.open.includes(:stock, :fills)).select { _1.quantity.positive? }
    end

    def call
      capital = @user.trading_capital.to_f
      risk = @positions.sum(&:open_risk)
      invested = @positions.sum(&:cost_basis)
      value = @positions.sum { _1.last_price * _1.quantity }
      {
        capital: capital.positive? ? capital : nil,
        open_risk: risk.round(2), market_value: value.round(2), invested: invested.round(2),
        cash: capital.positive? ? (capital - invested).round(2) : nil,
        heat: heat(capital, risk),
        positions: @positions.map do |position|
          { position_id: position.id, symbol: position.stock.symbol, open_risk: position.open_risk,
            heat_pct: pct(position.open_risk, capital), share_of_risk_pct: pct(position.open_risk, risk) }
        end,
        sectors: sectors(capital)
      }
    end

    # Heat with `extra_risk` added (a planned buy's loss at its stop). Pass `open_risk`
    # to reuse an already computed total.
    def self.heat_for(user, extra_risk: 0, open_risk: nil)
      open_risk ||= user.positions.open.includes(:stock, :fills).sum(&:open_risk)
      new(user, []).send(:heat, user.trading_capital.to_f, open_risk + extra_risk.to_f)
    end

    private

    def heat(capital, risk)
      limit = @user.max_open_risk_pct.to_f
      return { pct: nil, limit_pct: limit, state: "unknown", room: nil } unless capital.positive?

      used = risk / capital * 100
      state = if used > limit then "over"
      elsif used >= limit * WARN_SHARE then "near"
      else "ok"
      end
      { pct: used.round(2), limit_pct: limit, state: state, room: [ capital * limit / 100 - risk, 0 ].max.round(2) }
    end

    def sectors(capital)
      limit = @user.max_sector_pct.to_f
      @positions.group_by { _1.stock.sector.presence || "Other" }.map do |sector, group|
        value = group.sum { _1.last_price * _1.quantity }
        share = capital.positive? ? value / capital * 100 : nil
        { sector: sector, value: value.round(2), pct: share&.round(2), symbols: group.map { _1.stock.symbol }.sort, over: share ? share > limit : false }
      end.sort_by { -_1[:value] }
    end

    def pct(part, whole) = whole.positive? ? (part / whole * 100).round(2) : nil
  end
end
