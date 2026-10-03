require "rails_helper"

RSpec.describe "Sign-in", type: :request do
  let!(:user) { User.create!(email: "me@example.com", password: "a-long-password", jti: SecureRandom.uuid) }

  it "returns a token that opens the API, and revokes it on logout" do
    post "/login", params: { user: { email: "me@example.com", password: "a-long-password" } }, as: :json
    expect(response).to have_http_status(:ok)
    token = JSON.parse(response.body)["token"]
    expect(token).to be_present
    expect(JWT.decode(token, Warden::JWTAuth.config.secret, true, algorithm: "HS256").first["exp"]).to be_within(60).of(30.days.from_now.to_i)

    get "/api/v1/positions", headers: { "Authorization" => "Bearer #{token}" }
    expect(response).to have_http_status(:ok)

    delete "/logout", headers: { "Authorization" => "Bearer #{token}" }
    expect(user.reload.jti).not_to eq(JWT.decode(token, Warden::JWTAuth.config.secret, true, algorithm: "HS256").first["jti"])
  end

  it "rejects a wrong password and has no public sign-up or password reset" do
    post "/login", params: { user: { email: "me@example.com", password: "nope" } }, as: :json
    expect(response).to have_http_status(:unauthorized)

    post "/", params: { user: { email: "new@example.com", password: "a-long-password" } }, as: :json
    expect(response).to have_http_status(:not_found)
    expect(User.count).to eq(1)
    post "/password", params: { user: { email: "me@example.com" } }, as: :json
    expect(response).to have_http_status(:not_found)
  end
end
