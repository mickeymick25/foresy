# frozen_string_literal: true

# Rack endpoint pour les health checks qui contourne complètement OmniAuth
# Ce middleware intercepte les requêtes /health et /up et les traite directement
# sans passer par le middleware Rails normal (qui inclut OmniAuth)
#
# PLACÉ AU DÉBUT du middleware stack pour s'assurer qu'il est appelé avant tous les autres

class HealthRackEndpoint
  HEALTH_PATHS = ['/health', '/up', '/health/detailed', '/api/v1/health'].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    # Vérifier si c'est une requête de health check
    if HEALTH_PATHS.include?(request.path)
      handle_health_request(env, request)
    else
      # Pas une requête de health check, passer à l'application Rails normale
      @app.call(env)
    end
  rescue StandardError => e
    # En cas d'erreur dans le middleware, retourner une erreur 500
    Rails.logger.error "HealthRackEndpoint error: #{e.message}"
    [
      500,
      { 'Content-Type' => 'application/json' },
      [{ error: 'Health check error', message: e.message }.to_json]
    ]
  end

  private

  def handle_health_request(_env, request)
    case request.path
    when '/health'
      render_health_response('ok', 'Health check successful')
    when '/up'
      render_health_response('up', 'Service is up')
    when '/health/detailed'
      render_detailed_health_response
    else
      # Fallback pour les paths non reconnus
      render_health_response('ok', 'Health check endpoint')
    end
  end

  def render_health_response(status, message)
    response = {
      status: status,
      message: message,
      timestamp: Time.current.iso8601,
      environment: Rails.env,
      version: '1.8'
    }

    [
      200,
      {
        'Content-Type' => 'application/json',
        'Cache-Control' => 'no-cache, no-store, must-revalidate',
        'Pragma' => 'no-cache',
        'Expires' => '0'
      },
      [response.to_json]
    ]
  end

  def render_detailed_health_response
    # Test de connexion base de données
    db_status = ActiveRecord::Base.connection.active?

    response = {
      status: 'ok',
      timestamp: Time.current.iso8601,
      environment: Rails.env,
      version: '1.8',
      database: db_status ? 'connected' : 'disconnected',
      uptime: Process.clock_gettime(Process::CLOCK_MONOTONIC).round(2),
      memory: {
        rss: `ps -o rss= -p #{Process.pid}`.to_i,
        units: 'KB'
      },
      ruby: {
        version: RUBY_VERSION,
        platform: RUBY_PLATFORM
      }
    }

    [
      200,
      {
        'Content-Type' => 'application/json',
        'Cache-Control' => 'no-cache, no-store, must-revalidate',
        'Pragma' => 'no-cache',
        'Expires' => '0'
      },
      [response.to_json]
    ]
  rescue StandardError => e
    response = {
      status: 'error',
      timestamp: Time.current.iso8601,
      environment: Rails.env,
      version: '1.8',
      error: e.message,
      database: 'unknown'
    }

    [
      503, # Service Unavailable
      { 'Content-Type' => 'application/json' },
      [response.to_json]
    ]
  end
end

# Ajouter ce middleware au DÉBUT du stack (index 0)
# Cela garantit que les health checks sont traités AVANT OmniAuth et tous les autres middlewares
Rails.application.config.middleware.insert(0, HealthRackEndpoint)

Rails.logger.info '🏥 Health Rack Endpoint initialized - Health checks will bypass all other middleware'
