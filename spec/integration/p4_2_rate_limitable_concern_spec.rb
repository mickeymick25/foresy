# frozen_string_literal: true

# 🔴 P4.2 — Cohérence Archi : extraire extract_client_ip_for_rate_limiting
#
# This spec characterizes the fix for audit point C6
# (see docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md).
#
# The method extract_client_ip_for_rate_limiting was duplicated 3 times
# (AuthenticationController, UsersController, MissionsController).
# It should be extracted into a shared concern Common::RateLimitable.
#
# Invariant: Common::RateLimitable concern exists and provides the method.
# No controller should define it directly anymore.

require 'rails_helper'

RSpec.describe 'P4.2 — Common::RateLimitable concern' do
  describe 'concern existence' do
    it 'autoloads Common::RateLimitable' do
      expect(defined?(Common::RateLimitable)).to eq('constant')
    end

    it 'provides extract_client_ip_for_rate_limiting as a private method' do
      controller = Api::V1::AuthenticationController.new
      expect(controller.private_methods).to include(:extract_client_ip_for_rate_limiting)
    end
  end

  describe 'no duplication in controllers' do
    it 'AuthenticationController does not define the method directly' do
      # The method should come from the concern, not from the controller itself
      source = File.read(Rails.root.join('app/controllers/api/v1/authentication_controller.rb'))
      expect(source).not_to match(/def extract_client_ip_for_rate_limiting/)
    end

    it 'UsersController does not define the method directly' do
      source = File.read(Rails.root.join('app/controllers/api/v1/users_controller.rb'))
      expect(source).not_to match(/def extract_client_ip_for_rate_limiting/)
    end

    it 'MissionsController does not define the method directly' do
      source = File.read(Rails.root.join('app/controllers/api/v1/missions_controller.rb'))
      expect(source).not_to match(/def extract_client_ip_for_rate_limiting/)
    end
  end
end