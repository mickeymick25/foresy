# frozen_string_literal: true

require 'swagger_helper'

# RSpec behavioral tests for API deprecation headers (HTTP layer)
# Phase 1.8 - API Versioning Policy - Platinum Level
#
# This file tests the ACTUAL HTTP behavior:
# - Non-deprecated endpoints return NO deprecation headers
# - Deprecated endpoints return proper deprecation headers when configured
RSpec.describe 'API V1 - Deprecation Headers Integration', type: :request do
  # Test 1: Non-Deprecated Endpoint - Missions Index
  describe 'GET /api/v1/missions' do
    let(:user) { create(:user) }
    let(:company) { create(:company) }
    let!(:user_company) { create(:user_company, user: user, company: company, role: 'independent') }
    let(:token) { AuthenticationService.login(user, '127.0.0.1', 'test')[:token] }

    it 'returns NO deprecation headers when endpoint is not deprecated' do
      expect(Api::Deprecation::DEPRECATED_ENDPOINTS).to be_empty

      get '/api/v1/missions', headers: { 'Authorization' => "Bearer #{token}" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.headers['X-API-Deprecated']).to be_nil
      expect(response.headers['X-API-Sunset']).to be_nil
      expect(response.headers['X-API-Warning']).to be_nil
      expect(response.headers['Deprecation']).to be_nil
    end
  end

  # Test 2: Non-Deprecated Endpoint - CRAs Index
  describe 'GET /api/v1/cras' do
    let(:user) { create(:user) }
    let(:company) { create(:company) }
    let!(:user_company) { create(:user_company, user: user, company: company, role: 'independent') }
    let(:token) { AuthenticationService.login(user, '127.0.0.1', 'test')[:token] }

    before do
      # Stub RateLimitService to avoid rate limiting issues
      allow(RateLimitService).to receive(:check_rate_limit).and_return([true, nil])
      # Stub CraServices::List to avoid domain setup issues
      allow(CraServices::List).to receive(:call).and_return(
        Struct.new(:success?, :data).new(true, { cras: [], pagination: { page: 1, per_page: 20, total: 0 } })
      )
    end

    it 'returns NO deprecation headers when endpoint is not deprecated' do
      get '/api/v1/cras', headers: { 'Authorization' => "Bearer #{token}" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.headers['X-API-Deprecated']).to be_nil
    end
  end

  # Test 3: Non-Deprecated Endpoint - Mission Show
  describe 'GET /api/v1/missions/:id' do
    let(:user) { create(:user) }
    let(:company) { create(:company) }
    let!(:user_company) { create(:user_company, user: user, company: company, role: 'independent') }
    let(:token) { AuthenticationService.login(user, '127.0.0.1', 'test')[:token] }
    let(:mission) { create(:mission, :time_based, :with_creator, creator: user) }

    before do
      create(:mission_company, mission: mission, company: company, role: 'independent')
    end

    it 'returns NO deprecation headers' do
      get "/api/v1/missions/#{mission.id}", headers: { 'Authorization' => "Bearer #{token}" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.headers['X-API-Deprecated']).to be_nil
    end
  end

  # Test 4: Non-Deprecated Endpoint - CRA Show
  describe 'GET /api/v1/cras/:id' do
    let(:user) { create(:user) }
    let(:company) { create(:company) }
    let!(:user_company) { create(:user_company, user: user, company: company, role: 'independent') }
    let(:token) { AuthenticationService.login(user, '127.0.0.1', 'test')[:token] }
    let(:cra) do
      create(:cra, :with_creator, creator: user, year: Date.current.year,
                                  month: Date.current.month, status: 'draft')
    end

    it 'returns NO deprecation headers' do
      get "/api/v1/cras/#{cra.id}", headers: { 'Authorization' => "Bearer #{token}" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.headers['X-API-Deprecated']).to be_nil
    end
  end

  # Test 5: Edge case - Missing route
  describe 'GET /api/v1/nonexistent' do
    let(:user) { create(:user) }
    let(:company) { create(:company) }
    let!(:user_company) { create(:user_company, user: user, company: company, role: 'independent') }
    let(:token) { AuthenticationService.login(user, '127.0.0.1', 'test')[:token] }

    it 'handles missing route gracefully (no crash)' do
      get '/api/v1/nonexistent', headers: { 'Authorization' => "Bearer #{token}" }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  # Test 6: Edge case - Custom headers preserved
  describe 'Custom headers preservation' do
    let(:user) { create(:user) }
    let(:company) { create(:company) }
    let!(:user_company) { create(:user_company, user: user, company: company, role: 'independent') }
    let(:token) { AuthenticationService.login(user, '127.0.0.1', 'test')[:token] }

    it 'preserves custom headers when no deprecation' do
      get '/api/v1/missions',
          headers: { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/json' },
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to include('application/json')
    end
  end

  # Test 7: Deprecated Endpoint - Verifies headers are injected via HTTP (Platinum)
  describe 'GET /api/v1/missions - Deprecated Endpoint' do
    let(:user) { create(:user) }
    let(:company) { create(:company) }
    let!(:user_company) { create(:user_company, user: user, company: company, role: 'independent') }
    let(:token) { AuthenticationService.login(user, '127.0.0.1', 'test')[:token] }

    let(:deprecated_config) do
      {
        'missions' => {
          sunset_date: '2026-04-01',
          replacement: '/api/v2/missions',
          warning: 'This endpoint will be removed in v2. Use /api/v2/missions instead.'
        }
      }.freeze
    end

    before do
      Api::Deprecation.send(:remove_const, :DEPRECATED_ENDPOINTS)
      Api::Deprecation.const_set(:DEPRECATED_ENDPOINTS, deprecated_config)
    end

    after do
      Api::Deprecation.send(:remove_const, :DEPRECATED_ENDPOINTS)
      Api::Deprecation.const_set(:DEPRECATED_ENDPOINTS, {}.freeze)
    end

    it 'returns ALL deprecation headers when endpoint IS configured as deprecated' do
      get '/api/v1/missions', headers: { 'Authorization' => "Bearer #{token}" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.headers['X-API-Deprecated']).to eq('true')
      expect(response.headers['X-API-Sunset']).to eq('2026-04-01')
      expect(response.headers['X-API-Warning']).to include('v2')
      expect(response.headers['Deprecation']).to be_present
      expect(response.headers['Deprecation']).to include('01 Apr 2026')
    end
  end
end
