require 'rails_helper'

RSpec.describe 'Api::Users', type: :request do
  let(:user)  { create(:user) }
  let(:admin) { create(:user, :admin) }

  describe 'GET /api/users' do
    context 'without authentication' do
      it 'returns unauthorized status' do
        get '/api/users'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with regular user authentication' do
      it 'returns forbidden status' do
        get '/api/users', headers: auth_headers(user)
        expect(response).to have_http_status(:forbidden)
      end

      it 'returns admin required error message' do
        get '/api/users', headers: auth_headers(user)
        expect(json_response[:error]).to eq('Unauthorized. Admin access required.')
      end
    end

    context 'with admin authentication' do
      context 'with no params and a small dataset' do
        let!(:users) { create_list(:user, 3) }

        it 'returns ok status' do
          get '/api/users', headers: auth_headers(admin)
          expect(response).to have_http_status(:ok)
        end

        it 'returns users and meta in the response' do
          get '/api/users', headers: auth_headers(admin)
          expect(json_response).to have_key(:users)
          expect(json_response).to have_key(:meta)
        end

        it 'defaults to page 1 with per_page of 25' do
          get '/api/users', headers: auth_headers(admin)
          expect(json_response[:meta][:page]).to eq(1)
          expect(json_response[:meta][:per_page]).to eq(25)
        end

        it 'returns the correct total_count including admin and non-admin users' do
          get '/api/users', headers: auth_headers(admin)
          # 3 regular users + the admin calling the endpoint
          expect(json_response[:meta][:total_count]).to eq(4)
        end

        it 'returns rows with the expected keys' do
          get '/api/users', headers: auth_headers(admin)
          expected_keys = %i[id email given_name family_name phone_number admin square_customer_id created_at]
          expect(json_response[:users].first.keys).to match_array(expected_keys)
        end

        it 'orders users by created_at descending' do
          get '/api/users', headers: auth_headers(admin)
          ids = json_response[:users].map { |u| u[:id] }
          expect(ids).to eq(ids.sort.reverse)
        end
      end

      context 'with pagination params' do
        before { create_list(:user, 11) } # + admin = 12 total

        it 'limits results to per_page' do
          get '/api/users', params: { per_page: 5 }, headers: auth_headers(admin)
          expect(json_response[:users].length).to eq(5)
        end

        it 'reports correct meta for a paginated query' do
          get '/api/users', params: { per_page: 5 }, headers: auth_headers(admin)
          expect(json_response[:meta][:total_count]).to eq(12)
          expect(json_response[:meta][:total_pages]).to eq(3)
          expect(json_response[:meta][:per_page]).to eq(5)
        end

        it 'returns the tail page' do
          get '/api/users', params: { page: 3, per_page: 5 }, headers: auth_headers(admin)
          expect(json_response[:users].length).to eq(2)
          expect(json_response[:meta][:page]).to eq(3)
        end

        it 'clamps per_page above 100 down to 100' do
          get '/api/users', params: { per_page: 500 }, headers: auth_headers(admin)
          expect(json_response[:meta][:per_page]).to eq(100)
        end

        it 'clamps per_page below 1 up to 1' do
          get '/api/users', params: { per_page: 0 }, headers: auth_headers(admin)
          expect(json_response[:meta][:per_page]).to eq(1)
        end

        it 'coerces page < 1 to 1' do
          get '/api/users', params: { page: 0 }, headers: auth_headers(admin)
          expect(json_response[:meta][:page]).to eq(1)
        end
      end

      context 'with a search query' do
        let!(:alice) do
          create(:user, email: 'alice@example.com', given_name: 'Alice', family_name: 'Anderson')
        end
        let!(:bob) do
          create(:user, email: 'bob@example.com', given_name: 'Bob', family_name: 'Baker')
        end
        let!(:percent_user) do
          create(:user, email: 'a%b@example.com', given_name: 'Percy', family_name: 'Penrose')
        end

        it 'filters by email case-insensitively (lowercase query)' do
          get '/api/users', params: { q: 'ali' }, headers: auth_headers(admin)
          emails = json_response[:users].map { |u| u[:email] }
          expect(emails).to contain_exactly('alice@example.com')
        end

        it 'filters by email case-insensitively (uppercase query)' do
          get '/api/users', params: { q: 'ALI' }, headers: auth_headers(admin)
          emails = json_response[:users].map { |u| u[:email] }
          expect(emails).to contain_exactly('alice@example.com')
        end

        it 'filters by given_name' do
          get '/api/users', params: { q: 'Bob' }, headers: auth_headers(admin)
          emails = json_response[:users].map { |u| u[:email] }
          expect(emails).to contain_exactly('bob@example.com')
        end

        it 'filters by family_name' do
          get '/api/users', params: { q: 'Anderson' }, headers: auth_headers(admin)
          emails = json_response[:users].map { |u| u[:email] }
          expect(emails).to contain_exactly('alice@example.com')
        end

        it 'returns an empty result set when nothing matches' do
          get '/api/users', params: { q: 'zzznomatch' }, headers: auth_headers(admin)
          expect(json_response[:users]).to eq([])
          expect(json_response[:meta][:total_count]).to eq(0)
          expect(json_response[:meta][:total_pages]).to eq(0)
        end

        it 'treats a literal % as a character, not a wildcard' do
          get '/api/users', params: { q: '%' }, headers: auth_headers(admin)
          emails = json_response[:users].map { |u| u[:email] }
          expect(emails).to contain_exactly('a%b@example.com')
        end

        it 'ignores whitespace-only queries' do
          get '/api/users', params: { q: '   ' }, headers: auth_headers(admin)
          # admin + alice + bob + percent_user = 4 users
          expect(json_response[:meta][:total_count]).to eq(4)
        end
      end
    end
  end
end
