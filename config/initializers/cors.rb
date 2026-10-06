# Be sure to restart your server when you modify this file.

# Browsers may call the API from the frontend's address. In production set
# FRONTEND_ORIGINS to the deployed frontend, e.g. "https://nepse-journal.pages.dev"
# (comma-separate several).
FRONTEND_ORIGINS = ENV.fetch("FRONTEND_ORIGINS", "http://localhost:3001,http://localhost:5173,http://127.0.0.1:5173")
                      .split(",").map(&:strip).reject(&:empty?).freeze

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*FRONTEND_ORIGINS)
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options],
      expose: ['Authorization']
  end
end
