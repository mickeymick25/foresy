# Mini-FC-01 : Filtrage CRAs

**Type** : Enhancement FC-07  
**Priorité** : ⭐⭐⭐ Haute  
**Effort estimé** : 2-4 heures  
**Date** : 6 janvier 2026

---

## 1️⃣ Intention Métier

Permettre à un utilisateur de retrouver rapidement ses CRAs par période (année/mois) ou par statut, sans parcourir tout l'historique.

---

## 2️⃣ Surface API (FIGÉE)

```
GET /api/v1/cras
```

### Paramètres Autorisés

| Param | Type | Obligatoire | Description |
|-------|------|-------------|-------------|
| `year` | Integer | Non | Filtrer par année (ex: 2026) |
| `month` | Integer (1-12) | Non | Filtrer par mois |
| `status` | String | Non | Filtrer par status (draft/submitted/locked) |
| `page` | Integer | Non | Pagination (défaut: 1) |
| `per_page` | Integer | Non | Items par page (défaut: 25, max: 100) |

### Paramètres Explicitement Refusés

| Param | Raison |
|-------|--------|
| `user_id` | Hors scope - réservé admin futur |
| `mission_id` | Complexité - phase ultérieure |
| `created_at` | Redondant avec year/month |

---

## 3️⃣ Règles Métier

| Règle | Comportement |
|-------|--------------|
| `year` seul | ✅ Autorisé - tous les CRAs de l'année |
| `month` seul | ❌ Erreur 422 - `year` requis si `month` présent |
| `month` + `year` | ✅ Autorisé - CRAs du mois spécifique |
| `status` invalide | ❌ Erreur 422 - doit être draft/submitted/locked |
| CRA soft-deleted | ❌ Jamais retourné (default scope) |
| Aucun filtre | ✅ Retourne tous les CRAs accessibles (paginés) |
| Combinaison filtres | ✅ AND logique (year=2026 AND status=locked) |

---

## 4️⃣ Niveau d'Abstraction des Tests

| Élément | Décision | Justification |
|---------|----------|---------------|
| Tests modèles | ❌ Non | Scopes déjà testés |
| Tests callbacks | ❌ Non | Pas de callbacks |
| Tests services | ✅ **Oui** | Source de vérité |
| Tests request | ⚠️ Optionnel | Si temps disponible |
| Tests E2E | ❌ Non | Hors scope |

---

## 5️⃣ Stratégie TDD

```
RED   → Tests sur ListService avec filtres (6-8 tests)
GREEN → Ajout paramètres dans ListService existant
BLUE  → Extraction scopes si nécessaire (optionnel)
```

**Contraintes** :
- Aucune modification des modèles
- Aucun callback ActiveRecord
- Réutiliser les scopes existants (`by_year`, `by_month`, `by_status`)

---

## 6️⃣ Tests à Écrire (RED)

```ruby
# spec/services/api/v1/cras/list_service_filtering_spec.rb

describe 'filtering' do
  context 'by year' do
    it 'returns only CRAs from specified year'
  end

  context 'by month without year' do
    it 'raises InvalidPayloadError'
  end

  context 'by year and month' do
    it 'returns CRAs from specified month'
  end

  context 'by status' do
    it 'returns only CRAs with specified status'
  end

  context 'with invalid status' do
    it 'raises InvalidPayloadError'
  end

  context 'combined filters' do
    it 'applies AND logic to all filters'
  end
end
```

---

## 7️⃣ Réponse API

### Succès (200)

```json
{
  "data": [
    {
      "id": "uuid",
      "month": 2,
      "year": 2026,
      "status": "draft",
      "total_days": 15.5,
      "total_amount": 775000,
      "currency": "EUR"
    }
  ],
  "meta": {
    "current_page": 1,
    "total_pages": 3,
    "total_count": 52
  }
}
```

### Erreur 422 (month sans year)

```json
{
  "error": "invalid_payload",
  "message": "year is required when month is specified"
}
```

---

## ✅ Checklist Validation

- [ ] Mini-FC validé par CTO
- [ ] Tests RED écrits
- [ ] Tests GREEN passent
- [ ] RuboCop 0 offenses
- [ ] Documentation Swagger mise à jour
- [ ] Commit atomique

---

*Mini-FC créé : 6 janvier 2026*  
*Status : 📋 PRÊT POUR IMPLÉMENTATION*