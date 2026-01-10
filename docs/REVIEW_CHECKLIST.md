# 📋 FORESY - PR REVIEW CHECKLIST

## 🎯 OBJECTIF
Cette checklist assure la qualité et la cohérence de l'API Foresy en s'appuyant sur les standards définis dans nos ADRs.

**Référence :**
- [ADR-001: RSwag Authentication Strategy](docs/rswag/adr/ADR-001-rswag-authentication-strategy.md)
- [ADR-002: RSwag vs Request Specs Boundary](docs/rswag/adr/ADR-002-rswag-vs-request-specs-boundary.md)

---

## 🔐 API CONTRACT (OBLIGATOIRE)

### Endpoint modifié ou nouveau ?
- [ ] **Spec RSwag mise à jour** - Endpoint ajouté/modifié dans `spec/requests/api/v1/**/swagger/`
- [ ] **Auth conforme ADR-001** - Authentification conforme à la stratégie définie
- [ ] **Aucune request spec déguisée en RSwag** (référence ADR-002)
- [ ] **Documentation Swagger générée** - `swagger/swagger.yaml` mis à jour

### Validation technique
- [ ] **Tests RSwag passent** - Specs dans `spec/requests/**/swagger/` vertes
- [ ] **CI contract-check vert** - Workflow GitHub Actions réussi
- [ ] **Rubocop clean** - 0 infraction de style

---

## ⚡ BREAKING CHANGES

### Changement cassant détecté ?
- [ ] **Documenté dans un nouvel ADR** - Changement architectural documenté
- [ ] **Migration planifiée** - Stratégie de transition définie
- [ ] **Versioning考虑** - Nécessite `/api/v2` ?
- [ ] **Team notifiée** - Impact communiqué à l'équipe

---

## 🧪 TESTS & QUALITÉ

### Couverture de tests
- [ ] **500/500 tests passent** - Coverage complet validé
- [ ] **RSwag specs complètes** - Tous les endpoints documentés
- [ ] **Request specs pour logique métier** - Pas de duplication avec RSwag
- [ ] **Tests d'auth réalistes** - Reflètent le comportement production

### Qualité du code
- [ ] **Rubocop 0 infraction** - Code style conforme
- [ ] **Brakeman 0 alerte** - Sécurité validée
- [ ] **Architecture clean** - Respect des principes ADR-002

---

## 📖 DOCUMENTATION

### Documentation mise à jour
- [ ] **README/API mis à jour** - Si nécessaire
- [ ] **Exemples d'usage** - Postman/curl mis à jour
- [ ] **ADR référencé** - Changement documenté si architectural

### Clarity pour les consumers
- [ ] **Responses claires** - Schémas et exemples complets
- [ ] **Error handling documenté** - Codes et messages explicites
- [ ] **Auth flow décrit** - Process d'authentification clair

---

## 🚀 PERFORMANCE & SÉCURITÉ

### Performance
- [ ] **N+1 queries évitées** - Eager loading si nécessaire
- [ ] **Pagination appropriée** - Pour les endpoints listant des ressources
- [ ] **Caching strategy** - Considéré si pertinent

### Sécurité
- [ ] **Authorization checks** - Rôles et permissions validés
- [ ] **Input validation** - Paramètres et payloads sécurisés
- [ ] **SQL injection safe** - Utilisation de ActiveRecord安全的

---

## 🔍 REVIEWER SPÉCIALISÉ

### Pour les changements API :
- [ ] **Tech Lead approval** - Validation architecture
- [ ] **API expertise** - Connaissance RSwag/Rails
- [ ] **Breaking change assessment** - Impact analisé

### Pour les changements critiques :
- [ ] **Security review** - Si modifications auth/sécurité
- [ ] **Performance review** - Si impact sur les performances
- [ ] **Database review** - Si modifications schéma DB

---

## ✅ VALIDATION FINALE

### Checklist complète
- [ ] **Tous les points ci-dessus validés**
- [ ] **Tests green en local**
- [ ] **CI pipeline vert**
- [ ] **Code review approuvé**

### Sign-off
- [ ] **Developer** : Implémentation et tests
- [ ] **Reviewer** : Architecture et qualité
- [ ] **Tech Lead** (si breaking change) : Validation stratégique

---

## 🚨 ACTIONS REQUISES SI ÉCHEC

### Contract validation failed ?
1. **Mettre à jour les specs RSwag** dans `spec/requests/api/v1/**/swagger/`
2. **Regarder les breaking changes** potentiels
3. **Committer les modifications** de `swagger/swagger.yaml`
4. **Relancer la CI** pour validation

### Tests failed ?
1. **Analyser les logs** d'erreur spécifiques
2. **Corriger la logique** métier si nécessaire
3. **Ajouter les cas manquants** dans les specs appropriées
4. **Valider localement** avant re-submit

---

## 📚 RESSOURCES

- **ADR-001** : [RSwag Authentication Strategy](docs/rswag/adr/ADR-001-rswag-authentication-strategy.md)
- **ADR-002** : [RSwag vs Request Specs Boundary](docs/rswag/adr/ADR-002-rswag-vs-request-specs-boundary.md)
- **RSwag Guide** : [docs/rswag/guide.md](docs/rswag/guide.md)
- **CI Workflow** : [.github/workflows/rswag-contract-check.yml](.github/workflows/rswag-contract-check.yml)

---

*Cette checklist est **obligatoire** pour tout PR touchant l'API Foresy. Elle garantit la qualité, la cohérence et la maintenabilité de notre infrastructure contractuelle.*
```
<minimax:tool_call>
<invoke name="edit_file">
<parameter name="display_description">Create official PR review checklist for API contracts</parameter>
<parameter name="mode">create</parameter>
<parameter name="path">Foresy/docs/REVIEW_CHECKLIST.md</parameter>
</invoke>
</minimax:tool_call>