require 'rails_helper'

RSpec.describe 'Api::EquipmentRentalRequests', type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  describe 'POST /api/equipment_rental_requests' do
    let(:valid_params) do
      {
        equipment_rental_request: {
          customer_first_name: 'John',
          customer_last_name: 'Doe',
          customer_email: 'john@example.com',
          customer_phone: '555-1234',
          equipment_type: 'Excavator',
          pickup_date: Date.today + 7.days,
          return_date: Date.today + 14.days,
          rental_agreement_accepted: true
        }
      }
    end

    context 'without authentication' do
      it 'creates an equipment rental request' do
        expect {
          post '/api/equipment_rental_requests', params: valid_params
        }.to change(EquipmentRentalRequest, :count).by(1)
      end

      it 'returns created status' do
        post '/api/equipment_rental_requests', params: valid_params
        expect(response).to have_http_status(:created)
      end

      it 'returns success message' do
        post '/api/equipment_rental_requests', params: valid_params
        expect(json_response[:message]).to eq('Equipment rental request submitted successfully')
      end

      it 'does not associate with a user' do
        post '/api/equipment_rental_requests', params: valid_params
        expect(EquipmentRentalRequest.last.user_id).to be_nil
      end
    end

    context 'with authenticated user' do
      it 'associates equipment rental request with user' do
        post '/api/equipment_rental_requests', params: valid_params, headers: auth_headers(user)
        expect(EquipmentRentalRequest.last.user_id).to eq(user.id)
      end

      it 'returns created status' do
        post '/api/equipment_rental_requests', params: valid_params, headers: auth_headers(user)
        expect(response).to have_http_status(:created)
      end
    end

    context 'with invalid parameters' do
      it 'returns unprocessable_entity for missing required fields' do
        invalid_params = { equipment_rental_request: { customer_first_name: 'John' } }
        post '/api/equipment_rental_requests', params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error messages' do
        invalid_params = { equipment_rental_request: { customer_first_name: 'John' } }
        post '/api/equipment_rental_requests', params: invalid_params
        expect(json_response[:errors]).to be_present
      end

      it 'returns error for invalid email format' do
        invalid_email_params = valid_params.deep_merge(
          equipment_rental_request: { customer_email: 'invalid-email' }
        )
        post '/api/equipment_rental_requests', params: invalid_email_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:errors]).to include(/Customer email is invalid/)
      end

      it 'returns error for invalid date range' do
        invalid_date_params = valid_params.deep_merge(
          equipment_rental_request: {
            pickup_date: Date.today,
            return_date: Date.today - 1.day
          }
        )
        post '/api/equipment_rental_requests', params: invalid_date_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:errors]).to include(/Return date must be after pickup date/)
      end

      it 'returns error when rental agreement not accepted' do
        no_agreement_params = valid_params.deep_merge(
          equipment_rental_request: { rental_agreement_accepted: false }
        )
        post '/api/equipment_rental_requests', params: no_agreement_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:errors]).to include(/Rental agreement accepted must be accepted/)
      end
    end
  end

  describe 'GET /api/equipment_rental_requests' do
    let!(:rental_request1) { create(:equipment_rental_request, user: user) }
    let!(:rental_request2) { create(:equipment_rental_request, user: user) }

    context 'with admin authentication' do
      it 'returns ok status' do
        get '/api/equipment_rental_requests', headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
      end

      it 'returns all equipment rental requests' do
        get '/api/equipment_rental_requests', headers: auth_headers(admin)
        expect(json_response[:equipment_rental_requests].length).to eq(2)
      end

      it 'orders by created_at descending' do
        get '/api/equipment_rental_requests', headers: auth_headers(admin)
        expect(json_response[:equipment_rental_requests].first[:id]).to be_present
      end

      it 'includes formatted customer data' do
        get '/api/equipment_rental_requests', headers: auth_headers(admin)
        first_request = json_response[:equipment_rental_requests].first
        expect(first_request[:customer_name]).to be_present
        expect(first_request[:customer_email]).to be_present
        expect(first_request[:equipment]).to be_present
      end
    end

    context 'with regular user authentication' do
      it 'returns forbidden status' do
        get '/api/equipment_rental_requests', headers: auth_headers(user)
        expect(response).to have_http_status(:forbidden)
      end

      it 'returns error message' do
        get '/api/equipment_rental_requests', headers: auth_headers(user)
        expect(json_response[:error]).to eq('Unauthorized. Admin access required.')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        get '/api/equipment_rental_requests'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
