module Api
  module V1
    # Indicator scans (Scans::Crossovers) with how each signal played out historically
    # (Scans::CrossoverBacktest), cached until the next completed session.
    class ScansController < BaseController
      def crossovers
        render json: Scans::Cache.crossovers
      end

      # GET /scans/alert: the user's saved filter for Telegram messages.
      def alert
        render json: alert_payload
      end

      # PUT /scans/alert { signals: [...] } (empty to stop).
      def update_alert
        if current_user.update(scanner_alert_signals: Array(params[:signals]).map(&:to_s).uniq)
          render json: alert_payload
        else
          render json: { error: current_user.errors.full_messages.to_sentence }, status: :unprocessable_content
        end
      end

      # GET /scans/crossovers/:symbol: candles, indicator lines and signal episodes.
      def crossover_chart
        stock = Stock.active.find_by!(symbol: params[:symbol].to_s.upcase)
        chart = Scans::Crossovers.chart(stock)
        chart ? render(json: chart) : render(json: { error: "Not enough price history for #{stock.symbol}" }, status: :unprocessable_content)
      end

      private

      def alert_payload
        { signals: current_user.scanner_alert_signals, telegram_linked: current_user.telegram_chat_id.present? }
      end
    end
  end
end
