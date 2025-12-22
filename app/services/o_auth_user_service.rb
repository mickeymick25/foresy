# frozen_string_literal: true

# OAuthUserService
#
# Service responsible for OAuth user management.
# Handles user creation, updates, and validation for OAuth providers
# like GitHub and Google.
#
# This service extracts user management logic from OauthController to reduce
# complexity and improve maintainability.
class OAuthUserService
  # Find or create user from OAuth data using existing User model
  # Strategy:
  # 1. First, try to find by provider + uid (exact OAuth match)
  # 2. If not found, try to find by email (link existing account)
  # 3. If still not found, create new user
  def self.find_or_create_user_from_oauth(oauth_data)
    user = find_by_provider_and_uid(oauth_data) ||
           find_by_email_and_link_provider(oauth_data) ||
           build_new_user(oauth_data)

    process_user_creation_or_update(user, oauth_data)
    user
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create or update OAuth user: #{e.message}"
    raise
  end

  # Find user by provider and uid (exact OAuth match)
  def self.find_by_provider_and_uid(oauth_data)
    User.find_by(provider: oauth_data[:provider], uid: oauth_data[:uid])
  end

  # Find user by email and link the new OAuth provider
  def self.find_by_email_and_link_provider(oauth_data)
    user = User.find_by(email: oauth_data[:email])
    return nil unless user

    # Link this OAuth provider to existing account
    Rails.logger.info "Linking OAuth provider #{oauth_data[:provider]} to existing user #{user.email}"
    user.provider = oauth_data[:provider]
    user.uid = oauth_data[:uid]
    user
  end

  # Build new user for OAuth
  def self.build_new_user(oauth_data)
    User.new(provider: oauth_data[:provider], uid: oauth_data[:uid])
  end

  # Process user creation or update based on persistence
  def self.process_user_creation_or_update(user, oauth_data)
    if user.persisted?
      update_existing_oauth_user!(user, oauth_data)
    else
      create_oauth_user!(user, oauth_data)
    end
  end

  # Update existing OAuth user with latest data
  def self.update_existing_oauth_user!(user, oauth_data)
    user.email = oauth_data[:email] if oauth_data[:email].present?
    user.name = extract_user_name(oauth_data)
    user.active = true
    user.save!
  end

  # Create new OAuth user
  def self.create_oauth_user!(user, oauth_data)
    user.email = oauth_data[:email]
    user.name = extract_user_name(oauth_data)
    user.active = true
    user.save!
  end

  # Validate if user can be created from OAuth data
  def self.valid_oauth_user_data?(oauth_data)
    return false if oauth_data.blank?
    return false if oauth_data[:provider].blank?
    return false if oauth_data[:uid].blank?
    return false if oauth_data[:email].blank?

    true
  end

  # Find existing user by provider and uid
  def self.find_existing_user(provider, uid)
    User.find_by(provider: provider, uid: uid)
  end

  def self.extract_user_name(oauth_data)
    oauth_data[:name] || oauth_data[:nickname] || 'No Name'
  end
end
