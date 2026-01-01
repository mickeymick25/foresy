# frozen_string_literal: true

module E2e
  # E2E Setup Controller
  #
  # Provides isolated endpoint for E2E test infrastructure setup.
  # This controller is ONLY mounted when E2E_MODE=true or RAILS_ENV=test.
  #
  # 🔐 SECURITY RULES (NON-NEGOTIABLE):
  # - NOT accessible in production
  # - NOT part of public API (/api/v1)
  # - NOT documented in Swagger
  # - Disabled by default
  #
  # Purpose:
  # E2E tests declare the system state they need, they don't create business data.
  # This endpoint sets up the required state (User + Company + UserCompany relation).
  #
  # Usage:
  #   POST /__e2e__/setup
  #   {
  #     "user": { "email": "e2e@example.com", "password": "SecurePassword123!" },
  #     "company": { "name": "E2E Test Company", "role": "independent" }
  #   }
  #
  # Response:
  #   {
  #     "token": "jwt_token",
  #     "user_id": "uuid",
  #     "company_id": "uuid",
  #     "role": "independent"
  #   }
  class SetupController < ActionController::API
    # Security: Verify E2E mode is enabled
    before_action :verify_e2e_mode!

    # POST /__e2e__/setup
    # Creates a complete test context: User + Company + UserCompany relation
    def create
      user = create_or_find_user
      company = create_company
      user_company = create_user_company(user, company)
      token = generate_token(user)

      render json: build_response(user, company, user_company, token), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: 'Setup failed', message: e.record.errors.full_messages }, status: :unprocessable_entity
    rescue StandardError => e
      render json: { error: 'Setup failed', message: e.message }, status: :internal_server_error
    end

    private

    def build_response(user, company, user_company, token)
      { token: token, user_id: user.id, company_id: company.id, role: user_company.role, email: user.email }
    end

    # DELETE /__e2e__/cleanup
    # Cleans up E2E test data (optional, for test isolation)
    def destroy
      email_pattern = params[:email_pattern] || 'e2e-%@example.com'

      # Clean up in correct order (respect FK constraints)
      users = User.where('email LIKE ?', email_pattern)
      user_ids = users.pluck(:id)

      # Delete related data
      deleted_counts = {
        mission_companies: MissionCompany.joins(:mission)
                                         .where(missions: { created_by_user_id: user_ids })
                                         .delete_all,
        missions: Mission.where(created_by_user_id: user_ids).delete_all,
        user_companies: UserCompany.where(user_id: user_ids).delete_all,
        sessions: Session.where(user_id: user_ids).delete_all,
        users: users.delete_all
      }

      # Clean orphan companies (E2E created)
      deleted_counts[:companies] = Company.where('name LIKE ?', 'E2E%').delete_all

      render json: {
        message: 'Cleanup completed',
        deleted: deleted_counts
      }, status: :ok
    end

    # Security gate: Block if not in E2E mode
    def verify_e2e_mode!
      unless e2e_mode_enabled?
        render json: {
          error: 'Forbidden',
          message: 'E2E endpoints are disabled'
        }, status: :forbidden
      end
    end

    # Check if E2E mode is enabled
    def e2e_mode_enabled?
      Rails.env.test? || ENV['E2E_MODE'] == 'true'
    end

    # Create or find user from params
    def create_or_find_user
      email = user_params[:email]
      password = user_params[:password]

      User.find_by(email: email) || User.create!(
        email: email,
        password: password,
        password_confirmation: password
      )
    end

    # Create company from params
    def create_company
      timestamp = Time.current.to_i
      Company.create!(
        name: company_params[:name] || "E2E Company #{timestamp}",
        siret: company_params[:siret] || format('%014d', rand(10**14)),
        siren: company_params[:siren] || format('%09d', rand(10**9)),
        country: 'FR',
        currency: 'EUR'
      )
    end

    # Create UserCompany relation
    def create_user_company(user, company)
      role = company_params[:role] || 'independent'

      UserCompany.create!(
        user_id: user.id,
        company_id: company.id,
        role: role
      )
    end

    # Generate JWT token for user
    def generate_token(user)
      result = AuthenticationService.login(
        user,
        request.remote_ip || '127.0.0.1',
        request.user_agent || 'E2E Test Agent'
      )
      result[:token]
    end

    # Strong params for user
    def user_params
      params.require(:user).permit(:email, :password)
    end

    # Strong params for company
    def company_params
      params.require(:company).permit(:name, :siret, :siren, :role)
    end
  end
end
