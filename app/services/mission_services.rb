# frozen_string_literal: true

# MissionServices - Main Namespace File
#
# This file defines the main MissionServices class to avoid namespace conflicts
# with Zeitwerk autoloader. Individual service classes (Create, etc.)
# are defined in separate files within the mission_services directory.
#
# MIGRATION CONTEXT:
# - Relation-driven architecture for Mission operations
# - ApplicationResult pattern across all services
# - Dual-path support (legacy + relation-driven) based on USE_USER_RELATIONS flag
#
# @example Usage
#   result = MissionServices::Create.call(mission_params: params, current_user: user)
#
class MissionServices
  # Namespace class for Mission services
  # Individual services are defined in separate files:
  # - Create
  #
  # This empty class serves as a namespace to avoid
  # Zeitwerk autoloader conflicts.

  # Stub method to prevent EmptyClass RuboCop offense
  # Individual services are defined in separate files
  def self.service_available?(service_name)
    %w[Create].include?(service_name.to_s)
  end
end
