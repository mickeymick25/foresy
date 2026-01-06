# ✅ TECH-DEBT — Usage de Dry::Monads sans dépendance déclarée

**Date de création**: 2025-01-15  
**Date de résolution**: 2025-01-15  
**Priorité**: 🟢 Résolue  
**Statut**: ✅ RÉSOLU  
**Résolution**: Suppression de Dry::Monads, migration vers exceptions métier FC07

---

## 📋 Description Initiale

Le service `Api::V1::CraEntries::CreateService` utilisait `Dry::Monads` mais la gem `dry-monads` n'était **pas déclarée** dans le Gemfile.

### Erreur Originale

```
NameError: uninitialized constant Api::V1::CraEntries::CreateService::Dry (NameError)

        include Dry::Monads[:result]
                ^^^
/app/app/services/api/v1/cra_entries/create_service.rb:8
```

---

## 🔍 Analyse CTO

### Décision : NE PAS introduire dry-monads

**Raisons** :
1. **Paradigme isolé** — dry-monads introduit un style fonctionnel non partagé ailleurs dans le projet
2. **Non aligné avec FC07** — Le contrat FC07 impose des exceptions métier explicites (409, 422, 500)
3. **Friction avec ActiveRecord** — Les transactions DB et side-effects sont mal servis par les monads
4. **Dette cognitive** — Double logique d'erreur (`if result.success?` partout)
5. **Adoption partielle** — Le pire des mondes : ni standard Rails, ni standard Dry

### Alternative choisie : Exceptions métier FC07-compliant

```ruby
# ❌ AVANT (dry-monads)
include Dry::Monads[:result]

def call
  return Failure(error_type: :cra_locked) if cra.locked?
  Success(cra: cra)
end

# ✅ APRÈS (exceptions métier)
def call
  raise CraErrors::CraLockedError if cra.locked?
  Result.new(cra: cra)
end
```

---

## ✅ Résolution Appliquée

### 1. Création du module d'exceptions métier

**Fichier** : `app/errors/cra_errors.rb`

```ruby
module CraErrors
  class BaseError < StandardError
    attr_reader :code, :http_status
  end

  # 409 Conflict
  class CraLockedError < BaseError; end
  class CraSubmittedError < BaseError; end
  class DuplicateEntryError < BaseError; end

  # 422 Unprocessable Entity
  class InvalidTransitionError < BaseError; end
  class InvalidPayloadError < BaseError; end

  # 404 Not Found
  class CraNotFoundError < BaseError; end
  class EntryNotFoundError < BaseError; end
  class MissionNotFoundError < BaseError; end

  # 403 Forbidden
  class UnauthorizedError < BaseError; end
  class NoIndependentCompanyError < BaseError; end

  # 500 Internal Server Error
  class InternalError < BaseError; end
end
```

### 2. Refactoring des services

| Service | Statut |
|---------|--------|
| `CraEntries::CreateService` | ✅ Refactoré |
| `CraEntries::UpdateService` | ✅ Refactoré |
| `CraEntries::DestroyService` | ✅ Refactoré |
| `CraEntries::ListService` | ✅ Refactoré |
| `Cras::CreateService` | ✅ Refactoré |
| `Cras::UpdateService` | ✅ Refactoré |
| `Cras::DestroyService` | ✅ Refactoré |
| `Cras::ListService` | ✅ Refactoré |
| `Cras::LifecycleService` | ✅ Refactoré |

### 3. Pattern appliqué

```ruby
# frozen_string_literal: true

module Api
  module V1
    module CraEntries
      class CreateService
        Result = Struct.new(:entry, keyword_init: true)

        def self.call(cra:, entry_params:, mission_id:, current_user:)
          new(cra: cra, entry_params: entry_params, mission_id: mission_id, current_user: current_user).call
        end

        def initialize(cra:, entry_params:, mission_id:, current_user:)
          @cra = cra
          @entry_params = entry_params
          @mission_id = mission_id
          @current_user = current_user
        end

        def call
          validate_inputs!
          check_permissions!
          entry = build_entry!
          save_entry!(entry)

          Result.new(entry: entry)
        end

        private

        def validate_inputs!
          raise CraErrors::InvalidPayloadError.new('CRA is required', field: :cra) unless @cra.present?
          # ...
        end

        def check_permissions!
          raise CraErrors::CraLockedError if @cra.locked?
          # ...
        end
      end
    end
  end
end
```

---

## 📊 Résultats

### Vérification Zeitwerk

```bash
$ docker compose exec -T web bin/rails zeitwerk:check
Hold on, I am eager loading the application.
All is good!
```

### Métriques

| Métrique | Avant | Après |
|----------|-------|-------|
| Gem dry-monads | Utilisée sans déclaration | ❌ Supprimée |
| Services avec Dry::Monads | 9 | 0 |
| Pattern d'erreur | Monads + exceptions | Exceptions uniquement |
| Alignement FC07 | ❌ Partiel | ✅ Complet |

---

## 📝 Documentation

### Usage des exceptions dans les controllers

```ruby
# app/controllers/api/v1/cras_controller.rb

rescue_from CraErrors::CraLockedError do |e|
  render json: { error: e.code, message: e.message }, status: :conflict
end

rescue_from CraErrors::InvalidPayloadError do |e|
  render json: { error: e.code, message: e.message, field: e.field }, status: :unprocessable_entity
end

rescue_from CraErrors::UnauthorizedError do |e|
  render json: { error: e.code, message: e.message }, status: :forbidden
end
```

### Mapping HTTP FC07

| Exception | HTTP Status | Code FC07 |
|-----------|-------------|-----------|
| `CraLockedError` | 409 Conflict | `cra_locked` |
| `CraSubmittedError` | 409 Conflict | `cra_submitted` |
| `DuplicateEntryError` | 409 Conflict | `duplicate_entry` |
| `InvalidTransitionError` | 422 Unprocessable | `invalid_transition` |
| `InvalidPayloadError` | 422 Unprocessable | `invalid_payload` |
| `CraNotFoundError` | 404 Not Found | `not_found` |
| `UnauthorizedError` | 403 Forbidden | `unauthorized` |
| `InternalError` | 500 Internal | `internal_error` |

---

## 🔗 Références

- **Rapport d'analyse** : `docs/technical/analysis/concerns_analysis_report.md`
- **Phase 1 Concerns** : ✅ Terminée et validée
- **Décision CTO** : Exceptions métier > Dry::Monads

---

**Résolu par** : Co-Directeur Technique  
**Validé par** : CTO  
**Date de clôture** : 2025-01-15