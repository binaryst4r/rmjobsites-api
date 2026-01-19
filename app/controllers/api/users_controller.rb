class Api::UsersController < ApplicationController
  before_action :require_admin, only: [:admins]

  def admins
    admin_users = User.where(admin: true).order(:email)

    render json: {
      users: admin_users.map { |user| format_user(user) }
    }, status: :ok
  end

  private

  def require_admin
    unless current_user
      render json: { error: "Unauthorized. Please log in." }, status: :unauthorized
      return
    end

    unless current_user.admin?
      render json: { error: "Unauthorized. Admin access required." }, status: :forbidden
    end
  end

  def format_user(user)
    {
      id: user.id,
      email: user.email,
      given_name: user.given_name,
      family_name: user.family_name,
      admin: user.admin
    }
  end
end
