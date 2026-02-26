# frozen_string_literal: true

# Concern for handling API deprecation headers
#
# This module provides functionality to add deprecation headers to API responses
# following the RFC 8244 standard and Foresy's versioning policy.
#
# Usage:
#   class Api::V1::MissionsController < ApplicationController
#     include Api::Deprecation
#     before_action :add_deprecation_headers, only: [:index, :show]
#   end
#
module Api
  module Deprecation
    extend ActiveSupport::Concern

    # Map of deprecated endpoints with their deprecation information
    # Key: endpoint path (without version prefix for matching)
    # Value: Hash with sunset_date, replacement, and warning message
    DEPRECATED_ENDPOINTS = {
      # Example:
      # 'missions' => {
      #   sunset_date: '2026-04-01',
      #   replacement: '/api/v2/missions',
      #   warning: 'This endpoint will be removed in v2. Use /api/v2/missions instead.'
      # }
    }.freeze

    included do
      helper_method :deprecated_endpoint?, :deprecation_info
    end

    # Check if the current endpoint is deprecated
    # @return [Boolean]
    def deprecated_endpoint?
      deprecation_info.present?
    end

    # Get deprecation information for the current endpoint
    # @return [Hash, nil] deprecation info or nil if not deprecated
    def deprecation_info
      return nil unless controller_path && action_name

      # Build the endpoint key (e.g., 'api/v1/missions')
      endpoint_key = build_endpoint_key

      DEPRECATED_ENDPOINTS[endpoint_key]
    end

    # Add deprecation headers to the response
    # Call this in a before_action or after_action
    # @param endpoint_path [String, nil] optional endpoint path override
    def add_deprecation_headers(endpoint_path = nil)
      path = endpoint_path || build_endpoint_key
      info = DEPRECATED_ENDPOINTS[path]

      return unless info

      # Required deprecation headers
      response.headers['X-API-Deprecated'] = 'true'
      response.headers['X-API-Sunset'] = info[:sunset_date]
      response.headers['X-API-Warning'] = info[:warning]

      # RFC 8244 compliant Deprecation header
      # Format: "Sun, 01 Apr 2026 00:00:00 GMT; \"/path\""
      sunset_time = parse_date_to_http_date(info[:sunset_date])
      response.headers['Deprecation'] = "#{sunset_time} \"/api/v1/#{path}\""

      # Log deprecation warning for analytics
      Rails.logger.warn(
        "API Deprecation Warning: #{request.method} /api/v1/#{path} is deprecated. " \
        "Will be removed on #{info[:sunset_date]}. " \
        "Use #{info[:replacement]} instead."
      )
    end

    # Get all deprecated endpoints (for documentation, testing, etc.)
    # @return [Array<Hash>] list of deprecated endpoints with info
    def self.deprecated_endpoints
      DEPRECATED_ENDPOINTS.map do |path, info|
        {
          path: "/api/v1/#{path}",
          sunset_date: info[:sunset_date],
          replacement: info[:replacement],
          warning: info[:warning]
        }
      end
    end

    private

    # Build the endpoint key from controller path and action
    # @return [String] endpoint key (e.g., 'missions', 'cras')
    def build_endpoint_key
      # Extract the resource name from controller path
      # e.g., 'api/v1/missions' -> 'missions'
      controller_path.gsub(%r{^api/v1/}, '')
    end

    # Parse a date string to HTTP date format (RFC 7231)
    # @param date_str [String] date in YYYY-MM-DD format
    # @return [String] HTTP date format
    def parse_date_to_http_date(date_str)
      Date.parse(date_str).strftime('%a, %d %b %Y %H:%M:%S GMT')
    rescue Date::Error
      # If date parsing fails, return a default format
      date_str
    end
  end
end
