module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate_user!
      before_action :set_current_user_context

      private

      def authenticate_user!
        render json: { error: "Unauthorized" }, status: :unauthorized unless current_user
      end

      def set_current_user_context
        Current.user = current_user
      end

      def current_user
        return @current_user if defined?(@current_user)

        user = nil
        if decoded_token.present? && decoded_token["jti"].present?
          user = User.find_by(jti: decoded_token["jti"])
        end

        if user.nil? && (Rails.env.development? || Rails.env.test?)
          user = User.first || User.create!(
            email: "trader@nepse.com",
            password: "password123",
            jti: SecureRandom.uuid
          )
        end

        @current_user = user
      end

      def decoded_token
        auth_header = request.headers["Authorization"]
        return unless auth_header

        token = auth_header.split(" ").last
        secret = ENV.fetch("JWT_SECRET", "secret")
        JWT.decode(token, secret, true, algorithm: "HS256")[0]
      rescue JWT::DecodeError, JWT::VerificationError
        nil
      end
    end
  end
end
