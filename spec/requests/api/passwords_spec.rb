require "rails_helper"

RSpec.describe "Api::Passwords", type: :request do
  describe "POST /api/auth/forgot_password" do
    let!(:user) { create(:user, email: "forgot@example.com") }

    it "sends a password reset email for a known address" do
      message = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
      expect(UserMailer).to receive(:password_reset).with(user, kind_of(String)).and_return(message)

      post "/api/auth/forgot_password", params: { email: "forgot@example.com" }
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an unknown address without sending mail" do
      expect(UserMailer).not_to receive(:password_reset)

      post "/api/auth/forgot_password", params: { email: "ghost@example.com" }
      expect(response).to have_http_status(:ok)
      expect(json_response[:message]).to match(/if an account exists/i)
    end

    it "is case-insensitive on email lookup" do
      message = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
      expect(UserMailer).to receive(:password_reset).with(user, kind_of(String)).and_return(message)

      post "/api/auth/forgot_password", params: { email: "FORGOT@example.com" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/auth/reset_password" do
    let!(:user) { create(:user, email: "reset@example.com", password: "original123", password_confirmation: "original123") }

    def token_for(user)
      user.generate_token_for(:password_reset)
    end

    it "updates the password with a valid token and returns a fresh JWT" do
      token = token_for(user)

      post "/api/auth/reset_password", params: {
        token: token,
        password: "newsecret123",
        password_confirmation: "newsecret123"
      }

      expect(response).to have_http_status(:ok)
      expect(json_response[:token]).to be_present
      expect(user.reload.authenticate("newsecret123")).to be_truthy
    end

    it "rejects a tampered token" do
      post "/api/auth/reset_password", params: {
        token: "not-a-real-token",
        password: "newsecret123",
        password_confirmation: "newsecret123"
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response[:errors]).to include(/invalid or has expired/i)
    end

    it "rejects a reused token after a successful reset" do
      token = token_for(user)

      post "/api/auth/reset_password", params: {
        token: token,
        password: "firstnew123",
        password_confirmation: "firstnew123"
      }
      expect(response).to have_http_status(:ok)

      post "/api/auth/reset_password", params: {
        token: token,
        password: "secondnew123",
        password_confirmation: "secondnew123"
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns validation errors when the new password is too short" do
      token = token_for(user)

      post "/api/auth/reset_password", params: {
        token: token,
        password: "abc",
        password_confirmation: "abc"
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response[:errors].join).to match(/password/i)
    end
  end
end
