# 🔧 Correction Technique — FC-07 Concerns Namespace Fix

**Date** : 3 janvier 2026
**Statut** : 🔴 EN COURS
**Impact** : CRITIQUE - Tests RSpec échouent
**Feature Contract** : FC-07 (CRA)
**Dernière mise à jour** : 3 janvier 2026 - 21h30

---

## 📋 Contexte

Lors de la refactorisation des concerns pour FC-07 (CRA Management), plusieurs problèmes de namespacing Zeitwerk ont été identifiés, causant des erreurs 500 Internal Server Error dans les tests RSpec.

### Progression de la session
- ✅ Namespacing Zeitwerk corrigé
- ✅ CraErrors autoload corrigé
- ✅ ResponseFormatter créé et aligné FC-06
- ✅ git_version retiré (décision CTO)
- 🔴 Tests échouent toujours (500 Internal Server Error)

---

## 🔍 Problèmes Identifiés

### 1. Namespacing des Concerns CRA

**Problème** : Les concerns étaient définis avec un namespace incorrect.

```ruby
# ❌ AVANT - Incorrect
# app/controllers/concerns/api/v1/cras/error_handler.rb
module Cras
  module ErrorHandler
    # ...
  end
end

# ✅ APRÈS - Correct
module Api
  module V1
    module Cras
      module ErrorHandler
        extend ActiveSupport::Concern
        # ...
      end
    end
  end
end
```

**Fichiers corrigés** :
- `app/controllers/concerns/api/v1/cras/error_handler.rb`
- `app/controllers/concerns/api/v1/cras/rate_limitable.rb`
- `app/controllers/concerns/api/v1/cras/parameter_extractor.rb`
- `app/controllers/concerns/api/v1/cras/access_validation.rb`
- `app/controllers/concerns/api/v1/cras/response_formatter.rb` (créé)

### 2. Namespacing des Concerns CRA Entries

**Même problème** pour les concerns CRA Entries.

**Fichiers corrigés** :
- `app/controllers/concerns/api/v1/cra_entries/error_handler.rb`
- `app/controllers/concerns/api/v1/cra_entries/rate_limitable.rb`
- `app/controllers/concerns/api/v1/cra_entries/parameter_extractor.rb`
- `app/controllers/concerns/api/v1/cra_entries/response_formatter.rb`

### 3. Autoload CraErrors

**Problème** : `CraErrors` dans `lib/errors/cra_errors.rb` n'était pas autoloadé par Zeitwerk.

```
# Zeitwerk mapping strict :
lib/errors/cra_errors.rb → Errors::CraErrors  ❌

# Mais le fichier définissait :
module CraErrors
end
```

**Solution appliquée** : Déplacer le fichier vers `lib/cra_errors.rb`

```bash
mv lib/errors/cra_errors.rb lib/cra_errors.rb
```

### 4. Méthode cra_params manquante

**Problème** : La méthode `cra_params` n'était pas définie dans le CrasController.

**Solution** : Ajout de la méthode strong parameters.

```ruby
def cra_params
  params.permit(:month, :year, :currency, :description, :status)
end
```

### 5. ErrorRenderable re-levait les exceptions en test

**Problème** : `render_conditional_server_error` re-levait les exceptions en environnement non-production.

```ruby
# ❌ AVANT
def render_conditional_server_error(exception = nil)
  raise exception unless Rails.env.production?
  render_internal_server_error(exception)
end

# ✅ APRÈS
def render_conditional_server_error(exception = nil)
  raise exception if Rails.env.development?  # Seulement en dev
  render_internal_server_error(exception)
end
```

---

## ✅ Corrections Appliquées

| Fichier | Action | Statut |
|---------|--------|--------|
| `lib/cra_errors.rb` | Déplacé depuis `lib/errors/` | ✅ |
| `app/controllers/concerns/api/v1/cras/*.rb` | Namespace corrigé | ✅ |
| `app/controllers/concerns/api/v1/cra_entries/*.rb` | Namespace corrigé | ✅ |
| `app/controllers/api/v1/cras_controller.rb` | Ajout `cra_params`, fix includes | ✅ |
| `app/controllers/concerns/error_renderable.rb` | Fix re-raise logic | ✅ |
| `app/controllers/concerns/api/v1/cras/response_formatter.rb` | Créé avec méthodes de classe | ✅ |

### 6. Chemins complets des services dans le contrôleur

**Problème** : Le contrôleur utilisait `Cras::CreateService` au lieu de `Api::V1::Cras::CreateService`.

```ruby
# ❌ AVANT - Ne résout pas correctement
result = Cras::CreateService.call(...)
render json: Cras::ResponseFormatter.single(result.cra)

# ✅ APRÈS - Chemin complet
result = Api::V1::Cras::CreateService.call(...)
render json: Api::V1::Cras::ResponseFormatter.single(result.cra)
```

### 7. git_version retiré du ResponseFormatter

**Décision CTO** : Ne pas stocker `git_version` dans la table `cras`.

- Le FC-07 ne prévoit pas cette colonne
- Git Ledger est la source de vérité pour le versioning
- Stocker un SHA Git en DB = anti-pattern DDD

**Correction** : Suppression de `cra.git_version` du ResponseFormatter.

### 8. Format de réponse aligné FC-06

**Décision CTO** : Adapter le ResponseFormatter, pas les tests.

| Action | Format |
|--------|--------|
| create / show / update | objet JSON direct |
| index | `{ data: [...], meta: {...} }` |

```ruby
# ✅ ResponseFormatter.single retourne l'objet directement
def single(cra, include_entries: false)
  data = format_cra(cra)
  data  # Pas de wrapper { data: ... }
end
```

---

## 🔴 Problèmes Restants

### Tests RSpec Échouent Toujours

Après toutes les corrections, les tests retournent encore 500 :

```
DEBUG Response status: 500
DEBUG Response body: {"error":"Internal server error"}
```

**État actuel** :
- Zeitwerk : ✅ All is good!
- Services en isolation : ✅ Fonctionnent
- ResponseFormatter : ✅ Fonctionne
- Contrôleur via HTTP : 🔴 500 Internal Server Error

**Cause probable** :
Une exception est levée dans le flow et capturée par `ErrorRenderable.render_conditional_server_error`.

**Debug en cours** :
Modification de `ErrorRenderable` pour inclure les détails de l'exception dans la réponse JSON en environnement test.

### Actions Requises pour la prochaine session

1. **Identifier l'exception exacte** - Lancer le test avec le nouveau ErrorRenderable qui expose l'exception
2. **Corriger la cause racine** - Probablement dans l'authentification ou les before_actions
3. **Valider tous les tests CRA** - 71 tests à faire passer
4. **Valider tests CRA Entries** - 77 tests
5. **Revalider Rubocop/Brakeman**

---

## 📊 Validation Zeitwerk

```bash
$ bin/rails zeitwerk:check
Hold on, I am eager loading the application.
All is good!
```

✅ Zeitwerk charge correctement tous les fichiers.

---

## 🧪 Tests à Corriger

```bash
# IMPORTANT: Toujours passer DATABASE_URL pour la base de test
export TEST_DB_URL="postgres://postgres:password@db:5432/foresy_test"

# Reset la base de test (obligatoire si données corrompues)
docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=$TEST_DB_URL \
  -e DISABLE_DATABASE_ENVIRONMENT_CHECK=1 \
  web bundle exec rails db:drop db:create db:schema:load

# Lancer les tests CRA
docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=$TEST_DB_URL \
  web bundle exec rspec spec/requests/api/v1/cras_spec.rb

# Lancer un test spécifique avec debug
docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=$TEST_DB_URL \
  web bundle exec rspec spec/requests/api/v1/cras_spec.rb:29 --format documentation
```

### Debug ajouté (temporaire)

Le fichier `app/controllers/concerns/error_renderable.rb` a été modifié pour exposer les détails d'exception en environnement test :

```ruby
# En test, la réponse 500 inclut maintenant :
{
  "error": "Internal server error",
  "exception_class": "SomeError",
  "exception_message": "Details...",
  "backtrace": ["line1", "line2", ...]
}
```

---

## 📝 Checklist de Validation FC-07

- [x] Zeitwerk charge tous les fichiers
- [x] Namespacing concerns correct (`Api::V1::Cras::*`)
- [x] `CraErrors` autoloadé (`lib/cra_errors.rb`)
- [x] `cra_params` défini dans controller
- [x] Chemins complets services/formatters dans controller
- [x] `git_version` retiré (décision CTO - pas en DB)
- [x] ResponseFormatter aligné FC-06 (objet direct, pas de wrapper)
- [x] ErrorRenderable expose exceptions en test
- [ ] Identifier et corriger l'exception 500
- [ ] Tests RSpec CRA passent (71 tests)
- [ ] Tests RSpec CRA Entries passent (77 tests)
- [ ] Rubocop 0 offense
- [ ] Brakeman 0 warning
- [ ] Retirer debug ErrorRenderable
- [ ] Documentation finale

---

## 🎯 Prochaines Étapes (Prochaine Session)

### Immédiat
1. **Lancer le test avec debug** - Voir l'exception exacte dans la réponse JSON
2. **Corriger la cause racine** - Probablement dans before_actions ou authentification
3. **Valider le test POST create** - Premier test à faire passer

### Ensuite
4. **Faire passer tous les tests CRA** - 71 tests
5. **Faire passer tous les tests CRA Entries** - 77 tests
6. **Revalider Rubocop/Brakeman**
7. **Retirer le debug de ErrorRenderable**
8. **Mettre à jour la documentation** - Marquer FC-07 comme COMPLET

### Commande pour reprendre

```bash
# Lancer le test avec les détails d'exception
docker compose run --rm -e RAILS_ENV=test \
  -e DATABASE_URL=postgres://postgres:password@db:5432/foresy_test \
  web bundle exec rspec spec/requests/api/v1/cras_spec.rb:29 --format documentation
```

L'output devrait maintenant montrer :
```json
{
  "error": "Internal server error",
  "exception_class": "...",
  "exception_message": "...",
  "backtrace": [...]
}
```

---

## 📚 Références

- [FC-07 Feature Contract](../../FeatureContract/07_Feature%20Contract%20—%20CRA)
- [FC-07 Implementation Doc](../changes/2026-01-03-FC07_CRA_Implementation.md)
- [Zeitwerk Documentation](https://github.com/fxn/zeitwerk)
- [Rails Autoloading Guide](https://guides.rubyonrails.org/autoloading_and_reloading_constants.html)

---

## 📝 Décisions CTO Appliquées

### 1. git_version : NE PAS ajouter en DB
- FC-07 ne le prévoit pas
- Git Ledger = source de vérité
- SHA Git en DB = anti-pattern DDD

### 2. ResponseFormatter : Adapter au format tests
- Tests = contrat exécutable
- Cohérence avec FC-06
- Single resource → JSON direct
- Collection → `{ data: [...], meta: {...} }`

### 3. Namespacing : Chemins complets obligatoires
- Dans les controllers, utiliser `Api::V1::Cras::CreateService`
- Pas de raccourcis `Cras::CreateService`