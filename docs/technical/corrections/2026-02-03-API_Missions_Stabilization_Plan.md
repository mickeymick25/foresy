# 🚀 Plan de Stabilisation - API Missions (Février 2026)

## 📋 Contexte
Suite aux tests RSpec échoués, ce document détaille le plan d'action pour stabiliser l'API Missions et les handlers d'erreurs JWT/OAuth.

---

## 1️⃣ Stabiliser l'API Missions (Domain & Controller)

### a) Transitions de Statut

**Problème :**
Certains tests `PATCH /api/v1/missions/:id` échouent pour les transitions invalides (won → lead, completed → in_progress, etc.).

**Cause probable :**
- La méthode `Mission#transition_to!` ne lève pas d'exception mais renvoie `false`
- Le controller attend peut-être une exception pour renvoyer 422

**Solution appliquée :**
```ruby
# app/controllers/api/v1/missions_controller.rb
# CORRECTION : Suppression du return anticipé après transition_to!

new_status = mission_params[:status]

# 1. Status transition si nécessaire (sans return anticipé)
if new_status.present? && @mission.status != new_status
  @mission.transition_to!(new_status)
end

# 2. Autres updates (name, description, etc.)
updates = mission_params.except(:status).to_h  # .to_h requis pour ActionController::Parameters
if updates.any? { |k, v| v.present? }
  if @mission.update(updates)
    render json: mission_response(@mission, include_companies: true)
    return
  else
    render json: { error: 'Invalid Payload', message: @mission.errors.full_messages }, status: :unprocessable_entity
    return
  end
end

# 3. Réponse par défaut
render json: mission_response(@mission, include_companies: true)
```

**Note :** L'exception `InvalidTransitionError` existait déjà dans le modèle. Le problème était dans le controller : le `return` anticipé après `transition_to!` empêchait la mise à jour des autres champs (name, description).

**Résultat :** Tests PATCH "Mission updated successfully" (200) et "Invalid status transition" (422) passent ✅


---

### b) Validations Financières

**Problème :**
Tests `POST /api/v1/missions` échouent pour `time_based` sans `daily_rate` ou `fixed_price` sans `fixed_price`.

**Cause probable :**
- Les validations dans le modèle sont correctes (`validate_financial_fields`)
- Le controller peut ignorer les erreurs ou renvoyer le mauvais status code

**Solution :**
1. Vérifier que le controller renvoie bien 422 en cas d'échec de `mission.save!`
2. Vérifier que les messages d'erreur sont cohérents avec les validations
3. Corriger si nécessaire :

```ruby
# Example de correction dans le controller
def create
  mission = Mission.new(mission_params)
  mission.created_by_user_id = current_user.id

  if mission.save
    render json: mission, status: :created
  else
    render json: { errors: mission.errors.full_messages }, status: :unprocessable_entity
  end
end
```

---

### c) Access / Authorization

**Problème :**
Tests qui échouent avec 403 ou 404 pour les vérifications de permissions.

**Solution :**
Vérifier et corriger les méthodes suivantes :

| Méthode | Usage | Endpoint |
|---------|-------|----------|
| `Mission#modifiable_by?(user)` | PATCH, DELETE | `/missions/:id` |
| `Mission.accessible_to(user)` | GET, PATCH | `/missions` |

**Exemple de correction :**
```ruby
def update
  set_mission
  return render_forbidden unless @mission.modifiable_by?(current_user)

  if @mission.update(mission_params)
    render json: @mission, status: :ok
  else
    render json: { errors: @mission.errors.full_messages }, status: :unprocessable_entity
  end
end
```

---

## 2️⃣ JWT / OAuth / Error Handling

### a) JWT Errors

**Problème :**
Tests JWT Rescue From Behavior échouent → probablement le handler global (`rescue_from`) ne se comporte pas comme attendu.

**Solution :**
Vérifier dans `ApplicationController` et `ErrorRenderable` :

```ruby
# S'assurer que les exceptions JWT sont bien capturées
rescue_from JWT::DecodeError, JWT::ExpiredSignature, with: :render_jwt_error

private

def render_jwt_error(exception)
  render json: {
    error: 'Authentication Error',
    message: exception.message
  }, status: :unprocessable_entity
end
```

**Actions :**
- [ ] Vérifier que les exceptions JWT héritent de la bonne classe
- [ ] S'assurer que les tests utilisent le bon environnement
- [ ] Ajuster les mocks si nécessaire

---

### b) OAuth Logging / Monitoring

**Problème :**
Tests OAuth Feature Contract échouent.

**Solution :**
1. Vérifier le logging des erreurs OAuth
2. S'assurer qu'aucun token sensible n'est loggé
3. L'environnement de test doit simuler les erreurs correctement

**Exemple de correction :**
```ruby
def callback
  # Ne jamais logger le full_callback_response qui peut contenir des tokens
  Rails.logger.info "[OAuth] Provider: #{provider}, UID: #{uid}"

  begin
    # Logique OAuth
  rescue OAuthError => e
    Rails.logger.error "[OAuth] Error: #{e.message}"
    render json: { error: 'OAuth Error' }, status: :unprocessable_entity
  end
end
```

---

## 3️⃣ Processus de Correction (Ordre Prioritaire)

### Phase 1 : Corrections Fondamentales

| Ordre | Action | Impact |
|-------|--------|--------|
| 1 | Supprimer return anticipé après `transition_to!` | ✅ Corrige tests PATCH |
| 2 | Ajouter `.to_h` pour ActionController::Parameters | ✅ Corrige error `any?` |
| 3 | Contrôler permissions (`modifiable_by?`, `accessible_to`) | ✅ Déjà fonctionnel |

**Résultat Phase 1 :** Tests PATCH et lifecycle passent ✅

### Phase 2 : Error Handling et Tests

| Ordre | Action | Impact |
|-------|--------|--------|
| 4 | Supprimer token dummy dans swagger_helper | ✅ Corrige auth |
| 5 | Refactor tests : données dans `before` locaux | ✅ Corrige collisions |
| 6 | Paramètre rswag `:'Authorization'` avec guillemets | ✅ Corrige header |

**Résultat Phase 2 :** 0 collisions, tests stables ✅

---

## 📊 Résultats Finaux

| Métrique | Avant | Après |
|----------|-------|-------|
| Tests Missions | ~10 échecs | **0 échecs** |
| Random seed | Instable | **Stable (14/14)** |
| accessible_missions | count = 0 | **count = 1** |
| PATCH name update | nil | **valeur correcte** |


---

## 🔗 Fichiers Concernés

```
app/models/mission.rb
app/controllers/application_controller.rb
app/controllers/api/v1/missions_controller.rb
app/lib/error_renderable.rb
spec/requests/api/v1/missions/missions_spec.rb
spec/integration/jwt_error_handling_spec.rb
```

---

## ✅ Checklist de Validation

### Mission Transitions
- [x] `InvalidTransitionError` définie dans Mission
- [x] `transition_to!` lève l'exception (existante)
- [x] `rescue_from` dans ApplicationController
- [x] Test `won → lead` retourne 422
- [x] Test `completed → in_progress` retourne 422
- [x] Return anticipé supprimé du controller
- [x] `.to_h` ajouté pour ActionController::Parameters

### Financial Validations
- [x] `time_based` sans `daily_rate` → 422
- [x] `fixed_price` sans `fixed_price` → 422
- [x] Messages d'erreur clairs

### Authorization
- [x] `modifiable_by?` fonctionne pour PATCH/DELETE
- [x] `accessible_to` fonctionne pour GET/Index
- [x] 403 pour accès non autorisé
- [x] 404 pour ressource non trouvée

### JWT / OAuth
- [x] Token généré par `AuthenticationService.login`
- [x] Session active validée
- [x] Pas de token dummy
- [x] Paramètre `:'Authorization'` correct avec guillemets
- [x] Tests passent en environnement test (14/14)

## 4️⃣ Résolution Appliquée (Février 2026)

### Problèmes Identifiés et Solutions

| Problème | Symptôme | Cause Racine | Solution |
|----------|----------|--------------|-----------|
| Return anticipé controller | PATCH name = nil | `return` après `transition_to!` | Supprimer le return |
| Token dummy global | 401 avec token valide | `let(:auth_token) { 'Bearer dummy_token' }` | Supprimer shared_context |
| Collisions emails | "Email already taken" avec 1 test | `let!` globaux + rswag | Données dans `before` locaux |
| Paramètre rswag | `undefined method 'Authorization'` | Format incorrect | `parameter name: :'Authorization'` |

### Fichiers Modifiés

```
app/controllers/api/v1/missions_controller.rb  # Fix return anticipé + .to_h
spec/swagger_helper.rb                       # Suppression token dummy
spec/requests/api/v1/missions_spec.rb        # Refactor pattern Platinium
```

### Leçon Apprise

> **Règle Platinium :** Dans un spec rswag, `before` → données, `let` → paramètres. Jamais l'inverse.

---

## 🆕 Mise à jour (29 Janvier 2026) — Évolution de la Solution

### Contexte
Lors de la mise en œuvre du plan, une meilleure approche a été adoptée pour le pattern d'erreur : **validation-style** plutôt que **exception-based**.

### Évolution architecturale

| Aspect | Solution initiale | Solution finale | Raison |
|--------|-------------------|-----------------|--------|
| Erreur transition | `InvalidTransitionError` levée | `transition_to` retourne `false` | Alignement avec VISION.md Platinum Level |
| Gestion erreur | `rescue_from` global | Gestion locale dans controller | Cohérence pattern validation |
| API | `transition_to!` lève exception | `transition_to` validation-style | Clarté intent |

### Modifications apportées

#### 1. `app/models/mission.rb`
- ✅ Suppression de `InvalidTransitionError` (plus besoin)
- ✅ `transition_to` : retourne `false` + ajoute erreur si invalide
- ✅ `transition_to!` : alias de `transition_to` (compatibilité)

#### 2. `app/controllers/api/v1/missions_controller.rb`
- ✅ Utilise `transition_to` avec gestion de retour `false`
- ✅ Retourne 422 avec `@mission.errors[:status]`
- ✅ `rescue_from` supprimé (géré localement)

#### 3. `app/controllers/application_controller.rb`
- ✅ `rescue_from Mission::InvalidTransitionError` supprimé

#### 4. `spec/requests/api/v1/missions/missions_spec.rb`
- ✅ Tests mis à jour pour validation-style
- ✅ Vérification `result == false` au lieu de exception
- ✅ Warnings Rack corrigés (`:unprocessable_entity` → `:unprocessable_content`)

### Résultats finaux

| Métrique | Statut |
|----------|--------|
| **RSpec** | ✅ **489 examples, 0 failures** |
| **Rswag** | ✅ **128 examples, 0 failures** |
| **RuboCop** | ✅ **0 offenses** |
| **Brakeman** | ✅ **0 warnings** |

### Leçon apprise

> **Pattern Validation-Style > Exception-based** : Pour les transitions de statut métier, retourner `false` avec erreurs sur le modèle est plus cohérent avec Rails et facilite la validation composite.

---

**Dernière mise à jour :** 29 Janvier 2026  
**Statut final :** ✅ 489 examples, 0 failures  
**Note :** Évolution vers validation-style (pattern PLATINUM) implémentée

*Document généré pour le projet Foresy API - Mis à jour après résolution complète*
