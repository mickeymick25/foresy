# Spécifications des Tests - Projet Foresy

## 📋 Vue d'ensemble

Ce document décrit l'organisation des tests pour le projet Foresy, une API Rails 7.1.5 spécialisée dans l'authentification OAuth avec support Google et GitHub.

## 🏗️ Organisation des Tests

### Structure des Tests

```
spec/
├── acceptance/                    # Tests Feature Contract (Business Requirements)
│   └── oauth_feature_contract_spec.rb
├── integration/                   # Tests d'intégration (Workflows complets)
│   └── oauth/                     # Tests d'intégration OAuth
│       └── oauth_callback_spec.rb
├── requests/api/v1/               # Tests API REST (Endpoints HTTP)
│   └── authentication/            # Tests authentification API
│       ├── login_spec.rb
│       ├── logout_spec.rb
│       ├── refresh_spec.rb
│       └── sessions_spec.rb
├── unit/                          # Tests unitaires
│   ├── models/                    # Tests modèles (User, Session)
│   │   ├── user_spec.rb
│   │   └── session_spec.rb
│   └── services/                  # Tests services (Business Logic)
├── factories/                     # Factories pour tests (FactoryBot)
│   ├── users.rb
│   └── sessions.rb
└── support/                       # Helpers et configuration
    ├── auth_helpers.rb
    ├── omniauth.rb
    └── swagger_helper.rb
```

## 🔄 Évolution de l'Organisation

### Avant (Organisation Problématique)

L'ancienne organisation des tests présentait plusieurs problèmes :

- **Dispersion des tests OAuth** dans plusieurs répertoires
- **Nomenclature incohérente** (integration vs requests vs services)
- **Duplication massive** (6 fichiers de test OAuth pour la même fonctionnalité)
- **Manque de logique organisationnelle claire**

```
AVANT - Structure problématique :
├── spec/models/                   # Tests dispersés
├── spec/Services/                 # Nomenclature incohérente
├── spec/integration/api/v1/       # Profondeur excessive
├── spec/requests/api/v1/          # Tests dispersés
└── spec/requests/api/v1/oauth/    # Dispersion OAuth
```

### Après (Organisation Transparente)

La nouvelle organisation respecte les principes de **Test-Driven Development** et **Clean Architecture** :

- **Périmètres clairement définis** par type de test
- **Nomenclature transparente** et logique
- **Centralisation des tests OAuth** par catégorie
- **Architecture ascendante** : unitaire → intégration → acceptation

## 📖 Types de Tests

### 1. Tests d'Acceptation (`spec/acceptance/`)

**Objectif :** Valider les Feature Contracts et requirements business

**Caractéristiques :**
- Tests orientés business requirements
- Validation du comportement utilisateur final
- Tests complets de workflows end-to-end
- Couverture des cas nominaux et d'erreur selon les spécifications

**Exemple :**
```ruby
# spec/acceptance/oauth_feature_contract_spec.rb
# Test le Feature Contract OAuth complet :
# - Authentification Google/GitHub
# - Génération JWT
# - Gestion des erreurs selon les spécifications
```

### 2. Tests d'Intégration (`spec/integration/`)

**Objectif :** Valider les workflows complets et les interactions entre composants

**Caractéristiques :**
- Tests des workflows OAuth complets
- Intégration controller + services + modèles
- Simulation d'environnements réalistes
- Tests des flux de données entre composants

**Exemple :**
```ruby
# spec/integration/oauth/oauth_callback_spec.rb
# Test le workflow OAuth complet :
# - Requête HTTP → Controller → Services → Modèles → Réponse
```

### 3. Tests de Requêtes API (`spec/requests/api/`)

**Objectif :** Valider les endpoints HTTP de l'API REST

**Caractéristiques :**
- Tests des endpoints individuels
- Validation des réponses HTTP
- Tests des schémas Swagger/OpenAPI
- Tests des codes de statut et payloads

**Exemple :**
```ruby
# spec/requests/api/v1/authentication/login_spec.rb
# Test les endpoints d'authentification :
# - POST /api/v1/auth/login
# - POST /api/v1/auth/refresh
# - DELETE /api/v1/auth/logout
```

### 4. Tests Unitaires (`spec/unit/`)

**Objectif :** Valider les composants individuels en isolation

**4.1 Tests de Modèles (`spec/unit/models/`)**
- Validation des validations ActiveRecord
- Tests des associations et scopes
- Tests des méthodes d'instance et de classe

**4.2 Tests de Services (`spec/unit/services/`)**
- Validation de la logique métier
- Tests des services en isolation
- Validation des interactions avec les modèles

## 🎯 Tests OAuth - Organisation Spéciale

### Centralisation par Type

Les tests OAuth sont maintenant centralisés et organisés par type :

1. **Acceptance Tests** (`spec/acceptance/`)
   - `oauth_feature_contract_spec.rb` - Feature Contract complet

2. **Integration Tests** (`spec/integration/oauth/`)
   - `oauth_callback_spec.rb` - Workflow OAuth complet

3. **Unit Tests** (`spec/unit/services/`)
   - Tests des services OAuth individuels (OAuthValidationService, OAuthUserService, OAuthTokenService)

### Bénéfices de cette Organisation

- **Clarté** : Chaque type de test OAuth a sa place logique
- **Maintenance** : Facilite la localisation et la modification des tests
- **Compréhension** : Nouveaux développeurs comprennent rapidement l'architecture des tests
- **Évolutivité** : Structure extensible pour de nouveaux types de tests

## 🏗️ Principes d'Organisation

### 1. Test Pyramid

L'organisation respecte la pyramide de tests :

```
     Acceptance Tests (Few)
    /                   \
Integration Tests       Unit Tests (Many)
   /          \
API Tests    Service Tests
```

### 2. Clean Architecture

- **Séparation des préoccupations** : Chaque type de test dans son répertoire
- **Dépendances claires** : Du plus spécifique au plus général
- **Responsabilités distinctes** : Pas de chevauchement entre types de tests

### 3. Developer Experience

- **Navigation intuitive** : Les répertoires reflètent l'architecture applicative
- **Recherche facilitée** : Nomenclature claire et logique
- **Onboarding amélioré** : Structure prévisible pour les nouveaux développeurs

## 📋 Conventions et Bonnes Pratiques

### Nomenclature des Fichiers

- **Tests de modèles** : `#{model_name}_spec.rb`
- **Tests de services** : `#{service_name}_spec.rb` ou `#{service_name}_test.rb`
- **Tests d'API** : `#{endpoint_name}_spec.rb`
- **Tests Feature Contract** : `#{feature_name}_contract_spec.rb`
- **Tests d'intégration** : `#{workflow_name}_spec.rb`

### Structure des Tests

Chaque test suit la structure AAA (Arrange-Act-Assert) :

```ruby
RSpec.describe 'Feature/Component' do
  describe 'Behavior' do
    context 'when condition' do
      it 'expected behavior' do
        # Arrange
        setup = create(:user)
        
        # Act
        result = described_class.method(setup)
        
        # Assert
        expect(result).to eq(expected_value)
      end
    end
  end
end
```

### Factories

Utiliser FactoryBot pour créer des données de test :

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email { "user#{Faker::Number.number}@example.com" }
    provider { "google_oauth2" }
    uid { "uid_#{Faker::Number.number}" }
    name { "Test User" }
    active { true }
  end
end
```

## 🔧 Configuration

### Rails Helper

```ruby
# spec/rails_helper.rb
# Configuration globale pour tous les tests
# - Configuration de la base de données de test
# - Chargement de FactoryBot
# - Configuration d'OmniAuth pour les tests OAuth
```

### Support Files

```ruby
# spec/support/omniauth.rb
# Configuration OmniAuth pour les tests OAuth
OmniAuth.config.test_mode = true

# spec/support/auth_helpers.rb
# Helpers pour l'authentification dans les tests
```

## 🚀 Exécution des Tests

### Commandes Utiles

```bash
# Tous les tests
bundle exec rspec

# Tests par type
bundle exec rspec spec/acceptance/          # Feature Contracts
bundle exec rspec spec/integration/         # Intégration
bundle exec rspec spec/unit/models/         # Modèles
bundle exec rspec spec/unit/services/       # Services
bundle exec rspec spec/requests/api/        # API

# Tests spécifiques OAuth
bundle exec rspec spec/acceptance/oauth_feature_contract_spec.rb
bundle exec rspec spec/integration/oauth/oauth_callback_spec.rb

# Tests avec format détaillé
bundle exec rspec --format documentation
```

### Format de Sortie

```bash
# Format de documentation pour une meilleure lisibilité
bundle exec rspec --format documentation spec/acceptance/

# Avec timing pour identifier les tests lents
bundle exec rspec --format documentation --profile spec/
```

## 📊 Couverture de Tests

### Objectifs de Couverture

- **Modèles** : 100% (validations, associations, méthodes)
- **Services** : 95%+ (logique métier critique)
- **Controllers** : 90%+ (endpoints API critiques)
- **Feature Contracts** : 100% (requirements business)

### Métriques

Utiliser `simplecov` pour mesurer la couverture :

```ruby
# spec/spec_helper.rb
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
end
```

## 🔄 Maintenance

### Ajout de Nouveaux Tests

1. **Identifier le type de test** selon les critères ci-dessus
2. **Créer le fichier** dans le bon répertoire
3. **Suivre les conventions** de nomenclature et structure
4. **Utiliser les factories** appropriées
5. **Exécuter les tests** pour validation

### Migration de Tests Existants

Lors de l'ajout de nouvelles fonctionnalités :

1. **Analyser le type** de test nécessaire
2. **Placer dans le bon répertoire** selon l'organisation
3. **Vérifier les dépendances** avec les autres tests
4. **Mettre à jour cette documentation** si nécessaire

## 📚 Références

- [Testing Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)
- [Clean Architecture](https://8thlight.com/blog/uncle-bob/2012/08/13/the-clean-architecture.html)
- [RSpec Best Practices](https://rspec.info/upgrading-from-rspec-2/)
- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html)

---

**Dernière mise à jour :** 17 décembre 2025  
**Version :** 1.0  
**Responsable :** Équipe Technique Foresy