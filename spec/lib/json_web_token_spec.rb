require 'rails_helper'

RSpec.describe JsonWebToken do
  let(:user_id) { 123 }
  let(:payload) { { user_id: user_id } }

  describe '.encode' do
    it 'encodes a payload with default expiration' do
      token = JsonWebToken.encode(payload)
      expect(token).to be_a(String)
      expect(token).not_to be_empty
    end

    it 'includes expiration time in the payload' do
      expected_exp = 24.hours.from_now.to_i
      token = JsonWebToken.encode(payload)
      decoded = JWT.decode(token, described_class::SECRET_KEY)[0]

      # Allow for a small time difference due to test execution time
      expect(decoded['exp']).to be_within(2).of(expected_exp)
    end

    it 'accepts custom expiration time' do
      custom_exp = 1.hour.from_now
      token = JsonWebToken.encode(payload, custom_exp)
      decoded = JWT.decode(token, described_class::SECRET_KEY)[0]

      expect(decoded['exp']).to eq(custom_exp.to_i)
    end

    it 'preserves payload data' do
      token = JsonWebToken.encode(payload)
      decoded = JWT.decode(token, described_class::SECRET_KEY)[0]

      expect(decoded['user_id']).to eq(user_id)
    end
  end

  describe '.decode' do
    it 'decodes a valid token' do
      token = JsonWebToken.encode(payload)
      decoded = JsonWebToken.decode(token)

      expect(decoded).to be_a(HashWithIndifferentAccess)
      expect(decoded[:user_id]).to eq(user_id)
    end

    it 'returns nil for nil token' do
      expect(JsonWebToken.decode(nil)).to be_nil
    end

    it 'returns nil for invalid token' do
      expect(JsonWebToken.decode('invalid.token.here')).to be_nil
    end

    it 'returns nil for expired token' do
      token = JsonWebToken.encode(payload, 1.hour.ago)
      expect(JsonWebToken.decode(token)).to be_nil
    end

    it 'returns nil for token with wrong secret' do
      token = JWT.encode(payload, 'wrong_secret')
      expect(JsonWebToken.decode(token)).to be_nil
    end

    it 'allows access with both string and symbol keys' do
      token = JsonWebToken.encode(payload)
      decoded = JsonWebToken.decode(token)

      expect(decoded[:user_id]).to eq(user_id)
      expect(decoded['user_id']).to eq(user_id)
    end
  end

  describe 'round-trip encoding and decoding' do
    it 'preserves data through encode/decode cycle' do
      complex_payload = {
        user_id: 456,
        email: 'test@example.com',
        admin: true,
        metadata: { role: 'admin' }
      }

      token = JsonWebToken.encode(complex_payload)
      decoded = JsonWebToken.decode(token)

      expect(decoded[:user_id]).to eq(456)
      expect(decoded[:email]).to eq('test@example.com')
      expect(decoded[:admin]).to eq(true)
      expect(decoded[:metadata]).to eq({ 'role' => 'admin' })
    end
  end
end
