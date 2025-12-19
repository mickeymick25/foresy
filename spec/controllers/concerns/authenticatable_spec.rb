# frozen_string_literal: true

require 'rails_helper'

# Test controller to include the Authenticatable concern
class TestAuthenticatableController < ApplicationController
  include Authenticatable

  # Expose private methods for testing
  public :decode_token, :valid_payload?, :assign_current_user_and_session,
         :valid_session?, :bearer_token, :user_id_from, :session_id_from
end

RSpec.describe Authenticatable, type: :controller do
  controller(TestAuthenticatableController) do
    def index
      render json: { message: 'success' }
    end
  end

  let(:user) { create(:user) }
  let(:session) do
    user.sessions.create!(ip_address: '127.0.0.1', user_agent: 'Test', active: true, expires_at: 1.day.from_now)
  end
  let(:valid_payload) { { user_id: user.id, session_id: session.id } }
  let(:valid_token) { JsonWebToken.encode(valid_payload) }

  describe '#decode_token' do
    context 'with valid token' do
      it 'returns decoded payload as HashWithIndifferentAccess' do
        result = controller.decode_token(valid_token)

        expect(result).to be_a(HashWithIndifferentAccess)
        expect(result[:user_id]).to eq(user.id)
        expect(result[:session_id]).to eq(session.id)
      end
    end

    context 'with expired token' do
      let(:expired_token) do
        payload = valid_payload.merge(exp: 1.hour.ago.to_i)
        JWT.encode(payload, Rails.application.secret_key_base)
      end

      it 'returns :expired_token symbol' do
        result = controller.decode_token(expired_token)
        expect(result).to eq(:expired_token)
      end
    end

    context 'with invalid token' do
      it 'returns :invalid_token symbol for malformed token' do
        result = controller.decode_token('invalid.token.here')
        expect(result).to eq(:invalid_token)
      end

      it 'returns :invalid_token symbol for wrong signature' do
        wrong_token = JWT.encode(valid_payload, 'wrong_secret')
        result = controller.decode_token(wrong_token)
        expect(result).to eq(:invalid_token)
      end
    end
  end

  describe '#valid_payload?' do
    context 'with error symbols' do
      it 'returns false for :expired_token' do
        expect(controller.valid_payload?(:expired_token)).to be false
      end

      it 'returns false for :invalid_token' do
        expect(controller.valid_payload?(:invalid_token)).to be false
      end
    end

    context 'with nil payload' do
      it 'returns false' do
        expect(controller.valid_payload?(nil)).to be false
      end
    end

    context 'with missing fields' do
      it 'returns false when user_id is missing' do
        payload = { session_id: 'abc123' }
        expect(controller.valid_payload?(payload)).to be false
      end

      it 'returns false when session_id is missing' do
        payload = { user_id: 123 }
        expect(controller.valid_payload?(payload)).to be false
      end

      it 'returns false when both fields are missing' do
        payload = {}
        expect(controller.valid_payload?(payload)).to be false
      end
    end

    context 'with valid payload' do
      it 'returns true with symbol keys' do
        payload = { user_id: 123, session_id: 'abc123' }
        expect(controller.valid_payload?(payload)).to be true
      end

      it 'returns true with string keys' do
        payload = { 'user_id' => 123, 'session_id' => 'abc123' }
        expect(controller.valid_payload?(payload)).to be true
      end

      it 'returns true with HashWithIndifferentAccess' do
        payload = HashWithIndifferentAccess.new(user_id: 123, session_id: 'abc123')
        expect(controller.valid_payload?(payload)).to be true
      end
    end
  end

  describe '#assign_current_user_and_session' do
    context 'with valid payload' do
      it 'sets current_user' do
        controller.assign_current_user_and_session(valid_payload)
        expect(controller.current_user).to eq(user)
      end

      it 'sets current_session' do
        controller.assign_current_user_and_session(valid_payload)
        expect(controller.current_session).to eq(session)
      end
    end

    context 'with non-existent user' do
      it 'sets current_user to nil' do
        payload = { user_id: 'non-existent-id', session_id: session.id }
        controller.assign_current_user_and_session(payload)
        expect(controller.current_user).to be_nil
      end
    end

    context 'with non-existent session' do
      it 'sets current_session to nil' do
        payload = { user_id: user.id, session_id: 'non-existent-id' }
        controller.assign_current_user_and_session(payload)
        expect(controller.current_session).to be_nil
      end
    end
  end

  describe '#valid_session?' do
    before do
      controller.assign_current_user_and_session(valid_payload)
    end

    context 'with active session' do
      it 'returns true' do
        expect(controller.valid_session?).to be true
      end
    end

    context 'with expired session' do
      let(:expired_session) do
        user.sessions.create!(ip_address: '127.0.0.1', user_agent: 'Test', expires_at: 1.day.ago)
      end

      before do
        controller.instance_variable_set(:@current_user, user)
        controller.instance_variable_set(:@current_session, expired_session)
      end

      it 'returns false' do
        expect(controller.valid_session?).to be false
      end
    end

    context 'without current_user' do
      before { controller.instance_variable_set(:@current_user, nil) }

      it 'returns false' do
        expect(controller.valid_session?).to be false
      end
    end

    context 'without current_session' do
      before { controller.instance_variable_set(:@current_session, nil) }

      it 'returns false' do
        expect(controller.valid_session?).to be false
      end
    end
  end

  describe '#user_id_from and #session_id_from' do
    it 'extracts user_id from symbol key' do
      expect(controller.user_id_from({ user_id: 123 })).to eq(123)
    end

    it 'extracts user_id from string key' do
      expect(controller.user_id_from({ 'user_id' => 456 })).to eq(456)
    end

    it 'extracts session_id from symbol key' do
      expect(controller.session_id_from({ session_id: 'abc' })).to eq('abc')
    end

    it 'extracts session_id from string key' do
      expect(controller.session_id_from({ 'session_id' => 'xyz' })).to eq('xyz')
    end
  end

  describe 'full authentication flow: decode_token → valid_payload? → assign_current_user_and_session' do
    it 'successfully authenticates with valid token' do
      # Step 1: decode_token
      payload = controller.decode_token(valid_token)
      expect(payload).to be_a(HashWithIndifferentAccess)

      # Step 2: valid_payload?
      expect(controller.valid_payload?(payload)).to be true

      # Step 3: assign_current_user_and_session
      controller.assign_current_user_and_session(payload)
      expect(controller.current_user).to eq(user)
      expect(controller.current_session).to eq(session)

      # Step 4: valid_session?
      expect(controller.valid_session?).to be true
    end

    it 'fails authentication with expired token' do
      expired_payload = valid_payload.merge(exp: 1.hour.ago.to_i)
      expired_token = JWT.encode(expired_payload, Rails.application.secret_key_base)

      # Step 1: decode_token returns error symbol
      result = controller.decode_token(expired_token)
      expect(result).to eq(:expired_token)

      # Step 2: valid_payload? rejects error symbol
      expect(controller.valid_payload?(result)).to be false
    end

    it 'fails authentication with invalid token' do
      # Step 1: decode_token returns error symbol
      result = controller.decode_token('malformed.token')
      expect(result).to eq(:invalid_token)

      # Step 2: valid_payload? rejects error symbol
      expect(controller.valid_payload?(result)).to be false
    end

    it 'fails authentication with expired session' do
      # Create an expired session
      expired_session = user.sessions.create!(ip_address: '127.0.0.1', user_agent: 'Test', expires_at: 1.day.ago)
      expired_payload = { user_id: user.id, session_id: expired_session.id }
      expired_token = JsonWebToken.encode(expired_payload)

      # Steps 1-3 succeed
      payload = controller.decode_token(expired_token)
      expect(controller.valid_payload?(payload)).to be true
      controller.assign_current_user_and_session(payload)

      # Step 4: valid_session? fails because session is expired
      expect(controller.valid_session?).to be false
    end
  end
end
