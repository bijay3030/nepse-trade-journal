require "csv"

module DataManagement
  class TradeImportService
    REQUIRED_HEADERS = %w[stock_symbol status planned_entry_price target_price stop_loss_price].freeze

    attr_reader :user

    def initialize(user)
      @user = user
    end

    def template_csv
      CSV.generate(headers: true) do |csv|
        csv << import_headers
        csv << ["NABIL", "planned", 550, 590, 532, 200, "Turtle Breakout", "Breakout setup", nil, nil, nil, nil, nil, nil, nil, nil, nil]
      end
    end

    def preview(csv_content, format: "generic")
      rows = parse_rows(csv_content, format: format)
      result_rows = rows.each_with_index.map { |row, index| validate_row(row, index + 2) }
      build_result(result_rows)
    end

    def import(csv_content, format: "generic")
      preview_result = preview(csv_content, format: format)
      valid_rows = preview_result[:rows].select { |row| row[:errors].empty? }

      imported_ids = []
      ActiveRecord::Base.transaction do
        valid_rows.each do |row|
          imported_ids << persist_row!(row[:normalized])
        end
      end

      preview_result.merge(imported_count: imported_ids.size, imported_trade_plan_ids: imported_ids)
    end

    private

    def import_headers
      [
        "stock_symbol", "status", "planned_entry_price", "target_price", "stop_loss_price", "planned_quantity",
        "strategy_name", "entry_trigger_description", "actual_entry_price", "entry_quantity", "entry_time",
        "broker", "broker_fees", "exit_price", "exit_date", "exit_reason", "lesson_learned"
      ]
    end

    def parse_rows(csv_content, format:)
      parsed = CSV.parse(csv_content, headers: true)
      headers = parsed.headers.map { |header| header.to_s.strip }

      case format
      when "broker_statement"
        parse_broker_statement(parsed)
      else
        validate_headers!(headers)
        parsed.map { |row| row.to_h.transform_keys { |key| key.to_s.strip } }
      end
    end

    def validate_headers!(headers)
      missing = REQUIRED_HEADERS - headers
      raise ArgumentError, "Missing required headers: #{missing.join(', ')}" if missing.any?
    end

    def parse_broker_statement(parsed)
      parsed.map do |row|
        {
          "stock_symbol" => row["Symbol"] || row["SYMBOL"],
          "status" => row["Sell Price"].present? ? "closed" : "active",
          "planned_entry_price" => row["Buy Price"] || row["Rate"],
          "target_price" => row["Target"] || row["Buy Price"],
          "stop_loss_price" => row["Stop Loss"] || row["Buy Price"],
          "planned_quantity" => row["Qty"] || row["Quantity"],
          "strategy_name" => row["Strategy"] || "Imported Broker Statement",
          "entry_trigger_description" => "Imported from broker statement",
          "actual_entry_price" => row["Buy Price"] || row["Rate"],
          "entry_quantity" => row["Qty"] || row["Quantity"],
          "entry_time" => row["Trade Date"],
          "broker" => row["Broker"] || "Broker Statement",
          "broker_fees" => row["Commission"],
          "exit_price" => row["Sell Price"],
          "exit_date" => row["Sell Date"] || row["Trade Date"],
          "exit_reason" => row["Reason"] || "Imported",
          "lesson_learned" => row["Notes"]
        }
      end
    end

    def validate_row(row, row_number)
      normalized = normalize_row(row)
      errors = []

      errors << "stock_symbol is required" if normalized[:stock_symbol].blank?
      errors << "stock_symbol not found" if normalized[:stock_symbol].present? && Stock.find_by(symbol: normalized[:stock_symbol]).nil?
      errors << "status must be planned, active, or closed" unless %w[planned active closed].include?(normalized[:status])

      %i[planned_entry_price target_price stop_loss_price].each do |field|
        errors << "#{field} must be greater than 0" if normalized[field].to_f <= 0
      end

      if %w[active closed].include?(normalized[:status])
        errors << "actual_entry_price is required for active/closed" if normalized[:actual_entry_price].to_f <= 0
        errors << "entry_quantity is required for active/closed" if normalized[:entry_quantity].to_i <= 0
      end

      if normalized[:status] == "closed"
        errors << "exit_price is required for closed" if normalized[:exit_price].to_f <= 0
        errors << "exit_date is required for closed" if normalized[:exit_date].blank?
      end

      {
        row_number: row_number,
        source: row,
        normalized: normalized,
        errors: errors
      }
    end

    def normalize_row(row)
      {
        stock_symbol: row["stock_symbol"].to_s.strip.upcase,
        status: row["status"].to_s.strip.presence || "planned",
        planned_entry_price: row["planned_entry_price"].to_f,
        target_price: row["target_price"].to_f,
        stop_loss_price: row["stop_loss_price"].to_f,
        planned_quantity: row["planned_quantity"].to_i,
        strategy_name: row["strategy_name"].to_s.strip,
        entry_trigger_description: row["entry_trigger_description"].to_s.strip,
        actual_entry_price: row["actual_entry_price"].to_f,
        entry_quantity: row["entry_quantity"].to_i,
        entry_time: row["entry_time"].to_s.strip,
        broker: row["broker"].to_s.strip,
        broker_fees: row["broker_fees"].to_f,
        exit_price: row["exit_price"].to_f,
        exit_date: row["exit_date"].to_s.strip,
        exit_reason: row["exit_reason"].to_s.strip,
        lesson_learned: row["lesson_learned"].to_s.strip
      }
    end

    def build_result(result_rows)
      valid_count = result_rows.count { |row| row[:errors].empty? }
      invalid_count = result_rows.count - valid_count

      {
        rows: result_rows,
        valid_count: valid_count,
        invalid_count: invalid_count
      }
    end

    def persist_row!(row)
      stock = Stock.find_by!(symbol: row[:stock_symbol])
      strategy = if row[:strategy_name].present?
                   TradingStrategy.find_or_create_by!(name: row[:strategy_name])
                 end

      plan = user.trade_plans.create!(
        stock: stock,
        trading_strategy: strategy,
        status: row[:status],
        planned_entry_price: row[:planned_entry_price],
        target_price: row[:target_price],
        stop_loss_price: row[:stop_loss_price],
        planned_quantity: row[:planned_quantity].positive? ? row[:planned_quantity] : nil,
        entry_trigger_description: row[:entry_trigger_description]
      )

      if %w[active closed].include?(row[:status])
        execution = plan.create_trade_execution!(
          actual_entry_price: row[:actual_entry_price],
          quantity: row[:entry_quantity],
          entry_time: parse_datetime(row[:entry_time]) || Time.current,
          broker: row[:broker].presence,
          broker_fees: row[:broker_fees]
        )

        if row[:status] == "closed"
          execution.create_trade_result!(
            exit_price: row[:exit_price],
            exit_date: parse_datetime(row[:exit_date]) || Time.current,
            exit_reason: row[:exit_reason].presence,
            lesson_learned: row[:lesson_learned].presence
          )
        end
      end

      plan.id
    end

    def parse_datetime(value)
      return if value.blank?

      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end
  end
end
