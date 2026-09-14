# frozen_string_literal: true

module Api
  module V1
    # UserCompaniesController — FC-08 v3.2.3 (§37, §42-44)
    #
    # CRUD for UserCompany relationships belonging to the authenticated User.
    # - POST adds a new role to an existing Company (§37.2) — it does NOT replace
    #   the atomic onboarding endpoint POST /companies
    # - PATCH permits role modification ONLY (§37.3): user_id, company_id and
    #   deleted_at are never accepted
    # - DELETE soft-deletes the relationship (§37.4)
    #
    # Authorization (§43): only the owner of the relationship may access it.
    class UserCompaniesController < Api::V1::BaseController
      VALID_ROLES = %w[independent client].freeze

      before_action :authenticate_access_token!
      before_action :set_relationship, only: %i[show update destroy]
      before_action :authorize_relationship_access!, only: %i[show update destroy]

      # GET /api/v1/user_companies — §37.1
      # Relationships belonging to the authenticated user (explicit active scope, §31)
      def index
        relationships = UserCompany.active.for_user(current_user).includes(:company)

        render json: {
          data: relationships.map { |relationship| relationship_response(relationship) },
          meta: { total: relationships.count }
        }
      end

      # POST /api/v1/user_companies — §37.2
      # The relationship is always created for the authenticated user (§42):
      # any user_id in the payload is ignored.
      def create
        role = params[:role].to_s
        unless VALID_ROLES.include?(role)
          return error_unprocessable_entity("Role must be one of: #{VALID_ROLES.join(', ')}")
        end

        relationship = UserCompany.new(
          user: current_user,
          company_id: params[:company_id],
          role: role
        )

        if relationship.save
          render json: relationship_response(relationship), status: :created
        else
          error_unprocessable_entity(relationship.errors.full_messages.join(', '))
        end
      rescue ActiveRecord::RecordNotUnique
        # §45.5 — database uniqueness remains authoritative (INV-18)
        error_unprocessable_entity('An identical relationship already exists for this user and company')
      end

      # GET /api/v1/user_companies/:id
      def show
        render json: relationship_response(@relationship)
      end

      # PATCH /api/v1/user_companies/:id — §37.3 (role only)
      # user_id, company_id and deleted_at are structurally ignored: only the
      # role attribute is ever read from the payload.
      def update
        role = params[:role].to_s
        unless VALID_ROLES.include?(role)
          return error_unprocessable_entity("Role must be one of: #{VALID_ROLES.join(', ')}")
        end

        if @relationship.update(role: role)
          render json: relationship_response(@relationship)
        else
          error_unprocessable_entity(@relationship.errors.full_messages.join(', '))
        end
      rescue ActiveRecord::RecordNotUnique
        error_unprocessable_entity('An identical relationship already exists for this user and company')
      end

      # DELETE /api/v1/user_companies/:id — §37.4 (soft deletion)
      def destroy
        @relationship.discard
        render json: { message: 'Relationship deleted successfully' }, status: :ok
      end

      private

      def set_relationship
        @relationship = UserCompany.find_by(id: params[:id])
        error_not_found('Relationship not found') unless @relationship
      end

      # §43 — only the owner of the relationship may access it
      def authorize_relationship_access!
        return if @relationship.user_id == current_user.id

        error_forbidden('You do not have access to this relationship')
      end

      def relationship_response(relationship)
        {
          id: relationship.id,
          user_id: relationship.user_id,
          company_id: relationship.company_id,
          role: relationship.role,
          deleted_at: relationship.deleted_at,
          created_at: relationship.created_at,
          updated_at: relationship.updated_at
        }
      end
    end
  end
end
