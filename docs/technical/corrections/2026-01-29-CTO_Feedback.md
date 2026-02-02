
# 🚀 Plan d'Action - Feedback CTO (Janvier 2026)

## 📋 Contexte
Feedback reçu après revue technique. Ces corrections sont **bloquantes pour le merge** en production.

---

## 1️⃣ CRITIQUE ABSOLU — `:unprocessable_content` (Bloquant Merge)

### Diagnostic
- Rails ne reconnaît pas le symbole `:unprocessable_content`
- `render status: :unprocessable_content` → `ArgumentError` à l'exécution
- `HttpStatusMap` ne résout rien tant que Rails reçoit un symbole inconnu

### Décision Recommandée (Safe)
Revenir partout à `:unprocessable_entity` (422) — standard, lisible, zéro risque.

### Alternative (si mapping custom souhaité)
À faire **de manière centralisée** :

```ruby
render json: ..., status: HttpStatusMap.http_status(:unprocessable_content)
```

⚠️ **MAIS** : à appliquer partout, à documenter, à tester → sinon dette technique immédiate.

### Action Concrète

```bash
# Search & replace global
# :unprocessable_content → :unprocessable_entity

# Supprimer le symbole custom
# HttpStatusMap peut rester mais non utilisé pour l'instant
```

### Priorité
**🔴 BLOQUANT** — À faire en premier, avant tout le reste.

---

### 🔧 Bonus : Correction Configuration Rswag (Découverte durante le debugging)

#### Diagnostic
- Lors du run des specs, erreur `uninitialized constant Rswag (NameError)` dans `routes.rb:5`
- Causes : Rswag pas chargé dans l'environnement test
- Conséquence : Pas de routes définies → 404 sur TOUS les endpoints

#### Corrections appliquées
1. `spec/swagger_helper.rb` : Ajout de `require 'rswag/specs'`
2. `config/routes.rb` : Utilisation de `if defined?(Rswag)` pour éviter le crash

#### Vérification
```bash
bin/rails routes | grep export
# → export_api_v1_cra GET /api/v1/cras/:id/export ✓
```

#### Résultat
- 9 examples, 0 failures dans `spec/requests/api/v1/cras/export_spec.rb`

---

## 2️⃣ CRITIQUE — Conflit Result / ApplicationResult (Zeitwerk Trap)

### Diagnostic

| Fichier | Constante | Signature |
|---------|-----------|-----------|
| `app/lib/application_result.rb` | `ApplicationResult`, `Result` (alias) | A |
| `app/lib/result.rb` | `Result` | B |

- Zeitwerk = chargement **non déterministe**
- Risque de comportement différent selon environnement

### Décision Claire
**UN seul concept, UN seul contrat.**

### Option Recommandée

✅ `ApplicationResult` comme classe de base unique  
❌ Supprimer `app/lib/result.rb`  
❌ Supprimer le `alias Result` si inutile

```ruby
# app/lib/application_result.rb
class ApplicationResult
  attr_reader :value, :error

  def success?
    error.nil?
  end
end
```

### Action

```bash
# Supprimer le fichier redondant
rm app/lib/result.rb

# Nettoyer tous les Result.new, Result.success, etc.
# Remplacer par ApplicationResult.new, ApplicationResult.success, etc.

# Vérifier qu'aucun require manuel ne masque le problème
```

### Priorité
**🔴 BLOQUANT**

---

## 3️⃣ CRITIQUE — `vendor/bundle` et caches dans le repo

### Diagnostic
Présence de `vendor/bundle` dans le repo :
- Augmente la taille du repo
- Problèmes de sécurité
- CI lente
- Reviews difficiles

### Action Immédiate

```bash
# Supprimer le répertoire
git rm -r vendor/bundle
```

### Mise à jour `.gitignore`

```gitignore
/vendor/bundle
/.bundle
```

> 💡 Si besoin de gems figées → `Gemfile.lock` suffit.

### Priorité
**🔴 BLOQUANT**

---

## 4️⃣ IMPORTANT — Zeitwerk & `app/lib`

### Diagnostic
- Beaucoup de nouveaux namespaces créés
- `autoload` custom commenté dans `application.rb`
- Risque élevé de `NameError` en production

### Règles à Vérifier
Chemin ↔ constante strictement alignés.

#### ❌ Mauvais :

```ruby
# app/lib/domain/cra_entry/cra_entry.rb
module Domain::CraEntry
  class CraEntry
    # ERREUR: Le fichier ne correspond pas au namespace
  end
end
```

#### ✅ Bon (Option 1) :

```ruby
# app/lib/domain/cra_entry.rb
module Domain
  class CraEntry
  end
end
```

#### ✅ Bon (Option 2) :

```ruby
# app/lib/domain/cra_entry/cra_entry.rb
module Domain
  module CraEntry
    class CraEntry
    end
  end
end
```

### Action

```bash
# Vérification locale
bin/rails zeitwerk:check

# Corriger tous les chemins/constantes non alignés
# AVANT merge → crash prod assuré sinon
```

### Priorité
**🟠 IMPORTANT** — Corriger avant merge.

---

## 5️⃣ IMPORTANT — HttpStatusMap Non Utilisé Réellement

### Diagnostic
- Bonne intention initiale
- Mauvaise exécution pour l'instant

### Recommandation
Tant que vous ne faites pas :

```ruby
status: HttpStatusMap.http_status(...)
```

➡️ **Ne pas introduire de nouveaux symboles** dans `HttpStatusMap`.

### Option A : Standard Rails Only

```ruby
render status: :unprocessable_entity  # 422
```

### Option B : Usage Obligatoire via Helper

```ruby
def render_error(status:, **options)
  render json: ..., status: HttpStatusMap.http_status(status)
end
```

### Action
- Choisir **UNE** approche
- L'appliquer de manière consistante
- Documenter l'approche choisie

### Priorité
**🟠 IMPORTANT**

---

## 6️⃣ TESTS / FACTORIES — Risques Silencieux

### Points de Vigilance

`after(:create)` qui crée des associations :
- Tests moins lisibles
- Cycles possibles
- Lenteur CI

### Exemple de Risque

```ruby
# factory :cra avec after(:create) implicite
factory :cra do
  after(:create) { create(:mission) }  # ⚠️ Difficile à tracer
end
```

### Recommandation

```ruby
# Utiliser des traits explicites
factory :cra_entry do
  trait :with_mission do
    after(:create) { |entry| create(:mission, cra_entry: entry) }
  end
end

# Dans les tests :
create(:cra_entry, :with_mission)  # ✅ Clair, traçable
```

### Action

- [ ] Documenter le comportement de chaque factory avec `after(:create)`
- [ ] Migrer vers des traits explicites progressivement
- [ ] Revue de code pour identifier les cycles

### Priorité
**🟡 À TRAITER** — Technique, non bloquant.

---

## 7️⃣ Brakeman / Sécurité

### Diagnostic

- Fichier `.brakeman.ignore` modifié
- `action_text-trix` ajouté (approuvé)

### Action

```bash
# Repasser Brakeman sans le fichier .ignore
bundle exec brakeman

# Vérifier que l'alerte supprimée était bien :
# - Un faux positif, OU
# - Réellement corrigée
```

### Priorité
**🟡 À VÉRIFIER**

---

## 8️⃣ Cohérence de Namespaces (Non Bloquant)

### Diagnostic

Incohérence dans les namespaces de services :

```ruby
Services::CraEntries::Create   # ❌ Incohérent
CraServices::Create            # ❌ Incohérent
```

### Recommandation

Choisir **UNE** convention Rails :

**Option A :**

```ruby
CraEntries::Create
CraServices::Create
```

**Option B :**

```ruby
Services::CraEntries::Create
Services::CraServices::Create
```

Mais **pas les deux**.

### Action

- [ ] Définir une convention de nommage
- [ ] Appliquer uniformément
- [ ] (Optionnel) PR séparée pour refacto complète

### Priorité
**⚪ NON BLOQUANT** — À corriger progressivement.

---

## 🧭 Plan de Merge Recommandé (Ordre Exact)

| Ordre | Action | Priorité |
|-------|--------|----------|
| 1 | Fix `:unprocessable_content` → `:unprocessable_entity` | ✅ Terminé |
| 2 | Supprimer `vendor/bundle` | 🔴 Bloquant |
| 3 | Dédupliquer `Result` / `ApplicationResult` | 🔴 Bloquant |
| 4 | Passer `rails zeitwerk:check` | 🟠 Important |
| 5 | CI full (tests + Brakeman) | ✅ Validation |
| 6 | Merge | ✅ Terminé |

### Optionnel — PR Séparée

Après le merge, créer une PR dédiée pour :
- HttpStatusMap avancé
- Refacto namespaces
- Documentation lourde

---

## 📝 Checklist de Validation

### Avant Merge

- [x] `:unprocessable_content` remplacé par `:unprocessable_entity`
- [x] Configuration Rswag corrigée (`require 'rswag/specs'` + `defined?(Rswag)` dans routes.rb)
- [ ] `vendor/bundle` supprimé du repo
- [ ] `app/lib/result.rb` supprimé
- [ ] `ApplicationResult` utilisé uniformément
- [ ] `rails zeitwerk:check` passe sans erreur
- [ ] CI complète : Tests ✓, RuboCop ✓, Brakeman ✓

### Après Merge

- [ ] Review de la convention de nommage des namespaces
- [ ] Migration progressive des factories vers les traits explicites
- [ ] Documentation de l'approche HttpStatusMap

---

## 📞 Contact

Pour toute question sur ce feedback, contacter le CTO directement.

---

**Document généré :** Janvier 2026  
**Statut :** En attente de traitement  
**Prochaine revue :** Après corrections complètes
