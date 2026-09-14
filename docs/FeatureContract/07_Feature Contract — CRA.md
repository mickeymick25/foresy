🧾 FEATURE CONTRACT 07 — CRA

Compte Rendu d’Activité

⚠️ DOCUMENT CONTRACTUEL — SOURCE DE VÉRITÉ
⚠️ Toute ambiguïté DOIT être signalée avant implémentation
⚠️ Aucune déviation autorisée

1️⃣ Feature Name

CRA Management (Compte Rendu d’Activité)

2️⃣ Business Goal

Permettre à un Indépendant de :

déclarer son activité réelle par mission

suivre son temps / valeur produite

disposer d’un historique mensuel fiable, auditable et versionné

Fournir le socle :

de la facturation

du pilotage fiscal

des reportings long terme

👉 Le CRA est un artefact légal et contractuel, immutabilisé dans le temps.

3️⃣ Actors
Primary Actor

Authenticated User (JWT)

Pré-requis métier

L’utilisateur appartient à une Company avec rôle independent

Les missions référencées sont accessibles à l’utilisateur (règles FC06)

⚠️ Toute incohérence → 403 forbidden
⚠️ Mission non accessible → 404 not_found

4️⃣ Architectural Principles (NON NÉGOCIABLES)

🧱 Domain-Driven / Relation-Driven

❌ Aucune clé étrangère métier dans les Domain Models
✅ Toutes les relations passent par des Relation Models dédiés

Entités métiers pures

Relations auditables, versionnables

CRA = agrégat racine

5️⃣ Domain Models (purs)
CRA
Champ	Type	Required	Notes
id	UUID	Yes
month	Integer	Yes	1–12
year	Integer	Yes
status	Enum	Yes	draft | submitted | locked
description	Text	No	🆕 Metadata non financière
total_days	Decimal	No	Calculé
total_amount	Integer	No	Calculé
currency	String	Yes	ISO 4217
created_by_user_id	UUID	Yes	🆕 Audit-only
created_at	DateTime	Yes
updated_at	DateTime	Yes
locked_at	DateTime	No
deleted_at	DateTime	No	Soft delete

⚠️ Aucune référence métier vers Mission / Company
⚠️ created_by_user_id est audit-only, non relation métier
⚠️ description :

modifiable en draft

modifiable en submitted

figée en locked

CRAEntry
Champ	Type	Required	Notes
id	UUID	Yes
date	Date	Yes
quantity	Decimal	Yes	Quantité facturable
unit_price	Integer	Yes	En cents
description	Text	No
created_at	DateTime	Yes
updated_at	DateTime	Yes
deleted_at	DateTime	No
🔑 Définition contractuelle de quantity

Représente la quantité facturable déclarée

Unité : journée

Granularité libre (ex : 0.25, 0.5, 1.0, 2.0)

Aucune borne supérieure métier côté backend

⚠️ Entité strictement métier
⚠️ Aucune validation “morale” du temps n’est autorisée

6️⃣ Relation Models (OBLIGATOIRES)
CRAMission
Champ	Type	Required
id	UUID	Yes
cra_id	UUID	Yes
mission_id	UUID	Yes
created_at	DateTime	Yes

🔒 Contraintes

Un CRA peut être lié à plusieurs missions

Une mission ne peut apparaître qu’une seule fois dans un CRA

🆕 Règle de création

Le lien CRAMission est créé automatiquement

Déclenché lors de la première CRAEntry associée à la mission

Centralisé via un service métier (CraMissionLinker)

Aucun endpoint dédié exposé

CRAEntryCRA
Champ	Type	Required
id	UUID	Yes
cra_id	UUID	Yes
cra_entry_id	UUID	Yes
created_at	DateTime	Yes
CRAEntryMission
Champ	Type	Required
id	UUID	Yes
cra_entry_id	UUID	Yes
mission_id	UUID	Yes
created_at	DateTime	Yes
🔒 Contraintes métier sur les entrées

Un CRA peut contenir plusieurs CRAEntry pour une même date

Une date peut être associée à plusieurs missions distinctes

Une mission peut apparaître plusieurs fois dans un CRA sur des dates différentes

Unicité stricte
(cra_id, mission_id, date)


Validation métier (service-level)

Violation → 409 duplicate_entry

✔️ Multi-mission / même date : autorisé
✔️ Sur-facturation contractuelle : autorisée
✔️ Date sans entrée : autorisée

7️⃣ CRA Lifecycle (Status)
Enum strict

draft

submitted

locked

Transitions autorisées

draft → submitted

submitted → locked

⚠️ Aucun retour arrière
⚠️ Aucun changement possible après locked
Violation → 422 invalid_transition

8️⃣ Business Rules & Constraints
Accès

CRA accessible uniquement si :

user ∈ company independent

missions accessibles (FC06)

Violation → 404 not_found

Unicité

1 CRA max par (user, month, year)

Violation → 409 cra_already_exists

🆕 Contrainte DB obligatoire

Index unique (created_by_user_id, month, year)

Filtré sur deleted_at IS NULL

Protège des race conditions concurrentes

Modification

draft → modification libre

submitted → modification interdite sauf metadata non financière

locked → aucune modification

🆕 Metadata non financière autorisée en submitted

description (CRA-level uniquement)

❌ Toute modification financière ou d’entry en submitted est interdite
Violation → 409 cra_locked

Calculs (serveur only)

total_days = somme(CRAEntry.quantity)

total_amount = somme(quantity × unit_price)

🆕 Les totaux sont recalculés :

à chaque création / modification / suppression d’entry

lors du submit

lors du lock

⚠️ Valeurs dérivées
⚠️ Jamais trustées depuis le client

Suppression

Soft delete uniquement

Interdite si CRA = submitted ou locked

Violation → 409 cra_in_use

🆕 Soft-delete cascade

Soft-delete du CRA entraîne :

soft-delete des CRAEntry

soft-delete des relations (CRAMission, CRAEntryCRA, CRAEntryMission)

9️⃣ Git / Versioning Contract (PLATINUM)
Principe

Chaque CRA verrouillé (locked) est :

sérialisé dans un JSON canonique

versionné dans un Git repository interne

considéré comme immuable

Le Git Ledger constitue une preuve d’audit indépendante du stockage applicatif.

⚠️ Un CRA ne DOIT PAS passer au statut locked si l’écriture Git échoue.

🆕 [AJOUT] — Portée contractuelle

Le Git Ledger est une source d’audit secondaire contractuelle, indépendante :

de la base de données applicative

des mécanismes ORM

Il ne remplace pas la base applicative, mais en constitue une preuve append-only vérifiable.

Git Object

Repository : cra-ledger

Branch : main

Path local : /app/cra-ledger

Le repository est :

auto-initialisé au boot s’il est absent

append-only (aucune réécriture de l’historique)

🆕 [AJOUT] — Contraintes Git

❌ git rebase, git commit --amend, git push --force strictement interdits

❌ suppression de commits interdite

Toute tentative de réécriture de l’historique constitue une violation contractuelle

Environnements & Persistance
MVP / Environnements non-production (DEV, STAGING)

Le filesystem est éphémère

Le Git Ledger est considéré comme un bonus d'audit

La perte du dossier lors d'un redeploy est acceptée

Les données source restent en base de données

👉 Ce mode est explicitement autorisé hors production.

🆕 Production — DÉCISION CTO CONFIRMÉE ✅
✅ Option A — Volume persistant (Render Disk) OBLIGATOIRE

Le dossier /app/cra-ledger est monté sur un filesystem persistant

Les commits Git DOIVENT survivre aux redeploys

Le Git Ledger constitue une preuve d'audit durable, indépendante et opposable

Cette configuration est obligatoire en production.

Toute perte du Git Ledger en production est considérée comme un incident critique.

❌ Option B — Filesystem éphémère

Strictement interdite en production

Autorisée uniquement pour :

MVP

DEV

STAGING

⚠️ L'option B ne peut être utilisée en production sous aucune circonstance.

Git Identity (technique)

Les commits sont réalisés avec une identité technique dédiée :

name : foresy-ledger

email : ledger@foresy.internal

Aucune identité utilisateur métier ne doit apparaître dans l’historique Git.

🆕 [AJOUT] — Règle de traçabilité

L’identité Git ne doit jamais dépendre :

de l’utilisateur courant

du contexte métier

La traçabilité utilisateur reste assurée uniquement via le payload JSON

Commit
Message de commit
CRA locked — cra:{id} — {month}/{year}


🆕 [AJOUT] — Unicité

Il doit exister exactement un commit Git par CRA verrouillé

Aucun commit intermédiaire n’est autorisé pour un même CRA

Payload versionné (JSON canonique)
{
  "cra_id": "uuid",
  "month": 1,
  "year": 2025,
  "missions": ["uuid", "uuid"],
  "entries": [...],
  "totals": {
    "total_days": 1.0,
    "total_amount": 800
  }
}


🆕 [AJOUT] — Canonical JSON

Ordre des clés stable et déterministe

Aucune donnée calculée côté client

Le payload représente l’état exact du CRA au moment du lock

⚠️ Gestion des erreurs

Échec Git → 500 internal_error

Rollback complet

Le CRA reste non-locked

Aucun état intermédiaire n’est toléré

🆕 [AJOUT] — Observabilité

Toute erreur Git doit être :

loggée côté serveur

corrélable avec l’ID du CRA

🆕 Transactionnalité stricte (OBLIGATOIRE)

Le verrouillage du CRA DOIT être atomique :

recalcul des totaux

passage du statut à locked

commit Git

Toute erreur Git provoque :

une exception bloquante

un rollback total

aucune persistance partielle

🆕 [AJOUT] — Contrat technique

Cette transaction est implémentée dans un service applicatif dédié

❌ Aucune logique de lock ou Git dans le contrôleur

❌ Aucun contournement possible via API ou job async

🔟 API Scope
Method	Endpoint	Description
POST	/api/v1/cras	Créer CRA
GET	/api/v1/cras	Lister (paginated)
GET	/api/v1/cras/:id	Détail
PATCH	/api/v1/cras/:id	Modifier
DELETE	/api/v1/cras/:id	Soft delete
POST	/api/v1/cras/:id/submit	Soumettre
POST	/api/v1/cras/:id/lock	Verrouiller
🆕 Pagination GET /api/v1/cras

Paramètres :

page (default: 1)

per_page (default: 20)

Réponse :

{
  "data": [...],
  "meta": {
    "total": 120,
    "page": 1,
    "per_page": 20
  }
}

🆕 Endpoints CRAEntry
Method	Endpoint	Description
POST	/api/v1/cras/:cra_id/entries	Ajouter une entrée
GET	/api/v1/cras/:cra_id/entries	Lister les entrées
PATCH	/api/v1/cras/:cra_id/entries/:id	Modifier une entrée
DELETE	/api/v1/cras/:cra_id/entries/:id	Supprimer une entrée
1️⃣1️⃣ Inputs / Outputs
POST /api/v1/cras
{
  "month": 1,
  "year": 2025,
  "currency": "EUR"
}


Success — 201

{
  "id": "uuid",
  "status": "draft"
}

1️⃣2️⃣ Errors
Status	Code	Description
401	unauthorized
403	forbidden
404	not_found
409	cra_locked
409	cra_already_exists
409	duplicate_entry
422	invalid_payload
422	invalid_transition
500	internal_error

🆕 Error payload standard

{
  "error": "duplicate_entry",
  "message": "An entry already exists for this mission and date in this CRA."
}

1️⃣3️⃣ Swagger / OpenAPI

Schemas :

cra

cra_entry

cra_with_entries

error

Enums documentés

JWT security

Exemples success & errors

1️⃣4️⃣ E2E Tests (OBLIGATOIRES)

Script
bin/e2e/e2e_cra_lifecycle.sh

Scénario E2E canonique

Setup independent + 2 missions

Create CRA

Add entry (date D, mission A, quantity 0.5)

Add entry (date D, mission B, quantity 0.5)

Submit CRA

Lock CRA

Try modify → 409

Verify git commit exists

⚠️ Aucun mock
⚠️ HTTP réel uniquement

1️⃣5️⃣ Acceptance Criteria (Gherkin)
Scenario: Lock a CRA with multi-mission entries
  Given I am authenticated as independent
  And two missions exist
  When I create a CRA
  And I add entries on the same date for different missions
  And I submit the CRA
  And I lock the CRA
  Then the CRA is immutable
  And a Git commit exists

1️⃣6️⃣ Definition of Done

RSpec green

E2E green

Git versioning verified

Swagger OK

Rubocop / Brakeman OK

README updated

PR ready

1️⃣7️⃣ Test Strategy & TDD Contract (PLATINUM)
Principe général

Le développement de FC07 est soumis à un TDD strict et obligatoire.

Aucune implémentation n’est acceptée si elle n’est pas :

couverte par des tests automatisés

écrite après l’expression du comportement attendu

Hiérarchie des tests (OBLIGATOIRE)

Domain Tests (prioritaires)

Règles métier pures

Calculs (total_days, total_amount)

Unicité (cra_id, mission_id, date)

Lifecycle (draft → submitted → locked)

Interdictions de modification

❌ Aucun test de domaine ne doit dépendre :

du contrôleur

du routing

du HTTP

Service / Use-Case Tests

Lock transactionnel

Recalcul des totaux

GitLedgerService

Rollback en cas d’échec Git

Request Specs (API)

Contrats HTTP

Codes d’erreur

Payloads

E2E Tests (obligatoires)

Scénario canonique décrit en section 1️⃣4️⃣

Aucun mock

HTTP réel uniquement

Règles TDD non négociables

❌ Aucun code métier dans les contrôleurs

❌ Aucun test “happy-path only”

❌ Aucun mock de logique métier

✅ Tests écrits avant ou en même temps que le code

✅ Toute régression doit être couverte par un test reproduisant le bug

Critère de rejet automatique

Une PR FC07 est rejetée automatiquement si :

une règle métier n’est pas couverte par un test

un test contourne le domaine (ex: validation en contrôleur)

une règle est testée uniquement en E2E sans test de domaine

✅ ÉTAT FINAL
Axe	Statut
Architecture	🟢 Verrouillée
Réalisme métier	🟢 Conforme
Auditabilité	🟢 Totale
Git Ledger	🟢 Intégré
Scalabilité	🟢 Long terme
Qualité	🟢 Platinum

🤖 PROMPT MINIMAX-M2 — PLATINUM

FEATURE: CRA Management (FC07)

🔹 SYSTEM CONTEXT

You are a senior Ruby on Rails platform engineer.

You work on a Rails 8.1.1 API-only application, running in Docker.

Authentication is based on JWT tokens.

The system follows Domain-Driven Design and Relation-Driven Architecture:

Domain models are pure (no business foreign keys)

All relations are implemented via dedicated relation models

Aggregates are explicit

Auditability and determinism are mandatory

Security, correctness, immutability, and long-term auditability are non-negotiable.

You produce production-ready, CI-safe code.

🔹 FEATURE CONTRACT (SOURCE OF TRUTH)
FEATURE NAME

CRA Management (Compte Rendu d’Activité)

🎯 GOAL

Enable an Independent to:

Declare real activity per mission

Track produced time and value

Maintain a monthly, auditable, versioned CRA

Provide the functional base for:

Invoicing

Fiscal reporting

Long-term analytics

A CRA is a legal and contractual artifact, immutable once locked.

👤 ACTORS
Primary Actor

Authenticated User (JWT)

Business Preconditions

User belongs to a Company with role independent

Missions referenced are accessible to the user (FC06 rules)

Violations

Role incoherence → 403 forbidden

Mission not accessible → 404 not_found

🧱 ARCHITECTURAL PRINCIPLES (STRICT)

❌ No business foreign keys in Domain Models
✅ All relations via Relation Models

Domain entities are pure

Relations are auditable and versionable

CRA is the aggregate root

📦 DOMAIN MODELS (PURE)
CRA

Fields

id (UUID)

month (1–12)

year

status: draft | submitted | locked

description (Text, nullable) 🆕

total_days (Decimal, calculated)

total_amount (Integer, calculated)

currency (ISO 4217)

created_by_user_id (UUID) 🆕 (audit-only)

created_at

updated_at

locked_at

deleted_at (soft delete)

⚠️ No reference to Mission or Company
⚠️ created_by_user_id is audit-only, not a business relation

🆕 Description rules

Editable in draft

Editable in submitted

Frozen in locked

CRAEntry

Fields

id (UUID)

date (Date)

quantity (Decimal)

unit_price (Integer, cents)

description (Text)

created_at

updated_at

deleted_at

Quantity rules

Represents declared billable quantity

Unit: day

Granularity allowed (e.g. 0.25, 0.5, 1.0, 2.0)

No upper bound validation

No moral or time-based validation

⚠️ Domain-pure entity
⚠️ Backend must not enforce “≤ 1 day” constraints

🔗 RELATION MODELS (MANDATORY)
CRAMission

Fields

id

cra_id

mission_id

created_at

Constraints

A CRA can be linked to multiple missions

A mission can appear only once per CRA

🆕 Creation rule

CRAMission is created automatically

Triggered on the first CRAEntry linked to a mission

Centralized via a service (e.g. CraMissionLinker)

No dedicated endpoint is exposed

CRAEntryCRA

Fields

id

cra_id

cra_entry_id

created_at

CRAEntryMission

Fields

id

cra_entry_id

mission_id

created_at

Entry Constraints

A CRA may contain multiple entries on the same date

A date may be associated with multiple missions

A mission may appear multiple times across dates

✔ Multi-mission billing on the same date is allowed
✔ Over-billing is contractually allowed
✔ Empty dates are allowed

Strict uniqueness

(cra_id, mission_id, date)


Enforced via service-level validation

Cannot rely on a single DB index due to relation models

Violation → 409 duplicate_entry

🔁 CRA LIFECYCLE
Statuses

draft

submitted

locked

Allowed transitions

draft → submitted

submitted → locked

Rules

No rollback

No modification after locked

Violation → 422 invalid_transition

📜 BUSINESS RULES
Access

CRA accessible only if:

User ∈ company independent

Referenced missions are accessible (FC06)

Else → 404 not_found

Uniqueness

1 CRA max per (user, month, year)

Violation → 409 cra_already_exists

🆕 Database-level protection

Unique index on (created_by_user_id, month, year)

Scoped to deleted_at IS NULL

Prevents race conditions

Modification

draft → free modification

submitted → metadata only (non-financial)

locked → immutable

🆕 Metadata allowed in submitted

CRA-level description only

Violation → 409 cra_locked

Calculations (Server-side only)

total_days = Σ CRAEntry.quantity

total_amount = Σ(quantity × unit_price)

🆕 Totals must be recalculated

on entry create / update / delete

on submit

on lock

⚠️ Client values are never trusted

Deletion

Soft delete only

Forbidden if submitted or locked

Violation → 409 cra_in_use

🆕 Soft-delete cascade

Soft-deleting a CRA also soft-deletes:

CRAEntry

CRAMission

CRAEntryCRA

CRAEntryMission

🧬 GIT / VERSIONING CONTRACT (PLATINUM)

On CRA lock:

Serialize CRA into canonical JSON

Commit into internal Git repository

Commit is immutable

Git specs

Repository: cra-ledger

Branch: main

Local path: /app/cra-ledger

Repo auto-initialized if missing

Git identity (technical)

name: foresy-ledger

email: ledger@foresy.internal

Commit message

CRA locked — cra:{id} — {month}/{year}


Versioned payload

{
  "cra_id": "uuid",
  "month": 1,
  "year": 2025,
  "missions": ["uuid", "uuid"],
  "entries": [...],
  "totals": {
    "total_days": 1.0,
    "total_amount": 800
  }
}


Failure semantics

Git error → 500 internal_error

CRA remains unlocked

🆕 Transactional guarantee

CRA lock, totals recalculation and Git commit are executed in a single DB transaction

Any Git failure triggers a full rollback

🆕 Production — CTO DECISION CONFIRMED ✅
✅ Option A — Persistent Volume (Render Disk) MANDATORY

The /app/cra-ledger directory is mounted on persistent filesystem

Git commits MUST survive redeploys

Git Ledger constitutes durable, independent and enforceable audit proof

This configuration is mandatory in production.

Any loss of Git Ledger in production is considered a critical incident.

❌ Option B — Ephemeral Filesystem

Strictly forbidden in production

Allowed only for:

MVP

DEV

STAGING

⚠️ Option B cannot be used in production under any circumstance.

🌐 API SCOPE
CRA Endpoints

POST /api/v1/cras

GET /api/v1/cras 🆕 (paginated)

GET /api/v1/cras/:id

PATCH /api/v1/cras/:id

DELETE /api/v1/cras/:id 🆕 (soft delete)

POST /api/v1/cras/:id/submit

POST /api/v1/cras/:id/lock

🆕 Pagination contract

Params:

page (default 1)

per_page (default 20)

Response shape:

{
  "data": [...],
  "meta": {
    "total": 120,
    "page": 1,
    "per_page": 20
  }
}

🆕 CRAEntry Endpoints

POST /api/v1/cras/:cra_id/entries

GET /api/v1/cras/:cra_id/entries

PATCH /api/v1/cras/:cra_id/entries/:id

DELETE /api/v1/cras/:cra_id/entries/:id

🧪 E2E TESTS (MANDATORY)

Script:

bin/e2e/e2e_cra_lifecycle.sh


Canonical E2E scenario:

Setup independent + two missions

Create CRA

Add entry (date D, mission A, quantity 0.5)

Add entry (date D, mission B, quantity 0.5)

Submit CRA

Lock CRA

Attempt modification → 409

Verify Git commit exists

Constraints:

No mocks

Real HTTP calls only

CI-safe

Deterministic

✅ ACCEPTANCE CRITERIA (GHERKIN)

Scenario: Lock a CRA with multi-mission entries

Given I am authenticated as independent
And two missions exist
When I create a CRA
And I add entries on the same date for different missions
And I submit the CRA
And I lock the CRA
Then the CRA is immutable
And a Git commit exists

🔧 TASK

Implement full backend support for CRA Management strictly following this contract.

Requirements:

Rails models

Relation models

Controllers

Validations

Lifecycle enforcement

Git ledger integration

Swagger / OpenAPI

RSpec tests

E2E script

🧪 TEST STRATEGY — TDD STRICT (PLATINUM) 🆕
Mandatory TDD Contract

This feature MUST be implemented using strict Test-Driven Development (TDD).

No production code is acceptable unless:

the expected behavior is first expressed as a test

the test fails before implementation

the test passes after implementation

Test Hierarchy (NON-NEGOTIABLE)
1️⃣ Domain Specs

CRA lifecycle

Entry uniqueness

Totals calculation

Immutability

Soft-delete rules

❌ No HTTP
❌ No controllers
❌ No mocks of domain logic

2️⃣ Service / Use-Case Specs

Entry services

CraMissionLinker

Transactional CRA lock

GitLedgerService rollback on failure

3️⃣ Request Specs

All endpoints

Error codes and payloads

Controllers delegate to services only

4️⃣ E2E Tests

Real HTTP

Real DB

Real Git

No mocks

Forbidden Practices

Business logic in controllers

Skipping domain specs

Mocking domain behavior

Fixing bugs without tests

Acceptance Gate

PR must be rejected if:

Any business rule lacks a domain spec

Git transactionality is not test-covered

Lifecycle rules are only tested via HTTP

📤 OUTPUT FORMAT

Return:

Production-ready code

E2E script

Swagger schemas

Do NOT:

Add undocumented features

Change lifecycle rules

Add foreign keys to domain models

Mock anything
