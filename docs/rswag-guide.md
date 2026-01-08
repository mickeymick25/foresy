# Guide Standard RSwag - Équipe Foresy

**Version:** 2.0 - Règles Canoniques Figées  
**Date:** 7 janvier 2026  
**Auteur:** Équipe Lead Technique  
**Statut:** RÉFÉRENCE OFFICIELLE - Ces règles ne peuvent plus être violées

---

## 🧱 PRINCIPES FONDATEURS (À NE PLUS VIOLER)

### ❌ Ce qu'on ne fera PLUS JAMAIS

- ❌ **Générer des JWT à la main** (`JWT.encode`)
- ❌ **Utiliser `header` dans un `before`** (erreur: "header is not available from within an example")
- ❌ **Créer des helpers magiques pour RSwag**
- ❌ **Tester un comportement différent du backend réel**
- ❌ **Utiliser des traits factory complexes** (`:with_independent_company`, `:cra_with_entry_context`, etc.)

### ✅ Ce qu'on fera TOUJOURS

- ✅ **Utiliser `authenticate(user)`** - API d'auth réelle
- ✅ **Passer l'auth via `let(:Authorization)`** - RSwag DSL correct
- ✅ **Tester exactement ce que l'API retourne** - Pas d'idéologie
- ✅ **Une responsabilité = un test** - Clarté maximale
- ✅ **Créer l'utilisateur simplement** - `create(:user, email: "...", password: "...")`

---

## 🧩 STRUCTURE PROPRE DES TAGS CRA

### 🎯 Convention Canonique
```ruby
tags 'CRA'
```

### ❌ Interdits
- `CRA API`
- `Cra` 
- `CRA::Submit`
- `CRA Management`

### ✅ Un seul tag autorisé
```ruby
tags 'CRA'
```

---

## 🧪 SQUELETTE CANONIQUE D'UN ENDPOINT CRA

### Template Officiel (À Copier-Coller)
```ruby
# frozen_string_literal: true

require 'swagger_helper'

# Canonical RSwag spec for CRA endpoint
# Rules:
# - Authentication via authenticate(user)
# - Authorization passed with let(:Authorization) 
# - No JWT handcrafted
# - Tests reflect real backend behavior
# - One responsibility = one test

RSpec.describe 'CRA', swagger_doc: 'v1/swagger.yaml', type: :request do
  # Test data setup - using authenticate(user) as per canonical methodology
  let(:user) do
    create(
      :user,
      email: "cra_#{SecureRandom.hex(4)}@example.com",
      password: 'password123'
    )
  end

  # Canonical auth pattern: let(:Authorization) + authenticate(user)
  let(:Authorization) { "Bearer #{authenticate(user)}" }

  # Data setup minimal - clear and explicit (not over-architected)
  let(:draft_cra_id) do
    mission = create(:mission, created_by_user_id: user.id)
    cra = create(:cra, user: user, status: 'draft')

    entry = create(:cra_entry, :standard_entry)
    create(:cra_entry_mission, cra_entry: entry, mission: mission)
    create(:cra_entry_cra, cra_entry: entry, cra: cra)

    cra.id
  end

  path '/api/v1/cras/{id}/submit' do
    post 'Submit a CRA' do
      tags 'CRA'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string,
                description: 'Bearer token', required: true
      parameter name: :id, in: :path, schema: {
        type: :string,
        format: :uuid,
        example: '550e8400-e29b-41d4-a716-446655440000'
      }, required: true, description: 'CRA ID'

      response '200', 'CRA submitted successfully' do
        let(:id) { draft_cra_id }

        run_test! do |response|
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          expect(data).to include('id', 'year', 'month', 'status', 'currency')
          expect(data['status']).to eq('submitted')
          expect(data).to include('total_days', 'total_amount')
        end
      end

      response '401', 'Unauthorized - Missing token' do
        let(:Authorization) { nil }  # Explicitly no auth
        let(:id) { draft_cra_id }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
          data = JSON.parse(response.body)
          expect(data).to include('error')
        end
      end

      response '422', 'CRA without entries' do
        let(:id) { create(:cra, user: user, status: 'draft').id }

        run_test! do |response|
          expect(response).to have_http_status(:unprocessable_entity)
          body = JSON.parse(response.body)
          expect(body['error']).to eq('invalid_payload')
          expect(body).to include('message')
        end
      end
    end
  end
end
```

---

## 🧠 DATA SETUP MINIMAL (PAS DE CONTEXTE MONSTRUEUX)

### ⚠️ C'est ici que vous aviez sur-architecturé avant.

#### ❌ À éviter (Interdits)
- `cra_with_entry_context`
- factories "platinum-level"
- logique métier cachée dans les factories
- traits complexes comme `:with_independent_company`

#### ✅ À faire (Canoniques)

**Pattern simple et lisible :**
```ruby
let(:draft_cra_id) do
  mission = create(:mission, created_by_user_id: user.id)
  cra = create(:cra, user: user, status: 'draft')

  entry = create(:cra_entry, :standard_entry)
  create(:cra_entry_mission, cra_entry: entry, mission: mission)
  create(:cra_entry_cra, cra_entry: entry, cra: cra)

  cra.id
end
```

**Créer juste ce qu'il faut, explicitement :**
- Lisible > DRY
- Explique le métier par le code
- Aucune dépendance implicite

---

## 🚨 RÉPONSES = COMPORTEMENT RÉEL

On ne débat plus des messages d'erreur.

### Exemple Correct (Canon)
```ruby
response '422', 'CRA without entries' do
  let(:id) { create(:cra, user: user, status: 'draft').id }

  run_test! do |response|
    body = JSON.parse(response.body)
    expect(body['error']).to eq('invalid_payload')
  end
end
```

### Principe Fondamental
> **Le test documente l'API, pas ce qu'on aimerait qu'elle fasse.**

### Validation
- Si le backend retourne `'invalid_payload'`, le test doit attendre `'invalid_payload'`
- Pas de débats théoriques
- Pas de tentatives de "normalisation" artificielle

---

## 🔐 AUTHENTIFICATION RSwag (RÈGLES D'OR)

### Règles Canoniques (À GRAVER)

#### Authentication Rules (RSwag)
- **Valid auth** → `let(:Authorization) { "Bearer #{authenticate(user)}" }`
- **Missing auth** → `let(:Authorization) { '' }`
- **Invalid auth** → `let(:Authorization) { "Bearer #{invalid_jwt_token}" }`

#### ⚠️ PIÈGE RSwag CONNU
**Pourquoi `nil` ne fonctionne pas ?**
- RSwag compile les paramètres une fois
- Si `parameter name: :Authorization, in: :header` existe ET `let(:Authorization)` défini dans le scope
- → RSwag l'envoie quand même, même s'il vaut `nil`
- Résultat : Header présent → Authentifié → Requête réussie

#### ❌ Solutions Interdites
- **`let(:Authorization) { nil }`** → Ignoré par RSwag, header toujours présent
- **`before { headers.delete(...) }`** → Hors DSL RSwag, Swagger incohérent
- **Supprimer `let(:Authorization)`** → Non fiable, fragile selon l'ordre

#### ✅ Solution Canonique (Une Seule Est Correcte)
```ruby
response '401', 'Unauthorized - Missing token' do
  let(:Authorization) { '' }  # Token vide = header envoyé mais invalide
  let(:id) { draft_cra_id }

  run_test! do |response|
    expect(response).to have_http_status(:unauthorized)
  end
end
```

**Pourquoi ça marche ?**
- Le header est bien envoyé (parameter présent)
- Mais invalide (token vide)
- Le backend passe par le bon chemin d'erreur
- Swagger documente correctement le scénario

#### 🧱 Règle d'Or Finale
> **En RSwag, l'absence d'auth se teste avec un header vide, jamais avec nil.**

---

## 🔁 STRATÉGIE DE RECONSTRUCTION

### Recommandation d'Ordre
1. ✅ **POST /cras/{id}/submit** (endpoint prioritaire)
2. ✅ **GET /cras**
3. ✅ **GET /cras/{id}**
4. ✅ **POST /cras**
5. ✅ **PATCH /cras/{id}**

### Méthode
- **Un endpoint à la fois**
- **Il passe → Commit immédiatement**
- **Swagger se génère automatiquement**
- **On passe au suivant**

---

## 🧪 CHECK FINAL À CHAQUE ENDPOINT

Avant de passer au suivant :

```bash
# Tests doivent passer
bundle exec rspec spec/requests/api/v1/cras/swagger/

# Swagger doit se générer
bundle exec rake rswag:specs:swaggerize

# Si Swagger casse → on corrige immédiatement
```

### Critères de Validation
- ✅ **Tests RSpec passent**
- ✅ **Swagger se génère sans erreur**
- ✅ **Documentation cohérente**
- ✅ **Aucun warning**

---

## 📜 RÈGLES RSwag – CRA (OFFICIELLES)

### Interdictions Absolues
- ❌ **Pas de `header` dans `before`** (erreur RSpec)
- ❌ **Pas de `JWT.encode`** (génération manuelle)
- ❌ **Pas de factory "context"** (sur-architecture)
- ❌ **Pas de traits complexes** (`:with_independent_company`, etc.)

### Obligations Canoniques
- ✅ **`authenticate(user)` obligatoire** (API réelle)
- ✅ **`let(:Authorization)` obligatoire** (RSwag DSL)
- ✅ **Tests alignés backend, pas idéologiques** (réalité > théorie)
- ✅ **1 endpoint = 1 fichier** (responsabilité claire)

### Structure Fichiers
```
spec/requests/api/v1/cras/swagger/
├── swagger_submit_spec.rb     # POST /cras/{id}/submit
├── swagger_index_spec.rb      # GET /cras
├── swagger_show_spec.rb       # GET /cras/{id}
├── swagger_create_spec.rb     # POST /cras
└── swagger_update_spec.rb     # PATCH /cras/{id}
```

---

## 🏁 CONCLUSION (IMPORTANTE)

### Ce reset est une chance parce que :
- Vous avez compris où RSwag ment
- Vous savez comment JWT doit être testé
- Vous avez identifié les faux patterns
- Vous savez maintenant écrire des tests qui documentent réellement l'API

### La version 2.0 sera :
- **Plus courte** (minimalisme)
- **Plus lisible** (explicite)
- **Plus robuste** (pas de magie)
- **Plus pédagogique** (structure canonique)

### Impact pour l'Équipe
- **Pattern reproductible** : Tout le monde peut faire la même chose
- **Moins d'erreurs** : Règles figées empêchent les regressions
- **Documentation vivante** : Le guide évolue avec l'expérience
- **Qualité constante** : Même méthodologie partout

---

## 🔧 CONFIGURATION RAILS HELPER

### spec/rails_helper.rb
```ruby
# Inclure les helpers pour les tests request
config.include SwaggerAuthHelper, type: :request
```

### spec/support/swagger_auth_helper.rb
```ruby
module SwaggerAuthHelper
  # Utilise l'API d'auth réelle (RECOMMANDÉ)
  def authenticate(user)
    post '/api/v1/auth/login',
         params: { email: user.email, password: user.password }.to_json,
         headers: { 'Content-Type' => 'application/json' }

    JSON.parse(response.body)['token']
  end

  # Génération manuelle JWT (NON recommandée - seulement pour tests d'erreur)
  def invalid_jwt_token
    "invalid.token.here"
  end
end
```

---

**🚨 RAPPEL FINAL : Ces règles sont figées et ne peuvent plus être violées sous peine de régression.**

---

*Guide créé le 7 janvier 2026 - Version 2.0 avec règles canoniques figées*  
*Pour questions/références : consulter ce document et les specs existantes*