class ApplicationController < ActionController::API
  around_action :with_current_attributes

  private

  def with_current_attributes
    yield
  ensure
    Current.reset_all
  end
end
