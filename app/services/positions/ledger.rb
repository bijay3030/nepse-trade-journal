module Positions
  # Matches a position's sells against its buys first-in, first-out, for realized P&L
  # and capital gains tax (CGT).
  #
  # Each buy lot carries its cost including commission and SEBON; each sell's proceeds
  # are after commission, SEBON and the DP charge. A sell is split across the lots it
  # uses, proportionally. CGT for individuals: 10% on a lot held up to LONG_TERM_DAYS,
  # 7.5% beyond, on each sell's net gain (a loss isn't taxed or carried over).
  class Ledger
    SHORT_TERM_RATE = 0.10
    LONG_TERM_RATE = 0.075
    LONG_TERM_DAYS = 365

    Lot = Struct.new(:traded_on, :quantity, :unit_cost, keyword_init: true)

    attr_reader :sales, :open_lots

    def initialize(fills)
      @open_lots = []
      @sales = []
      fills.sort_by { [ _1.traded_on, _1.buy? ? 0 : 1, _1.id.to_i ] }.each { _1.buy? ? add_buy(_1) : add_sell(_1) }
    end

    # Totals over every sale.
    def realized
      gross = sales.sum { _1[:gain] }
      tax = sales.sum { _1[:tax] }
      { proceeds: sales.sum { _1[:proceeds] }.round(2), cost: sales.sum { _1[:cost] }.round(2),
        gain: gross.round(2), tax: tax.round(2), net: (gross - tax).round(2) }
    end

    # What the shares still held cost, from their own lots.
    def open_cost = open_lots.sum { _1.quantity * _1.unit_cost }.round(2)
    def open_quantity = open_lots.sum(&:quantity)

    private

    def add_buy(fill)
      amount = fill.price.to_f * fill.quantity
      @open_lots << Lot.new(traded_on: fill.traded_on, quantity: fill.quantity, unit_cost: (amount + Nepse::Costs.buy_costs(amount)) / fill.quantity)
    end

    def add_sell(fill)
      proceeds = Nepse::Costs.net_proceeds(fill.price, fill.quantity)
      remaining = fill.quantity
      pieces = []
      while remaining.positive? && (lot = @open_lots.first)
        used = [ lot.quantity, remaining ].min
        share = proceeds * used / fill.quantity
        cost = lot.unit_cost * used
        days = (fill.traded_on - lot.traded_on).to_i
        pieces << { quantity: used, cost: cost, proceeds: share, days: days, rate: days > LONG_TERM_DAYS ? LONG_TERM_RATE : SHORT_TERM_RATE }
        lot.quantity -= used
        @open_lots.shift if lot.quantity.zero?
        remaining -= used
      end

      gain = pieces.sum { _1[:proceeds] - _1[:cost] }
      tax = [ pieces.sum { (_1[:proceeds] - _1[:cost]) * _1[:rate] }, 0 ].max
      @sales << { fill_id: fill.id, traded_on: fill.traded_on, quantity: fill.quantity, price: fill.price.to_f,
                  proceeds: proceeds, cost: pieces.sum { _1[:cost] }.round(2), gain: gain.round(2), tax: gain.positive? ? tax.round(2) : 0.0,
                  days_held: pieces.map { _1[:days] }.max }
    end
  end
end
