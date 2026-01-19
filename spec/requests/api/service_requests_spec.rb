require 'rails_helper'

RSpec.describe 'Api::ServiceRequests', type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  describe 'POST /api/service_requests' do
    let(:valid_params) do
      {
        service_request: {
          customer_name: 'John Doe',
          company: 'Acme Inc',
          service_requested: 'Installation',
          pickup_date: Date.today + 7.days,
          return_date: Date.today + 14.days,
          manufacturer: 'TestCo',
          model: 'Model-123',
          serial_number: 'SN123456'
        }
      }
    end

    context 'without authentication' do
      it 'creates a service request' do
        expect {
          post '/api/service_requests', params: valid_params
        }.to change(ServiceRequest, :count).by(1)
      end

      it 'returns created status' do
        post '/api/service_requests', params: valid_params
        expect(response).to have_http_status(:created)
      end

      it 'returns success message' do
        post '/api/service_requests', params: valid_params
        expect(json_response[:message]).to eq('Service request submitted successfully')
      end

      it 'does not associate with a user' do
        post '/api/service_requests', params: valid_params
        expect(ServiceRequest.last.user_id).to be_nil
      end
    end

    context 'with authenticated user' do
      it 'associates service request with user' do
        post '/api/service_requests', params: valid_params, headers: auth_headers(user)
        expect(ServiceRequest.last.user_id).to eq(user.id)
      end
    end

    context 'with invalid parameters' do
      it 'returns unprocessable_entity for missing required fields' do
        invalid_params = { service_request: { customer_name: 'John Doe' } }
        post '/api/service_requests', params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error messages' do
        invalid_params = { service_request: { customer_name: 'John Doe' } }
        post '/api/service_requests', params: invalid_params
        expect(json_response[:errors]).to be_present
      end

      it 'returns error for invalid date range' do
        invalid_date_params = valid_params.deep_merge(
          service_request: {
            pickup_date: Date.today,
            return_date: Date.today - 1.day
          }
        )
        post '/api/service_requests', params: invalid_date_params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:errors]).to include(/Return date must be after pickup date/)
      end
    end
  end

  describe 'GET /api/service_requests' do
    let!(:service_request1) { create(:service_request, user: user) }
    let!(:service_request2) { create(:service_request, user: user) }

    context 'with admin authentication' do
      it 'returns ok status' do
        get '/api/service_requests', headers: auth_headers(admin)
        expect(response).to have_http_status(:ok)
      end

      it 'returns all service requests' do
        get '/api/service_requests', headers: auth_headers(admin)
        expect(json_response[:service_requests].length).to eq(2)
      end

      it 'orders by created_at descending' do
        get '/api/service_requests', headers: auth_headers(admin)
        expect(json_response[:service_requests].first[:id]).to eq(service_request2.id)
      end
    end

    context 'with regular user authentication' do
      it 'returns forbidden status' do
        get '/api/service_requests', headers: auth_headers(user)
        expect(response).to have_http_status(:forbidden)
      end

      it 'returns error message' do
        get '/api/service_requests', headers: auth_headers(user)
        expect(json_response[:error]).to eq('Unauthorized. Admin access required.')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        get '/api/service_requests'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/service_requests/:id/assign' do
    let!(:service_request) { create(:service_request) }
    let(:another_admin) { create(:user, :admin) }

    context 'with admin authentication' do
      it 'assigns service request to admin user' do
        post "/api/service_requests/#{service_request.id}/assign",
             params: { assigned_to_user_id: another_admin.id },
             headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(service_request.reload.assignment).to be_present
        expect(service_request.assignment.assigned_to_user).to eq(another_admin)
      end

      it 'returns success message' do
        post "/api/service_requests/#{service_request.id}/assign",
             params: { assigned_to_user_id: another_admin.id },
             headers: auth_headers(admin)

        expect(json_response[:message]).to eq('Service request assigned successfully')
      end

      it 'sets assigned_by_user to current admin' do
        post "/api/service_requests/#{service_request.id}/assign",
             params: { assigned_to_user_id: another_admin.id },
             headers: auth_headers(admin)

        expect(service_request.reload.assignment.assigned_by_user).to eq(admin)
      end

      it 'returns error when assigning to non-admin user' do
        post "/api/service_requests/#{service_request.id}/assign",
             params: { assigned_to_user_id: user.id },
             headers: auth_headers(admin)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:error]).to match(/User must be an admin/)
      end

      it 'updates existing assignment' do
        create(:service_request_assignment,
               service_request: service_request,
               assigned_to_user: admin,
               assigned_by_user: admin)

        post "/api/service_requests/#{service_request.id}/assign",
             params: { assigned_to_user_id: another_admin.id },
             headers: auth_headers(admin)

        expect(response).to have_http_status(:ok)
        expect(service_request.reload.assignment.assigned_to_user).to eq(another_admin)
      end

      it 'returns not_found for non-existent service request' do
        post "/api/service_requests/99999/assign",
             params: { assigned_to_user_id: another_admin.id },
             headers: auth_headers(admin)

        expect(response).to have_http_status(:not_found)
      end

      it 'returns not_found for non-existent user' do
        post "/api/service_requests/#{service_request.id}/assign",
             params: { assigned_to_user_id: 99999 },
             headers: auth_headers(admin)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with regular user authentication' do
      it 'returns forbidden status' do
        post "/api/service_requests/#{service_request.id}/assign",
             params: { assigned_to_user_id: admin.id },
             headers: auth_headers(user)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized status' do
        post "/api/service_requests/#{service_request.id}/assign",
             params: { assigned_to_user_id: admin.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
