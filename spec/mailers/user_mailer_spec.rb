require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  describe "#password_reset" do
    let(:user) { create(:user, email: "mailer@example.com", given_name: "Mailer") }
    let(:token) { "fake-reset-token-abc" }
    let(:mail) { described_class.password_reset(user, token) }

    it "renders with the right headers" do
      expect(mail.to).to eq([user.email])
      expect(mail.subject).to match(/reset your rmjobsites password/i)
    end

    it "includes the reset link containing the token" do
      expect(mail.body.encoded).to include(token)
      expect(mail.body.encoded).to include("/reset-password/#{token}")
    end

    it "greets the user by their given name when present" do
      expect(mail.body.encoded).to include("Mailer")
    end
  end
end
