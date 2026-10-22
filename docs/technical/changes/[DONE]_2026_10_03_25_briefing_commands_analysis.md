# 📐 Analyse #25 — Commandes canoniques de test du BRIEFING : diagnostic, preuves, plan de correction

**Date :** 2026-10-03 (horodatage git-clock hôte — convention d'écart de datation tracée, tracker #26 §4)
**Chantier :** BACKLOG **#25** — « BRIEFING — commande canonique de test erronée » (création 26/09)
**Statut :** ✅ **CORRIGÉE + CERTIFIÉE (2026-10-03)** — patch exécuté (5 commandes sur le service `test` +
note fc08::014 + Zeitwerk) · chaque forme vérifiée par exécution (rubocop 244/0 · brakeman 0 · zeitwerk OK ·
OAuth 41/0, seed 51711) · **#25 CLOSED** · suivi T1-T7 : §4 · fc08::018
**Discipline :** Investigation → preuve → arbitrage → modification (règle 26/09) — ce document est l'étape
« preuve », préalable au patch.

---

## 1. Conclusion en une page

| Question | Réponse |
|---|---|
| **Diagnostic** | Le § « Essential Testing Commands » de `docs/BRIEFING.md` (L674-688) invoque **5 commandes de test sur le service `web`** = environne­ment **development** (RAILS_ENV=development, base `foresy_development`) — en contradiction avec l'architecture du compose qui fournit un **service `test` dédié** (profil `test`) |
| **Cause racine (déjà tracée)** | fc08::014 + audit `[DONE]_2026_09_26_oauth_investigation.md` §6 : le run du close-out #26 sur `web` a court-circuité le guard GitLedger (`Rails.env.test?` faux ⇒ `&&` L37 avant stub ENV) → **3 faux échecs INV-D12-01 + 13 écrits réels de test dans le ledger** (qualification #24, purge O-B) |
| **Portée de la correction** | **5 lignes** de commande (L677 · L680 · L681 · L684 · L687) + **1 ligne de note** explicative — les autres commandes du BRIEFING (L642-648 dev up/ps/logs, L738-747 gestion compose, L747 `bash`) sont **des commandes de développement légitimes** : non concernées |
| **Vérifikasi des commandes correctes** | La forme `docker-compose --profile test run --rm test …` est **celle utilisée pour toutes les suites vertes de session** (1133/0 ×3 : seeds 11258 · 34758 · 47400) — validée en pratique (A9-style) |
| **Risque si non corrigé** | Récurrence du run erroné (classe d'incident fc08::014) à chaque suivi de BRIEFING par un nouvel agent |

---

## 2. Phase 1 — Faits (preuves ligne à ligne)

### 2.1 Architecture du compose (docker-compose.yml)

| Service | Environnement | Usage |
|---|---|---|
| `web` (L50-104) | `RAILS_ENV: development` (L83) · `DATABASE_URL: …foresy_development` (L84) | serveur de dev (commande `docker-compose … web`) |
| `test` (L109-147) | `RAILS_ENV: test` (L129) · `DATABASE_URL: …foresy_test` (L130) · `REDIS_URL: …0` vs `…1` · **`profiles: [test]`** (L146-147) | **service de test** — `docker-compose --profile test run --rm test …` |

> ⚠️ Détail : le service `test` pose aussi `PARALLEL_WORKERS: 2` (inoffensif sans parallel_tests en RSpec).

### 2.2 Preuve empirique de l'incident (session, tracée)

- 26/09 — `docker-compose run --rm web bundle exec rails runner` : **`rails_env: "development"`** (probe, fc08::017/audit #26 §6).
- Conséquence démontrée : 3 faux échecs INV-D12-01 + **11 écrits réels** (run plein) + **2** (isolation) — provenance prouvée (audit `[DONE]_2026_09_28_24_ledger_provenance_investigation.md` §3, 23/23).
- Correction validée en pratique : toutes les suites post-incident ont tourné sur `--profile test … test` (BACKLOG : 1133/0, fc08::016/017).

### 2.3 Inventaire des commandes du BRIEFING (§636-747)

| Ligne | Commande | Verdict |
|---|---|---|
| L642-648 | `docker-compose up -d` / `ps` / `logs -f web` | ✅ dév légitime (serveur) — non concernée |
| **L677** | `docker-compose run --rm web bundle exec rspec` | ❌ **suite complète en dev-env** |
| **L680** | `docker-compose run --rm web bundle exec rspec spec/acceptance/oauth_feature_contract_spec.rb` | ❌ idem |
| **L681** | `docker-compose run --rm web bundle exec rspec spec/integration/oauth/oauth_callback_spec.rb` | ❌ idem |
| **L684** | `docker-compose run --rm web bundle exec rubocop` | ❌ **fonctionne accidentellement** (rubocop ne dépend pas de Rails.env) — mais mauvais service (corpus/volume différent) |
| **L687** | `docker-compose run --rm web bundle exec brakeman` | ❌ idem (Brakeman strict — même scan, mais mauvais service) |
| L738-747 | `down` / `up -d --build` / `down -v` / `run --rm web bash` | ✅ gestion compose/dév légitime — non concernée |
| README L195-201 | `docker-compose up -d` (Installation) | ✅ dév légitime — non concernée |

### 2.4 Chiffrage de l'impact (si non corrigé)

Tout agent suivant le BRIEFING à la lettre reproduit la classe d'incident fc08::014 : faux échecs
INV-D12-01 · écritures réelles dans le ledger · couverture/pool erronés. Le coût d'un incident est déjà
qualifié (#24 : 23 commits à qualifier + purge).

---

## 3. Plan de correction proposé (arbitrage — exécution après GO)

**Patch minimal (5 lignes + 1 note)** dans `docs/BRIEFING.md` § « Essential Testing Commands » :

```bash
# Service `test` OBLIGATOIRE pour toute exécution de test (RAILS_ENV=test, foresy_test) —
# cf. fc08::014 : le service `web` boote en development (base foresy_development) et
# court-circuite le guard Git Ledger (Rails.env.test? faux).
# Complete RSpec test suite
docker-compose --profile test run --rm test bundle exec rspec

# OAuth-specific tests
docker-compose --profile test run --rm test bundle exec rspec spec/acceptance/oauth_feature_contract_spec.rb
docker-compose --profile test run --rm test bundle exec rspec spec/integration/oauth/oauth_callback_spec.rb

# Code quality checks
docker-compose --profile test run --rm test bundle exec rubocop

# Security audit
docker-compose --profile test run --rm test bundle exec brakeman

# Zeitwerk
docker-compose --profile test run --rm test bundle exec rails zeitwerk:check
```

- Les commandes dév (L642-648, 738-747) restent inchangées (usage légitime documenté).
- **Vérification post-patch** : exécuter chaque forme corrigée une fois (rubocop/zeitwerk/rspec ciblé)
  pour attester que les commandes du BRIEFING sont copier-coller-runnable ✓.
- **Hors périmètre** (restent ouverts) : #24-bis prévention structurelle (garde spec-level du mode réel
  hors overlay — option O-C, chantier séparé) · README : la commande Installation `up -d` est légitime,
  non concernée.

---

## 4. Suivi d'avancement d'implémentation (T1-T7)

| # | Étape | Statut | Où ça vit |
|---|---|---|---|
| T1 | **Analyse #25 écrite** (diagnostic + preuves + plan — ce document) | ✅ fait (2026-10-03) | ce doc · BACKLOG #25 (référence) |
| T2 | Branche `docs/fix-25-briefing-tests` + **patch BRIEFING** : 5 commandes corrigées (`--profile test … test`) + note explicative fc08::014 + commande Zeitwerk ajoutée | ✅ fait | branche/PR dédiée · BRIEFING §636-747 |
| T3 | **Vérification** : chaque forme corrigée exécutée une fois — **rubocop 244/0 · zeitwerk OK · brakeman 0 warning · rspec OAuth 41/0 (seed 51711)** — attestées copier-coller-runnable | ✅ fait (2026-10-03) | journal ci-dessous |
| T4 | **BACKLOG #25 close** (+ row « Chantiers livrés ») | ✅ fait | BACKLOG |
| T5 | Préfixe `[DONE]_` sur ce document | ✅ fait | renommage du doc |
| T6 | Merge PR + **réindexation hub** (le doc d'analyse + BRIEFING servis) | ⬜ post-merge | hub RAG |
| T7 | **Mémoire fc08::018 proposée** (leçon : l'analyse précède le patch, comme pour #26 tracker) — validation CTO à la clôture | ⬜ proposition | hub (après validation) |

**Rappel de gouvernance** (règle 26/09) : T2-T5 n'exécutent **pas** de code applicatif — patch documentaire
uniquement, guidé par ce plan ; le préfixe `[DONE]_` ne viendra qu'après vérification des commandes (T3).

**Journal d'exécution (2026-10-03, sources Session — sorties d'outils)** : patch appliqué (T2) →
T3 : `rubocop` **244 files / 0 offense** · `zeitwerk:check` **All is good!** · `brakeman` **0 warning**
(3 ignored préexistants) · `rspec` **41 examples / 0 failures** (seed 51711) — chaque forme exécutée
exactement telle qu'écrite au BRIEFING. Aucun défaut constaté sur les formes dév légitimes (inchangées).

---

## 5. Références

- `docs/BRIEFING.md` L642-648 (dév légitime) · L674-688 (les 5 commandes erronées) · L738-747 (dév légitime)
- `docker-compose.yml` L50-104 (web/dev) · L109-147 (test) · L146-147 (profil)
- Probes + incidents : mémoire fc08::014/015/016/017 · audit `[DONE]_2026_09_26_oauth_investigation.md` §6 ·
  audit `[DONE]_2026_09_28_24_ledger_provenance_investigation.md` §3/§5.1
- BACKLOG #24 (close, O-B) · #25 (ce chantier) · #27 · #28 potentiel

---

**Document créé le :** 2026-10-03
**Propriétaire :** Équipe technique Foresy
*Préfixe `[DONE]_` à appliquer à l'issue de la correction + vérification des commandes.*