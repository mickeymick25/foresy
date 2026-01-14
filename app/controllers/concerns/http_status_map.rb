# app/controllers/concerns/http_status_map.rb
# Mapping HTTP centralisé et canonique - P1.4.2 Rules
# Une seule source de vérité pour tous les statuts HTTP

module HTTP_STATUS_MAP
  HTTP_STATUS_MAP = {
    ok: 200,
    created: 201,
    no_content: 204,

    validation_error: 422,    # Validation métier
    unauthorized: 403,        # Non autorisé (policy)
    forbidden: 403,           # Alias pour unauthorized (compatibilité)
    not_found: 404,          # Ressource absente
    conflict: 409,            # Pour les conflits (duplicate entries, etc.)
    bad_request: 400,         # Payload invalide (format / missing)
    internal_error: 500       # Erreurs internes non gérées
  }.freeze

  def self.[](key)
    HTTP_STATUS_MAP[key]
  end

  def self.ok
    200
  end

  def self.created
    201
  end

  def self.no_content
    204
  end

  def self.validation_error
    422
  end

  def self.unauthorized
    403
  end

  def self.forbidden
    403
  end

  def self.not_found
    404
  end

  def self.conflict
    409
  end

  def self.bad_request
    400
  end

  def self.internal_error
    500
  end
end
