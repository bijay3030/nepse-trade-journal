class AddGrowthRateToStockCompanyFinancials < ActiveRecord::Migration[8.0]
  def change
    # Chukul's earnings growth rate (%), the figure behind its PEG ratio.
    add_column :stock_company_financials, :growth_rate, :decimal, precision: 10, scale: 2
  end
end
