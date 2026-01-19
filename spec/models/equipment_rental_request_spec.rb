require 'rails_helper'

RSpec.describe EquipmentRentalRequest, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      request = build(:equipment_rental_request)
      expect(request).to be_valid
    end

    it 'requires customer_first_name' do
      request = build(:equipment_rental_request, customer_first_name: nil)
      expect(request).not_to be_valid
      expect(request.errors[:customer_first_name]).to include("can't be blank")
    end

    it 'requires customer_last_name' do
      request = build(:equipment_rental_request, customer_last_name: nil)
      expect(request).not_to be_valid
      expect(request.errors[:customer_last_name]).to include("can't be blank")
    end

    it 'requires customer_email' do
      request = build(:equipment_rental_request, customer_email: nil)
      expect(request).not_to be_valid
      expect(request.errors[:customer_email]).to include("can't be blank")
    end

    it 'validates customer_email format' do
      request = build(:equipment_rental_request, customer_email: 'invalid-email')
      expect(request).not_to be_valid
      expect(request.errors[:customer_email]).to include("is invalid")
    end

    it 'accepts valid customer_email format' do
      request = build(:equipment_rental_request, customer_email: 'test@example.com')
      expect(request).to be_valid
    end

    it 'requires customer_phone' do
      request = build(:equipment_rental_request, customer_phone: nil)
      expect(request).not_to be_valid
      expect(request.errors[:customer_phone]).to include("can't be blank")
    end

    it 'requires equipment_type' do
      request = build(:equipment_rental_request, equipment_type: nil)
      expect(request).not_to be_valid
      expect(request.errors[:equipment_type]).to include("can't be blank")
    end

    it 'requires pickup_date' do
      request = build(:equipment_rental_request, pickup_date: nil)
      expect(request).not_to be_valid
      expect(request.errors[:pickup_date]).to include("can't be blank")
    end

    it 'requires return_date' do
      request = build(:equipment_rental_request, return_date: nil)
      expect(request).not_to be_valid
      expect(request.errors[:return_date]).to include("can't be blank")
    end

    it 'requires return_date to be after pickup_date' do
      request = build(:equipment_rental_request, :with_invalid_dates)
      expect(request).not_to be_valid
      expect(request.errors[:return_date]).to include("must be after pickup date")
    end

    it 'is valid when return_date is after pickup_date' do
      request = build(:equipment_rental_request,
                     pickup_date: Date.today,
                     return_date: Date.today + 1.day)
      expect(request).to be_valid
    end

    it 'requires rental_agreement_accepted to be true' do
      request = build(:equipment_rental_request, :agreement_not_accepted)
      expect(request).not_to be_valid
      expect(request.errors[:rental_agreement_accepted]).to include("must be accepted")
    end

    it 'is valid when rental_agreement_accepted is true' do
      request = build(:equipment_rental_request,
                      rental_agreement_accepted: true,
                      pickup_date: Date.today + 7.days,
                      return_date: Date.today + 14.days)
      expect(request).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to user (optional)' do
      association = EquipmentRentalRequest.reflect_on_association(:user)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:optional]).to be_truthy
    end

    it 'can be created without a user' do
      request = build(:equipment_rental_request, user: nil)
      expect(request).to be_valid
    end

    it 'can be associated with a user' do
      user = create(:user)
      request = create(:equipment_rental_request, user: user)
      expect(request.user).to eq(user)
    end
  end
end
