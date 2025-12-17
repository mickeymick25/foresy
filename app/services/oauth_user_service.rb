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
  def self.find_or_create_user_from_oauth(oauth_data)
    user = initialize_user(oauth_data)
    process_user_creation_or_update(user, oauth_data)
    user
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create or update OAuth user: #{e.message}"
    raise
  end

  # Initialize user with provider and uid
  def self.initialize_user(oauth_data)
    User.find_or_initialize_by(
      provider: oauth_data[:provider],
      uid: oauth_data[:uid]
    )
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
