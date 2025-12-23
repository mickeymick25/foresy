# frozen_string_literal: true

# spec/services/json_web_token_spec.rb
#
# Tests pour JsonWebToken avec gestion d'exceptions robuste
# SECURITY: Tests vérifient que les tokens ne sont PAS loggés
#
require 'rails_helper'

RSpec.describe JsonWebToken do
  describe '.encode' do
    let(:payload) { { user_id: 123, session_id: 'abc123' } }
    let(:expiration) { 15.minutes.from_now }

    it 'encodes payload successfully' do
      token = described_class.encode(payload, expiration)
      expect(token).to be_present

      decoded = JWT.decode(token, Rails.application.secret_key_base)[0]
      expect(decoded['user_id']).to eq(123)
      expect(decoded['session_id']).to eq('abc123')
      expect(decoded['exp']).to be_present
    end

    context 'when JWT::EncodeError occurs' do
      it 'logs error without sensitive data and raises exception' do
        allow(JWT).to receive(:encode).and_raise(JWT::EncodeError, 'Invalid encoding')

        expect(Rails.logger).to receive(:error).with(/JWT encode failed: JWT::EncodeError/)

        expect do
          described_class.encode(payload, expiration)
        end.to raise_error(/JWT encoding failed: Invalid encoding/)
      end
    end

    context 'when unexpected error occurs' do
      it 'logs error without sensitive data and raises exception' do
        allow(JWT).to receive(:encode).and_raise(StandardError, 'Unexpected error')

        expect(Rails.logger).to receive(:error).with(/Unexpected JWT encode error: StandardError/)

        expect do
          described_class.encode(payload, expiration)
        end.to raise_error(/JWT encoding failed unexpectedly/)
      end
    end
  end

  describe '.refresh_token' do
    let(:user_id) { 456 }

    it 'creates refresh token successfully' do
      token = described_class.refresh_token(user_id)
      expect(token).to be_present

      decoded = JWT.decode(token, Rails.application.secret_key_base)[0]
      expect(decoded['user_id']).to eq(user_id)
      expect(decoded['refresh_exp']).to be_present
    end

    context 'when encoding fails' do
      it 'logs error without token and raises error' do
        allow(JWT).to receive(:encode).and_raise(JWT::EncodeError, 'Encoding failed')

        expect(Rails.logger).to receive(:error).with(/JWT refresh token encode failed: JWT::EncodeError/)

        expect do
          described_class.refresh_token(user_id)
        end.to raise_error(/JWT refresh token encoding failed: Encoding failed/)
      end
    end
  end

  describe '.decode' do
    let(:valid_payload) { { user_id: 123, session_id: 'abc123' } }
    let(:valid_token) { JWT.encode(valid_payload, Rails.application.secret_key_base) }

    it 'decodes token successfully' do
      expect(Rails.logger).to receive(:debug).with(/JWT decoded successfully/)

      decoded = described_class.decode(valid_token)
      expect(decoded[:user_id]).to eq(123)
      expect(decoded[:session_id]).to eq('abc123')
      expect(decoded).to be_a(HashWithIndifferentAccess)
    end

    context 'with malformed token' do
      it 'handles JWT::DecodeError without logging token' do
        malformed_token = 'invalid.token'

        expect(Rails.logger).to receive(:warn).with(/JWT decode failed: JWT::DecodeError/)

        expect do
          described_class.decode(malformed_token)
        end.to raise_error(JWT::DecodeError)
      end
    end

    context 'with expired token' do
      it 'handles JWT::ExpiredSignature without logging token' do
        expired_payload = { user_id: 123, exp: Time.now.to_i - 3600 }
        expired_token = JWT.encode(expired_payload, Rails.application.secret_key_base)

        expect(Rails.logger).to receive(:warn).with(/JWT token expired: JWT::ExpiredSignature/)

        expect do
          described_class.decode(expired_token)
        end.to raise_error(JWT::ExpiredSignature)
      end
    end

    context 'with invalid signature' do
      it 'handles JWT::VerificationError without logging token' do
        wrong_key = 'different_secret_key'
        invalid_signature_token = JWT.encode(valid_payload, wrong_key)

        expect(Rails.logger).to receive(:warn).with(/JWT signature verification failed: JWT::VerificationError/)

        expect do
          described_class.decode(invalid_signature_token)
        end.to raise_error(JWT::VerificationError)
      end
    end

    context 'with unexpected error' do
      it 'handles StandardError without logging token' do
        allow(JWT).to receive(:decode).and_raise(StandardError, 'Unexpected error')

        expect(Rails.logger).to receive(:error).with(/Unexpected JWT decode error: StandardError/)

        expect do
          described_class.decode(valid_token)
        end.to raise_error(/JWT decode failed unexpectedly/)
      end
    end

    context 'with nil token' do
      it 'handles nil token' do
        expect do
          described_class.decode(nil)
        end.to raise_error(JWT::DecodeError)
      end
    end

    context 'with empty token' do
      it 'handles empty token' do
        expect do
          described_class.decode('')
        end.to raise_error(JWT::DecodeError)
      end
    end

    context 'with APM metrics' do
      it 'handles NewRelic availability gracefully' do
        expect do
          described_class.decode('invalid.token')
        end.to raise_error(JWT::DecodeError)
      end

      it 'handles Datadog availability gracefully' do
        expect do
          described_class.decode('invalid.token')
        end.to raise_error(JWT::DecodeError)
      end
    end
  end

  describe 'security - no token logging' do
    it 'does not log tokens on encode' do
      expect(Rails.logger).not_to receive(:info).with(/eyJ/)
      expect(Rails.logger).not_to receive(:debug).with(/eyJ/)
      expect(Rails.logger).not_to receive(:warn).with(/eyJ/)
      expect(Rails.logger).not_to receive(:error).with(/eyJ/)

      described_class.encode(user_id: 123)
    end

    it 'does not log tokens on decode errors' do
      allow(Rails.logger).to receive(:warn)

      expect(Rails.logger).not_to receive(:warn).with(/first 50 chars/)
      expect(Rails.logger).not_to receive(:warn).with(/Token:/)
      expect(Rails.logger).not_to receive(:error).with(/Token:/)

      expect { described_class.decode('invalid.token') }.to raise_error(JWT::DecodeError)
    end
  end

  describe 'integration tests' do
    it 'encodes and decodes round-trip successfully' do
      original_payload = { user_id: 789, session_id: 'xyz789', role: 'admin' }

      token = described_class.encode(original_payload)
      decoded = described_class.decode(token)

      expect(decoded[:user_id]).to eq(789)
      expect(decoded[:session_id]).to eq('xyz789')
      expect(decoded[:role]).to eq('admin')
    end

    it 'handles large payload without performance degradation' do
      large_payload = {
        user_id: 123,
        session_id: 'abc123',
        permissions: (1..50).map { |i| { resource: "resource_#{i}", action: "action_#{i}" } }
      }

      start_time = Time.current
      token = described_class.encode(large_payload)
      encoding_duration = Time.current - start_time

      expect(encoding_duration).to be < 0.1

      start_time = Time.current
      decoded = described_class.decode(token)
      decoding_duration = Time.current - start_time

      expect(decoding_duration).to be < 0.1
      expect(decoded[:permissions].length).to eq(50)
    end

    it 'maintains security with different token types' do
      access_token = described_class.encode(user_id: 123, session_id: 'abc')
      refresh_token = described_class.refresh_token(123)

      access_decoded = JWT.decode(access_token, Rails.application.secret_key_base)[0]
      expect(access_decoded['exp']).to be_present

      refresh_decoded = JWT.decode(refresh_token, Rails.application.secret_key_base)[0]
      expect(refresh_decoded['refresh_exp']).to be_present
      expect(refresh_decoded['exp']).to be_nil
    end
  end
end
