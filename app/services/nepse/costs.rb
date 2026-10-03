module Nepse
  # Trading costs on NEPSE equities (individual investors):
  #
  #   broker commission  by transaction value (SEBON slabs from 2024-05-14):
  #                      up to 50,000 0.36% · to 5 lakh 0.33% · to 20 lakh 0.306% ·
  #                      to 1 crore 0.27% · above 0.243%
  #   SEBON fee          0.015% of the transaction value, on buys and sells
  #   DP charge          Rs 25 per stock per day, on the sell side
  #
  # Capital gains tax applies to gains when selling and is handled when a position is closed.
  module Costs
    COMMISSION_SLABS = [
      [ 50_000, 0.0036 ], [ 500_000, 0.0033 ], [ 2_000_000, 0.00306 ], [ 10_000_000, 0.0027 ], [ Float::INFINITY, 0.00243 ]
    ].freeze
    SEBON_RATE = 0.00015
    DP_CHARGE = 25.0
    LOT_SIZE = 10

    module_function

    def commission_rate(amount) = COMMISSION_SLABS.find { |limit, _| amount <= limit }.last

    def commission(amount) = (amount * commission_rate(amount)).round(2)
    def sebon_fee(amount) = (amount * SEBON_RATE).round(2)

    # { amount:, commission:, sebon:, dp:, total: } for one buy or sell of `amount` rupees.
    def breakdown(amount, side:)
      amount = amount.to_f
      parts = { commission: commission(amount), sebon: sebon_fee(amount), dp: side == :sell ? DP_CHARGE : 0.0 }
      { amount: amount.round(2), **parts, total: parts.values.sum.round(2) }
    end

    def buy_costs(amount) = breakdown(amount, side: :buy)[:total]
    def sell_costs(amount) = breakdown(amount, side: :sell)[:total]

    # What selling `quantity` shares at `price` leaves after the sell-side costs.
    def net_proceeds(price, quantity)
      amount = price.to_f * quantity
      (amount - sell_costs(amount)).round(2)
    end

    # The sell price at which the proceeds after costs cover `total_cost`.
    def break_even_price(total_cost, quantity)
      return if quantity.to_i <= 0

      price = total_cost.to_f / quantity
      # The commission rate depends on the amount, so settle on it in a few steps.
      3.times { price = (total_cost + DP_CHARGE) / (quantity * (1 - commission_rate(price * quantity) - SEBON_RATE)) }
      price.round(2)
    end
  end
end
