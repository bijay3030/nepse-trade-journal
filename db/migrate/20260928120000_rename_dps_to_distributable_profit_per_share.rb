class RenameDpsToDistributableProfitPerShare < ActiveRecord::Migration[8.0]
  def change
    # Chukul's "dps" is distributable profit per share (can be negative), not dividend per share.
    rename_column :stock_company_financials, :dps, :distributable_profit_per_share
  end
end
