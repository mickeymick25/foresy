# Mini-FC-02 : Export CRAs

**Type** : Enhancement FC-07  
**Priorité** : ⭐⭐⭐ Haute  
**Effort estimé** : CSV 2-3h, PDF 4-8h  
**Date création** : 6 janvier 2026  
**Date implémentation** : 7 janvier 2026  
**Status** : ✅ **TERMINÉ (CSV)**

---

## 1️⃣ Intention Métier

Permettre à un utilisateur d'exporter un CRA en format exploitable (CSV pour tableur, PDF pour impression/archivage) afin de faciliter le reporting, la facturation et la conformité légale.

---

## 2️⃣ Surface API (FIGÉE)

```
GET /api/v1/cras/:id/export
```

### Paramètres Autorisés

| Param | Type | Obligatoire | Défaut | Description |
|-------|------|-------------|--------|-------------|
| `export_format` | String | Non | `csv` | Format d'export (csv uniquement pour l'instant) |
| `include_entries` | Boolean | Non | `true` | Inclure le détail des entrées |

> ⚠️ **Note** : On utilise `export_format` au lieu de `format` pour éviter tout conflit avec le paramètre Rails réservé `params[:format]`.

### Paramètres Explicitement Refusés

| Param | Raison |
|-------|--------|
| `json` | Déjà disponible via GET /api/v1/cras/:id |
| `xlsx` | Complexité - dépendance lourde |
| `pdf` | Phase 2 - à implémenter si besoin confirmé |
| `template_id` | Hors scope MVP |

---

## 3️⃣ Règles Métier

| Règle | Comportement |
|-------|--------------|
| CRA inexistant | ❌ Erreur 404 |
| CRA non accessible | ❌ Erreur 403 |
| CRA soft-deleted | ❌ Erreur 404 |
| Format invalide | ❌ Erreur 422 - doit être csv |
| CRA sans entrées | ✅ Export avec headers + TOTAL (zéros) |
| CRA draft | ✅ Autorisé |
| CRA submitted | ✅ Autorisé |
| CRA locked | ✅ Autorisé |

---

## 4️⃣ Implémentation Réalisée

### Service : `Api::V1::Cras::ExportService`

**Fichier** : `app/services/api/v1/cras/export_service.rb`

**Caractéristiques** :
- ✅ Format CSV uniquement (extensible pour PDF)
- ✅ UTF-8 avec BOM pour compatibilité Excel
- ✅ Option `include_entries` (true/false)
- ✅ Validation du format avec erreur explicite
- ✅ Conversion des montants en euros (division par 100)
- ✅ Évite N+1 avec `includes(:cra_entry_missions, :missions)`

### Controller : `Api::V1::CrasController#export`

**Route** : `GET /api/v1/cras/:id/export`

**Caractéristiques** :
- ✅ Authentification JWT requise
- ✅ Validation d'accès au CRA (héritée FC-07)
- ✅ `send_data` avec `disposition: 'attachment'`
- ✅ Paramètre `export_format` (pas `format`)

### Dépendance Ruby 3.4+

**Gemfile** :
```ruby
# Ruby 3.4+ extracted csv from stdlib runtime
# Required for CRA export feature (Mini-FC-02)
gem 'csv', '~> 3.3'
```

> ⚠️ **Important** : À partir de Ruby 3.4, `csv` n'est plus chargée par défaut. L'ajout explicite au Gemfile est obligatoire.

---

## 5️⃣ Structure CSV

### Headers

```csv
date,mission_name,quantity,unit_price_eur,line_total_eur,description
```

### Exemple complet

```csv
date,mission_name,quantity,unit_price_eur,line_total_eur,description
2026-01-10,Mission Alpha,1.0,500.00,500.00,Development work
2026-01-11,Mission Alpha,0.5,500.00,250.00,Code review
TOTAL,,1.5,,750.00,
```

### Avec `include_entries=false`

```csv
date,mission_name,quantity,unit_price_eur,line_total_eur,description
TOTAL,,1.5,,750.00,
```

---

## 6️⃣ Réponses API

### Succès (200)

```
HTTP/1.1 200 OK
Content-Type: text/csv
Content-Disposition: attachment; filename="cra_2026_01.csv"

[UTF-8 BOM]date,mission_name,quantity,unit_price_eur,line_total_eur,description
2026-01-10,Mission Alpha,1.0,500.00,500.00,Development work
TOTAL,,1.5,,750.00,
```

### Erreur 422 (format invalide)

```json
{
  "error": "invalid_payload",
  "message": "format must be one of: csv",
  "timestamp": "2026-01-07T10:30:00Z"
}
```

### Erreur 401 (non authentifié)

```json
{
  "error": "unauthorized",
  "message": "Authentication required"
}
```

### Erreur 403 (accès refusé)

```json
{
  "error": "unauthorized",
  "message": "CRA not accessible",
  "timestamp": "2026-01-07T10:30:00Z"
}
```

### Erreur 404 (CRA inexistant)

```json
{
  "error": "not_found",
  "message": "CRA with ID xxx not found",
  "timestamp": "2026-01-07T10:30:00Z"
}
```

---

## 7️⃣ Tests Implémentés

### Tests Service (17 tests)

**Fichier** : `spec/services/api/v1/cras/export_service_spec.rb`

| Contexte | Tests |
|----------|-------|
| Format CSV valide | 7 tests (headers, content, totals, filename, amounts) |
| CRA sans entrées | 2 tests (headers + total only) |
| Format invalide | 3 tests (xml, pdf, nil) |
| Format uppercase | 1 test (CSV → csv) |
| Option include_entries | 4 tests (true/false behavior) |

### Tests Request (9 tests)

**Fichier** : `spec/requests/api/v1/cras/export_spec.rb`

| Contexte | Tests |
|----------|-------|
| Authentification valide | 5 tests (headers, content, default format, include_entries) |
| Format invalide | 1 test (422) |
| Non authentifié | 1 test (401) |
| CRA inexistant | 1 test (404) |
| Accès refusé | 1 test (403) |

---

## 8️⃣ Checklist Validation

### Phase 1 : CSV ✅ TERMINÉ
- [x] Mini-FC validé par CTO
- [x] Tests RED écrits (17 tests service)
- [x] Tests GREEN passent
- [x] Request specs ajoutées (9 tests)
- [x] RuboCop 0 offenses
- [x] Documentation mise à jour
- [x] Suite complète : 427 tests GREEN

### Phase 2 : PDF (optionnel - non implémenté)
- [ ] Besoin confirmé par produit
- [ ] Gem prawn ajoutée
- [ ] Tests RED écrits (PDF)
- [ ] Tests GREEN passent
- [ ] Commit atomique

---

## 9️⃣ Extension Future : PDF

Si le besoin PDF est confirmé :

**Gemfile** :
```ruby
gem 'prawn', '~> 2.4'
gem 'prawn-table', '~> 0.2'
```

**Service** : Étendre `SUPPORTED_FORMATS` et ajouter méthode `export_pdf`

**Tests** : Best effort (présence structure, pas pixel perfect)

---

## 📊 Métriques

| Métrique | Valeur |
|----------|--------|
| Tests service | 17 |
| Tests request | 9 |
| Total nouveaux tests | 26 |
| Suite complète | 427 GREEN |
| Temps implémentation | ~3h |
| Lignes de code service | ~95 |

---

*Mini-FC créé : 6 janvier 2026*  
*Implémenté : 7 janvier 2026*  
*Status : ✅ TERMINÉ (CSV)*