# frozen_string_literal: true

module Api
  module V1
    module Missions
      # Centralized error handling concern for mission-related operations
      # Handles MissionErrors and renders appropriate JSON responses
      module ErrorHandler
        extend ActiveSupport::Concern

        private

        # Centralized error handler for all mission-related exceptions
        # Logs errors and renders appropriate JSON responses
        #
        # @param exception [Exception] The exception to handle
        # @return [void]
        #
        # @example
        #   handle_mission_error(CraErrors::InvalidPayloadError.new("Invalid mission data"))
        #   # Renders JSON with appropriate error structure
        def handle_mission_error(exception)
          Rails.logger.error "[MissionsController] Mission Error: #{exception.class.name} - #{exception.message}"

          case exception
          when MissionErrors::InvalidPayloadError
            render json: {
              error: 'invalid_payload',
              message: exception.message,
              field: exception.respond_to?(:field) ? exception.field : nil,
              timestamp: Time.current.iso8601
            }.compact, status: :unprocessable_content
          when MissionErrors::InvalidTransitionError
            render json: {
              error: 'invalid_transition',
              message: exception.message,
              timestamp: Time.current.iso8601
            }, status: :unprocessable_content
          when MissionErrors::MissionLockedError
            render json: {
              error: 'mission_locked',
              message: exception.message,
              timestamp: Time.current.iso8601
            }, status: :conflict
          when MissionErrors::MissionInUseError
            render json: {
              error: 'mission_in_use',
              message: exception.message,
              timestamp: Time.current.iso8601
            }, status: :conflict
          when MissionErrors::DuplicateEntryError
            render json: {
              error: 'duplicate_entry',
              message: exception.message,
              timestamp: Time.current.iso8601
            }, status: :conflict
          when MissionErrors::MissionNotFoundError
            render json: {
              error: 'not_found',
              message: exception.message,
              timestamp: Time.current.iso8601
            }, status: :not_found
          when MissionErrors::UnauthorizedError
            render json: {
              error: 'unauthorized',
              message: exception.message,
              timestamp: Time.current.iso8601
            }, status: :forbidden
          when MissionErrors::NoIndependentCompanyError
            render json: {
              error: 'forbidden',
              message: exception.message,
              timestamp: Time.current.iso8601
            }, status: :forbidden
          when MissionErrors::InternalError
            render json: {
              error: 'internal_error',
              message: exception.message,
              timestamp: Time.current.iso8601
            }, status: :internal_server_error
          else
            # Fallback for any other MissionErrors::BaseError
            render json: {
              error: 'mission_error',
              message: exception.message,
              timestamp: Time.current.iso8601
            }, status: :unprocessable_content
          end
        end
      end
    end
  end
end
