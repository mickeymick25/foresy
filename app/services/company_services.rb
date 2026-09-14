# frozen_string_literal: true

# CompanyServices - Main Namespace File (FC-08)
#
# This file defines the main CompanyServices class to avoid namespace conflicts
# with Zeitwerk autoloader (house pattern: see cra_services.rb).
# Individual service classes are defined in separate files within the
# company_services directory.
#
# @example Usage
#   result = CompanyServices::Create.call(
#     company_params: params.require(:company).permit(...),
#     role: 'independent',
#     current_user: user
#   )
#
class CompanyServices
  # Individual services are defined in separate files:
  # - Create (atomic onboarding — FC-08 §38, INV-16/17)

  # Stub method to prevent EmptyClass RuboCop offense (house pattern:
  # see cra_services.rb)
  def self.service_available?(service_name)
    %w[Create].include?(service_name.to_s)
  end
end
