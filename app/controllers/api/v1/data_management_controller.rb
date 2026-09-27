module Api
  module V1
    class DataManagementController < BaseController
      def trades_export_csv
        csv = export_service.trades_csv(include_deleted: ActiveModel::Type::Boolean.new.cast(params[:include_deleted]))
        send_data csv, filename: "trades-#{Date.current}.csv", type: "text/csv"
      end

      def journal_export_markdown
        markdown = export_service.journal_markdown(include_deleted: ActiveModel::Type::Boolean.new.cast(params[:include_deleted]))
        send_data markdown, filename: "journal-#{Date.current}.md", type: "text/markdown"
      end

      def analytics_export_report
        report = export_service.analytics_report_text
        send_data report, filename: "analytics-report-#{Date.current}.pdf", type: "application/pdf"
      end

      def full_backup
        render json: export_service.full_backup_hash(include_deleted: true)
      end

      def import_template
        csv = import_service.template_csv
        send_data csv, filename: "trade-import-template.csv", type: "text/csv"
      end

      def import_preview
        result = import_service.preview(params.require(:csv_content), format: params[:format].presence || "generic")
        render json: result
      rescue ArgumentError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def import_commit
        result = import_service.import(params.require(:csv_content), format: params[:format].presence || "generic")
        render json: result, status: :created
      rescue ArgumentError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def deleted_trades
        plans = TradePlan.with_deleted.where(user_id: current_user.id).where.not(deleted_at: nil).order(deleted_at: :desc)
        render json: {
          deleted_trades: plans.map do |plan|
            {
              id: plan.id,
              stock_symbol: plan.stock&.symbol,
              status: plan.status,
              deleted_at: plan.deleted_at
            }
          end
        }
      end

      def restore_trade
        plan = TradePlan.with_deleted.where(user_id: current_user.id).find(params[:id])
        plan.restore!(source: "data_management")
        render json: { restored: true, id: plan.id }
      end

      def audit_logs
        logs = current_user.audit_logs.order(created_at: :desc).limit(500)
        render json: { audit_logs: logs.as_json }
      end

      private

      def export_service
        @export_service ||= DataManagement::ExportService.new(current_user)
      end

      def import_service
        @import_service ||= DataManagement::TradeImportService.new(current_user)
      end
    end
  end
end
