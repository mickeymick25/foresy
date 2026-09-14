# frozen_string_literal: true

# Company Create Service — FC-08 v3.2.3 (§36.2, §38, INV-16/17)
#
# Atomic Company onboarding: creates the Company AND its initial UserCompany
# relationship in a single transaction. A failure in either step persists nothing.
#
# CONTRACT (house pattern — MissionServices::Create):
# - Returns ApplicationResult exclusively
# - No business exceptions raised
# - No HTTP concerns in service
#
# @example
#   result = CompanyServices::Create.call(
#     company_params: params.require(:company).permit(...),
#     role: 'independent',
#     current_user: user
#   )
#
class CompanyServices
  class Create
    VALID_ROLES = %w[independent client].freeze

    def self.call(company_params:, role:, current_user:)
      new(company_params: company_params, role: role, current_user: current_user).call
    end

    def initialize(company_params:, role:, current_user:)
      @company_params = company_params
      @role = role
      @current_user = current_user
    end

    def call
      unless company_params.present?
        return ApplicationResult.bad_request(
          error: :missing_parameters,
          message: 'Company parameters are required'
        )
      end

      unless current_user.present?
        return ApplicationResult.bad_request(
          error: :missing_parameters,
          message: 'Current user is required'
        )
      end

      # §45.4 — role is a UserCompany attribute, validated before any persistence
      unless VALID_ROLES.include?(role.to_s)
        return ApplicationResult.unprocessable_entity(
          error: :invalid_role,
          message: "Role must be one of: #{VALID_ROLES.join(', ')}"
        )
      end

      # Atomic onboarding (INV-16/17): Company + UserCompany in one transaction
      company = nil
      ActiveRecord::Base.transaction do
        company = Company.new(company_attributes)
        company.save!

        company.user_companies.create!(user: current_user, role: role.to_s)
      end

      ApplicationResult.created(
        data: { company: company.reload },
        message: 'Company created successfully'
      )
    rescue ActiveRecord::RecordInvalid => e
      ApplicationResult.unprocessable_entity(
        error: :validation_failed,
        message: e.record.errors.full_messages.join(', ')
      )
    rescue ActiveRecord::RecordNotUnique
      ApplicationResult.unprocessable_entity(
        error: :duplicate_relationship,
        message: 'An identical relationship already exists for this user and company'
      )
    rescue StandardError => e
      Rails.logger.error "CompanyServices::Create error: #{e.message}" if defined?(Rails)
      ApplicationResult.internal_error(
        error: :internal_error,
        message: 'An unexpected error occurred while creating the company'
      )
    end

    private

    attr_reader :company_params, :role, :current_user

    def company_attributes
      company_params.permit(:name, :siren, :siret, :legal_form, :tax_number,
                            :address_line_1, :address_line_2, :postal_code,
                            :city, :country, :currency, :vat_regime)
                    .to_h
    end
  end
end
