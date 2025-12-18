# frozen_string_literal: true

# OAuthConcern
#
# Concern that provides OAuth authentication functionality.
# Handles OAuth callbacks, user creation/updates, and data extraction
# for external providers like GitHub and Google.
module OauthConcern
  extend ActiveSupport::Concern
  included do
    def oauth_callback
      auth = extract_oauth_data
      return render_unauthorized('OAuth data missing') unless auth

      user = find_or_create_user_from_auth(auth)
      return render_unprocessable_entity('User creation failed') unless user.persisted?

      perform_oauth_login(user)
    end

    def extract_oauth_data
      request.env['omniauth.auth'] || Rails.application.env_config['omniauth.auth']
    end

    def perform_oauth_login(user)
      result = AuthenticationService.login(user, request.remote_ip, request.user_agent)
      render json: {
        token: result[:token],
        refresh_token: result[:refresh_token],
        user: user
      }, status: :ok
    end

    def find_or_create_user_from_auth(auth)
      auth_data = extract_auth_data(auth)
      user = find_or_initialize_user(auth_data[:provider], auth_data[:uid])
      if user.persisted?
        update_existing_user!(user, auth_data[:email], auth_data[:name], auth_data[:nickname])
      else
        create_oauth_user!(user, auth_data[:email], auth_data[:name], auth_data[:nickname])
      end
      user
    end
  end

  private

  def extract_auth_data(auth)
    provider_and_uid = extract_provider_and_uid(auth)
    info = extract_info_data(auth)
    extracted_fields = extract_all_info_fields(info)
    {
      provider: provider_and_uid[:provider],
      uid: provider_and_uid[:uid],
      email: extracted_fields[:email],
      name: extracted_fields[:name],
      nickname: extracted_fields[:nickname]
    }
  end

  def extract_provider_and_uid(auth)
    provider = auth.respond_to?(:provider) ? auth.provider : (auth[:provider] || auth['provider'])
    uid = auth.respond_to?(:uid) ? auth.uid : (auth[:uid] || auth['uid'])
    {
      provider: provider,
      uid: uid
    }
  end

  def extract_all_info_fields(info)
    {
      email: extract_info_field(info, :email),
      name: extract_info_field(info, :name),
      nickname: extract_info_field(info, :nickname)
    }
  end

  def extract_info_data(auth)
    auth.respond_to?(:info) ? auth.info : (auth[:info] || auth['info'])
  end

  def extract_info_field(info, field)
    return nil if info.blank?

    if info.respond_to?(field)
      info.send(field)
    else
      info[field] || info[field.to_s]
    end
  end

  def find_or_initialize_user(provider, uid)
    User.find_or_initialize_by(provider: provider, uid: uid)
  end

  def update_existing_user!(user, email, name, nickname)
    user.email = email if email.present?
    user.name = name || nickname || user.name || 'No Name'
    user.save
  end

  def create_oauth_user!(user, email, name, nickname)
    user.email = email
    user.name = name || nickname || 'No Name'
    user.active = true
    Rails.logger.error "Failed to create OAuth user: #{user.errors.full_messages.join(', ')}" unless user.save
  end
end
