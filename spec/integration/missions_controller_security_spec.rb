# frozen_string_literal: true

# 🔒 Security invariant spec: missions_controller must not leak debug
# output to stdout.
#
# This spec characterizes the security fix for audit point C3
# (see docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md).
#
# The MissionsController had 10 `puts` statements in set_mission and
# validate_mission_access! that printed internal state (params, IDs,
# mission objects, accessible mission lists) to stdout.
#
# Invariant: After a request to /api/v1/missions/:id, stdout must NOT
# contain any debug output from set_mission or validate_mission_access!.

require 'rails_helper'

RSpec.describe 'MissionsController debug output non-disclosure', type: :request do
  let(:user) { create(:user, email: 'security@example.com', password: 'password123') }
  let(:company) { create(:company) }
  let(:mission) { create(:mission, :with_creator, creator: user) }
  let(:token) { AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token] }

  before do
    create(:user_company, user: user, company: company, role: 'independent')
    create(:mission_company, mission: mission, company: company, role: 'independent')
  end

  def capture_stdout
    stdout_capture = StringIO.new
    original_stdout = $stdout
    $stdout = stdout_capture
    begin
      yield
    ensure
      $stdout = original_stdout
    end
    stdout_capture.string
  end

  def auth_headers
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  end

  describe 'GET /api/v1/missions/:id' do
    it 'does not print debug output from set_mission' do
      output = capture_stdout do
        get "/api/v1/missions/#{mission.id}", headers: auth_headers
      end

      expect(output).not_to include('=== DEBUG: set_mission ===')
      expect(output).not_to include('params[:id]')
      expect(output).not_to include('@mission.present?')
    end

    it 'does not print debug output from validate_mission_access!' do
      output = capture_stdout do
        get "/api/v1/missions/#{mission.id}", headers: auth_headers
      end

      expect(output).not_to include('=== DEBUG: validate_mission_access! ===')
      expect(output).not_to include('accessible_missions.count')
      expect(output).not_to include('accessible_missions.ids')
      expect(output).not_to include('current_user.id')
      expect(output).not_to include('END DEBUG')
    end

    it 'does not leak mission IDs or internal state to stdout' do
      output = capture_stdout do
        get "/api/v1/missions/#{mission.id}", headers: auth_headers
      end

      expect(output).not_to include(mission.id.to_s)
      expect(output).not_to include(user.id.to_s)
    end
  end
end
