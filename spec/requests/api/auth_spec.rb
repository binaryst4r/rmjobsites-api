require 'rails_helper'

RSpec.describe 'Api::Auth', type: :request do
  describe 'POST /api/auth/register' do
    let(:valid_params) do
      {
        email: 'newuser@example.com',
        password: 'password123',
        password_confirmation: 'password123'
      }
    end

    context 'with valid parameters' do
      it 'creates a new user' do
        expect {
          post '/api/auth/register', params: valid_params
        }.to change(User, :count).by(1)
      end

      it 'returns created status' do
        post '/api/auth/register', params: valid_params
        expect(response).to have_http_status(:created)
      end

      it 'returns JWT token' do
        post '/api/auth/register', params: valid_params
        expect(json_response[:token]).to be_present
      end

      it 'returns user data' do
        post '/api/auth/register', params: valid_params
        expect(json_response[:user]).to include(
          email: 'newuser@example.com',
          admin: false
        )
        expect(json_response[:user][:id]).to be_present
      end
    end

    context 'with invalid parameters' do
      it 'returns unprocessable_entity for missing email' do
        post '/api/auth/register', params: valid_params.merge(email: '')
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error messages' do
        post '/api/auth/register', params: valid_params.merge(email: '')
        expect(json_response[:errors]).to be_present
      end

      it 'returns error for password mismatch' do
        post '/api/auth/register', params: valid_params.merge(password_confirmation: 'different')
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error for duplicate email' do
        create(:user, email: 'duplicate@example.com')
        post '/api/auth/register', params: valid_params.merge(email: 'duplicate@example.com')
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:errors]).to include(/Email has already been taken/)
      end

      it 'returns error for short password' do
        post '/api/auth/register', params: valid_params.merge(password: '123', password_confirmation: '123')
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'POST /api/auth/login' do
    let!(:user) { create(:user, email: 'test@example.com', password: 'password123', password_confirmation: 'password123') }

    context 'with valid credentials' do
      it 'returns ok status' do
        post '/api/auth/login', params: { email: 'test@example.com', password: 'password123' }
        expect(response).to have_http_status(:ok)
      end

      it 'returns JWT token' do
        post '/api/auth/login', params: { email: 'test@example.com', password: 'password123' }
        expect(json_response[:token]).to be_present
      end

      it 'returns user data' do
        post '/api/auth/login', params: { email: 'test@example.com', password: 'password123' }
        expect(json_response[:user]).to include(
          id: user.id,
          email: 'test@example.com',
          admin: false
        )
      end

      it 'returns admin flag for admin users' do
        admin = create(:user, :admin, email: 'admin@example.com', password: 'password123', password_confirmation: 'password123')
        post '/api/auth/login', params: { email: 'admin@example.com', password: 'password123' }
        expect(json_response[:user][:admin]).to be true
      end
    end

    context 'with invalid credentials' do
      it 'returns unauthorized for wrong password' do
        post '/api/auth/login', params: { email: 'test@example.com', password: 'wrongpassword' }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns error message for wrong password' do
        post '/api/auth/login', params: { email: 'test@example.com', password: 'wrongpassword' }
        expect(json_response[:error]).to eq('Invalid email or password')
      end

      it 'returns unauthorized for non-existent email' do
        post '/api/auth/login', params: { email: 'nonexistent@example.com', password: 'password123' }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns error message for non-existent email' do
        post '/api/auth/login', params: { email: 'nonexistent@example.com', password: 'password123' }
        expect(json_response[:error]).to eq('Invalid email or password')
      end
    end
  end

  describe 'GET /api/auth/profile' do
    let(:user) { create(:user) }

    context 'with valid authentication' do
      it 'returns ok status' do
        get '/api/auth/profile', headers: auth_headers(user)
        expect(response).to have_http_status(:ok)
      end

      it 'returns current user data' do
        get '/api/auth/profile', headers: auth_headers(user)
        expect(json_response[:user]).to be_present
      end
    end

    context 'without authentication' do
      it 'returns ok status with nil user' do
        get '/api/auth/profile'
        expect(response).to have_http_status(:ok)
        expect(json_response[:user]).to be_nil
      end
    end

    context 'with invalid token' do
      it 'returns unauthorized status' do
        get '/api/auth/profile', headers: { 'Authorization' => 'Bearer invalid.token.here' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
