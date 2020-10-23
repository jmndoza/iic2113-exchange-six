class ApplicationController < ActionController::Base
    # Devise code
  before_action :configure_permitted_parameters, if: :devise_controller?

  respond_to :json

  protected

  # Devise methods
  # Authentication key(:email) and password field will be added automatically by devise.
  def configure_permitted_parameters
    added_attrs = [:email]#[:email, :first_name, :last_name]
    devise_parameter_sanitizer.permit :sign_up, keys: added_attrs
    devise_parameter_sanitizer.permit :account_update, keys: added_attrs
  end

  # Doorkeeper methods
  def current_resource_owner
    User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
  end
end
