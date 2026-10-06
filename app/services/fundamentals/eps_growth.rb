module Fundamentals
  # Year-on-year EPS growth for the latest quarterly report (CAN SLIM looks for 25%+).
  #
  # From our own history when the same quarter of the previous fiscal year is stored
  # (source "reported"); otherwise Chukul's growth rate for the latest report (source
  # "chukul"). History builds up from the weekly fundamentals sync: no earlier quarters
  # could be backfilled (ShareSansar shows only the latest quarter, Merolagani only PDFs).
  # Not point in time, so it isn't in the backtest. Information only.
  module EpsGrowth
    STRONG_PCT = 25.0

    module_function

    def call(stock)
      latest = latest_quarter(stock) or return
      prior = year_ago(stock, latest)
      if prior && latest.eps && prior.eps.to_f.positive?
        growth = ((latest.eps.to_f / prior.eps.to_f - 1) * 100).round(1)
        source = "reported"
      elsif latest.growth_rate
        growth = latest.growth_rate.to_f.round(1)
        source = "chukul"
      end
      return unless growth

      { growth_pct: growth, source: source, fiscal_year: latest.fiscal_year, quarter: latest.quarter,
        eps: latest.eps&.to_f, prior_eps: prior&.eps&.to_f, strong: growth >= STRONG_PCT }
    end

    def latest_quarter(stock)
      stock.company_financials.select { _1.quarter.start_with?("Q") && fiscal_start(_1.fiscal_year) }.max_by { [ fiscal_start(_1.fiscal_year), _1.quarter ] }
    end

    def year_ago(stock, latest)
      start = fiscal_start(latest.fiscal_year)
      stock.company_financials.find { _1.quarter == latest.quarter && fiscal_start(_1.fiscal_year) == start - 1 }
    end

    # "082/083" and "2082/083" -> 82: the fiscal year's starting year.
    def fiscal_start(fiscal_year)
      match = fiscal_year.to_s.match(%r{\A(\d{2,4})/\d{2,3}\z}) or return
      match[1].to_i % 100
    end
  end
end
