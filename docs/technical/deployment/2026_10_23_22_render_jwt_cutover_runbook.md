# 🚀 Runbook de bascule Render — #22 Hardening JWT (clé dédiée)

**Date de préparation :** 23 octobre 2026
**Auteur :** Zed Agent (BACKLOG #22 — arbitrage CTO : **Option A — préparation de la bascule, SANS push**)
**Statut :** 🕓 **PRÉPARATION TERMINÉE — push DIFFÉRÉ jusqu'à fenêtre de déploiement confirmée + autorisation
push explicite** (le push déclenche l'auto-deploy Render = **LA BASCULE**)
**Référence chantier :** `docs/technical/audits/[DONE]_2026_10_23_22_jwt_hardening_investigation.md` (#22, T1-T7,
certifié — commit `e0e60e4e`) · condition de release §6.3 · mémoire `fc08::021`
**Registre de santé au moment de l'écriture :** fetch effectué (23/10) — `HEAD = e0e60e4e` ·
`origin/main = ed6806b9` (inchangé) · rangé `origin/main..main` = **uniquement** `e0e60e4e` (chantier #22 certifié) ·
arbre propre · hub : knowledge 2489 chunks / memories 22 (fc08::021 vérifiée Chroma, top-hit).

---

## 1. Effet de la bascule (à annoncer verbatim)

À l'occasion du déploiement du commit `e0e60e4e` (+ éventuels commits documentaires certifiés qui le suivent) :
- tous les **access tokens** (15 min) et **refresh tokens** (30 j) émis avant la bascule — signés avec l'ancienne
  clé `secret_key_base` — deviennent **invalides** (`401 UNAUTHORIZED`) ;
- **chaque utilisateur actif devra se re-connecter** (les données ne sont **pas** affectées : seule
  l'authentification doit être repassée) ;
- après reconnexion : tokens signés par la clé dédiée `JWT_SECRET` (configurée et vérifiable —
  `ConfigurationError` au boot si absente/vide ⇒ déploiement avorté, `/health` jamais atteint).

## 2. Annonce (texte à publier par le CTO — canaux/heure à fixer par lui)

> **[FR] Maintenance de sécurité — Foresy API**
> À l'occasion du déploiement du <DATE/HEURE FENÊTRE>, Foresy bascule la signature de ses jetons
> d'authentification vers une clé de sécurité dédiée (durcissement #22). Tous les jetons actuels deviennent
> invalides : **une reconnexion sera requise** après la maintenance. Vos données ne sont pas affectées.
> Durée estimée d'impact par utilisateur : la reconnexion (~1 minute). Aucune action en amont nécessaire.
>
> **[EN] Security maintenance — Foresy API**
> On <DATE/HEURE FENÊTRE>, Foresy rotates its authentication signing key to a dedicated secret (#22 hardening).
> All existing tokens become invalid: **please sign in again** after the maintenance. Your data is unaffected.

**Checklist annonce :** canal(s) utilisateur définis par le CTO · horodatage de la publication consigné ci-dessous
(§6 journal, rempli à la bascule) · l'annonce doit précéder le push (condition #1).

## 3. Vérifications pré-push (conditions CTO 1-3 — rejouables à la fenêtre)

| # | Vérification | Commande/méthode | Critère |
|---|---|---|---|
| 1 | **Annonce publiée** | §2 | horodatage consigné §6 |
| 2a | **Cible distante inchangée** | `git --no-pager fetch origin` puis `git rev-parse --short=8 origin/main` | `ed6806b9` (aucun changement distant inattendu) |
| 2b | **HEAD local = chaîne certifiée ≥ `e0e60e4e`** | `git rev-parse --short=8 HEAD` + `git --no-pager log --oneline origin/main..main` | HEAD ≥ `e0e60e4e` ; tout commit du rang = certifié & documenté |
| 2c | **Arbre propre** | `git --no-optional-locks status -sb` | porcelain vide |
| 3 | **Pre-pose `JWT_SECRET` effective** | dashboard Render → foresy-api → Environment | `JWT_SECRET` listée (lecture de présence — déjà confirmée par capture 23/10 ; re-lecture avant push recommandée) |
| 3bis | **AUTORISATION PUSH EXPLICITE** | message CTO | « GO PUSH » consigné — le push déclenche l'auto-deploy |

## 4. Procédure de bascule (exécutée après « GO PUSH »)

1. **`git push origin main`** → surveillance Render (**Events** du service) : build → release → boot.
2. **Boot & health** : `curl -s -o /dev/null -w '%{http_code}' https://foresy-api.onrender.com/health` → `200`
   (répéter pendant la sortie de l'ancien/démarrage du nouveau process). Si `ConfigurationError` au boot →
   déploiement en échec visible → §4bis rollback.
3. **Sondes post-bascule** (compte de test dédié, credentials jamais imprimés) :
   - S-1 : `POST /api/v1/auth/login` → **200** + token *fresh* (signé clé dédiée) ;
   - S-2 : endpoint protégé (ex. `GET /api/v1/companies`) avec token fresh → **200** ;
   - S-3 : **ancien access token** capturé pré-push (stocké local, jamais imprimé/masqué) rejoué → **401
     UNAUTHORIZED** (format contrat `{code, message, details}`) — preuve de bascule effective ;
   - S-4 : refresh flow avec refresh_token *fresh* → **200** + nouveau pair (rotation OK) ;
   - S-5 : ancien refresh token (pré-bascule) au refresh → **401**.
4. **Critères de succès** : S-1 200 · S-2 200 · S-3 401 · S-4 200 · S-5 401 · `/health` 200 · logs Render sans
   `ConfigurationError` · 0 erreur 500.
5. **Consignation** : résultats réels (horodatés — §6) puis **clôture §5**.

### 4bis Rollback (si échec)
- **Choix recommandé** : Dashboard Render → foresy-api → **Rollbacks** → redéployer le **prior deploy**
  (`ed6806b9`) — plus sûr, sans commit supplémentaire : retour à la signature `secret_key_base` (le code ancien
  ignore `JWT_SECRET`) → les tokens *fresh* émis pendant la fenêtre deviennent invalides (re-login #2) ;
- alternative Git : revert + push (nouvelle bascule annulant la première) ;
- la variable `JWT_SECRET` reste posée et **dormante** dans tous les cas (non consommée par l'ancien code).

## 5. Clôture du dossier (après sondes OK — à exécuter à la bascule)

1. Filling réel : horodatages, hashes deploy Render, sondes S-1..S-5, logs — **ce document renommé `[DONE]_…`**.
2. Amendment `fc08::021` : condition de release → **ACCOMPLIE** (sondes + horodatage).
3. `suivi_impl::001` : bascule Render → **accomplie**.
4. BACKLOG #22 : condition de release → levée/déroulée (référence du mémo).
5. Reindex hub + **vérification Chroma** avant de déclarer le dossier **CLOSED**.

## 6. Journal (rempli au fil de l'eau)

- 2026-10-23 — Préparation : vérifications condition 2 exécutées réellement (fetch + compare : `HEAD = e0e60e4e`,
  `origin/main = ed6806b9` inchangé, rangé = 1 commit certifié, arbre propre) · annonce §2 rédigée (canaux/heure
  à fixer par le CTO) · runbook committé localement — **push différé**.
- _[fenêtre de déploiement — à compléter]_ : annonce publiée __ ; autorisation push __ ; push __ ;
  boot/health __ ; sondes S-1..S-5 __ ; clôture réalisée __.

---
*Règle : le push est une action opérationnelle distincte de la certification — jamais assimilé ; aucun résultat de
la bascule n'est présumé acquis avant exécution et mesure.*