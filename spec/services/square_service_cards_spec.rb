require 'rails_helper'

RSpec.describe SquareService, type: :service do
  let(:service) { described_class.new }
  let(:mock_client) { double('Square::Client') }
  let(:mock_cards_api) { double('CardsApi') }
  let(:mock_payments_api) { double('PaymentsApi') }

  before do
    allow(Square::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:cards).and_return(mock_cards_api)
    allow(mock_client).to receive(:payments).and_return(mock_payments_api)
  end

  describe '#create_card' do
    let(:customer_id) { 'CUSTOMER_123' }
    let(:source_id) { 'cnon:card-nonce-ok' }
    let(:billing_address) do
      {
        address_line_1: '123 Main St',
        locality: 'San Francisco',
        administrative_district_level_1: 'CA',
        postal_code: '94103',
        country: 'US'
      }
    end
    let(:cardholder_name) { 'John Doe' }

    let(:successful_response) do
      {
        card: {
          id: 'ccof:CARD_ID_123',
          card_brand: 'VISA',
          last_4: '1234',
          exp_month: 12,
          exp_year: 2025,
          cardholder_name: cardholder_name,
          billing_address: billing_address,
          customer_id: customer_id
        }
      }
    end

    context 'with all parameters' do
      it 'creates a card on file successfully' do
        expect(mock_cards_api).to receive(:create) do |**args|
          expect(args[:source_id]).to eq(source_id)
          expect(args[:card][:customer_id]).to eq(customer_id)
          expect(args[:card][:billing_address]).to eq(billing_address)
          expect(args[:card][:cardholder_name]).to eq(cardholder_name)
          expect(args[:idempotency_key]).to be_present

          double(to_h: successful_response)
        end

        result = service.create_card(
          customer_id: customer_id,
          source_id: source_id,
          billing_address: billing_address,
          cardholder_name: cardholder_name
        )

        expect(result[:card][:id]).to eq('ccof:CARD_ID_123')
        expect(result[:card][:last_4]).to eq('1234')
        expect(result[:card][:customer_id]).to eq(customer_id)
      end
    end

    context 'with minimal parameters' do
      it 'creates a card with only required fields' do
        expect(mock_cards_api).to receive(:create) do |**args|
          expect(args[:source_id]).to eq(source_id)
          expect(args[:card][:customer_id]).to eq(customer_id)
          expect(args[:card][:billing_address]).to be_nil
          expect(args[:card][:cardholder_name]).to be_nil

          double(to_h: successful_response)
        end

        result = service.create_card(
          customer_id: customer_id,
          source_id: source_id
        )

        expect(result[:card]).to be_present
      end
    end

    context 'when API returns an error' do
      it 'raises a SquareError' do
        allow(mock_cards_api).to receive(:create)
          .and_raise(StandardError.new('Invalid card'))

        expect {
          service.create_card(
            customer_id: customer_id,
            source_id: source_id
          )
        }.to raise_error(SquareService::SquareError, /Invalid card/)
      end
    end
  end

  describe '#list_customer_cards' do
    let(:customer_id) { 'CUSTOMER_123' }
    let(:successful_response) do
      {
        cards: [
          {
            id: 'ccof:CARD_1',
            card_brand: 'VISA',
            last_4: '1111',
            exp_month: 12,
            exp_year: 2025,
            customer_id: customer_id
          },
          {
            id: 'ccof:CARD_2',
            card_brand: 'MASTERCARD',
            last_4: '2222',
            exp_month: 6,
            exp_year: 2026,
            customer_id: customer_id
          }
        ],
        cursor: 'NEXT_PAGE_TOKEN'
      }
    end

    context 'with default parameters' do
      it 'lists all active cards for a customer' do
        expect(mock_cards_api).to receive(:list) do |**args|
          expect(args[:customer_id]).to eq(customer_id)
          expect(args[:include_disabled]).to eq(false)

          double(to_h: successful_response)
        end

        result = service.list_customer_cards(customer_id: customer_id)

        expect(result[:cards]).to be_an(Array)
        expect(result[:cards].length).to eq(2)
        expect(result[:cards].first[:id]).to eq('ccof:CARD_1')
        expect(result[:cursor]).to eq('NEXT_PAGE_TOKEN')
      end
    end

    context 'with pagination cursor' do
      it 'includes the cursor in the request' do
        cursor = 'PAGE_TOKEN_123'

        expect(mock_cards_api).to receive(:list) do |**args|
          expect(args[:customer_id]).to eq(customer_id)
          expect(args[:cursor]).to eq(cursor)

          double(to_h: successful_response)
        end

        service.list_customer_cards(customer_id: customer_id, cursor: cursor)
      end
    end

    context 'with include_disabled true' do
      it 'includes disabled cards in the response' do
        expect(mock_cards_api).to receive(:list) do |**args|
          expect(args[:include_disabled]).to eq(true)

          double(to_h: successful_response)
        end

        service.list_customer_cards(
          customer_id: customer_id,
          include_disabled: true
        )
      end
    end
  end

  describe '#get_card' do
    let(:card_id) { 'ccof:CARD_123' }
    let(:successful_response) do
      {
        card: {
          id: card_id,
          card_brand: 'VISA',
          last_4: '4242',
          exp_month: 12,
          exp_year: 2025,
          cardholder_name: 'John Doe',
          customer_id: 'CUSTOMER_123'
        }
      }
    end

    it 'retrieves a card by ID' do
      expect(mock_cards_api).to receive(:get) do |**args|
        expect(args[:card_id]).to eq(card_id)

        double(to_h: successful_response)
      end

      result = service.get_card(card_id: card_id)

      expect(result[:card][:id]).to eq(card_id)
      expect(result[:card][:last_4]).to eq('4242')
    end

    it 'raises error when card not found' do
      allow(mock_cards_api).to receive(:get)
        .and_raise(StandardError.new('Card not found'))

      expect {
        service.get_card(card_id: 'INVALID_ID')
      }.to raise_error(SquareService::SquareError, /Card not found/)
    end
  end

  describe '#disable_card' do
    let(:card_id) { 'ccof:CARD_123' }
    let(:successful_response) do
      {
        card: {
          id: card_id,
          card_brand: 'VISA',
          last_4: '4242',
          enabled: false
        }
      }
    end

    it 'disables a card successfully' do
      expect(mock_cards_api).to receive(:disable) do |**args|
        expect(args[:card_id]).to eq(card_id)

        double(to_h: successful_response)
      end

      result = service.disable_card(card_id: card_id)

      expect(result[:card][:id]).to eq(card_id)
      expect(result[:card][:enabled]).to eq(false)
    end

    it 'raises error when card cannot be disabled' do
      allow(mock_cards_api).to receive(:disable)
        .and_raise(StandardError.new('Card already disabled'))

      expect {
        service.disable_card(card_id: card_id)
      }.to raise_error(SquareService::SquareError, /Card already disabled/)
    end
  end

  describe '#charge_card_on_file' do
    let(:card_id) { 'ccof:CARD_123' }
    let(:amount) { 1000 } # $10.00 in cents
    let(:customer_id) { 'CUSTOMER_123' }
    let(:successful_response) do
      {
        payment: {
          id: 'PAYMENT_123',
          source_type: 'CARD',
          card_details: {
            card: {
              card_brand: 'VISA',
              last_4: '4242'
            }
          },
          amount_money: {
            amount: amount,
            currency: 'USD'
          },
          status: 'COMPLETED'
        }
      }
    end

    context 'with minimal parameters' do
      it 'charges a card on file successfully' do
        expect(mock_payments_api).to receive(:create) do |**args|
          expect(args[:source_id]).to eq(card_id)
          expect(args[:amount_money][:amount]).to eq(amount)
          expect(args[:amount_money][:currency]).to eq('USD')
          expect(args[:idempotency_key]).to be_present

          double(to_h: successful_response)
        end

        result = service.charge_card_on_file(
          card_id: card_id,
          amount: amount
        )

        expect(result[:payment][:id]).to eq('PAYMENT_123')
        expect(result[:payment][:status]).to eq('COMPLETED')
        expect(result[:payment][:amount_money][:amount]).to eq(amount)
      end
    end

    context 'with all parameters' do
      it 'includes all optional parameters in the request' do
        reference_id = 'ORDER_123'
        note = 'Monthly subscription payment'

        expect(mock_payments_api).to receive(:create) do |**args|
          expect(args[:source_id]).to eq(card_id)
          expect(args[:customer_id]).to eq(customer_id)
          expect(args[:reference_id]).to eq(reference_id)
          expect(args[:note]).to eq(note)
          expect(args[:amount_money][:currency]).to eq('EUR')

          double(to_h: successful_response)
        end

        service.charge_card_on_file(
          card_id: card_id,
          amount: amount,
          currency: 'EUR',
          customer_id: customer_id,
          reference_id: reference_id,
          note: note
        )
      end
    end

    context 'when payment fails' do
      it 'raises a SquareError' do
        allow(mock_payments_api).to receive(:create)
          .and_raise(StandardError.new('Insufficient funds'))

        expect {
          service.charge_card_on_file(
            card_id: card_id,
            amount: amount
          )
        }.to raise_error(SquareService::SquareError, /Insufficient funds/)
      end
    end
  end
end
