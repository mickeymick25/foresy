# Mini-FC-02 : Export CRAs

**Type** : Enhancement FC-07  
**Priorité** : ⭐⭐⭐ Haute  
**Effort estimé** : CSV 2-3h, PDF 4-8h  
**Date** : 6 janvier 2026

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
| `format` | String | Non | `csv` | Format d'export (csv/pdf) |
| `include_entries` | Boolean | Non | `true` | Inclure le détail des entrées |

### Paramètres Explicitement Refusés

| Param | Raison |
|-------|--------|
| `json` | Déjà disponible via GET /api/v1/cras/:id |
| `xlsx` | Complexité - dépendance lourde |
| `template_id` | Hors scope MVP |

---

## 3️⃣ Règles Métier

| Règle | Comportement |
|-------|--------------|
| CRA inexistant | ❌ Erreur 404 |
| CRA non accessible | ❌ Erreur 404 (pas 403) |
| CRA soft-deleted | ❌ Erreur 404 |
| Format invalide | ❌ Erreur 422 - doit être csv ou pdf |
| CRA sans entrées | ✅ Export vide (headers CSV, PDF avec mention "Aucune entrée") |
| CRA draft | ✅ Autorisé (mention "BROUILLON" sur PDF) |
| CRA locked | ✅ Autorisé (mention "VERROUILLÉ" sur PDF) |

---

## 4️⃣ Niveau d'Abstraction des Tests

| Élément | Décision | Justification |
|---------|----------|---------------|
| Tests modèles | ❌ Non | Pas de modification modèles |
| Tests callbacks | ❌ Non | Pas de callbacks |
| Tests services | ✅ **Oui** | Source de vérité |
| Tests request | ⚠️ Optionnel | Content-Type validation |
| Tests E2E | ❌ Non | Hors scope |

---

## 5️⃣ Stratégie TDD

```
RED   → Tests sur ExportService (CSV + PDF)
GREEN → Implémentation minimale
BLUE  → Extraction helpers si nécessaire
```

**Contraintes** :
- Aucune modification des modèles
- Aucun callback ActiveRecord
- CSV = canonique (tests sur structure et contenu)
- PDF = best effort (tests sur présence, pas pixel perfect)

---

## 6️⃣ Décisions Techniques (FIGÉES)

### CSV : Canonique

| Aspect | Décision |
|--------|----------|
| Encodage | UTF-8 avec BOM |
| Séparateur | Virgule (,) |
| Headers | Obligatoires en première ligne |
| Montants | En euros (division par 100) |
| Dates | Format ISO 8601 (YYYY-MM-DD) |

**Structure CSV** :
```csv
date,mission_name,quantity,unit_price_eur,line_total_eur,description
2026-01-15,Mission Alpha,1.0,500.00,500.00,Development work
2026-01-16,Mission Alpha,0.5,500.00,250.00,Code review
```

**Ligne de totaux** :
```csv
TOTAL,,15.5,,7750.00,
```

### PDF : Best Effort

| Aspect | Décision |
|--------|----------|
| Gem | `prawn` (léger, sans dépendance système) |
| Format | A4 portrait |
| Tests | Structure présente, pas contenu exact |

**Structure PDF** :
- En-tête : Période (Mois/Année), Status, Utilisateur
- Corps : Tableau des entrées groupées par mission
- Pied : Totaux (total_days, total_amount), Date génération

---

## 7️⃣ Tests à Écrire (RED)

```ruby
# spec/services/api/v1/cras/export_service_spec.rb

describe Api::V1::Cras::ExportService do
  describe 'CSV export' do
    context 'with valid CRA' do
      it 'returns CSV content with correct headers'
      it 'includes all entries'
      it 'calculates line totals correctly'
      it 'includes total row'
      it 'formats amounts in euros (not cents)'
    end

    context 'with empty CRA' do
      it 'returns CSV with headers only'
    end

    context 'with include_entries=false' do
      it 'returns summary only'
    end
  end

  describe 'PDF export' do
    context 'with valid CRA' do
      it 'returns PDF binary data'
      it 'has correct content type'
      it 'includes CRA period in content'
    end

    context 'with draft CRA' do
      it 'includes BROUILLON watermark'
    end
  end

  describe 'error handling' do
    context 'with invalid format' do
      it 'raises InvalidPayloadError'
    end

    context 'with non-existent CRA' do
      it 'raises CraNotFoundError'
    end
  end
end
```

---

## 8️⃣ Réponse API

### Succès CSV (200)

```
Content-Type: text/csv; charset=utf-8
Content-Disposition: attachment; filename="cra_2026_02.csv"

date,mission_name,quantity,unit_price_eur,line_total_eur,description
2026-02-15,Mission Alpha,1.0,500.00,500.00,Development
TOTAL,,15.5,,7750.00,
```

### Succès PDF (200)

```
Content-Type: application/pdf
Content-Disposition: attachment; filename="cra_2026_02.pdf"

[Binary PDF data]
```

### Erreur 422 (format invalide)

```json
{
  "error": "invalid_payload",
  "message": "format must be 'csv' or 'pdf'"
}
```

---

## 9️⃣ Dépendances

| Format | Gem | Status |
|--------|-----|--------|
| CSV | Ruby stdlib | ✅ Aucune installation |
| PDF | `prawn` | ⚠️ À ajouter au Gemfile |

**Ajout Gemfile** :
```ruby
gem 'prawn', '~> 2.4'
gem 'prawn-table', '~> 0.2'
```

---

## ✅ Checklist Validation

### Phase 1 : CSV (prioritaire)
- [ ] Mini-FC validé par CTO
- [ ] Tests RED écrits (CSV)
- [ ] Tests GREEN passent
- [ ] RuboCop 0 offenses
- [ ] Commit atomique

### Phase 2 : PDF (optionnel)
- [ ] Gem prawn ajoutée
- [ ] Tests RED écrits (PDF)
- [ ] Tests GREEN passent
- [ ] Commit atomique

---

## 🔄 Ordre d'Implémentation

```
1. CSV Export (2-3h)
   ├── ExportService avec format=csv
   ├── Tests canoniques sur structure
   └── Controller action + route

2. PDF Export (4-8h) - OPTIONNEL
   ├── Ajout gem prawn
   ├── ExportService avec format=pdf
   ├── Tests best effort
   └── Même controller action
```

**Recommandation** : Implémenter CSV d'abord, valider, puis PDF si besoin confirmé.

---

*Mini-FC créé : 6 janvier 2026*  
*Status : 📋 PRÊT POUR IMPLÉMENTATION*