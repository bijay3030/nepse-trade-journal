module Api
  module V1
    class DigestsController < BaseController
      # Recent digests without their content, newest first.
      def index
        digests = current_user.daily_digests.latest_first.limit(30)
        render json: {
          unread_count: current_user.daily_digests.unread.count,
          digests: digests.map { |digest| summary(digest) }
        }
      end

      # "latest" or a session date. The latest is built on demand when the nightly job
      # hasn't made one yet (a new user, or the digest was just switched on).
      def show
        digest =
          if params[:id] == "latest"
            current_user.daily_digests.latest_first.first || (current_user.digest_enabled && Digests::Builder.call(current_user))
          else
            current_user.daily_digests.find_by(traded_on: params[:id])
          end
        return render(json: { error: "No digest yet" }, status: :not_found) unless digest

        render json: summary(digest).merge(content: digest.content)
      end

      def mark_read
        digest = current_user.daily_digests.find_by!(traded_on: params[:id])
        digest.update!(read_at: digest.read_at || Time.current)
        render json: summary(digest)
      end

      def preferences
        render json: preferences_payload
      end

      def update_preferences
        attrs = {}
        attrs[:digest_enabled] = ActiveModel::Type::Boolean.new.cast(params[:enabled]) if params.key?(:enabled)
        attrs[:digest_sections] = Array(params[:sections]).map(&:to_s) & DailyDigest::SECTIONS if params.key?(:sections)
        current_user.update!(attrs)
        render json: preferences_payload
      end

      private

      def summary(digest)
        { id: digest.id, traded_on: digest.traded_on.iso8601, read_at: digest.read_at, headline: digest.headline }
      end

      def preferences_payload
        { enabled: current_user.digest_enabled, sections: current_user.digest_sections, available_sections: DailyDigest::SECTIONS }
      end
    end
  end
end
