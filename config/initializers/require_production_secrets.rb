# Production must not fall back to the development JWT secret.
if Rails.env.production? && ENV["JWT_SECRET"].blank? && !ENV["SECRET_KEY_BASE_DUMMY"]
  raise "JWT_SECRET must be set in production"
end
