# frozen_string_literal: true

module Api
  module V1
    # CompaniesController — FC-08 v3.2.3 (§36, §38-44)
    #
    # CRUD for Company with explicit UserCompany-based authorization.
    # POST /companies is the principal onboarding endpoint (§38): it creates
    # the Company and its initial UserCompany relationship atomically.
    #
    # Parameter wrapping (§40): flat JSON payloads are wrapped under :company
    # with role EXCLUDED from the wrapper (INV-22) — role is read separately
    # as a UserCompany parameter (§39).
    #
    # Parameter security (§42): id, deleted_at, created_at, updated_at, user_id
    # are never mass-assigned.
    #
    # Authorization (§43): access requires an ACTIVE UserCompany relationship.
    class CompaniesController < Api::V1::BaseController
      wrap_parameters :company, include: %i[name siren siret legal_form tax_number
                                            address_line_1 address_line_2 postal_code
                                            city country currency vat_regime]

      before_action :authenticate_access_token!
      before_action :set_company, only: %i[show update destroy]
      before_action :authorize_company_access!, only: %i[show update destroy]

      # GET /api/v1/companies — §36.1
      # Companies accessible through ACTIVE UserCompany relationships (§31)
      def index
        companies = Company.active
                           .joins(:user_companies)
                           .where(user_companies: { user_id: current_user.id, deleted_at: nil })
                           .distinct

        render json: {
          data: companies.map { |company| company_response(company) },
          meta: { total: companies.count }
        }
      end

      # POST /api/v1/companies — §36.2, §38 (atomic onboarding)
      def create
        result = CompanyServices::Create.call(
          company_params: company_params,
          role: params[:role],
          current_user: current_user
        )

        if result.success?
          render json: company_response(result.data[:company]), status: :created
        else
          render_result_error(result)
        end
      end

      # GET /api/v1/companies/:id — §36.3
      def show
        render json: company_response(@company)
      end

      # PATCH /api/v1/companies/:id — §36.4
      def update
        if @company.update(company_update_params)
          render json: company_response(@company)
        else
          error_unprocessable_entity(@company.errors.full_messages.join(', '))
        end
      end

      # DELETE /api/v1/companies/:id — §36.5 (soft deletion only, Scenario 14)
      def destroy
        @company.discard
        render json: { message: 'Company deleted successfully' }, status: :ok
      end

      private

      def set_company
        @company = Company.find_by(id: params[:id])
        error_not_found('Company not found') unless @company
      end

      # §43 — explicit authorization: an active UserCompany relationship must exist
      def authorize_company_access!
        return if UserCompany.active.exists?(user_id: current_user.id, company_id: @company.id)

        error_forbidden('You do not have access to this company')
      end

      # §42 — only explicitly permitted Company attributes
      def company_params
        params.require(:company).permit(:name, :siren, :siret, :legal_form, :tax_number,
                                        :address_line_1, :address_line_2, :postal_code,
                                        :city, :country, :currency, :vat_regime)
      end

      def company_update_params
        company_params
      end

      def company_response(company)
        {
          id: company.id,
          name: company.name,
          siren: company.siren,
          siret: company.siret,
          legal_form: company.legal_form,
          tax_number: company.tax_number,
          address_line_1: company.address_line_1,
          address_line_2: company.address_line_2,
          postal_code: company.postal_code,
          city: company.city,
          country: company.country,
          currency: company.currency,
          vat_regime: company.vat_regime,
          created_at: company.created_at,
          updated_at: company.updated_at
        }
      end

      # Dispatch a service result error to the appropriate standardized
      # error method based on the result's HTTP status (house pattern).
      def render_result_error(result)
        message = result.message || result.error.to_s
        case result.status
        when :conflict
          error_conflict(message)
        when :forbidden
          error_forbidden(message)
        when :not_found
          error_not_found(message)
        when :bad_request
          error_bad_request(message)
        when :internal_server_error, :internal_error
          error_internal(message)
        else
          error_unprocessable_entity(message)
        end
      end
    end
  end
end
