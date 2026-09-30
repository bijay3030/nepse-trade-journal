class AddReferenceDataSources < ActiveRecord::Migration[8.0]
  def change
    # Where each field's current value came from: { "field" => { "source" => "chukul", "at" => "..." } }
    add_column :stocks, :field_sources, :jsonb, null: false, default: {}
    add_column :stocks, :chukul_id, :integer
    add_column :stocks, :chukul_sector_id, :integer
    add_index :stocks, :chukul_id, unique: true

    add_column :stock_company_financials, :field_sources, :jsonb, null: false, default: {}
    add_column :stock_company_financials, :roa, :decimal, precision: 8, scale: 2
    add_column :stock_company_financials, :dps, :decimal, precision: 10, scale: 2

    add_column :market_indices, :sector, :string
    add_column :market_indices, :source, :string

    create_table :stock_dividends do |t|
      t.references :stock, null: false, foreign_key: true
      t.string :fiscal_year, null: false
      t.decimal :cash_percent, precision: 8, scale: 2
      t.decimal :bonus_percent, precision: 8, scale: 2
      t.decimal :total_percent, precision: 8, scale: 2
      t.date :announced_on
      t.date :book_close_on
      t.date :agm_on
      t.string :source, null: false
      t.timestamps
    end
    add_index :stock_dividends, [ :stock_id, :fiscal_year ], unique: true
  end
end
