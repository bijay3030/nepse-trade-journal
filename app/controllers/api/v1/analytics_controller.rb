module Api
  module V1
    class AnalyticsController < BaseController
      def dashboard
        range = parse_date_range

        stats = {
          overview: calculate_overview(range),
          performance_chart: equity_curve_data(range),
          strategy_breakdown: strategy_performance(range),
          mistake_analysis: mistake_frequency(range),
          emotional_correlation: emotion_analysis(range),
          recent_trades: recent_trades_summary(5)
        }

        render json: stats
      end

      def trade_statistics
        range = parse_date_range

        render json: {
          win_rate: calculate_win_rate(range),
          profit_factor: calculate_profit_factor(range),
          expectancy: calculate_expectancy(range),
          average_risk_reward: calculate_avg_rr(range),
          max_drawdown: calculate_max_drawdown(range),
          sharpe_ratio: calculate_sharpe(range),
          total_trades: completed_trades(range).count,
          winning_trades: completed_trades(range).select(&:is_win?).count,
          losing_trades: completed_trades(range).reject(&:is_win?).count
        }
      end

      private

      def parse_date_range
        now = Time.current

        case params[:period]
        when "7d" then 7.days.ago..now
        when "30d" then 30.days.ago..now
        when "90d" then 90.days.ago..now
        when "ytd" then Date.current.beginning_of_year..now
        else 30.days.ago..now
        end
      end

      def calculate_overview(range)
        trades = completed_trades(range)
        return {} if trades.empty?

        total_pnl = trades.sum(&:net_pnl)
        {
          total_pnl: total_pnl.round(2),
          total_pnl_formatted: format_currency(total_pnl),
          win_rate: calculate_win_rate(range),
          profit_factor: calculate_profit_factor(range),
          total_trades: trades.count,
          average_trade: (total_pnl / trades.count).round(2),
          best_trade: trades.max_by(&:net_pnl)&.net_pnl&.round(2),
          worst_trade: trades.min_by(&:net_pnl)&.net_pnl&.round(2)
        }
      end

      def completed_trades(range)
        current_user.trade_results
          .joins(trade_execution: :trade_plan)
          .where(created_at: range)
          .includes(trade_execution: { trade_plan: [:stock, :trading_strategy] })
      end

      def equity_curve_data(range)
        cumulative = 0

        completed_trades(range)
          .order(:exit_date)
          .map do |trade|
            cumulative += trade.net_pnl
            {
              date: trade.exit_date.to_date,
              cumulative_pnl: cumulative.round(2),
              trade_pnl: trade.net_pnl.round(2)
            }
          end
      end

      def strategy_performance(range)
        completed_trades(range)
          .group_by { |trade| trade.trade_plan.trading_strategy&.name || "Unassigned" }
          .map do |strategy_name, trades|
            wins = trades.count(&:is_win?)
            {
              strategy: strategy_name,
              trades: trades.size,
              win_rate: ((wins.to_f / trades.size) * 100).round(1),
              net_pnl: trades.sum(&:net_pnl).round(2)
            }
          end
          .sort_by { |entry| -entry[:net_pnl] }
      end

      def mistake_frequency(range)
        tag_counts = Hash.new(0)

        completed_trades(range).each do |trade|
          Array(trade.mistake_tags).each { |tag| tag_counts[tag] += 1 }
        end

        tag_counts.map { |tag, count| { tag: tag, count: count } }.sort_by { |entry| -entry[:count] }
      end

      def emotion_analysis(range)
        grouped = completed_trades(range).group_by { |trade| trade.trade_plan.emotional_state_at_entry.presence || "Unknown" }

        grouped.map do |emotion, trades|
          {
            emotion: emotion,
            average_pnl: (trades.sum(&:net_pnl) / trades.size).round(2),
            win_rate: ((trades.count(&:is_win?).to_f / trades.size) * 100).round(1),
            trades: trades.size
          }
        end
      end

      def recent_trades_summary(limit)
        current_user.trade_results
          .includes(trade_execution: { trade_plan: :stock })
          .order(created_at: :desc)
          .limit(limit)
          .map do |result|
            {
              stock: result.trade_plan.stock.symbol,
              exit_date: result.exit_date,
              net_pnl: result.net_pnl.round(2),
              is_win: result.is_win?
            }
          end
      end

      def calculate_win_rate(range)
        trades = completed_trades(range)
        return 0 if trades.empty?

        ((trades.count(&:is_win?).to_f / trades.count) * 100).round(1)
      end

      def calculate_profit_factor(range)
        trades = completed_trades(range)
        gross_profit = trades.select(&:is_win?).sum(&:net_pnl)
        gross_loss = trades.reject(&:is_win?).sum(&:net_pnl).abs

        return 0 if gross_loss.zero?

        (gross_profit / gross_loss).round(2)
      end

      def calculate_expectancy(range)
        trades = completed_trades(range)
        return 0 if trades.empty?

        (trades.sum(&:net_pnl) / trades.count).round(2)
      end

      def calculate_avg_rr(range)
        values = current_user.trade_plans
          .where(created_at: range)
          .where.not(planned_entry_price: nil, target_price: nil, stop_loss_price: nil)
          .map do |plan|
            risk = plan.planned_entry_price - plan.stop_loss_price
            reward = plan.target_price - plan.planned_entry_price
            next if risk.to_f <= 0

            reward / risk
          end
          .compact

        return 0 if values.empty?

        (values.sum / values.size).round(2)
      end

      def calculate_max_drawdown(range)
        curve = equity_curve_data(range)
        return 0 if curve.empty?

        peak = -Float::INFINITY
        max_drawdown = 0

        curve.each do |point|
          value = point[:cumulative_pnl]
          peak = [peak, value].max
          drawdown = peak - value
          max_drawdown = [max_drawdown, drawdown].max
        end

        max_drawdown.round(2)
      end

      def calculate_sharpe(range)
        returns = completed_trades(range).map(&:net_pnl)
        return 0 if returns.size < 2

        mean = returns.sum.to_f / returns.size
        variance = returns.sum { |r| (r - mean)**2 } / (returns.size - 1)
        stddev = Math.sqrt(variance)
        return 0 if stddev.zero?

        (mean / stddev).round(2)
      end

      def format_currency(amount)
        "Rs. #{amount.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
      end
    end
  end
end
