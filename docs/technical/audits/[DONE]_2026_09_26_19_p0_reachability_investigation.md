# 🔍 Investigation #19 — Reachabilité des « P0 transactionnels » (C-1/C-2) · pivots UserCra / UserMission

**Date :** 26 septembre 2026
**Auteur :** Zed Agent (BACKLOG **#19** — clause de surveillance : « évidence attendue : reachabilité des échecs de pivot
après `save!` — analyse de `UserCra`/`UserMission` validations, à fournir en lecture seule »)
**Statut :** ✅ Investigation terminée — **aucune modification de code** — qualification arbitrée CTO 26/09 :
🟢 **pas de P0 démontrable** · 🟡 **dette architecturale latente** · 🔎 **race #14** → investigation séparée (BACKLOG #26)
**Périmètre :** `app/services/cra_services/create.rb` (`save_cra`, `create_user_cra_relation!`) ·
`app/services/mission_services/create.rb` (`save_mission`, `create_mission_company_relations!`,
`create_user_mission_relation!`) · pivots `UserCra`/`UserMission`/`MissionCompany` · `db/schema.rb` (FK, index
uniques partiels, enums) · appelants (`CrasController`, `MissionsController`)
**Discipline (CTO) :** un code qui semble dangereux n'est pas encore un bug · une exception théoriquement possible
n'est pas encore une transaction cassée · un scénario imaginable n'est pas un scénario atteignable — la chaîne
doit être démontrée. *Investigation → preuve → arbitrage → modification* (règle #21).

---

## 1. Conclusion en une page (arbitrage CTO 26/09)

| Élément | Qualification |
|---|---|
| C-1 / C-2 — « commit sans pivot » | **Pattern structurel présent** (rescue **dans** le bloc transaction + `return`) |
| Reachability actuelle | **Non démontrée** — conditions d'échec pivot toutes fermées au code |
| Perte / corruption de données actuelle | **Non démontrée** |
| **P0 transactionnel** | ❌ **Non confirmé** — déclassement de l'étude 24/09 (C-1 🔴 / C-2 🔴 → 🟡 dette latente) |
| `client_company_id` inconnu → 500 | Anomalie UX/erreur atteignable → **à qualifier séparément** (BACKLOG #27) |
| RuntimeError défensif « No independent company » → 500 | Observation secondaire (garanti absent par `check_user_permissions`) |
| Future validation app-level sur les pivots | **Risque latent** — rendrait la chaîne vivante et silencieuse |
| Race #14 (garde SELECT sans contrainte DB) | 🔎 **Observation indépendante à investiguer** (BACKLOG #26 — non qualifiée prématurément) |

**Correction C-1/C-2 maintenant : NO GO** — pas de bénéfice de production démontré ; « le code est dangereux en
théorie » ne fonde pas une correction immédiate. Le remède structurel (rescues **hors** bloc, pattern
`cra_services/lifecycle.rb` L146/L173 / `CompanyServices::Create`) reste documenté pour un futur arbitrage.

---

## 2. Phase 1 — Faits (lecture directe, ligne à ligne)

### 2.1 Mécanisme C-1 — `CraServices::Create#save_cra`

```
CrasController#create (cras_controller.rb L46-56) → CraServices::Create.call
  → garde params/user présents (create.rb L33-45)
  → validate_cra_params (L48-49) → check_user_permissions (L51-53 : user_companies indépendant exists?, L178-193)
  → check_duplicate_entry (L57-58, L200-212 — SELECT #14, pré-build → 409)
  → build_cra (L216-232 : Cra.new + valid? → 422 si invalide)
  → save_cra (L242-286) :
      ActiveRecord::Base.transaction do
        cra.save!                              # ← RecordInvalid possible (validations Cra)
        cra.reload
        create_user_cra_relation!(cra, current_user)   # ← pivot UserCra
      rescue ActiveRecord::RecordInvalid → return (409/422)   # ← DANS le bloc : return = COMMIT
      rescue ActiveRecord::RecordNotFound → return 404
      end
      ApplicationResult.success
    rescue StandardError → internal_error                     # ← HORS bloc (L279-285)
```

- `create_user_cra_relation!` (L294-312) : `UserCra.new(user_id: user.id, cra_id: cra.id, role: 'creator')` →
  `valid?` → si invalide : `raise ActiveRecord::RecordInvalid` (re-levé L303) → **capturé par le rescue interne**
  → `return` → bloc terminé sans exception → **COMMIT du CRA déjà persisté** (mécanisme démontré).
- `UserCra` (user_cra.rb) : validations L27-30 (presence ×2 + inclusion role) · `belongs_to :user/:cra,
  optional: false` L36-37 (présence d'association) · `ROLES = %w[creator contributor reviewer]`, `DEFAULT_ROLE = 'creator'` L18-19.

### 2.2 Mécanisme C-2 — `MissionServices::Create#save_mission`

- `MissionsController#create` (missions_controller.rb L49-59) → `MissionServices::Create.call` — gardes symétriques
  (L33-45, L48-53, `check_user_permissions` L248-264 : **même requête** `exists?` que `user_independent_company` L364-366).
- `save_mission` (L304-336) : `transaction { mission.save! ; mission.reload ; create_mission_company_relations! ;
  create_user_mission_relation! } rescue RecordInvalid → return 422 / rescue RecordNotFound → return 404` — **même anti-pattern**.
- `create_mission_company_relations!` (L344-361) : `user_independent_company` nil → `raise 'No independent company
  found…'` (RuntimeError L347 — **non rescué** → rollback sain) · `MissionCompany.create!(company_id: …, role:
  'independent')` puis, si param : `create!(company_id: client_id, role: 'client')`.
- `create_user_mission_relation!` (L374-393) : idem C-1 (champs garantis, `raise RecordInvalid` re-levé).

### 2.3 Pivots — validations, FK, index uniques partiels (schema)

| Table | FK (schema.rb) | Contraintes uniques | Notes |
|---|---|---|---|
| `user_cras` (L185-195) | `fk_user_cras_cra` / `fk_user_cras_user` (cascade, L234-235) | **unique partielles** : `(cra_id, role='creator')` et `(user_id, cra_id, role='creator')` (L190, L192) — **contrairement au commentaire modèle « No global unique index »** | NOT NULL ×3, role enum `user_relation_role` default `'creator'` |
| `user_missions` (L197-206) | `fk_user_missions_mission` / `fk_user_missions_user` (cascade, L236-237) | idem (L202) | idem |
| `mission_companies` (L117-127) | → companies / missions (**sans** cascade, L229-230) | `(mission_id, company_id, role)` unique (L124) | role enum `mission_company_role_enum` |

`MissionCompany` (mission_company.rb) : presence `mission_id`/`company_id`, inclusion role, 2 unicité
(scope `mission_id+company_id+role` / `mission_id+role`), règle custom « 1 indépendant max » (L71-89).

### 2.4 Garde #14 et inertie du modèle

- `Cra#validate_uniqueness` (cra.rb L337-351) : lit `user_cras.find_by(role: 'creator')&.user_id` → **nil à la
  création** (pivot inexistant) → `return` précoce → **inerte à la création** (conforme tracker #14).
- Le 409 doublon vient donc du garde **service-level** `check_duplicate_entry` (SELECT, L200-212), **avant** build.
- La branche `duplicate_detected` du rescue interne de `save_cra` (L250-265) est **vestigiale** : le message
  `'A CRA already exists…'` ne peut être ajouté par le modèle que si un pivot existe déjà — impossible pour un CRA frais.

### 2.5 Appelants réels

`CrasController#create` / `MissionsController#create` — contrôleurs thin, délégation `.call`, `current_user`
JWT-authentifié (User persisté). Aucun autre appelant de ces deux services (grep `app/`).

---

## 3. Phase 2 — Reachability : **non démontrée** (démonstration inverse)

### 3.1 Chaîne candidate CRA — conditions fermées

`user.id → cra.id → save! → validation pivot X → condition Y → RecordInvalid → rescue interne → return → COMMIT sans pivot`

| Condition Y d'échec pivot | Réalité au code | Verdict |
|---|---|---|
| `user_id` nil | garde `current_user.present?` (L40-45) + User persisté (auth JWT) | fermé |
| `cra_id` nil | `save!` + `reload` immédiatement avant, même transaction | fermé |
| `role` ∉ ROLES | constante `'creator'` | fermé |
| `belongs_to :user` charge nil (« User must exist ») | nécessite suppression concurrente du user **post-auth** — seul `delete_all` users vivant : `app/controllers/__test_support__/e2e/setup_controller.rb#destroy` (**verrouillé prod**, audit 24/09) | **non atteignable** (aucun chemin applicatif de suppression user) |
| `belongs_to :cra` charge nil | row insérée dans la même transaction, visible | fermé |
| Collision index unique partiel « creator » | `cra_id` UUID **frais** jamais exposé avant la réponse | fermé — et un échec DB lèverait `RecordNotUnique` **non rescué** → rollback sain |
| FK violée | `cra_id`/`user_id` = refs valides | fermé |
| Doublon CRA à `save!` | `Cra#validate_uniqueness` **inerte** (§2.4) — et un échec de `save!` ne persiste rien → COMMIT vide **bénin** | fermé |

`cra.reload` échouant (row disparue entre INSERT et reload) : nécessiterait une suppression concurrente du cra
frais (id jamais exposé) — non atteignable ; atteignable théoriquement → return 404 → commit — même famille
d'irréalisme (aucun acteur ne connaît l'id).

### 3.2 Chaîne candidate Mission — conditions fermées

Idem C-1 pour le pivot `UserMission` (champs garantis, `mission_id` frais) **plus** :

| Condition Y | Réalité | Verdict |
|---|---|---|
| `MissionCompany` presence company_id | indépendant : garanti (`check_user_permissions` `exists?`) ; client : param présent | fermé (présence) |
| `MissionCompany` inclusion role | constantes `'independent'`/`'client'` | fermé |
| `MissionCompany` unicité (scope mission_id) | mission **frais** → 0 rows existantes | fermé |
| RuntimeError « No independent company » | **non rescué** → rollback sain ; défensif — `check_user_permissions` garantit l'existence (même requête `exists?`) | rollback sain |
| `client_company_id` inconnu → **FK violation** (`mission_companies` → companies, L229) | **non rescué** → rollback sain → 500 (données intègres) | atteignable — **UX, pas intégrité** (BACKLOG #27) |

### 3.3 Les exceptions DB réelles ne sont pas absorbées

Tout échec au niveau DB (`RecordNotUnique`, `ForeignKeyViolation`, NOT NULL, enum) n'est **pas** couvert par
`rescue ActiveRecord::RecordInvalid/RecordNotFound` → remonte hors du bloc → **ROLLBACK correct** →
`rescue StandardError` externe → `internal_error` (500). Les données restent intègres dans tous les cas
réalistes identifiés.

---

## 4. Phase 3 — Impact

1. **Données** : aucun scénario réaliste de commit-sans-pivot / perte-corruption aujourd'hui (reachability non démontrée).
2. **Anomalies UX atteignables** (données intègres, à qualifier séparément — BACKLOG **#27**) :
   - `client_company_id` inconnu → `ForeignKeyViolation` → **500 au lieu de 422** ;
   - RuntimeError défensif « No independent company found » → **500** (observation secondaire — garanti absent par le check).
3. **Risque latent structurel** : le pattern est un piège — toute **future validation app-level sur les pivots**
   (rôles multiples, unicité via pivot) rendrait la chaîne vivante et silencieuse ; le garde `valid?` des pivots
   dépend aussi de l'existence des rows référencées (belongs_to) — seule condition de fragilité = suppression
   concurrente (aucun chemin applicatif).
4. **Observation adjacente — race #14** (hors 2 P0, non qualifiée) :
   - `check_duplicate_entry` = SELECT applicatif pré-build ;
   - lien créateur = pivot `UserCra` **créé après** l'insert CRA → **aucune contrainte DB équivalente possible** à
     l'échelle actuelle (et `Cra#validate_uniqueness` inerte à la création) ;
   - fenêtre de course : deux créations concurrentes (même créateur, mois, année) peuvent passer le SELECT
     simultanément → 2 CRAs persistés ;
   - **5 points à démontrer avant qualification** (BACKLOG **#26**) : ① deux créations concurrentes passent la
     garde simultanément ② transactions poursuivies ③ absence de protection concurrente modèle/schéma ④ deux CRAs
     persistés ⑤ violation effective du contrat #14.

---

## 4. Phase 4 — Qualification (arbitrée CTO 26/09)

| Item | Qualification |
|---|---|
| C-1 (`CraServices::Create`) / C-2 (`MissionServices::Create`) — « commit sans pivot » | 🟡 **Dette architecturale latente** — pattern présent, **non atteignable** ; correction **NO GO** (pas de bénéfice de production démontré) ; remède structurel documenté (rescues hors bloc — pattern `lifecycle.rb` L146/L173 / `CompanyServices::Create`) pour un futur arbitrage |
| « 2 bugs transactionnels P0 » (étude 24/09) | ❌ **Non démontrés** — déclassement S-1 tracé au BACKLOG (requalification par preuves, conformément à la clause) |
| `client_company_id` inconnu → 500 | 🟡 Anomalie UX/erreur — **à qualifier séparément** (BACKLOG #27) |
| RuntimeError défensif → 500 | 🟢 Observation secondaire |
| Future validation app-level pivot | 🟡 Risque latent (clôture du pattern, à surveiller à toute évolution des pivots) |
| Race #14 (garde SELECT) | 🔎 **Investigation séparée requise** (BACKLOG #26) — 5 points de démonstration posés |

---

## 5. Distinctions de périmètre (règle de lecture)

- **Mécanisme dangereux mais non atteignable** : C-1/C-2 (rescue-in-transaction + return) — dette latente, pas de correction.
- **Anomalies effectivement atteignables** : UX 500 (client inconnu) — données intègres, à qualifier séparément.
- **Observations adjacentes non encore qualifiées** : race #14 (investigation dédiée), RuntimeError défensif.
- Conformité règle de méthode du 26/09 : *Investigation → preuve → arbitrage → modification* — aucun commit de
  correction produit (aucune correction recommandée).

---

## 6. Références

- `app/services/cra_services/create.rb` L33-79 (gardes/call), L178-212 (permissions + garde #14), L242-312 (save_cra + pivot)
- `app/services/mission_services/create.rb` L32-74, L248-264 (permissions), L304-336 (save_mission), L344-393 (relations)
- `app/models/user_cra.rb` L27-37 · `app/models/user_mission.rb` L22-29 · `app/models/mission_company.rb` L40-49, L71-89
- `app/models/cra.rb` L337-351 (validate_uniqueness — inerte à la création)
- `app/controllers/api/v1/cras_controller.rb` L46-56 · `missions_controller.rb` L49-59
- `db/schema.rb` L117-127 (mission_companies), L185-206 (pivots), L223-237 (FKs)
- `app/controllers/__test_support__/e2e/setup_controller.rb` L94-98 (seul delete_all users — verrouillé prod, audit 24/09)
- Étude d'origine : `docs/technical/audits/2026_09_24_services_layer_homogeneity_study.md` §4 (C-1/C-2) · §9 (S-1)
- Historique RAG : mémoire fc08::012 (clause de surveillance) · BACKLOG #19 · arbitrage CTO 26/09

---

**Document créé le :** 26 septembre 2026
**Propriétaire :** Équipe technique Foresy
*Statut de clôture : investigation arbitrée (qualification validée) — préfixe `[DONE]_` appliqué ; toute
correction ultérieure C-1/C-2 ou qualification race #14 fera l'objet de chantiers dédiés (#26/#27).*