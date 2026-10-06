module Users
  class SessionsController < Devise::SessionsController
    respond_to :json

    private

    def respond_with(resource, _opts = {})
      token = request.env["warden-jwt_auth.token"]
      render json: {
        message: "Logged in successfully",
        user: { id: resource.id, email: resource.email },
        token: token
      }, status: :ok
    end

    def respond_to_on_destroy(*)
      render json: { message: "Logged out successfully" }, status: :ok
    end
  end
end
