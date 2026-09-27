require "csv"

module DataManagement
  class ExportService
    def initialize(user)
      @user = user
    end

    def trades_csv(include_deleted: false)
      plans = trade_plans_scope(include_deleted)
      headers = [
        "trade_plan_id", "status", "created_at", "updated_at", "stock_symbol", "stock_name", "strategy_name",
        "entry_strategy", "analysis_type", "entry_trigger_description", "planned_entry_price", "target_price", "stop_loss_price",
        "position_size_percent", "planned_quantity", "expected_hold_duration", "market_condition_at_entry", "emotional_state_at_entry",
        "sector_trend", "news_catalyst", "plan_deleted_at", "execution_id", "actual_entry_price", "execution_quantity", "entry_time",
        "broker", "broker_fees", "order_type", "entry_efficiency", "execution_notes", "execution_deleted_at", "result_id", "exit_price",
        "exit_date", "exit_reason", "exit_efficiency", "max_price_reached", "min_price_reached", "exit_broker_fees", "mistake_tags",
        "lesson_learned", "emotional_state_at_exit", "net_pnl", "result_deleted_at"
      ]

      CSV.generate(headers: true) do |csv|
        csv << headers

        plans.includes(:stock, :trading_strategy, :trade_execution).find_each do |plan|
          execution = include_deleted ? TradeExecution.with_deleted.find_by(trade_plan_id: plan.id) : plan.trade_execution
          result = execution ? (include_deleted ? TradeResult.with_deleted.find_by(trade_execution_id: execution.id) : execution.trade_result) : nil

          csv << [
            plan.id,
            plan.status,
            plan.created_at,
            plan.updated_at,
            plan.stock&.symbol,
            plan.stock&.name,
            plan.trading_strategy&.name,
            plan.entry_strategy,
            plan.analysis_type,
            plan.entry_trigger_description,
            plan.planned_entry_price,
            plan.target_price,
            plan.stop_loss_price,
            plan.position_size_percent,
            plan.planned_quantity,
            plan.expected_hold_duration,
            plan.market_condition_at_entry,
            plan.emotional_state_at_entry,
            plan.sector_trend,
            plan.news_catalyst,
            plan.deleted_at,
            execution&.id,
            execution&.actual_entry_price,
            execution&.quantity,
            execution&.entry_time,
            execution&.broker,
            execution&.broker_fees,
            execution&.order_type,
            execution&.entry_efficiency,
            execution&.notes,
            execution&.deleted_at,
            result&.id,
            result&.exit_price,
            result&.exit_date,
            result&.exit_reason,
            result&.exit_efficiency,
            result&.max_price_reached,
            result&.min_price_reached,
            result&.exit_broker_fees,
            Array(result&.mistake_tags).join("|"),
            result&.lesson_learned,
            result&.emotional_state_at_exit,
            result&.net_pnl,
            result&.deleted_at
          ]
        end
      end
    end

    def journal_markdown(include_deleted: false)
      entries = journal_scope(include_deleted).order(trade_date: :desc)

      lines = ["# Trading Journal", "", "Exported at: #{Time.current}", ""]
      entries.each do |entry|
        lines << "## #{entry.trade_date}"
        lines << "- Mood: #{entry.mood.presence || 'N/A'}"
        lines << "- Discipline Score: #{entry.discipline_score || 'N/A'}"
        lines << "- Deleted At: #{entry.deleted_at}" if include_deleted && entry.deleted_at.present?
        lines << ""
        lines << (entry.content.presence || "_No content_")
        lines << ""
      end
      lines.join("\n")
    end

    def analytics_report_text
      results = trade_results_scope
      total_pnl = results.sum(&:net_pnl)
      wins = results.count(&:is_win?)
      losses = results.count - wins
      win_rate = results.any? ? ((wins.to_f / results.count) * 100).round(2) : 0

      <<~REPORT
        NEPSE TRADE ANALYTICS REPORT
        Generated: #{Time.current}

        Total Trades: #{results.count}
        Winning Trades: #{wins}
        Losing Trades: #{losses}
        Win Rate: #{win_rate}%
        Net P&L: Rs. #{total_pnl.round(2)}

        Best Trade: Rs. #{results.max_by(&:net_pnl)&.net_pnl&.round(2) || 0}
        Worst Trade: Rs. #{results.min_by(&:net_pnl)&.net_pnl&.round(2) || 0}
      REPORT
    end

    def full_backup_hash(include_deleted: true)
      {
        exported_at: Time.current,
        user: {
          id: @user.id,
          email: @user.email
        },
        trade_plans: serialize_trade_plans(include_deleted: include_deleted),
        daily_journals: serialize_journals(include_deleted: include_deleted),
        portfolios: serialize_portfolios,
        audit_logs: @user.audit_logs.order(created_at: :desc).limit(5_000).as_json
      }
    end

    private

    def trade_plans_scope(include_deleted)
      scope = include_deleted ? TradePlan.with_deleted : TradePlan.all
      scope.where(user_id: @user.id)
    end

    def trade_results_scope
      TradeResult.where(trade_execution_id: TradeExecution.where(trade_plan_id: TradePlan.where(user_id: @user.id).select(:id)).select(:id))
    end

    def journal_scope(include_deleted)
      scope = include_deleted ? DailyJournal.with_deleted : DailyJournal.all
      scope.where(user_id: @user.id)
    end

    def serialize_trade_plans(include_deleted:)
      trade_plans_scope(include_deleted)
        .includes(:stock, :trading_strategy)
        .map do |plan|
          execution = include_deleted ? TradeExecution.with_deleted.find_by(trade_plan_id: plan.id) : plan.trade_execution
          result = execution ? (include_deleted ? TradeResult.with_deleted.find_by(trade_execution_id: execution.id) : execution.trade_result) : nil

          {
            plan: plan.as_json,
            stock: plan.stock&.as_json,
            strategy: plan.trading_strategy&.as_json,
            execution: execution&.as_json,
            result: result&.as_json
          }
        end
    end

    def serialize_journals(include_deleted:)
      journal_scope(include_deleted)
        .includes(:versions)
        .map do |journal|
          {
            journal: journal.as_json,
            versions: journal.versions.order(version_number: :desc).as_json
          }
        end
    end

    def serialize_portfolios
      @user.portfolios.includes(:holdings).map do |portfolio|
        {
          portfolio: portfolio.as_json,
          holdings: portfolio.holdings.as_json
        }
      end
    end
  end
end
