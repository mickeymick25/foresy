# Guide Méthodologique d'Implémentation

**Document** : Guide réutilisable pour l'implémentation de nouvelles features  
**Méthodologie** : TDD/DDD Stricte  
**Dernière mise à jour** : 6 janvier 2026  
**Basé sur** : FC-06 Missions, FC-07 CRA (TDD Platinum)

---

## 🎯 Vue d'Ensemble

Ce guide définit la méthodologie standard pour implémenter de nouvelles features dans Foresy.
Il est basé sur les leçons apprises lors de FC-06 et FC-07.

### Principes Fondamentaux

1. **TDD Authentique** : Tests d'abord, code ensuite
2. **DDD Strict** : Domaine d'abord, technique ensuite
3. **Services > Callbacks** : Logique métier dans les services
4. **Relation-Driven** : Pas de FK directes entre entités métier

---

## 📋 Checklist Pré-Implémentation

Avant de commencer :

- [ ] Feature Contract rédigé et validé
- [ ] Scope fonctionnel clairement défini
- [ ] Invariants métier identifiés
- [ ] Erreurs métier listées avec codes HTTP
- [ ] Endpoints API définis
- [ ] Modèles de données esquissés

---

## 🔄 Cycle TDD : RED → GREEN → REFACTOR

### Phase RED : Écrire le Test qui Échoue

```ruby
# spec/services/api/v1/feature/my_service_spec.rb

RSpec.describe Api::V1::Feature::MyService do
  describe '.call' do
    context 'when valid params' do
      it 'performs the expected action' do
        result = described_class.call(params: valid_params)
        
        expect(result).to be_success
        expect(result.data).to have_attributes(expected_attributes)
      end
    end

    context 'when invalid params' do
      it 'raises appropriate error' do
        expect {
          described_class.call(params: invalid_params)
        }.to raise_error(FeatureErrors::InvalidPayloadError)
      end
    end
  end
end
```

**Règles RED** :
- Test doit échouer pour la bonne raison
- Test doit être minimal mais complet
- Test doit documenter le comportement attendu

### Phase GREEN : Code Minimal pour Passer

```ruby
# app/services/api/v1/feature/my_service.rb

module Api
  module V1
    module Feature
      class MyService
        def self.call(params:)
          new(params: params).call
        end

        def initialize(params:)
          @params = params
        end

        def call
          validate_params!
          perform_action
          build_result
        end

        private

        attr_reader :params

        def validate_params!
          raise FeatureErrors::InvalidPayloadError unless params_valid?
        end

        def perform_action
          # Minimum code to pass the test
        end

        def build_result
          OpenStruct.new(success: true, data: @result)
        end
      end
    end
  end
end
```

**Règles GREEN** :
- Écrire le minimum de code pour faire passer le test
- Ne pas anticiper les besoins futurs
- Ne pas optimiser prématurément

### Phase REFACTOR : Améliorer Sans Casser

```ruby
# Après refactoring - même comportement, meilleur code

module Api
  module V1
    module Feature
      class MyService
        include ServiceBase  # Extraction de patterns communs
        
        def call
          validate!
          execute
          success(data: @result)
        end

        private

        def validate!
          validate_presence!(:required_field)
          validate_format!(:email_field, EMAIL_REGEX)
        end

        def execute
          ActiveRecord::Base.transaction do
            create_record
            trigger_side_effects
          end
        end
      end
    end
  end
end
```

**Règles REFACTOR** :
- Les tests doivent rester verts
- Extraire les duplications
- Améliorer la lisibilité
- Ne pas ajouter de fonctionnalité

---

## 🏗️ Structure d'Implémentation par Couche

### 1. Couche Domaine (Models)

```
app/models/
├── feature.rb              # Entité pure (pas de FK métier)
├── feature_relation.rb     # Table de relation si nécessaire
└── concerns/
    └── feature_validatable.rb
```

**Règles Domaine** :
- Modèles purs sans logique métier complexe
- Validations de format uniquement
- Pas de callbacks avec effets de bord
- Relations via tables dédiées

**Template Model** :
```ruby
# app/models/feature.rb
class Feature < ApplicationRecord
  # Soft delete
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }

  # Validations de format
  validates :name, presence: true, length: { minimum: 2, maximum: 255 }
  validates :status, presence: true, inclusion: { in: VALID_STATUSES }

  # Associations via relations
  has_many :feature_relations, dependent: :destroy
  has_many :related_entities, through: :feature_relations

  # Méthodes de lecture
  def active?
    deleted_at.nil?
  end

  def discarded?
    deleted_at.present?
  end
end
```

### 2. Couche Exceptions

```
lib/
└── feature_errors.rb       # Exceptions métier typées
```

**Template Exceptions** :
```ruby
# lib/feature_errors.rb
module FeatureErrors
  class BaseError < StandardError
    attr_reader :code, :http_status

    def initialize(message = nil, code: nil, http_status: :unprocessable_entity)
      @code = code
      @http_status = http_status
      super(message || default_message)
    end
  end

  class NotFoundError < BaseError
    def initialize(message = nil)
      super(message || 'Resource not found', code: :not_found, http_status: :not_found)
    end
  end

  class InvalidPayloadError < BaseError
    def initialize(message = nil)
      super(message || 'Invalid payload', code: :invalid_payload, http_status: :unprocessable_entity)
    end
  end

  class UnauthorizedError < BaseError
    def initialize(message = nil)
      super(message || 'Unauthorized', code: :unauthorized, http_status: :forbidden)
    end
  end
end
```

### 3. Couche Services

```
app/services/api/v1/feature/
├── create_service.rb
├── update_service.rb
├── destroy_service.rb
├── list_service.rb
└── show_service.rb
```

**Template Service CRUD** :
```ruby
# app/services/api/v1/feature/create_service.rb
module Api
  module V1
    module Feature
      class CreateService
        def self.call(params:, current_user:)
          new(params: params, current_user: current_user).call
        end

        def initialize(params:, current_user:)
          @params = params
          @current_user = current_user
        end

        def call
          validate_inputs!
          check_permissions!
          validate_business_rules!
          
          ActiveRecord::Base.transaction do
            create_record!
            create_relations!
            trigger_side_effects!
          end

          build_success_result
        rescue FeatureErrors::BaseError
          raise
        rescue StandardError => e
          handle_unexpected_error(e)
        end

        private

        attr_reader :params, :current_user, :record

        def validate_inputs!
          raise FeatureErrors::InvalidPayloadError, 'Name is required' if params[:name].blank?
        end

        def check_permissions!
          raise FeatureErrors::UnauthorizedError unless user_authorized?
        end

        def validate_business_rules!
          # Règles métier spécifiques
        end

        def create_record!
          @record = ::Feature.create!(permitted_params)
        end

        def create_relations!
          # Créer les relations nécessaires
        end

        def trigger_side_effects!
          # Recalculs, notifications, etc.
        end

        def build_success_result
          OpenStruct.new(success: true, record: record)
        end

        def handle_unexpected_error(error)
          Rails.logger.error "[CreateService] Unexpected error: #{error.message}"
          raise FeatureErrors::InternalError
        end

        def permitted_params
          params.slice(:name, :description, :status)
        end

        def user_authorized?
          # Logique d'autorisation
          true
        end
      end
    end
  end
end
```

### 4. Couche Controller

```
app/controllers/api/v1/
└── features_controller.rb
```

**Template Controller** :
```ruby
# app/controllers/api/v1/features_controller.rb
module Api
  module V1
    class FeaturesController < ApplicationController
      before_action :authenticate_user!

      def index
        result = Feature::ListService.call(
          params: filter_params,
          current_user: current_user
        )
        render json: result.data, status: :ok
      end

      def show
        result = Feature::ShowService.call(
          id: params[:id],
          current_user: current_user
        )
        render json: result.record, status: :ok
      end

      def create
        result = Feature::CreateService.call(
          params: feature_params,
          current_user: current_user
        )
        render json: result.record, status: :created
      end

      def update
        result = Feature::UpdateService.call(
          id: params[:id],
          params: feature_params,
          current_user: current_user
        )
        render json: result.record, status: :ok
      end

      def destroy
        Feature::DestroyService.call(
          id: params[:id],
          current_user: current_user
        )
        head :no_content
      end

      private

      def feature_params
        params.require(:feature).permit(:name, :description, :status)
      end

      def filter_params
        params.permit(:page, :per_page, :status, :search)
      end
    end
  end
end
```

### 5. Couche Tests

```
spec/
├── services/api/v1/feature/
│   ├── create_service_spec.rb
│   ├── update_service_spec.rb
│   ├── destroy_service_spec.rb
│   └── list_service_spec.rb
├── models/
│   └── feature_spec.rb
└── factories/
    └── feature.rb
```

**Template Test Service** :
```ruby
# spec/services/api/v1/feature/create_service_spec.rb
require 'rails_helper'

RSpec.describe Api::V1::Feature::CreateService do
  let(:user) { create(:user) }
  let(:valid_params) { { name: 'Test Feature', description: 'Description' } }

  describe '.call' do
    context 'with valid params' do
      it 'creates a feature' do
        result = described_class.call(params: valid_params, current_user: user)

        expect(result).to be_success
        expect(result.record).to be_persisted
        expect(result.record.name).to eq('Test Feature')
      end
    end

    context 'with missing name' do
      it 'raises InvalidPayloadError' do
        expect {
          described_class.call(params: { description: 'Test' }, current_user: user)
        }.to raise_error(FeatureErrors::InvalidPayloadError)
      end
    end

    context 'without authorization' do
      it 'raises UnauthorizedError' do
        allow_any_instance_of(described_class).to receive(:user_authorized?).and_return(false)

        expect {
          described_class.call(params: valid_params, current_user: user)
        }.to raise_error(FeatureErrors::UnauthorizedError)
      end
    end
  end
end
```

---

## 📊 Ordre d'Implémentation Recommandé

### Pour un nouveau CRUD complet :

```
1. Exceptions (lib/feature_errors.rb)
   └── Définir toutes les erreurs métier

2. Factory (spec/factories/feature.rb)
   └── Permettre la création de données de test

3. Model (app/models/feature.rb)
   └── Structure minimale sans logique

4. Tests Services (spec/services/)
   └── TDD : écrire les tests d'abord

5. Services (app/services/)
   └── Implémenter pour faire passer les tests

6. Controller (app/controllers/)
   └── Déléguer aux services

7. Routes (config/routes.rb)
   └── Exposer les endpoints

8. Documentation
   └── Swagger, README, etc.
```

### Pour un nouvel endpoint sur feature existante :

```
1. Test Service (RED)
   └── Définir le comportement attendu

2. Service (GREEN)
   └── Minimum pour passer le test

3. Refactor
   └── Améliorer sans casser

4. Controller action
   └── Déléguer au service

5. Route
   └── Exposer l'endpoint

6. Documentation
   └── Mettre à jour Swagger
```

---

## ⚠️ Pièges Courants à Éviter

### 1. Logique dans les Callbacks

```ruby
# ❌ MAUVAIS
class Feature < ApplicationRecord
  after_save :recalculate_totals
  after_save :send_notification
end

# ✅ BON
class CreateService
  def call
    create_record!
    recalculate_totals!
    send_notification!
  end
end
```

### 2. FK Directes entre Entités Métier

```ruby
# ❌ MAUVAIS
class CraEntry < ApplicationRecord
  belongs_to :cra
  belongs_to :mission
end

# ✅ BON
class CraEntry < ApplicationRecord
  has_many :cra_entry_cras
  has_many :cras, through: :cra_entry_cras
end
```

### 3. RSpec Lazy Evaluation

```ruby
# ❌ MAUVAIS - entry pas encore créé
let(:entry) { create_entry }
before { cra.reload }

# ✅ BON - forcer l'évaluation
before do
  entry  # Force lazy evaluation
  cra.reload
end
```

### 4. Montants en Float

```ruby
# ❌ MAUVAIS
total_amount = 150.50  # Float imprécis

# ✅ BON
total_amount = 15050   # Integer en centimes
```

### 5. Tests qui Testent l'Implémentation

```ruby
# ❌ MAUVAIS - teste le callback
it 'calls after_save callback' do
  expect(record).to receive(:recalculate)
  record.save
end

# ✅ BON - teste le comportement
it 'recalculates totals after creation' do
  service.call
  expect(cra.reload.total_amount).to eq(expected_amount)
end
```

---

## 🧪 Commandes de Validation

```bash
# Tests unitaires
docker compose exec web bundle exec rspec spec/services/

# Tests modèles
docker compose exec web bundle exec rspec spec/models/

# Tous les tests
docker compose exec web bundle exec rspec

# Qualité code
docker compose exec web bundle exec rubocop

# Sécurité
docker compose exec web bundle exec brakeman

# Swagger
docker compose exec web bundle exec rake rswag:specs:swaggerize
```

---

## 📝 Checklist Post-Implémentation

- [ ] Tous les tests passent (RSpec)
- [ ] 0 offenses RuboCop
- [ ] 0 warnings Brakeman
- [ ] Swagger généré et à jour
- [ ] Documentation mise à jour
- [ ] Commits atomiques et bien nommés
- [ ] PR créée avec description complète
- [ ] Review demandée

---

## 🔗 Références

- [VISION.md](../../VISION.md) - Principes architecturaux
- [FC-07 Methodology](../fc07/methodology/fc07_methodology_tracker.md) - Exemple TDD Platinum
- [FC-07 Phase 3C Report](../fc07/phases/FC07-Phase3C-Completion-Report.md) - Services > Callbacks
- [Conformity Audit](../audits/2026-01-06-FC06-FC07-Conformity-Audit.md) - Critères de conformité

---

*Guide créé : 6 janvier 2026*  
*Basé sur : FC-06 Missions, FC-07 CRA*  
*Niveau : TDD PLATINUM*