module Api
  module V1
    class DailyJournalsController < BaseController
      def index
        entries = current_user.daily_journals.order(trade_date: :desc)
        render json: { entries: entries.as_json }
      end

      def create
        entry = current_user.daily_journals.find_or_initialize_by(trade_date: journal_params[:trade_date])
        entry.assign_attributes(journal_params)

        if entry.save
          render json: entry.as_json, status: :created
        else
          render json: { errors: entry.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def show
        entry = current_user.daily_journals.find(params[:id])
        render json: entry.as_json
      end

      def version_history
        entry = current_user.daily_journals.find(params[:daily_journal_id])
        versions = entry.versions.order(version_number: :desc)
        render json: { versions: versions.as_json }
      end

      def restore_version
        entry = current_user.daily_journals.find(params[:daily_journal_id])
        version = entry.versions.find(params[:id])

        entry.update!(
          content: version.content,
          mood: version.mood,
          discipline_score: version.discipline_score
        )

        render json: { restored: true, entry: entry.as_json }
      end

      private

      def journal_params
        params.require(:daily_journal).permit(:trade_date, :mood, :discipline_score, :content)
      end
    end
  end
end
