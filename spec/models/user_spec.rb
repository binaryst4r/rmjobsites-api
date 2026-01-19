require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'requires an email' do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'requires a unique email' do
      create(:user, email: 'test@example.com')
      user = build(:user, email: 'test@example.com')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("has already been taken")
    end

    it 'requires a valid email format' do
      user = build(:user, email: 'invalid-email')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("is invalid")
    end

    it 'requires a password with minimum length' do
      user = build(:user, password: '12345', password_confirmation: '12345')
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("is too short (minimum is 6 characters)")
    end

    it 'accepts valid password' do
      user = build(:user, password: 'password123', password_confirmation: 'password123')
      expect(user).to be_valid
    end
  end

  describe 'associations' do
    it 'has many service_requests' do
      association = User.reflect_on_association(:service_requests)
      expect(association.macro).to eq(:has_many)
    end

    it 'has many assigned_service_requests' do
      association = User.reflect_on_association(:assigned_service_requests)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:class_name]).to eq('ServiceRequestAssignment')
    end
  end

  describe 'password authentication' do
    it 'authenticates with correct password' do
      user = create(:user, password: 'password123', password_confirmation: 'password123')
      expect(user.authenticate('password123')).to eq(user)
    end

    it 'fails authentication with incorrect password' do
      user = create(:user, password: 'password123', password_confirmation: 'password123')
      expect(user.authenticate('wrongpassword')).to be_falsey
    end

    it 'stores encrypted password' do
      user = create(:user, password: 'password123', password_confirmation: 'password123')
      expect(user.password_digest).not_to be_nil
      expect(user.password_digest).not_to eq('password123')
    end
  end

  describe 'admin attribute' do
    it 'defaults to false' do
      user = create(:user)
      expect(user.admin).to be_falsey
    end

    it 'can be set to true' do
      user = create(:user, :admin)
      expect(user.admin).to be_truthy
    end
  end
end
