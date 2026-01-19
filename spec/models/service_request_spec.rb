require 'rails_helper'

RSpec.describe ServiceRequest, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      service_request = build(:service_request)
      expect(service_request).to be_valid
    end

    it 'requires customer_name' do
      service_request = build(:service_request, customer_name: nil)
      expect(service_request).not_to be_valid
      expect(service_request.errors[:customer_name]).to include("can't be blank")
    end

    it 'requires company' do
      service_request = build(:service_request, company: nil)
      expect(service_request).not_to be_valid
      expect(service_request.errors[:company]).to include("can't be blank")
    end

    it 'requires service_requested' do
      service_request = build(:service_request, service_requested: nil)
      expect(service_request).not_to be_valid
      expect(service_request.errors[:service_requested]).to include("can't be blank")
    end

    it 'requires pickup_date' do
      service_request = build(:service_request, pickup_date: nil)
      expect(service_request).not_to be_valid
      expect(service_request.errors[:pickup_date]).to include("can't be blank")
    end

    it 'requires return_date' do
      service_request = build(:service_request, return_date: nil)
      expect(service_request).not_to be_valid
      expect(service_request.errors[:return_date]).to include("can't be blank")
    end

    it 'requires manufacturer' do
      service_request = build(:service_request, manufacturer: nil)
      expect(service_request).not_to be_valid
      expect(service_request.errors[:manufacturer]).to include("can't be blank")
    end

    it 'requires model' do
      service_request = build(:service_request, model: nil)
      expect(service_request).not_to be_valid
      expect(service_request.errors[:model]).to include("can't be blank")
    end

    it 'requires serial_number' do
      service_request = build(:service_request, serial_number: nil)
      expect(service_request).not_to be_valid
      expect(service_request.errors[:serial_number]).to include("can't be blank")
    end

    it 'requires return_date to be after pickup_date' do
      service_request = build(:service_request,
                              pickup_date: Date.today,
                              return_date: Date.today - 1.day)
      expect(service_request).not_to be_valid
      expect(service_request.errors[:return_date]).to include("must be after pickup date")
    end

    it 'is valid when return_date is after pickup_date' do
      service_request = build(:service_request,
                              pickup_date: Date.today,
                              return_date: Date.today + 1.day)
      expect(service_request).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to user (optional)' do
      association = ServiceRequest.reflect_on_association(:user)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:optional]).to be_truthy
    end

    it 'has one assignment' do
      association = ServiceRequest.reflect_on_association(:assignment)
      expect(association.macro).to eq(:has_one)
      expect(association.options[:class_name]).to eq('ServiceRequestAssignment')
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it 'destroys associated assignment when destroyed' do
      admin = create(:user, :admin)
      service_request = create(:service_request)
      assignment = create(:service_request_assignment,
                         service_request: service_request,
                         assigned_to_user: admin,
                         assigned_by_user: admin)

      expect { service_request.destroy }.to change { ServiceRequestAssignment.count }.by(-1)
    end
  end
end
