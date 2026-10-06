module Api
  module V1
    # Sell-rule alerts for the user's positions (Positions::Monitor).
    class PositionAlertsController < BaseController
      def index
        alerts = current_user.position_alerts.includes(position: [ :stock, :fills ]).recent.limit(50)
        render json: {
          unread_count: current_user.position_alerts.unread.count,
          alerts: ActiveModelSerializers::SerializableResource.new(alerts, each_serializer: PositionAlertSerializer).as_json
        }
      end

      # Marks the given alert ids, or all unread alerts, as read.
      def mark_read
        scope = current_user.position_alerts.unread
        scope = scope.where(id: Array(params[:ids])) if params[:ids].present?
        render json: { updated: scope.update_all(read_at: Time.current) }
      end
    end
  end
end
