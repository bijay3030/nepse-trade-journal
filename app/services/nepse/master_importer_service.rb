module Nepse
  class MasterImporterService
    DEFAULT_SEED_FILE = Rails.root.join("db", "seeds", "nepse_stocks.json").to_s

    def self.call(json_file_path = DEFAULT_SEED_FILE)
      new(json_file_path).import
    end

    def self.seed!(json_file_path = DEFAULT_SEED_FILE)
      call(json_file_path)
    end

    def initialize(file_path = DEFAULT_SEED_FILE)
      @file_path = file_path
    end

    def import
      return { success: false, message: "Seed file not found: #{@file_path}" } unless File.exist?(@file_path)

      raw_data = File.read(@file_path)
      records = JSON.parse(raw_data)
      created_count = 0
      updated_count = 0

      Stock.transaction do
        records.each do |item|
          symbol = item["symbol"].to_s.upcase.strip
          next if symbol.blank?

          stock = Stock.find_or_initialize_by(symbol: symbol)
          is_new = stock.new_record?

          stock.name = item["name"] || symbol
          stock.sector = item["sector"] || "Others"
          stock.security_type = item["security_type"] || "Equity"
          stock.listed_shares = item["listed_shares"].to_i if item["listed_shares"].present?
          stock.paid_up_value = item["paid_up_value"].to_f if item["paid_up_value"].present?
          stock.last_price = item["last_price"].to_f if item["last_price"].present?
          stock.high_52w = item["high_52w"].to_f if item["high_52w"].present?
          stock.low_52w = item["low_52w"].to_f if item["low_52w"].present?
          stock.last_updated ||= Time.current

          stock.save!
          stock.recalculate_market_cap!

          if is_new
            created_count += 1
          else
            updated_count += 1
          end
        end
      end

      { success: true, created: created_count, updated: updated_count, total: created_count + updated_count }
    rescue StandardError => e
      Rails.logger.error("Nepse::MasterImporterService error: #{e.message}")
      { success: false, error: e.message }
    end
  end
end
