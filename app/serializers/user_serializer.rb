class UserSerializer
  def initialize(user, options = {})
    @user = user
    @format = options[:for] || :default
  end

  def as_json
    case @format
    when :square
      square_customer_format
    else
      default_format
    end
  end

  private

  # Default format for auth endpoints (login, register, profile)
  def default_format
    {
      id: @user.id,
      email: @user.email,
      admin: @user.admin,
      square_customer_id: @user.square_customer_id,
      given_name: @user.given_name,
      family_name: @user.family_name,
      phone_number: @user.phone_number,
      address_line_1: @user.address_line_1,
      address_line_2: @user.address_line_2,
      city: @user.city,
      state: @user.state,
      postal_code: @user.postal_code,
      country: @user.country
    }
  end

  # Square API compatible format for customer endpoints
  def square_customer_format
    {
      id: @user.square_customer_id || "local_#{@user.id}",
      email_address: @user.email,
      given_name: @user.given_name,
      family_name: @user.family_name,
      phone_number: @user.phone_number,
      address: {
        address_line_1: @user.address_line_1,
        address_line_2: @user.address_line_2,
        locality: @user.city,
        administrative_district_level_1: @user.state,
        postal_code: @user.postal_code,
        country: @user.country
      }.compact
    }.compact
  end
end
