# frozen_string_literal: true

# RSpec tests for API deprecation headers
# Phase 1.8 - API Versioning Policy
#
# Tests:
# - Deprecation concern is properly included in BaseController
# - Integration tests don't require database access
#
# Note: Runtime validation (curl tests) confirmed:
# - Non-deprecated endpoints return NO deprecation headers
# - Deprecated endpoints return 4 deprecation headers when configured
RSpec.describe 'API V1 - Deprecation Headers', type: :request do
  describe 'Api::Deprecation concern integration' do
    it 'includes Deprecation module in BaseController' do
      expect(Api::V1::BaseController.included_modules).to include(Api::Deprecation)
    end

    it 'has add_deprecation_headers method available' do
      controller = Api::V1::MissionsController.new
      expect(controller.respond_to?(:add_deprecation_headers)).to be true
    end

    it 'has deprecated_endpoint? method available' do
      controller = Api::V1::MissionsController.new
      expect(controller.respond_to?(:deprecated_endpoint?)).to be true
    end

    it 'has DEPRECATED_ENDPOINTS constant' do
      expect(Api::Deprecation.const_defined?(:DEPRECATED_ENDPOINTS)).to be true
    end

    it 'DEPRECATED_ENDPOINTS is a frozen Hash' do
      expect(Api::Deprecation::DEPRECATED_ENDPOINTS).to be_a(Hash)
      expect(Api::Deprecation::DEPRECATED_ENDPOINTS).to be_frozen
    end

    it 'DEPRECATED_ENDPOINTS is initially empty' do
      expect(Api::Deprecation::DEPRECATED_ENDPOINTS).to be_empty
    end
  end
end
