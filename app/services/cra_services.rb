# frozen_string_literal: true

# CraServices - Main Namespace File
#
# This file defines the main CraServices class to avoid namespace conflicts
# with Zeitwerk autoloader. Individual service classes (Create, List, etc.)
# are defined in separate files within the cra_services directory.
#
# MIGRATION CONTEXT:
# - Unified architecture for CRA operations
# - ApplicationResult pattern across all services
# - Eliminates dual architecture (Api::V1::Cras::* + CraServices::*)
#
# @example Usage
#   result = CraServices::Create.call(cra_params: params, current_user: user)
#   result = CraServices::List.call(current_user: user, filters: filters)
#
class CraServices
  # Namespace class for CRA services
  # Individual services are defined in separate files:
  # - Create
  # - List
  # - Update
  # - Destroy
  # - Lifecycle
  # - Export
  #
  # This empty class serves as a namespace to avoid
  # Zeitwerk autoloader conflicts.

  # Stub method to prevent EmptyClass RuboCop offense
  # Individual services are defined in separate files
  def self.service_available?(service_name)
    %w[Create List Update Destroy Lifecycle Export].include?(service_name.to_s)
  end
end
