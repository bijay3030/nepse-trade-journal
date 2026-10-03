module Positions
  # How many shares to buy so that hitting the stop loses at most `risk_pct` of
  # capital, counting the buy costs and the sell costs at the stop. Rounded down to
  # 10-share lots and never more than the capital buys. A sizing aid, not advice.
  module Sizer
    LOT = Nepse::Costs::LOT_SIZE

    module_function

    def call(capital:, risk_pct:, entry:, stop:, target: nil)
      capital, risk_pct, entry, stop = [ capital, risk_pct, entry, stop ].map(&:to_f)
      return { error: "Set your trading capital and risk per trade in Settings" } unless capital.positive? && risk_pct.positive?
      return { error: "The stop must be below the entry price" } unless entry.positive? && stop.positive? && stop < entry

      budget = capital * risk_pct / 100
      by_risk = (budget / (entry - stop)).floor
      by_capital = (capital / entry).floor
      quantity = round_to_lot([ by_risk, by_capital ].min)
      quantity -= LOT while quantity.positive? && (loss_at(stop, quantity, entry) > budget || total_cost(entry, quantity) > capital)

      result = { risk_budget: budget.round(2), lot_size: LOT, limited_by: by_capital < by_risk ? "capital" : "risk" }
      return result.merge(quantity: 0, note: "Your risk budget is smaller than the loss on one #{LOT}-share lot at this stop") if quantity.zero?

      result.merge(details(entry, stop, target.to_f, quantity, capital))
    end

    # The cost, loss at the stop, break-even and target figures for a given quantity.
    def details(entry, stop, target, quantity, capital = nil)
      amount = entry * quantity
      buy = Nepse::Costs.breakdown(amount, side: :buy)
      cost = (amount + buy[:total]).round(2)
      loss = loss_at(stop, quantity, entry)
      gain = target.positive? ? (Nepse::Costs.net_proceeds(target, quantity) - cost).round(2) : nil
      {
        quantity: quantity, amount: amount.round(2), buy_costs: buy, total_cost: cost,
        loss_at_stop: loss, loss_pct_of_capital: capital&.positive? ? (loss / capital * 100).round(2) : nil,
        break_even: Nepse::Costs.break_even_price(cost, quantity),
        gain_at_target: gain, reward_risk: gain && loss.positive? ? (gain / loss).round(2) : nil
      }
    end

    def total_cost(entry, quantity) = entry * quantity + Nepse::Costs.buy_costs(entry * quantity)
    def loss_at(stop, quantity, entry) = (total_cost(entry, quantity) - Nepse::Costs.net_proceeds(stop, quantity)).round(2)
    def round_to_lot(quantity) = [ quantity / LOT * LOT, 0 ].max
  end
end
