# MAINTENANCE_GUIDELINES.md - Guidelines de Maintenance Documentaire

**Date de création** : 28 Janvier 2026  
**Version** : 1.0  
**Objectif** : Prévenir les incohérences documentaires et maintenir la cohérence cross-documents

---

## 🎯 OBJECTIF ET PORTÉE

### Principe Fondamental
Ces guidelines garantissent la **cohérence documentaire** à travers tous les documents du projet Foresy, empêchant les futures contradictions identifiées lors de l'audit du 28 Janvier 2026.

### Documents Concernés
1. **README.md** - Vue d'ensemble projet
2. **VISION.md** - Vision produit et architecture
3. **BRIEFING.md** - État actuel et développement
4. **README.md** - Métriques source de vérité ⭐
5. **Feature Contracts** - Documents techniques spécifiques
6. **[DONE]_2026_01_27_DDD_Audit_CRA_Tests_Migration.md** - Source autoritaire architecture

---

## 📋 RÈGLES DE MAINTENANCE OBLIGATOIRES

### 🕐 RÈGLE 1 : HARMONISATION TEMPORELLE

#### Dates Standardisées
```markdown
# Format obligatoire pour toutes les dates
**Dernière mise à jour** : DD Month YYYY (soir)
**Validé le** : DD Month YYYY

# Exemples corrects
✅ "28 Janvier 2026 (soir)"
✅ "Validé le 28 janvier 2026"  
❌ "Dec 20, 2025" (format US)
❌ "Dernière MAJ : aujourd'hui"
```

#### Hiérarchie Temporelle
1. **README.md** = Source de vérité temporelle
2. Autres documents = Doivent être ≤ date README.md
3. **Audit DDD** = Source autoritaire pour architecture

### 🧮 RÈGLE 2 : MÉTRIQUES SYNCHRONISÉES

#### Tests RSpec - Valeurs Officielles
```yaml
# AU 28 JANVIER 2026 - NE PAS MODIFIER SANS MISE À JOUR README.md
Total RSpec: 449 examples, 0 failures
FC-07 CRA: 449 tests (TDD PLATINUM)
FC-06 Missions: 30 tests
OAuth: 15 tests

# RÈGLE : Tout changement → Mettre à jour README.md d'abord
```

#### Tests Swagger (Rswag)
```yaml
Rswag: 128 examples, 0 failures
Generation: auto-généré depuis tests
```

#### Qualité Code
```yaml
RuboCop: 147 files inspected, no offenses
Brakeman: 0 Security Warnings (3 ignored)
Zeitwerk: All files loading correctly
```

### 🎯 RÈGLE 3 : FEATURE CONTRACTS STATUS

#### Tableaux Synchronisés
```markdown
# Structure obligatoire dans VISION.md et BRIEFING.md
| FC# | Feature | Status | Tests | Certification |
|-----|---------|--------|-------|---------------|
| FC-07 | CRA | ✅ DONE | 449 | 🏆 PLATINUM CERTIFIED |

# RÈGLES :
- Status DOIVENT être identiques cross-documents
- Tests count DOIT correspondre à README.md
- Certification level DOIT refléter l'état réel
```

#### États Feature Contracts
- **✅ DONE** : Fonctionnellement terminé et testé
- **📋 NEXT** : Priorité suivante planifiée  
- **📋 PLANNED** : Roadmap future
- **🔴 ACTIVE** : En cours de développement (rare)

### 🏗️ RÈGLE 4 : ARCHITECTURE DDD/RDD

#### Terminologie Standardisée
```markdown
# Migration DDD/RDD
✅ "COMPLÉTÉE (27-28 Janvier 2026)"
✅ "Architecture pure"
✅ "Domaine CRA certifié Platinium"

❌ Éviter : "En cours", "Partiellement complété"
❌ Éviter : Dates multiples contradictoires
```

#### Principes Fondamentaux
- ❌ **Aucune FK entre entités métier**
- ✅ Relations par tables dédiées, explicites, versionnables
- ✅ Domain Services vs API Adapters séparés
- ✅ ApplicationResult pattern normalisé

---

## 🔄 PROCESSUS DE MISE À JOUR

### 📝 Workflow Standard pour Modification Code

#### Étape 1 : Évaluation Impact
```bash
# Questions à se poser :
- [ ] Tests RSpec affected ? → Update README.md
- [ ] Feature Contract status changed ? → Update VISION.md + BRIEFING.md  
- [ ] Architecture modification ? → Update DDD audit doc
- [ ] Production deployment ? → Update BRIEFING.md timeline
```

#### Étape 2 : Mise à Jour Documents
```markdown
# Ordre de priorité :
1. README.md (métriques techniques)
2. DDD_Audit_*.md (si architecture touchée)
3. BRIEFING.md (état global)
4. VISION.md (feature contracts table)
5. README.md (vue d'ensemble si nécessaire)
```

#### Étape 3 : Validation Croisée
```bash
# Checklist de cohérence finale :
- [ ] Dates cohérentes (≤ README.md)
- [ ] Compteurs tests identiques cross-documents
- [ ] Feature Contracts status alignés
- [ ] Architecture terminology unifiée
- [ ] Production URLs actuelles
```

### 🎯 Cas d'Usage Spécifiques

#### Ajout de Tests
```markdown
# Si ajout de tests RSpec :
1. Update README.md : "Total RSpec: X+new tests"
2. Update BRIEFING.md : Quality Metrics section
3. Update VISION.md : Si nouveau Feature Contract
4. Validation : Tous les docs mentionnent le même total
```

#### Nouveau Feature Contract
```markdown
# Si création FC-XX :
1. Update VISION.md : Nouvelle ligne dans table
2. Update BRIEFING.md : FeatureContract structure
3. Update README.md : Nouvelle entrée FC-XX
4. Update README.md : Si feature majeure
```

#### Migration Architecture
```markdown
# Si changement DDD/RDD :
1. Create DDD_Audit_*.md : Détails techniques
2. Update README.md : Status migration
3. Update BRIEFING.md : Architecture section
4. Update VISION.md : Si principes modifiés
```

---

## ⚠️ VALIDATION ET CONTRÔLE

### 🔍 Validation Automatique (Future)

#### Script de Cohérence
```bash
#!/bin/bash
# scripts/validate_docs.sh (À CRÉER)

echo "🔍 Validation cohérence documentaire..."

# Vérifier dates
LAST_SYNC=$(grep "Dernière mise à jour" docs/README.md | cut -d: -f2)
LAST_BRIEFING=$(grep "Last Updated" docs/BRIEFING.md | cut -d: -f2)

if [[ "$LAST_SYNC" > "$LAST_BRIEFING" ]]; then
    echo "❌ BRIEFING.md plus ancien que README.md"
fi

# Vérifier compteurs tests
SPEC_COUNT=$(grep "Total RSpec" docs/README.md | grep -o '[0-9]*')
BRIEFING_COUNT=$(grep "449 examples" docs/BRIEFING.md | grep -o '[0-9]*')

if [[ "$SPEC_COUNT" != "$BRIEFING_COUNT" ]]; then
    echo "❌ Incohérence tests RSpec: $SPEC_COUNT vs $BRIEFING_COUNT"
fi

echo "✅ Validation documentaire terminée"
```

#### Checklist Pre-Merge
```markdown
## ✅ Pre-Merge Documentation Checklist

### Obligatoire pour chaque PR :
- [ ] README.md mis à jour (si métriques changées)
- [ ] Cohérence dates vérifiée
- [ ] Compteurs tests identiques cross-documents
- [ ] Feature Contracts status alignés
- [ ] Architecture terminology unifiée

### Validation Technique :
- [ ] Script validate_docs.sh passe (si disponible)
- [ ] Aucun conflict entre documents
- [ ] Source de vérité respectée (README.md)
```

### 🚨 Alertes et Escalade

#### Signaux d'Alarme
```markdown
# 🚨 Incohérences détectées automatiquement :
- Dates contradictoires entre documents
- Compteurs tests différents
- Feature Contract status en conflit
- URLs production obsolètes
- Architecture terminology incohérente

# 🚨 Escalade automatique :
1. Alerte dans PR comments
2. Block merge jusqu'à résolution
3. Notification co-directeur technique
```

---

## 📚 GUIDE DE RÉSOLUTION

### 🔧 Résolution Incohérences Courantes

#### Problème : Dates contradictoires
```markdown
# Symptôme : 
BRIEFING.md "Dec 20, 2025" vs README.md "Jan 28, 2026"

# Solution :
1. Identifier document le plus récent (source autoritaire)
2. Harmoniser tous les documents ≤ cette date
3. Mettre à jour "Last Updated" si nécessaire
4. Valider cohérence temporelle
```

#### Problème : Compteurs tests incohérents
```markdown
# Symptôme :
VISION.md "427 tests" vs BRIEFING.md "449 tests"

# Solution :
1. Vérifier README.md (source de vérité)
2. Harmoniser tous les documents = README.md
3. Expliquer différence si sous-ensemble (ex: CraServices::Create)
4. Documenter méthodologie comptage
```

#### Problème : Feature Contract status contradictoire
```markdown
# Symptôme :
BRIEFING.md "FC-07 FAILING" vs "FC-07 100% TERMINÉ"

# Solution :
1. Identifier état réel actuel (tests, production)
2. Mettre à jour statut dans tous les documents
3. Supprimer références obsolètes
4. Documenter résolution dans audit technique
```

### 📖 Template de Correction
```markdown
# Correction Documentaire - Template

## Problème Identifié
**Document(s)** : 
**Incohérence** :
**Impact** :

## Solution Appliquée
**Source de vérité** :
**Documents modifiés** :
**Validation** :

## Résultat
**Avant** :
**Après** :
**Statut** : ✅ RÉSOLU

## Prévention
**Règle violée** :
**Action préventive** :
**Monitoring** :
```

---

## 🎯 RESPONSABILITÉS

### 👥 Rôles et Responsabilités

#### Co-Directeur Technique
- **Responsable** : Surveillance cohérence documentaire
- **Duties** : 
  - Validation updates critiques
  - Maintenance standards Platinum
  - Audit régulier cohérence
  - Formation équipe sur guidelines

#### Équipe Développement
- **Responsable** : Application guidelines au quotidien
- **Duties** :
  - Mise à jour README.md
  - Validation cohérence avant PR
  - Escalade incohérences détectées
  - Respect processus de maintenance

#### QA/Validation
- **Responsable** : Vérification technique métriques
- **Duties** :
  - Validation nombres tests réels
  - Vérification URLs production
  - Test coverage verification
  - Rapport incohérences

### 📅 Fréquence de Maintenance

#### Quotidien
- [ ] Vérification cohérence après chaque commit significatif
- [ ] Mise à jour README.md si métriques changées

#### Hebdomadaire  
- [ ] Audit cohérence cross-documents
- [ ] Validation Feature Contracts status
- [ ] Vérification URLs production

#### Mensuel
- [ ] Audit complet documentation
- [ ] Mise à jour guidelines si nécessaire
- [ ] Formation équipe sur nouvelles règles

---

## 📊 MÉTRIQUES DE MAINTENANCE

### KPI de Qualité Documentaire
```yaml
# Métriques à tracker :
Incohérences_détectées: 0 (objectif)
Temps_résolution: < 24h
Documents_à_jour: 100%
Features_synchronisés: 100%
Dates_cohérentes: 100%

# Alertes :
🔴 > 1 incohérence détectée
🟡 Délai résolution > 48h
🟢 Tout vert
```

### Dashboard de Surveillance
```markdown
# État Documentation Dashboard

| Document | Dernière MAJ | Cohérence | Status |
|----------|--------------|-----------|---------|
| README.md | 28 Jan 2026 | ✅ | À jour |
| BRIEFING.md | 28 Jan 2026 | ✅ | À jour |
| VISION.md | 28 Jan 2026 | ✅ | À jour |
| VISION.md | 28 Jan 2026 | ✅ | À jour |
```

---

## 🚀 ÉVOLUTION ET AMÉLIORATION

### Versioning des Guidelines
```markdown
# MAINTENANCE_GUIDELINES.md versions :

v1.0 (28 Jan 2026) : Création initiale
- Règles harmonisation temporelle
- Processus métriques synchronisées  
- Workflow Feature Contracts
- Validation automatique (future)

# Prochaines améliorations :
v1.1 : Scripts validation automatique
v1.2 : Intégration CI/CD hooks
v1.3 : Dashboard temps réel
```

### Feedback et Amélioration
```markdown
# Processus amélioration continue :

1. Collecte feedback équipe
2. Identification pain points
3. Proposition améliorations
4. Test nouvelles règles
5. Deployment nouvelles guidelines
6. Formation équipe
```

---

## 📞 CONTACT ET SUPPORT

### Questions et Support
- **Responsable** : Co-Directeur Technique
- **Escalade** : Pour incohérences non résolues
- **Feedback** : Amélioration guidelines bienvenues

### Resources
- **README.md** : Source vérité métriques
- **Scripts** : `scripts/validate_docs.sh` (future)
- **Templates** : Correction documentaire
- **Audit** : `[DONE]_2026_01_27_DDD_Audit_CRA_Tests_Migration.md`

---

**Dernière mise à jour** : 28 Janvier 2026  
**Prochaine révision** : Après déploiement scripts validation  
**Statut** : ✅ ACTIF - Application immédiate requise