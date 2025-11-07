# frozen_string_literal: true

# Active OmniAuth test mode to avoid real external requests
OmniAuth.config.test_mode = true

# Mocked auth hash for Google OAuth2
OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
                                                                     provider: 'google_oauth2',
                                                                     uid: '1234567890',
                                                                     info: {
                                                                       email: 'google_user@example.com',
                                                                       first_name: 'Google',
                                                                       last_name: 'User'
                                                                     },
                                                                     credentials: {
                                                                       token: 'mock_google_token',
                                                                       refresh_token: 'mock_google_refresh_token',
                                                                       expires_at: Time.now + 1.week
                                                                     }
                                                                   })

# Mocked auth hash for GitHub
OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
                                                              provider: 'github',
                                                              uid: '0987654321',
                                                              info: {
                                                                email: 'github_user@example.com',
                                                                name: 'GitHub User',
                                                                nickname: 'githubuser'
                                                              },
                                                              credentials: {
                                                                token: 'mock_github_token',
                                                                expires: false
                                                              }
                                                            })
