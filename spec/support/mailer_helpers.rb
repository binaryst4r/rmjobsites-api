RSpec.configure do |config|
  config.before(:each) do
    # Stub out mailer deliveries by default to prevent actual email sending in tests
    allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_later)
  end
end
