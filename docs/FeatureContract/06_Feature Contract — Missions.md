🧾 FEATURE CONTRACT 06 — MISSIONS

(Domain-Driven / Relation-Driven Architecture)

⚠️ DOCUMENT CONTRACTUEL — SOURCE DE VÉRITÉ
⚠️ Toute ambiguïté DOIT être signalée avant implémentation
⚠️ Aucune déviation autorisée

1️⃣ Feature Name

Mission Management

2️⃣ Business Goal

Permettre à un Indépendant de :

créer et gérer ses missions professionnelles

structurer son activité contractuelle

fournir le socle fonctionnel du CRA, de la facturation et du pilotage fiscal

disposer d’un historique fiable, auditable et versionnable de ses engagements

👉 Une Mission représente un contrat opérationnel entre :

une entreprise représentée par l’indépendant

une entreprise cliente

Une mission peut exister sans représentant humain côté client.

3️⃣ Actors
Primary Actor

Authenticated User (JWT)

Pré-requis métier

L’utilisateur peut être lié à une ou plusieurs Company

Chaque lien User ↔ Company porte un rôle

Les rôles possibles sont :

independent

client

⚠️ La gestion des rôles utilisateurs est hors scope de ce feature.

🔐 Règle fondamentale d’accès (verrouillée)

La capacité de créer / voir / modifier une Mission dépend du rôle de la Company de l’utilisateur vis-à-vis de la Mission.

Un utilisateur peut :

être independent sur certaines missions

être client sur d’autres

cumuler les deux rôles via des companies distinctes

Accès autorisé si et seulement si :

l’utilisateur appartient à une Company

cette Company est liée à la Mission via MissionCompany

avec un rôle independent ou client

Toute autre tentative d’accès → 404 not_found

4️⃣ Architectural Principles (NON NÉGOCIABLES)
🧱 Domain-Driven / Relation-Driven Rule

❌ Aucune clé étrangère métier dans les Domain Models

✅ Toutes les relations passent par des tables dédiées

Principes

Les entités métier sont pures

Les relations sont :

explicites

auditables

versionnables

5️⃣ Domain Models (purs)
Mission
Champ	Type	Required	Notes
id	UUID	Yes
name	String	Yes
description	Text	No
mission_type	Enum	Yes	time_based | fixed_price
status	Enum	Yes	Voir lifecycle
start_date	Date	Yes
end_date	Date	No	Peut être ouverte
daily_rate	Integer	Conditional	Obligatoire si time_based
fixed_price	Integer	Conditional	Obligatoire si fixed_price
currency	String	Yes	ISO 4217 — défaut EUR
created_at	DateTime	Yes
updated_at	DateTime	Yes
deleted_at	DateTime	No	Soft delete

⚠️ Aucune référence vers Company ou User

6️⃣ Relation Models (OBLIGATOIRES)
MissionCompany
Champ	Type	Required	Notes
id	UUID	Yes
mission_id	UUID	Yes
company_id	UUID	Yes
role	Enum	Yes	independent | client
created_at	DateTime	Yes
🔒 Contraintes structurelles

Une Mission DOIT avoir :

exactement 1 Company independent

au plus 1 Company client (optionnelle au moment de la création)

7️⃣ Mission Lifecycle (Status)
Enum strict

lead

pending

won

in_progress

completed

Transitions autorisées (MVP)

lead → pending

pending → won

won → in_progress

in_progress → completed

⚠️ Pas de retour arrière
⚠️ Aucune transition automatique
⚠️ Toute transition invalide → 422 invalid_transition

8️⃣ Business Rules & Constraints
🧑‍💼 Ownership & Access

L’accès à une mission est autorisé uniquement si :

l’utilisateur appartient à une Company

liée à la Mission avec le rôle independent ou client

Toute tentative d’accès sans rôle → 404 not_found

🏗️ Création d’une Mission

Une Mission NE PEUT être créée que si :

une Company independent existe

l’utilisateur y est rattaché

Cas supporté MVP :

Mission créée par un independent

La Company client :

peut exister sans utilisateur

est optionnelle à la création

est liée uniquement via MissionCompany

✏️ Modification d’une Mission
Droit de modification (MVP)

Seul le créateur de la Mission peut la modifier

Créateur possible :

independent

(création côté client prévue ultérieurement)

Champs modifiables
Avant won

Tous les champs sont modifiables

Après won (Option A)

Les champs contractuels restent modifiables

Toute modification post-won :

est considérée sensible

n’est pas bloquée

peut déclencher une notification (voir ci-dessous)

🔔 Notifications post-won

Une notification est envoyée uniquement si :

une Company client est liée

un représentant client existe

un email client est présent

Sinon :

aucune notification

aucune erreur

comportement silencieux

📐 Mission Type Rules
time_based

daily_rate requis

fixed_price interdit

fixed_price

fixed_price requis

daily_rate interdit

Violation → 422 invalid_payload

📅 Dates

start_date ≤ end_date

end_date optionnelle

Violation → 422 invalid_payload

🗑️ Suppression

Suppression logique uniquement (deleted_at)

Si la mission est liée à un CRA :

❌ suppression interdite

✅ archivage uniquement

Violation → 409 mission_in_use

9️⃣ API Scope
Method	Endpoint	Description
POST	/api/v1/missions	Créer une mission
GET	/api/v1/missions	Lister
GET	/api/v1/missions/:id	Détail
PATCH	/api/v1/missions/:id	Modifier
DELETE	/api/v1/missions/:id	Archiver
🔟 Inputs / Outputs
POST /api/v1/missions
{
  "name": "Mission Data Platform",
  "description": "Backend architecture",
  "mission_type": "time_based",
  "status": "won",
  "start_date": "2025-01-01",
  "daily_rate": 600,
  "currency": "EUR",
  "client_company_id": "uuid"
}


⚠️ client_company_id est utilisé uniquement pour créer la relation MissionCompany

Success — 201
{
  "id": "uuid",
  "name": "Mission Data Platform",
  "status": "won",
  "mission_type": "time_based"
}

1️⃣1️⃣ Errors
Status	Code	Description
401	unauthorized	JWT invalide
403	forbidden	User sans Company independent ou sans Company active
404	not_found	Mission inaccessible (aucun rôle)
422	invalid_payload	Validation métier
422	invalid_transition	Transition interdite
409	mission_in_use	Mission liée à un CRA
500	internal_error
1️⃣2️⃣ Swagger / OpenAPI Requirements

Schéma Mission

Schéma MissionCompany

Enums documentés

Exemples success & error

JWT security scheme

1️⃣3️⃣ Acceptance Criteria (Gherkin)
Feature: Mission management

Scenario: Create a time-based mission
  Given I am authenticated as an independent
  And my company is linked as independent
  When I create a mission with type time_based
  Then the mission is created successfully

Scenario: Prevent fixed_price without price
  When I create a fixed_price mission without fixed_price
  Then I receive a 422 error

Scenario: Access another company mission
  When I fetch a mission I do not belong to
  Then I receive a 404 response

1️⃣4️⃣ Definition of Done

RSpec green

Swagger auto-generated

Rubocop OK

Brakeman OK

README updated

PR ready to merge

✅ ÉTAT FINAL
Axe	Statut
Architecture	🟢 Verrouillée
Domain purity	🟢 Respectée
Relation-driven	🟢 Appliquée
Scalabilité	🟢 Long terme
Qualité	🏆 PLATINUM

🤖 PROMPT MINIMAX-M2 — PLATINUM
Feature: Mission Management (FC06)
🔹 SYSTEM CONTEXT

You are a senior Ruby on Rails platform engineer.

You work on a Rails 8.1.1 API-only application, running in Docker, using PostgreSQL.

Authentication is based on JWT tokens.

The system follows Domain-Driven Design and Relation-Driven Architecture.

Non-negotiable principles:

Domain models MUST remain pure

NO business foreign keys in domain models

ALL relations MUST be modeled via explicit relation tables

Security, correctness, determinism and auditability are mandatory

You produce production-ready, CI-safe code.

🔹 FEATURE CONTRACT (SOURCE OF TRUTH)

FEATURE NAME: Mission Management

This prompt MUST be implemented strictly according to the following contract.
Any ambiguity MUST be flagged before implementation.
NO deviation is allowed.

🔹 BUSINESS GOAL

Enable an Independent to:

create and manage professional missions

structure contractual activity

provide the functional base for CRA, billing and fiscal reporting

maintain a reliable, auditable and future-versionable history of engagements

A Mission represents an operational contract between:

an independent company

a client company

A mission MAY exist without a human representative on the client side.

🔹 ACTORS & ACCESS MODEL
Primary Actor

Authenticated User (JWT)

Role model

A user can belong to one or more Companies

Each User ↔ Company relation carries a role:

independent

client

Role management is OUT OF SCOPE.

Fundamental access rule (LOCKED)

Access to create / view / update a Mission is allowed if and only if:

the user belongs to a Company

this Company is linked to the Mission

via MissionCompany

with role independent OR client

Any other access attempt MUST return 404 not_found.

🔹 ARCHITECTURAL RULES (NON NEGOTIABLE)

❌ NO foreign keys to Company or User in Mission

✅ ALL relationships via relation tables

Domain models MUST be pure

Relations MUST be explicit, auditable and versionable

🔹 DOMAIN MODELS (PURE)
Mission
Field	Type	Required
id	UUID	Yes
name	String	Yes
description	Text	No
mission_type	Enum	Yes (time_based, fixed_price)
status	Enum	Yes
start_date	Date	Yes
end_date	Date	No
daily_rate	Integer	Conditional
fixed_price	Integer	Conditional
currency	String	Yes (ISO 4217, default EUR)
created_at	DateTime	Yes
updated_at	DateTime	Yes
deleted_at	DateTime	No (soft delete)

⚠️ MUST NOT reference Company or User.

🔹 RELATION MODELS (MANDATORY)
MissionCompany
Field	Type	Required
id	UUID	Yes
mission_id	UUID	Yes
company_id	UUID	Yes
role	Enum	Yes (independent, client)
created_at	DateTime	Yes
Structural constraints

A Mission MUST have:

exactly 1 independent Company

at most 1 client Company (optional at creation)

🔹 MISSION LIFECYCLE
Status enum (STRICT)

lead

pending

won

in_progress

completed

Allowed transitions (MVP only)

lead → pending

pending → won

won → in_progress

in_progress → completed

Rules:

NO rollback

NO automatic transitions

Invalid transition → 422 invalid_transition

🔹 BUSINESS RULES
Mission creation

A Mission CAN be created ONLY IF:

an independent Company exists

the user belongs to it

MVP scope:

creation by independent only

client company optional

client may exist without any user

Mission modification
Who can modify

ONLY the creator of the Mission (MVP)

Creator is currently always the independent

Editable fields

Before won: all fields editable

After won (Option A):

contract fields remain editable

modification is allowed

modification is considered sensitive

Post-WON notifications

A notification MUST be sent ONLY IF:

a client company is linked

a client representative exists

a client email is present

Otherwise:

NO notification

NO error

silent behavior

Mission type rules
time_based

daily_rate REQUIRED

fixed_price FORBIDDEN

fixed_price

fixed_price REQUIRED

daily_rate FORBIDDEN

Violation → 422 invalid_payload

Date rules

start_date ≤ end_date

end_date optional

Violation → 422 invalid_payload

Deletion

Soft delete only

If Mission is linked to a CRA:

deletion FORBIDDEN

archive ONLY

Violation → 409 mission_in_use

🔹 API SCOPE
Method	Endpoint
POST	/api/v1/missions
GET	/api/v1/missions
GET	/api/v1/missions/:id
PATCH	/api/v1/missions/:id
DELETE	/api/v1/missions/:id
🔹 ERROR CONTRACT
HTTP	Code	Meaning
401	unauthorized	Invalid JWT
403	forbidden	No independent company / no active company
404	not_found	Mission inaccessible (no role)
422	invalid_payload	Business validation
422	invalid_transition	Lifecycle violation
409	mission_in_use	Linked CRA
500	internal_error
🔹 OPENAPI REQUIREMENTS

Mission schema

MissionCompany schema

All enums documented

Success & error examples

JWT security scheme

🔹 ACCEPTANCE CRITERIA (Gherkin)
Feature: Mission management

Scenario: Create a time-based mission
  Given I am authenticated as an independent
  And my company is linked as independent
  When I create a mission with type time_based
  Then the mission is created successfully

Scenario: Prevent fixed_price without price
  When I create a fixed_price mission without fixed_price
  Then I receive a 422 error

Scenario: Access another company mission
  When I fetch a mission I do not belong to
  Then I receive a 404 response

🔹 TASK

Implement the Mission Management feature strictly according to this contract.

Constraints

DO NOT modify existing authentication logic

DO NOT add business foreign keys to domain models

DO NOT bypass relation tables

DO NOT mock business rules

Quality Bar

RSpec MUST be green

Swagger MUST be generated

Rubocop MUST pass

Brakeman MUST pass

Code MUST be production-ready

🔹 OUTPUT FORMAT

Return:

The complete implementation

OR explicitly list blocking ambiguities

Do NOT:

add explanations

add commentary

diverge from the contract
