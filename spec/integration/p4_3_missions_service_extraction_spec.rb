# frozen_string_literal: true

# 🔴 P4.3 — Cohérence Archi : extraire la logique métier de MissionsController
# dans des Service Objects (MissionServices::*), suivant le pattern CraServices::*.
#
# This spec characterizes the fix for audit point C10
# (see docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md).
#
# Invariants:
# 1. MissionServices::Create / Update / Delete exist and return ApplicationResult
# 2. MissionsController#create delegates to MissionServices::Create.call
#    (no MissionCompany.create! directly in the controller)
# 3. MissionsController#update delegates to MissionServices::Update.call
#    (no transition_to directly in the controller)
# 4. MissionsController#destroy delegates to MissionServices::Delete.call
#    (no @mission.discard business logic in the controller)
# 5. Controller uses the render_result_error pattern for service failures

require 'rails_helper'

RSpec.describe 'P4.3 — MissionsController service extraction' do
  describe 'service existence and ApplicationResult contract' do
    it 'MissionServices::Create exists and exposes .call' do
      expect(MissionServices::Create).to be_a(Class)
      expect(MissionServices::Create).to respond_to(:call)
    end

    it 'MissionServices::Update exists and exposes .call' do
      expect(MissionServices::Update).to be_a(Class)
      expect(MissionServices::Update).to respond_to(:call)
    end

    it 'MissionServices::Delete exists and exposes .call' do
      expect(MissionServices::Delete).to be_a(Class)
      expect(MissionServices::Delete).to respond_to(:call)
    end

    it 'MissionServices::Create returns ApplicationResult for invalid input' do
      result = MissionServices::Create.call(mission_params: nil, current_user: nil)
      expect(result).to be_a(ApplicationResult)
      expect(result).to be_failure
    end

    it 'MissionServices::Update returns ApplicationResult for forbidden input' do
      user = create(:user)
      mission = create(:mission)
      result = MissionServices::Update.call(mission: mission, mission_params: {}, current_user: user)
      expect(result).to be_a(ApplicationResult)
      expect(result).to be_failure
    end

    it 'MissionServices::Delete returns ApplicationResult for forbidden input' do
      user = create(:user)
      mission = create(:mission)
      result = MissionServices::Delete.call(mission: mission, current_user: user)
      expect(result).to be_a(ApplicationResult)
      expect(result).to be_failure
    end
  end

  describe 'no business logic in MissionsController (source invariants)' do
    let(:controller_source) do
      File.read(Rails.root.join('app/controllers/api/v1/missions_controller.rb'))
    end

    it 'does not create MissionCompany directly' do
      expect(controller_source).not_to match(/MissionCompany\.create/)
      expect(controller_source).not_to match(/mission_companies\.create!/)
    end

    it 'does not call transition_to directly on @mission' do
      expect(controller_source).not_to match(/@mission\.transition_to/)
      expect(controller_source).not_to match(/\.transition_to\(/)
    end

    it 'does not call discard directly on @mission' do
      expect(controller_source).not_to match(/@mission\.discard/)
    end

    it 'delegates create to MissionServices::Create.call' do
      expect(controller_source).to match(/MissionServices::Create\.call/)
    end

    it 'delegates update to MissionServices::Update.call' do
      expect(controller_source).to match(/MissionServices::Update\.call/)
    end

    it 'delegates destroy to MissionServices::Delete.call' do
      expect(controller_source).to match(/MissionServices::Delete\.call/)
    end

    it 'uses render_result_error pattern for service failures' do
      expect(controller_source).to match(/render_result_error/)
    end
  end

  describe 'behavioral delegation (controller dispatches to services)', type: :request do
    let(:user) { create(:user) }
    let(:company) { create(:company) }
    let(:token) { AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token] }
    let(:auth_headers) do
      { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' }
    end

    before do
      create(:user_company, user: user, company: company, role: 'independent')
    end

    it 'POST /api/v1/missions dispatches to MissionServices::Create' do
      expect(MissionServices::Create).to receive(:call).and_call_original

      post '/api/v1/missions',
           params: {
             name: 'P43 Mission',
             mission_type: 'time_based',
             start_date: Date.current.to_s,
             daily_rate: 500,
             currency: 'EUR'
           }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:created)
    end

    it 'PATCH /api/v1/missions/:id dispatches to MissionServices::Update' do
      mission = create(:mission, :with_creator, creator: user, status: 'lead')
      create(:mission_company, mission: mission, company: company, role: 'independent')

      expect(MissionServices::Update).to receive(:call).and_call_original

      patch "/api/v1/missions/#{mission.id}",
            params: { status: 'pending' }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
    end

    it 'DELETE /api/v1/missions/:id dispatches to MissionServices::Delete' do
      mission = create(:mission, :with_creator, creator: user)
      create(:mission_company, mission: mission, company: company, role: 'independent')

      expect(MissionServices::Delete).to receive(:call).and_call_original

      delete "/api/v1/missions/#{mission.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
    end
  end
end
