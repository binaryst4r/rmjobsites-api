class Api::UsersController < ApplicationController
  before_action :require_admin, only: [:admins, :index]

  def admins
    admin_users = User.where(admin: true).order(:email)

    render json: {
      users: admin_users.map { |user| format_user(user) }
    }, status: :ok
  end

  def index
    page     = [params[:page].to_i, 1].max
    per_page = (params[:per_page].presence || 25).to_i.clamp(1, 100)
    q        = params[:q].to_s.strip

    scope = User.order(created_at: :desc)

    if q.present?
      like = "%#{ActiveRecord::Base.sanitize_sql_like(q)}%"
      scope = scope.where(
        'email ILIKE :q OR given_name ILIKE :q OR family_name ILIKE :q',
        q: like
      )
    end

    total_count = scope.count
    users       = scope.offset((page - 1) * per_page).limit(per_page)

    render json: {
      users: users.map { |u| UserSerializer.new(u, for: :admin_list).as_json },
      meta: {
        page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
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
