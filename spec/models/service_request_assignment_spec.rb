require 'rails_helper'

RSpec.describe ServiceRequestAssignment, type: :model do
  describe 'validations' do
    let(:admin_user) { create(:user, :admin) }
    let(:regular_user) { create(:user) }
    let(:service_request) { create(:service_request) }

    it 'is valid with valid attributes' do
      assignment = build(:service_request_assignment,
                        service_request: service_request,
                        assigned_to_user: admin_user,
                        assigned_by_user: admin_user)
      expect(assignment).to be_valid
    end

    it 'requires service_request_id to be unique' do
      create(:service_request_assignment,
            service_request: service_request,
            assigned_to_user: admin_user,
            assigned_by_user: admin_user)

      duplicate = build(:service_request_assignment,
                       service_request: service_request,
                       assigned_to_user: admin_user,
                       assigned_by_user: admin_user)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:service_request_id]).to include("has already been taken")
    end

    it 'requires assigned_to_user to be an admin' do
      assignment = build(:service_request_assignment,
                        service_request: service_request,
                        assigned_to_user: regular_user,
                        assigned_by_user: admin_user)

      expect(assignment).not_to be_valid
      expect(assignment.errors[:assigned_to_user]).to include("must be an admin user")
    end

    it 'is valid when assigned_to_user is an admin' do
      assignment = build(:service_request_assignment,
                        service_request: service_request,
                        assigned_to_user: admin_user,
                        assigned_by_user: admin_user)

      expect(assignment).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to service_request' do
      association = ServiceRequestAssignment.reflect_on_association(:service_request)
      expect(association.macro).to eq(:belongs_to)
    end

    it 'belongs to assigned_to_user' do
      association = ServiceRequestAssignment.reflect_on_association(:assigned_to_user)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:class_name]).to eq('User')
    end

    it 'belongs to assigned_by_user' do
      association = ServiceRequestAssignment.reflect_on_association(:assigned_by_user)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:class_name]).to eq('User')
    end
  end

  describe 'callbacks' do
    let(:admin_user) { create(:user, :admin) }
    let(:service_request) { create(:service_request) }

    it 'sends assignment notification after create' do
      expect(ServiceRequestMailer).to receive_message_chain(:assignment_notification, :deliver_later)

      create(:service_request_assignment,
            service_request: service_request,
            assigned_to_user: admin_user,
            assigned_by_user: admin_user)
    end
  end
end
