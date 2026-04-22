require "rails_helper"

RSpec.describe CustomerImporter do
  let(:fixture_path) { Rails.root.join("docs/test-customer-import.csv") }

  describe "#call" do
    it "imports all rows from the sample CSV into new users" do
      expect { described_class.new(fixture_path.to_s).call }
        .to change(User, :count).by(3)

      cj = User.find_by(email: "cj.holder@heicivil.com")
      expect(cj).to be_present
      expect(cj.given_name).to eq("CJ")
      expect(cj.family_name).to eq("Holder")
      expect(cj.company_name).to eq("HEI Civil")
      expect(cj.square_customer_id).to eq("4Z9WSV6V2RYDNYMSJF08EXWYJW")
      expect(cj.phone_number).to eq("+17205956459")
      expect(cj.address_line_1).to eq("5460 Montana Vista Way")
      expect(cj.city).to eq("Castle Rock")
      expect(cj.state).to eq("CO")
      expect(cj.postal_code).to eq("80108")
      expect(cj.country).to eq("US")
      expect(cj.password_digest).to be_present
    end

    it "is idempotent — re-importing skips existing users" do
      first = described_class.new(fixture_path.to_s).call
      expect(first.imported.size).to eq(3)
      expect(first.skipped.size).to eq(0)

      second = described_class.new(fixture_path.to_s).call
      expect(second.imported.size).to eq(0)
      expect(second.skipped.size).to eq(3)
      expect(second.skipped.first[:reason]).to eq("already exists")
    end

    it "dedups by square_customer_id even if email differs" do
      User.create!(
        email: "existing@example.com",
        password: SecureRandom.hex(32),
        square_customer_id: "4Z9WSV6V2RYDNYMSJF08EXWYJW"
      )

      result = described_class.new(fixture_path.to_s).call
      expect(result.imported.size).to eq(2)
      expect(result.skipped.size).to eq(1)
    end

    it "skips rows with a blank email" do
      csv = <<~CSV
        First Name,Last Name,Email Address,Phone Number,Square Customer ID
        Nora,NoEmail,,,SOMEID123
      CSV

      result = described_class.new(StringIO.new(csv)).call
      expect(result.imported.size).to eq(0)
      expect(result.skipped.size).to eq(1)
      expect(result.skipped.first[:reason]).to eq("blank email")
    end

    it "strips the Excel text-forcer quote from phone numbers" do
      csv = <<~CSV
        First Name,Last Name,Email Address,Phone Number,Square Customer ID
        Phone,Test,phone@example.com,'+17201234567,SQX1
      CSV

      result = described_class.new(StringIO.new(csv)).call
      expect(result.imported.size).to eq(1)
      expect(User.find_by(email: "phone@example.com").phone_number).to eq("+17201234567")
    end

    it "collects row-level errors instead of aborting" do
      csv = <<~CSV
        First Name,Last Name,Email Address,Phone Number,Square Customer ID
        Bad,Email,not-a-valid-email,,SQX2
        Good,Email,good@example.com,,SQX3
      CSV

      result = described_class.new(StringIO.new(csv)).call
      expect(result.imported.size).to eq(1)
      expect(result.failed.size).to eq(1)
      expect(result.failed.first[:email]).to eq("not-a-valid-email")
      expect(result.failed.first[:errors].join).to match(/email/i)
    end
  end
end
