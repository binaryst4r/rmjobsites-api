require 'rails_helper'

RSpec.describe SendgridService do
  let(:service) { described_class.new }

  let(:order) do
    {
      id: 'ORDER123',
      created_at: '2025-01-15T10:30:00Z',
      total_money: { amount: 15000, currency: 'USD' },
      total_line_items_money: { amount: 12000, currency: 'USD' },
      total_tax_money: { amount: 1000, currency: 'USD' },
      total_service_charge_money: { amount: 2000, currency: 'USD' },
      line_items: [
        {
          name: 'Test Product',
          quantity: '2',
          total_money: { amount: 12000, currency: 'USD' }
        }
      ],
      fulfillments: [
        {
          type: 'PICKUP',
          pickup_details: {
            pickup_at: '2025-01-16T14:00:00Z',
            note: 'Please bring a valid ID for pickup.'
          }
        }
      ]
    }
  end

  let(:payment) do
    {
      id: 'PAYMENT123',
      card_details: {
        card: {
          card_brand: 'VISA',
          last_4: '1234'
        }
      }
    }
  end

  let(:customer) do
    {
      id: 'CUSTOMER123',
      email_address: 'test@example.com',
      given_name: 'John',
      family_name: 'Doe'
    }
  end

  describe '#send_order_confirmation' do
    context 'when SendGrid API key is not configured' do
      before do
        allow(Rails.application.config.sendgrid).to receive(:[]).with(:api_key).and_return(nil)
      end

      it 'logs a warning and returns false' do
        expect(Rails.logger).to receive(:warn).with(/SendGrid API key not configured/)
        result = service.send_order_confirmation(
          order: order,
          payment: payment,
          customer: customer,
          fulfillment_type: 'PICKUP'
        )
        expect(result).to be false
      end
    end

    context 'when SendGrid API key is configured' do
      before do
        allow(Rails.application.config.sendgrid).to receive(:[]).with(:api_key).and_return('test_api_key')
        allow(Rails.application.config.sendgrid).to receive(:[]).with(:from_email).and_return('orders@test.com')
        allow(Rails.application.config.sendgrid).to receive(:[]).with(:from_name).and_return('Test Store')
      end

      context 'when email is sent successfully' do
        let(:mock_response) { double('response', status_code: 202, body: 'Accepted') }
        let(:mock_client) { double('client') }
        let(:mock_mail_endpoint) { double('mail_endpoint') }
        let(:mock_send_endpoint) { double('send_endpoint') }

        before do
          allow(SendGrid::API).to receive(:new).and_return(mock_client)
          allow(mock_client).to receive(:client).and_return(mock_client)
          allow(mock_client).to receive(:mail).and_return(mock_mail_endpoint)
          allow(mock_mail_endpoint).to receive(:_).with('send').and_return(mock_send_endpoint)
          allow(mock_send_endpoint).to receive(:post).and_return(mock_response)
        end

        it 'sends the email and returns true' do
          expect(Rails.logger).to receive(:info).with(/Order confirmation email sent successfully/)

          result = service.send_order_confirmation(
            order: order,
            payment: payment,
            customer: customer,
            fulfillment_type: 'PICKUP'
          )

          expect(result).to be true
        end

        it 'includes correct email content for pickup orders' do
          expect(SendGrid::API).to receive(:new).with(api_key: 'test_api_key').and_return(mock_client)

          service.send_order_confirmation(
            order: order,
            payment: payment,
            customer: customer,
            fulfillment_type: 'PICKUP'
          )
        end
      end

      context 'when email sending fails with error response' do
        let(:mock_response) { double('response', status_code: 400, body: 'Bad Request') }
        let(:mock_client) { double('client') }
        let(:mock_mail_endpoint) { double('mail_endpoint') }
        let(:mock_send_endpoint) { double('send_endpoint') }

        before do
          allow(SendGrid::API).to receive(:new).and_return(mock_client)
          allow(mock_client).to receive(:client).and_return(mock_client)
          allow(mock_client).to receive(:mail).and_return(mock_mail_endpoint)
          allow(mock_mail_endpoint).to receive(:_).with('send').and_return(mock_send_endpoint)
          allow(mock_send_endpoint).to receive(:post).and_return(mock_response)
        end

        it 'logs the error and returns false' do
          expect(Rails.logger).to receive(:error).with(/SendGrid API returned error: 400/)
          expect(Rails.logger).to receive(:error).with(/Failed to send order confirmation email/)

          result = service.send_order_confirmation(
            order: order,
            payment: payment,
            customer: customer,
            fulfillment_type: 'PICKUP'
          )

          expect(result).to be false
        end
      end

      context 'when an exception is raised' do
        before do
          allow(SendGrid::API).to receive(:new).and_raise(StandardError.new('Network error'))
        end

        it 'logs the error and returns false' do
          expect(Rails.logger).to receive(:error).with(/Failed to send order confirmation email: Network error/)

          result = service.send_order_confirmation(
            order: order,
            payment: payment,
            customer: customer,
            fulfillment_type: 'PICKUP'
          )

          expect(result).to be false
        end
      end
    end

    context 'with shipment fulfillment type' do
      let(:shipping_order) do
        order.merge(
          fulfillments: [
            {
              type: 'SHIPMENT',
              shipment_details: {
                recipient: {
                  display_name: 'Jane Doe',
                  address: {
                    address_line_1: '123 Main St',
                    address_line_2: 'Apt 4',
                    locality: 'Denver',
                    administrative_district_level_1: 'CO',
                    postal_code: '80202'
                  }
                }
              }
            }
          ]
        )
      end

      let(:mock_response) { double('response', status_code: 202, body: 'Accepted') }
      let(:mock_client) { double('client') }
      let(:mock_mail_endpoint) { double('mail_endpoint') }
      let(:mock_send_endpoint) { double('send_endpoint') }

      before do
        allow(Rails.application.config.sendgrid).to receive(:[]).with(:api_key).and_return('test_api_key')
        allow(Rails.application.config.sendgrid).to receive(:[]).with(:from_email).and_return('orders@test.com')
        allow(Rails.application.config.sendgrid).to receive(:[]).with(:from_name).and_return('Test Store')

        allow(SendGrid::API).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:client).and_return(mock_client)
        allow(mock_client).to receive(:mail).and_return(mock_mail_endpoint)
        allow(mock_mail_endpoint).to receive(:_).with('send').and_return(mock_send_endpoint)
        allow(mock_send_endpoint).to receive(:post).and_return(mock_response)
      end

      it 'sends email with shipping details' do
        expect(Rails.logger).to receive(:info).with(/Order confirmation email sent successfully/)

        result = service.send_order_confirmation(
          order: shipping_order,
          payment: payment,
          customer: customer,
          fulfillment_type: 'SHIPMENT'
        )

        expect(result).to be true
      end
    end
  end

  describe 'private methods' do
    describe '#format_money' do
      it 'formats money correctly' do
        result = service.send(:format_money, { amount: 12345, currency: 'USD' })
        expect(result).to eq('$123.45')
      end

      it 'handles nil money' do
        result = service.send(:format_money, nil)
        expect(result).to eq('$0.00')
      end

      it 'handles zero amount' do
        result = service.send(:format_money, { amount: 0, currency: 'USD' })
        expect(result).to eq('$0.00')
      end
    end

    describe '#format_order_date' do
      it 'formats date correctly' do
        result = service.send(:format_order_date, '2025-01-15T10:30:00Z')
        expect(result).to match(/January 15, 2025/)
      end

      it 'handles nil date' do
        result = service.send(:format_order_date, nil)
        expect(result).to eq('')
      end
    end

    describe '#format_pickup_time' do
      it 'formats pickup time correctly' do
        result = service.send(:format_pickup_time, '2025-01-16T14:00:00Z')
        expect(result).to match(/Wednesday, January/)
      end

      it 'handles nil time' do
        result = service.send(:format_pickup_time, nil)
        expect(result).to eq('')
      end
    end
  end
end
