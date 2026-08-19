# frozen_string_literal: true

# 🔒 P2.3 — Unification Erreurs : toutes les erreurs CRA entries utilisent
# le format StandardizedError { code, message, details }
#
# This spec validates that CraEntriesController error responses follow
# the standardized format (no more render_fc07_error with { error, message,
# timestamp } or inline { error: ..., message: ... }).
#
# Invariant: All error responses from /api/v1/cras/:cra_id/entries must
# use { code, message } format, never { error, message, timestamp }.

require 'rails_helper'

RSpec.describe 'P2.3 — CraEntries error format unification', type: :request do
  let(:user) { create(:user, password: 'password123') }
  let(:company) { create(:company) }
  let(:cra) { create(:cra, :with_creator, creator: user) }
  let(:token) { AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token] }
  let(:headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' } }

  before do
    create(:user_company, user: user, company: company, role: 'independent')
  end

  describe 'error response format' do
    it 'returns { code, message } format for not found errors' do
      get '/api/v1/cras/00000000-0000-0000-0000-000000000000/entries', headers: headers
      parsed = JSON.parse(response.body)
      expect(parsed).to have_key('code')
      expect(parsed).not_to have_key('error')
      expect(parsed).not_to have_key('timestamp')
    end

    it 'returns { code, message } format for forbidden errors' do
      other_user = create(:user, password: 'password123')
      other_token = AuthenticationService.login(other_user, '127.0.0.1', 'rswag')[:token]
      other_headers = { 'Authorization' => "Bearer #{other_token}" }

      get "/api/v1/cras/#{cra.id}/entries", headers: other_headers
      parsed = JSON.parse(response.body)
      expect(parsed).to have_key('code')
      expect(parsed).not_to have_key('error')
    end

    it 'does not use render_fc07_error format anywhere' do
      get '/api/v1/cras/00000000-0000-0000-0000-000000000000/entries', headers: headers
      parsed = JSON.parse(response.body)
      expect(parsed).not_to have_key('timestamp')
      expect(parsed).not_to have_key('resource_type')
    end
  end
end
