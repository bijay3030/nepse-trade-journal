module Api
  module V1
    # Connecting the user's Telegram chat and choosing which messages it gets.
    class TelegramController < BaseController
      def show
        render json: status_payload
      end

      # A one-time t.me link; pressing Start in the bot links the chat (Telegram::Linker).
      def link
        return not_configured unless Telegram::Client.configured?

        url = Telegram::Linker.start(current_user)
        render json: status_payload.merge(link_url: url)
      rescue Telegram::Error => e
        render json: { error: e.message }, status: :bad_gateway
      end

      # Reads the bot's messages now instead of waiting for the next minute's poll.
      def check
        return not_configured unless Telegram::Client.configured?

        Telegram::Linker.poll
        current_user.reload
        render json: status_payload
      rescue Telegram::Error => e
        render json: { error: e.message }, status: :bad_gateway
      end

      def update
        attrs = {}
        attrs[:telegram_watchlist_alerts] = ActiveModel::Type::Boolean.new.cast(params[:watchlist_alerts]) if params.key?(:watchlist_alerts)
        attrs[:telegram_board_alerts] = ActiveModel::Type::Boolean.new.cast(params[:board_alerts]) if params.key?(:board_alerts)
        current_user.update!(attrs)
        render json: status_payload
      end

      def unlink
        Telegram::Linker.unlink!(current_user)
        render json: status_payload
      end

      def test
        return not_configured unless Telegram::Client.configured?
        return render(json: { error: "Connect Telegram first" }, status: :unprocessable_entity) if current_user.telegram_chat_id.blank?

        Telegram::Client.new.send_message(current_user.telegram_chat_id, Telegram::Messages.test_message(current_user))
        render json: status_payload.merge(sent: true)
      rescue Telegram::Error => e
        Telegram::Linker.unlink!(current_user) if e.chat_unreachable?
        render json: { error: e.message }, status: :bad_gateway
      end

      private

      def status_payload
        {
          configured: Telegram::Client.configured?,
          linked: current_user.telegram_chat_id.present?,
          username: current_user.telegram_username,
          pending: current_user.telegram_link_expires_at&.future? || false,
          watchlist_alerts: current_user.telegram_watchlist_alerts,
          board_alerts: current_user.telegram_board_alerts
        }
      end

      def not_configured
        render json: { error: "Telegram isn't set up on the server: set TELEGRAM_BOT_TOKEN and restart." }, status: :service_unavailable
      end
    end
  end
end
