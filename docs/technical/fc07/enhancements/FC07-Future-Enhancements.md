# FC-07 Future Enhancements

**Feature Contract** : FC-07 - CRA (Compte Rendu d'Activité) Management  
**Status** : 📋 BACKLOG - Améliorations Optionnelles  
**Source** : CTO Review PR #13 (6 janvier 2026)  
**Priorité** : Basse (Nice to have)

---

## 🎯 Contexte

Ces améliorations ont été identifiées lors de la review CTO de la PR #13 (FC-07).
Elles ne sont **pas requises** par le Feature Contract mais seraient utiles pour un produit de reporting complet.

> "These are not required by FC-07 but commonly useful in reporting products."
> — CTO Review

---

## 📋 Mini Feature Contracts (Implémentation)

Chaque enhancement dispose d'un **Mini-FC** détaillant les règles d'implémentation :

| Enhancement | Mini-FC | Status | Priorité |
|-------------|---------|--------|----------|
| Filtrage CRAs | [MINI-FC-01](./MINI-FC-01-CRA-Filtering.md) | 📋 Prêt | ⭐⭐⭐ |
| Export CSV/PDF | [MINI-FC-02](./MINI-FC-02-CRA-Export.md) | 📋 Prêt | ⭐⭐⭐ |

> ⚠️ **Règle CTO** : Ne pas implémenter sans Mini-FC validé.
> Chaque Mini-FC définit : surface API figée, règles métier, niveau de tests, stratégie TDD.

---

## 📋 Améliorations Proposées

### 1. Filtrage / Querying CRAs

**Endpoint proposé** : `GET /api/v1/cras?year=2026&month=2&user_id=xxx`

**Description** :
Permettre aux utilisateurs de filtrer les CRAs par critères multiples.

**Paramètres de query** :
| Paramètre | Type | Description |
|-----------|------|-------------|
| `year` | Integer | Filtrer par année |
| `month` | Integer (1-12) | Filtrer par mois |
| `user_id` | UUID | Filtrer par utilisateur (admin only) |
| `status` | Enum | Filtrer par status (draft/submitted/locked) |
| `mission_id` | UUID | Filtrer par mission liée |

**Exemples** :
```
GET /api/v1/cras?year=2026
GET /api/v1/cras?year=2026&month=2
GET /api/v1/cras?status=locked
GET /api/v1/cras?mission_id=uuid
```

**Implémentation suggérée** :
- Utiliser les scopes existants (`by_year`, `by_month`, `by_status`)
- Ajouter la logique de filtrage dans `ListService`
- Combiner avec la pagination existante (Pagy)

**Effort estimé** : 2-4 heures

---

### 2. Export / Download Summary Endpoints

**Endpoint proposé** : `GET /api/v1/cras/:id/export`

**Description** :
Permettre l'export d'un CRA en différents formats pour reporting et archivage.

**Formats supportés** :
| Format | Content-Type | Description |
|--------|--------------|-------------|
| CSV | `text/csv` | Export tableur simple |
| PDF | `application/pdf` | Document formaté pour impression |
| JSON | `application/json` | Export données brutes |

**Paramètres** :
| Paramètre | Type | Défaut | Description |
|-----------|------|--------|-------------|
| `format` | String | `json` | Format d'export (csv/pdf/json) |
| `include_entries` | Boolean | `true` | Inclure les entrées détaillées |

**Exemples** :
```
GET /api/v1/cras/uuid/export
GET /api/v1/cras/uuid/export?format=csv
GET /api/v1/cras/uuid/export?format=pdf
GET /api/v1/cras/uuid/export?format=json&include_entries=false
```

**Structure CSV suggérée** :
```csv
date,mission_name,quantity,unit_price,line_total,description
2026-01-15,Mission Alpha,1.0,50000,50000,Development work
2026-01-16,Mission Alpha,0.5,50000,25000,Code review
```

**Structure PDF suggérée** :
- En-tête avec période (mois/année) et utilisateur
- Tableau des entrées groupées par mission
- Totaux par mission
- Total général (total_days, total_amount)
- Pied de page avec date de génération et status

**Dépendances potentielles** :
- CSV : Natif Ruby (pas de gem)
- PDF : `prawn` ou `wicked_pdf` gem

**Effort estimé** : 
- CSV : 2-3 heures
- PDF : 4-8 heures (design + implémentation)

---

## 🏗️ Architecture Suggérée

### Service d'Export

```ruby
# app/services/api/v1/cras/export_service.rb
module Api
  module V1
    module Cras
      class ExportService
        def initialize(cra:, format:, options: {})
          @cra = cra
          @format = format
          @options = options
        end

        def call
          case @format
          when 'csv' then export_csv
          when 'pdf' then export_pdf
          when 'json' then export_json
          else raise CraErrors::InvalidPayloadError, "Unknown format: #{@format}"
          end
        end

        private

        def export_csv
          # Génération CSV
        end

        def export_pdf
          # Génération PDF via Prawn
        end

        def export_json
          # Sérialisation JSON enrichie
        end
      end
    end
  end
end
```

### Controller Action

```ruby
# Dans CrasController
def export
  cra = find_cra
  format = params[:format] || 'json'
  
  result = Api::V1::Cras::ExportService.new(
    cra: cra,
    format: format,
    options: export_options
  ).call
  
  send_data result[:data],
            filename: result[:filename],
            type: result[:content_type]
end
```

---

## 📊 Priorisation

| Enhancement | Valeur Business | Effort | Priorité |
|-------------|-----------------|--------|----------|
| Filtrage par année/mois | Haute | Faible | ⭐⭐⭐ |
| Filtrage par status | Moyenne | Faible | ⭐⭐ |
| Export CSV | Haute | Faible | ⭐⭐⭐ |
| Export PDF | Moyenne | Moyen | ⭐⭐ |
| Filtrage par mission | Basse | Faible | ⭐ |

**Recommandation** : Commencer par filtrage année/mois + export CSV (quick wins).

---

## 🔗 Références

- [PR #13 - FC-07 CRA Management](https://github.com/mickeymick25/foresy/pull/13)
- [FC-07 README](./README.md)
- [Feature Contract 07](../../FeatureContract/07_Feature%20Contract%20—%20CRA)
- [ListService existant](../../../app/services/api/v1/cras/list_service.rb)

---

## 📝 Notes d'Implémentation

### Quand implémenter ?

Ces features peuvent être implémentées :
1. **Maintenant** : Si le besoin utilisateur est immédiat
2. **FC-08+** : En parallèle d'autres features
3. **Post-MVP** : Après validation du core product

### Contraintes à respecter

- Maintenir l'architecture service-oriented
- Respecter les règles d'accès FC-06/FC-07
- Tests TDD pour chaque nouvelle feature
- Documentation Swagger/OpenAPI

### Protocole d'Exécution (CTO)

```
1. Mini-FC validé (15-30 min)
2. RED : Tests services uniquement
3. GREEN : Implémentation minimale
4. BLUE : Refactor optionnel
5. Commit atomique
```

**Interdictions** :
- ❌ Coder sans Mini-FC validé
- ❌ Tests sur callbacks ou modèles
- ❌ Mélanger controller + service + modèle
- ❌ Improviser les règles métier

---

## 🔗 Références

- [Guide Méthodologique](../../guides/implementation_methodology.md)
- [FC-07 Methodology](../methodology/fc07_methodology_tracker.md)
- [Mini-FC-01 Filtrage](./MINI-FC-01-CRA-Filtering.md)
- [Mini-FC-02 Export](./MINI-FC-02-CRA-Export.md)

---

*Document créé : 6 janvier 2026*  
*Mise à jour : 6 janvier 2026 - Ajout Mini-FCs*  
*Source : CTO Review PR #13*  
*Status : 📋 BACKLOG avec Mini-FCs prêts*