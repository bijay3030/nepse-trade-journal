class StockCompanyFinancialSerializer < ActiveModel::Serializer
  attributes :id, :fiscal_year, :quarter, :reported_on, :eps, :pe_ratio,
             :book_value, :pb_ratio, :roe, :net_profit, :paid_up_capital,
             :reserve_and_surplus, :npl_ratio, :roa, :distributable_profit_per_share, :field_sources

  def eps
    object.eps.to_f
  end

  def pe_ratio
    object.pe_ratio.to_f
  end

  def book_value
    object.book_value.to_f
  end

  def pb_ratio
    object.pb_ratio.to_f
  end

  def roe
    object.roe.to_f
  end

  def net_profit
    object.net_profit.to_f
  end

  def paid_up_capital
    object.paid_up_capital.to_f
  end

  def reserve_and_surplus
    object.reserve_and_surplus.to_f
  end

  def npl_ratio
    object.npl_ratio.to_f
  end

  def roa
    object.roa&.to_f
  end

  # Not the dividend paid; see StockDividend for dividends.
  def distributable_profit_per_share
    object.distributable_profit_per_share&.to_f
  end
end
