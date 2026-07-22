# frozen_string_literal: true

# 🔒 Security invariant spec: __test_support__ routes must NEVER be
# accessible in production, even if E2E_MODE=true is mistakenly set.
#
# This spec characterizes the security fix for audit point F3
# (see docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md).
#
# Defense in depth strategy:
#   1. config/routes.rb: routes not mounted in production
#   2. SetupController#verify_e2e_mode!: blocks if production
#
# This spec covers layer 2 (controller gate) via:
#   - Unit test on e2e_mode_enabled? logic (all env combinations)
#   - Request test confirming the gate renders 404 when blocked

require 'rails_helper'

RSpec.describe TestSupport::E2e::SetupController, type: :controller do
  describe '#e2e_mode_enabled?' do
    subject(:result) { controller.send(:e2e_mode_enabled?) }

    context 'when Rails.env is test' do
      before { allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('test')) }

      it { is_expected.to be(true) }

      it 'stays enabled even without E2E_MODE' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('E2E_MODE').and_return(nil)
        expect(result).to be(true)
      end
    end

    context 'when Rails.env is production and E2E_MODE=true (attack scenario)' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('E2E_MODE').and_return('true')
      end

      it { is_expected.to be(false) }
    end

    context 'when Rails.env is production and E2E_MODE is unset' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('E2E_MODE').and_return(nil)
      end

      it { is_expected.to be(false) }
    end

    context 'when Rails.env is development and E2E_MODE=true' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('E2E_MODE').and_return('true')
      end

      it { is_expected.to be(true) }
    end
  end
end

RSpec.describe 'SetupController gate behavior', type: :request do
  describe 'when the E2E gate blocks (simulated production + E2E_MODE=true)' do
    # We stub the gate method directly to avoid side effects from stubbing
    # Rails.env globally (which changes config.consider_all_requests_local
    # and other middleware behavior). The unit test above already validates
    # that e2e_mode_enabled? returns false in production + E2E_MODE=true.
    before do
      allow_any_instance_of(TestSupport::E2e::SetupController).to receive(:e2e_mode_enabled?)
        .and_return(false)
    end

    it 'renders 404 for POST /__test_support__/e2e/setup' do
      post '/__test_support__/e2e/setup', params: { user: { email: 'x@example.com', password: 'pw' } }
      expect(response).to have_http_status(:not_found)
    end

    it 'renders 404 for DELETE /__test_support__/e2e/cleanup' do
      delete '/__test_support__/e2e/cleanup'
      expect(response).to have_http_status(:not_found)
    end

    it 'does not create any test data' do
      expect do
        post '/__test_support__/e2e/setup', params: { user: { email: 'x@example.com', password: 'pw' } }
      end.not_to change(User, :count)
    end

    it 'does not leak internal error details (not 500, not 422, not 2xx)' do
      post '/__test_support__/e2e/setup', params: { user: { email: 'x@example.com', password: 'pw' } }
      expect(response).to have_http_status(:not_found)
      expect(response).not_to have_http_status(:internal_server_error)
      expect(response).not_to have_http_status(:unprocessable_entity)
      expect(response).not_to be_successful
    end
  end
end
