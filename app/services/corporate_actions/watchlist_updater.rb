module CorporateActions
  # Keeps watchlist setups in step with book closes:
  # - warns once, WARN_DAYS before a book close, that the price will be adjusted;
  # - after a bonus book close, divides the item's levels by (1 + bonus%), the same
  #   adjustment the price gets, so the zone and stop still line up with the chart.
  class WatchlistUpdater
    WARN_DAYS = 5

    def self.call(on: Nepse::MarketHours.today) = new(on).call

    def initialize(on)
      @on = on
    end

    def call
      summary = { warned: 0, adjusted: 0 }
      WatchlistItem.tracked.includes(:stock).find_each do |item|
        summary[:warned] += 1 if warn(item)
        summary[:adjusted] += adjust(item)
      end
      summary
    end

    private

    def warn(item)
      upcoming = Upcoming.for_stock(item.stock, on: @on)
      return false unless upcoming && upcoming[:days_until] <= WARN_DAYS
      # On the day of a bonus book close the "levels adjusted" alert says it all.
      return false if upcoming[:days_until].zero? && upcoming[:bonus_percent].to_f.positive?

      return false if item.alerts.where(kind: "book_close_soon").where("message LIKE ?", "%FY #{upcoming[:fiscal_year]}%").exists?

      entitlement = [ ("#{upcoming[:bonus_percent]}% bonus" if upcoming[:bonus_percent].to_f.positive?),
                      ("#{upcoming[:cash_percent]}% cash" if upcoming[:cash_percent].to_f.positive?) ].compact.join(" and ")
      message = "#{item.stock.symbol} book close on #{upcoming[:book_close_on].strftime('%b %-d')} (FY #{upcoming[:fiscal_year]}#{entitlement.present? ? ", #{entitlement}" : ''})."
      message += " The price will be adjusted for the bonus; your levels will be adjusted to match." if upcoming[:bonus_percent].to_f.positive?
      item.alerts.create!(user: item.user, kind: "book_close_soon", message: message)
      true
    end

    # Bonus book closes on or before today, after the item was added, not yet applied.
    def adjust(item)
      applied = item.level_adjustments.map { _1["fiscal_year"] }
      dividends = item.stock.dividends
        .where("bonus_percent > 0").where(book_close_on: item.created_at.to_date..@on)
        .where.not(fiscal_year: applied).order(:book_close_on)

      dividends.count do |dividend|
        factor = 1 / (1 + dividend.bonus_percent.to_f / 100)
        WatchlistItem.transaction do
          updates = %i[entry_zone_low entry_zone_high invalidation_price stop_loss_price target_price pivot_price price_at_add].to_h do |field|
            value = item.public_send(field)
            [ field, value && (value.to_f * factor).round(2) ]
          end
          item.update!(
            **updates,
            level_adjustments: item.level_adjustments + [ {
              "fiscal_year" => dividend.fiscal_year, "bonus_percent" => dividend.bonus_percent.to_f,
              "factor" => factor.round(6), "book_close_on" => dividend.book_close_on.iso8601
            } ]
          )
          item.alerts.create!(
            user: item.user, kind: "levels_adjusted",
            message: "#{item.stock.symbol} levels adjusted for the #{dividend.bonus_percent.to_f}% bonus (book close #{dividend.book_close_on.strftime('%b %-d')}): " \
                     "zone now #{format('%.2f', item.entry_zone_low)}-#{format('%.2f', item.entry_zone_high)}, invalidation #{format('%.2f', item.invalidation_price)}."
          )
        end
        true
      end
    end
  end
end
