# app/controllers/concerns/http_status_map.rb
# frozen_string_literal: true

# Mapping HTTP centralisé et canonique - P1.4.2 Rules
# Concern Rails correctement incluable pour HTTP Status Codes
# Une seule source de vérité pour tous les statuts HTTP

module HttpStatusMap
  extend ActiveSupport::Concern

  HTTP_STATUS_CODES = {
    ok: 200,
    created: 201,
    no_content: 204,

    validation_error: 422,    # Validation métier
    unauthorized: 401,        # Non authentifié (missing/expired token)
    forbidden: 403,           # Non autorisé (policy/access denied)
    not_found: 404, # Ressource absente
    conflict: 409,            # Pour les conflits (duplicate entries, etc.)
    bad_request: 400,         # Payload invalide (format / missing)
    internal_error: 500       # Erreurs internes non gérées
  }.freeze

  included do
    def http_status(key)
      HTTP_STATUS_CODES[key]
    end

    def ok
      200
    end

    def created
      201
    end

    def no_content
      204
    end

    def validation_error
      422
    end

    def unauthorized
      401
    end

    def forbidden
      403
    end

    def not_found
      404
    end

    def conflict
      409
    end

    def bad_request
      400
    end

    def internal_error
      500
    end
  end

  class_methods do
    def [](key)
      HTTP_STATUS_CODES[key]
    end
  end
end
