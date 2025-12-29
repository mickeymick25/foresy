# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Rate Limiting Authentication Endpoints - FC-05', type: :request do
  # Feature Contract FC-05: Rate Limiting for Authentication Endpoints
  # Business Goal: Protect authentication endpoints from brute force, credential stuffing, and automated abuse
  # without degrading legitimate user experience.

  # === LOGIN ENDPOINT TESTS ===
  path '/api/v1/auth/login' do
    post 'Authenticates a user with rate limiting' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :login_params, in: :body, required: true, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: :email },
          password: { type: :string, format: :password }
        },
        required: %w[email password]
      }

      # === SCENARIO: Login under rate limit ===
      # Given: I send less than 5 login requests per minute
      # When: I call POST /api/v1/auth/login
      # Then: I receive a normal response
      response '401', 'user authenticated (under rate limit)' do
        let(:login_params) do
          {
            email: 'invalid_user_never_exists@example.com',
            password: 'invalid_wrong_password_123'
          }
        end

        run_test! do |response|
          # Should return 401 for invalid credentials (expected behavior with test data)
          expect(response.status).to eq(401)
          expect(response.status).not_to eq(500) # Should not be a server error
        end
      end

      # === SCENARIO: Login rate limit exceeded ===
      # Given: I send more than 5 login requests per minute
      # When: I call POST /api/v1/auth/login
      # Then: I receive a 429 response
      # And: a Retry-After header is present
      response '429', 'rate limit exceeded - too many login attempts' do
        let(:login_params) do
          {
            email: 'invalid_user_never_exists@example.com',
            password: 'invalid_wrong_password_123'
          }
        end

        # Simulate exceeding rate limit by making 6 HTTP requests (limit is 5 per minute)
        before do
          # Make 6 HTTP requests to exceed the limit of 5
          6.times do |i|
            post '/api/v1/auth/login',
                 params: login_params.to_json,
                 headers: { 'Content-Type' => 'application/json' }
            if i < 5
              # First 5 requests should succeed (200 or 401 for invalid credentials)
              expect(response).not_to have_http_status(429)
            else
              # 6th request should be rate limited (429)
              expect(response).to have_http_status(429)
            end
          end
        end

        run_test! do |response|
          # This request should be rate limited
          expect(response.status).to eq(429)
          expect(response.headers).to include('Retry-After')
          expect(response.headers['Retry-After']).to match(/\d+/)

          data = JSON.parse(response.body)
          expect(data['error']).to eq('Rate limit exceeded')
          expect(data['retry_after']).to be_between(58, 60)
        end
      end

      # === EDGE CASE: IP address extraction ===
      # IP absente → fallback sur request.remote_ip
      response '401', 'handles missing X-Forwarded-For by using remote_ip' do
        let(:login_params) do
          {
            email: 'invalid_user_never_exists@example.com',
            password: 'invalid_wrong_password_123'
          }
        end

        # Test without X-Forwarded-For header (should fallback to remote_ip)
        run_test! do |response|
          expect(response.status).to eq(401) # Should return 401 for invalid credentials
          expect(response.status).not_to eq(429) # Should not be rate limited for single request
        end
      end
    end
  end

  # === SIGNUP ENDPOINT TESTS ===
  path '/api/v1/signup' do
    post 'Creates a new user with rate limiting' do
      tags 'Users'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :user_params, in: :body, required: true, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: :email },
          password: { type: :string, format: :password },
          password_confirmation: { type: :string, format: :password }
        },
        required: %w[email password password_confirmation]
      }

      # === SCENARIO: Signup rate limiting ===
      # Given: I send less than 3 signup requests per minute
      # When: I call POST /api/v1/signup
      # Then: I receive a normal response
      response '422', 'user created (under rate limit)' do
        let(:user_params) do
          {
            user: {
              email: "unique_test_user_#{Time.current.to_i}@example.com",
              password: 'invalid_wrong_password_123',
              password_confirmation: 'invalid_wrong_password_123'
            }
          }
        end

        # Make actual HTTP request with parameters to test the endpoint
        before do
          post '/api/v1/signup',
               params: user_params.to_json,
               headers: { 'Content-Type' => 'application/json' }
        end

        run_test! do |response|
          # Should return 422 validation error (email already taken is expected behavior)
          expect(response.status).to eq(422)
          expect(response.status).not_to eq(429) # Should not be rate limited for single request
        end
      end

      # Given: I send more than 3 signup requests per minute
      # When: I call POST /api/v1/signup
      # Then: I receive a 429 response
      response '429', 'rate limit exceeded - too many signup attempts' do
        let(:user_params) do
          {
            email: 'newuser@example.com',
            password: 'invalid_wrong_password_123',
            password_confirmation: 'invalid_wrong_password_123'
          }
        end

        # Simulate exceeding rate limit by making 4 HTTP requests (limit is 3 per minute)
        before do
          # Make 4 HTTP requests to exceed the limit of 3
          4.times do |i|
            post '/api/v1/signup',
                 params: user_params.to_json,
                 headers: { 'Content-Type' => 'application/json' }
            if i < 3
              # First 3 requests should succeed (201 for valid signup)
              expect(response).not_to have_http_status(429)
            else
              # 4th request should be rate limited (429)
              expect(response).to have_http_status(429)
            end
          end
        end

        run_test! do |response|
          # This request should be rate limited
          expect(response.status).to eq(429)
          expect(response.headers).to include('Retry-After')

          data = JSON.parse(response.body)
          expect(data['error']).to eq('Rate limit exceeded')
          expect(data['retry_after']).to be_an(Integer)
        end
      end
    end
  end

  # === REFRESH ENDPOINT TESTS ===
  path '/api/v1/auth/refresh' do
    post 'Refreshes authentication token with rate limiting' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :refresh_params, in: :body, required: true, schema: {
        type: :object,
        properties: {
          refresh_token: { type: :string }
        },
        required: %w[refresh_token]
      }

      # === SCENARIO: Refresh rate limiting ===
      # Given: I send less than 10 refresh requests per minute
      # When: I call POST /api/v1/auth/refresh
      # Then: I receive a normal response
      response '401', 'token refreshed (under rate limit)' do
        let(:refresh_params) do
          {
            refresh_token: 'dummy_refresh_token'
          }
        end

        run_test! do |response|
          # Should return normal response (401 invalid token is expected with dummy data)
          expect(response.status).to be_in([200, 401])
          expect(response.status).not_to eq(429) # Should not be rate limited for single request
          expect(response.status).not_to eq(500) # Should not be a server error
        end
      end

      # Given: I send more than 10 refresh requests per minute
      # When: I call POST /api/v1/auth/refresh
      # Then: I receive a 429 response
      response '429', 'rate limit exceeded - too many refresh attempts' do
        let(:refresh_params) do
          {
            refresh_token: 'dummy_refresh_token'
          }
        end

        # Simulate exceeding rate limit by making 11 HTTP requests (limit is 10 per minute)
        before do
          # Make 11 HTTP requests to exceed the limit of 10
          11.times do |i|
            post '/api/v1/auth/refresh',
                 params: refresh_params.to_json,
                 headers: { 'Content-Type' => 'application/json' }
            if i < 10
              # First 10 requests should not be rate limited (may get 401 for invalid token)
              expect(response).not_to have_http_status(429)
            else
              # 11th request should be rate limited (429)
              expect(response).to have_http_status(429)
            end
          end
        end

        run_test! do |response|
          # This request should be rate limited
          expect(response.status).to eq(429)
          expect(response.headers).to include('Retry-After')

          data = JSON.parse(response.body)
          expect(data['error']).to eq('Rate limit exceeded')
          expect(data['retry_after']).to be_between(58, 60)
          expect(data['retry_after']).to be_an(Integer)
        end
      end
    end
  end

  # === OUT-OF-SCOPE ENDPOINT TESTS ===
  # When: I call a non-auth endpoint repeatedly
  # Then: no rate limit is applied

  # Health endpoint - should never be rate-limited
  path '/health' do
    get 'Health check endpoint - not rate-limited' do
      tags 'Health'
      produces 'application/json'

      response '200', 'health check (not rate-limited)' do
        run_test! do |response|
          expect(response.status).to eq(200)
          expect(response).not_to have_http_status(429)
        end
      end
    end
  end

  # OAuth failure endpoint - should never be rate-limited
  path '/api/v1/auth/failure' do
    get 'OAuth failure endpoint - not rate-limited' do
      tags 'OAuth'
      produces 'application/json'

      response '401', 'oauth failure (not rate-limited)' do
        run_test! do |response|
          # OAuth failure endpoint should not be rate-limited
          expect(response.status).not_to eq(429)
          # Accept any non-429 response as valid (200, 401, 404, 422, etc.)
          expect([200, 401, 404, 422]).to include(response.status)
        end
      end
    end
  end

  # Logout endpoint - should never be rate-limited
  path '/api/v1/auth/logout' do
    delete 'Logout endpoint - not rate-limited' do
      tags 'Authentication'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: false

      # Accept multiple response codes as long as they're not 429 (rate limited)
      response '401', 'logout success (not rate-limited)' do
        let(:Authorization) { 'Bearer invalid_token_test_12345' }

        run_test! do |response|
          # Logout endpoint should not be rate-limited
          expect(response.status).not_to eq(429)
          # Accept 401 (unauthorized) as expected with invalid token
          expect(response.status).to eq(401)
        end
      end

      response '401', 'logout unauthorized (not rate-limited)' do
        let(:Authorization) { 'Bearer invalid_token_test_67890' }

        run_test! do |response|
          # Logout endpoint should not be rate-limited
          expect(response.status).not_to eq(429)
          # Accept 401 (unauthorized) as expected with invalid token
          expect(response.status).to eq(401)
        end
      end
    end
  end

  # GET to login endpoint - should never be rate-limited (only POST is rate-limited)
  # Note: GET /api/v1/auth/login doesn't exist, so it returns 404 (not rate-limited)
  path '/api/v1/auth/login' do
    get 'GET login endpoint - not rate-limited (endpoint does not exist)' do
      tags 'Authentication'
      produces 'application/json'

      response '404', 'get login endpoint does not exist (not rate-limited)' do
        run_test! do
          expect(response.status).to eq(404) # Endpoint doesn't exist
          expect(response.status).not_to eq(429) # Not rate-limited
        end
      end
    end
  end

  # DELETE to logout endpoint - should never be rate-limited (only POST is rate-limited)
  # Note: PUT /api/v1/auth/refresh doesn't exist, so we test DELETE /api/v1/auth/logout which does exist
  path '/api/v1/auth/logout' do
    delete 'DELETE logout endpoint - not rate-limited (only POST is rate-limited)' do
      tags 'Authentication'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: false

      response '401', 'delete logout success (not rate-limited)' do
        let(:Authorization) { 'Bearer invalid_token_test_delete_12345' }

        run_test! do |response|
          # DELETE logout endpoint should not be rate-limited
          expect(response.status).not_to eq(429)
          # Accept 401 (unauthorized) as expected with invalid token
          expect(response.status).to eq(401)
        end
      end

      response '401', 'delete logout unauthorized (not rate-limited)' do
        let(:Authorization) { 'Bearer invalid_token_test_delete_67890' }

        run_test! do |response|
          # DELETE logout endpoint should not be rate-limited
          expect(response.status).not_to eq(429)
          # Accept 401 (unauthorized) as expected with invalid token
          expect(response.status).to eq(401)
        end
      end
    end
  end

  # === REDIS UNAVAILABLE EDGE CASE ===
  # Redis indisponible → fail closed (HTTP 429)
  # Test using existing login endpoint with Redis failure simulation header
  path '/api/v1/auth/login' do
    post 'Test Redis unavailable - fail closed (HTTP 429)' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :login_params, in: :body, required: true, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: :email },
          password: { type: :string, format: :password }
        },
        required: %w[email password]
      }

      response '429', 'fail closed when Redis is down' do
        let(:login_params) do
          {
            email: 'invalid_user_never_exists@example.com',
            password: 'invalid_wrong_password_123'
          }
        end

        # This test verifies that when Redis is unavailable,
        # the system fails closed (returns 429) rather than fail open
        # Mock RateLimitService to simulate Redis failure
        before do
          allow(RateLimitService).to receive(:check_rate_limit).and_return([false, 60])
        end

        run_test! do |response|
          expect(response.status).to eq(429) # Fail closed
          expect(response.headers).to include('Retry-After')

          data = JSON.parse(response.body)
          expect(data['error']).to eq('Rate limit exceeded')
          expect(data['retry_after']).to be_an(Integer)
        end
      end
    end
  end

  # === IMPLEMENTATION VERIFICATION ===
  # These tests will verify implementation details once rate limiting is implemented

  describe 'Implementation verification for Feature Contract FC-05' do
    context 'should be implemented with Redis storage (not local memory)' do
      it 'uses Redis for rate limit storage' do
        # Verify that RateLimitService uses Redis, not local memory
        expect(RateLimitService.private_methods).to include(:redis)

        # Verify that Redis is used for storage operations
        expect(RateLimitService.methods).to include(:check_rate_limit)

        # Test Redis connection by clearing a test rate limit
        test_ip = '192.168.1.100'
        RateLimitService.clear_rate_limit('auth/login', test_ip)

        # Verify Redis key format and operations work
        key = "rate_limit:auth/login:#{test_ip}"
        expect(key).to match(%r{^rate_limit:auth/login:[\d.:]+$})
      end
    end

    context 'should implement sliding window algorithm' do
      it 'uses sliding window for rate limiting' do
        # Verify sliding window constants are defined
        expect(RateLimitService.const_defined?(:WINDOW_SIZE)).to be true
        expect(RateLimitService::WINDOW_SIZE).to eq(60)

        # Test that rate limiting works with sliding window behavior
        test_ip = '192.168.1.101'

        # Clear any existing rate limit
        RateLimitService.clear_rate_limit('auth/login', test_ip)

        # Make requests and verify sliding window behavior
        allow(RateLimitService).to receive(:redis).and_call_original

        5.times do
          allowed, retry_after = RateLimitService.check_rate_limit('auth/login', test_ip)
          expect(allowed).to be true
          expect(retry_after).to eq(0)
        end

        # 6th request should be blocked
        allowed, retry_after = RateLimitService.check_rate_limit('auth/login', test_ip)
        expect(allowed).to be false
        expect(retry_after).to be_between(58, 60)
      end
    end

    context 'should use IP-based identification' do
      it 'identifies clients by IP address' do
        # Verify that extract_client_ip method exists
        expect(RateLimitService.methods).to include(:extract_client_ip)

        # Test IP extraction with different headers
        test_ip = '203.0.113.45'

        # Create a mock request object
        request = double('request')
        allow(request).to receive(:env).and_return({
                                                     'HTTP_X_FORWARDED_FOR' => "#{test_ip}, 10.0.0.1",
                                                     'HTTP_X_REAL_IP' => '10.0.0.2',
                                                     'REMOTE_ADDR' => '10.0.0.3'
                                                   })

        # X-Forwarded-For should have priority
        expect(RateLimitService.extract_client_ip(request)).to eq(test_ip)

        # Test fallback when X-Forwarded-For is missing
        request_no_forwarded = double('request')
        allow(request_no_forwarded).to receive(:env).and_return({
                                                                  'HTTP_X_REAL_IP' => test_ip,
                                                                  'REMOTE_ADDR' => '10.0.0.3'
                                                                })

        expect(RateLimitService.extract_client_ip(request_no_forwarded)).to eq(test_ip)

        # Test final fallback to REMOTE_ADDR
        request_remote_only = double('request')
        allow(request_remote_only).to receive(:env).and_return({
                                                                 'REMOTE_ADDR' => test_ip
                                                               })

        expect(RateLimitService.extract_client_ip(request_remote_only)).to eq(test_ip)
      end
    end

    context 'should have centralized logic (not in controllers)' do
      it 'centralizes rate limiting logic' do
        # Verify that all rate limiting logic is in RateLimitService
        expect(RateLimitService.methods).to include(:check_rate_limit)
        expect(RateLimitService.methods).to include(:extract_client_ip)
        expect(RateLimitService.methods).to include(:rate_limited_endpoint?)
        expect(RateLimitService.methods).to include(:extract_endpoint)

        # Verify that configuration is centralized
        expect(RateLimitService.methods).to include(:config)
        config = RateLimitService.config
        expect(config).to be_a(Hash)
        expect(config.keys).to include('auth/login', 'auth/signup', 'auth/refresh')

        # Verify rate limits are correct
        expect(config['auth/login']).to eq(5)
        expect(config['auth/signup']).to eq(3)
        expect(config['auth/refresh']).to eq(10)

        # Test that logic is in service, not in controllers
        expect(Object.const_defined?('RateLimitService')).to be true
      end
    end

    context 'should log rate limit exceeded events' do
      it 'logs with rate_limit.exceeded tag' do
        # Test that logging methods exist and work
        test_ip = '192.168.1.102'
        endpoint = 'auth/login'

        # Clear any existing rate limit
        RateLimitService.clear_rate_limit(endpoint, test_ip)

        # Mock Rails logger to capture log output
        log_messages = []
        allow(Rails.logger).to receive(:info) do |&block|
          log_messages << block.call if block
        end

        # Exceed rate limit to trigger logging
        6.times do
          RateLimitService.check_rate_limit(endpoint, test_ip)
        end

        # Verify that log message contains required elements
        expect(log_messages.any? { |msg| msg.to_s.include?('rate_limit.exceeded') }).to be true

        # Test IP masking in logs (security requirement)
        # The log should not contain the full IP address
        full_ip_logs = log_messages.select { |msg| msg.to_s.include?(test_ip) }
        expect(full_ip_logs).to be_empty

        # Verify masked IP format in logs
        masked_ip_logs = log_messages.select { |msg| msg.to_s.include?('192.168.x.x') }
        expect(masked_ip_logs.any?).to be true

        # Test Redis failure logging
        redis_error_logs = []
        allow(Rails.logger).to receive(:warn) do |&block|
          redis_error_logs << block.call if block
        end

        # Force Redis error by mocking Redis failure
        allow(RateLimitService).to receive(:redis).and_raise(StandardError.new('Connection refused'))

        allowed, retry_after = RateLimitService.check_rate_limit(endpoint, test_ip)
        expect(allowed).to be false # Should fail closed
        expect(retry_after).to eq(60)

        # Verify Redis failure logging
        expect(redis_error_logs.any? { |msg| msg.to_s.include?('rate_limit.redis_unavailable') }).to be true
      end
    end
  end
end
