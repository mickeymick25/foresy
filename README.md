# Foresy

Foresy est une application Ruby on Rails qui fournit une API RESTful pour la gestion des utilisateurs avec authentification JWT.

## Fonctionnalités

- Authentification des utilisateurs avec JWT
- Système de rafraîchissement des jetons
- Documentation API avec Swagger
- Gestion des utilisateurs (inscription, connexion)
- Invalidation de toutes les sessions actives d'un utilisateur (seules les sessions actives sont concernées)

## 🚀 Améliorations Récentes & État du Code

### 📊 Qualité du Code (Octobre 2024)

**Statut :** Code 100% conforme aux standards RuboCop
- ✅ **0 offense RuboCop** dans tout le projet
- ✅ **94 tests RSpec** qui passent (0 échec)
- ✅ **Refactorisation complète** du contrôleur d'authentification
- ✅ **Architecture optimisée** et maintenable

### 🔧 Refactorisations Effectuées

**AuthenticationController (`app/controllers/api/v1/authentication_controller.rb`) :**
- ✅ **find_or_create_user_from_auth** : Divisée en 5 méthodes plus petites (complexité ABC 45.06 → 0)
- ✅ **login** : Refactorisée avec méthodes auxiliaires (complexité ABC 28.71 → 0)
- ✅ **oauth_callback** : Optimisée et divisée (complexité ABC 18.49 → 0)
- ✅ **extract_auth_data** : Simplifiée et optimisée (longueur 13 lignes → 0)
- ✅ **Documentation** : Ajoutée pour la classe et les modules

### 🧪 Tests & Validation

**Couverture de Tests Complète :**
- **Authentification JWT** : Login, logout, token refresh ✅
- **OAuth** : Google OAuth2 & GitHub ✅
- **Gestion des sessions** : Création, expiration, invalidation ✅
- **API REST** : Tous les endpoints fonctionnels ✅
- **Modèles** : User, Session avec validations complètes ✅

### 🏗️ Architecture

**Améliorations Structurelles :**
- Code modulaire avec méthodes spécialisées
- Séparation claire des responsabilités
- Meilleure lisibilité et maintenabilité
- Standards Rails & Ruby respectés

**Résultat :** Transformation complète d'un code complexe vers un code de qualité production, entièrement testé et conforme aux meilleures pratiques.

## Prérequis

- Ruby 3.2.2
- Rails 7.1.0
- PostgreSQL
- Docker et Docker Compose (optionnel)

## Installation

1. Cloner le dépôt :
   ```bash
   git clone https://github.com/votre-username/foresy.git
   cd foresy
   ```

2. Installer les dépendances :
   ```bash
   bundle install
   ```

3. Configurer la base de données :
   ```bash
   cp config/database.yml.example config/database.yml
   # Éditer config/database.yml avec vos paramètres
   ```

4. Créer et migrer la base de données :
   ```bash
   rails db:create db:migrate
   ```

5. Démarrer le serveur :
   ```bash
   rails server
   ```

## Utilisation avec Docker

1. Construire les images :
   ```bash
   docker-compose build
   ```

2. Démarrer les conteneurs :
   ```bash
   docker-compose up
   ```

## Documentation API

La documentation Swagger est disponible à l'adresse :
```
http://localhost:3000/api-docs
```

## Tests

Pour exécuter les tests :

### Avec Docker Compose (recommandé)
```bash
docker-compose up test
```

Ou pour plus de détails :
```bash
docker-compose run --rm test bundle exec rspec --format documentation
```

### En local
```bash
bundle exec rspec
```

### Linter (RuboCop)
```bash
bundle exec rubocop
```

Ou avec Docker :
```bash
docker-compose run --rm test bundle exec rubocop
```

## Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

## Endpoints d'authentification

### Inscription (signup)

**POST** `/api/v1/signup`

Ce endpoint permet de créer un nouvel utilisateur sans authentification préalable.

**Corps attendu :**
```json
{
  "email": "user@example.com",
  "password": "votre_mot_de_passe",
  "password_confirmation": "votre_mot_de_passe"
}
```

**Réponses possibles :**
- `201 Created` :
  ```json
  {
    "token": "<access_token>",
    "email": "user@example.com"
  }
  ```
- `422 Unprocessable Entity` :
  ```json
  {
    "errors": ["Email has already been taken", ...]
  }
  ```

### Rafraîchissement du token (refresh)

**POST** `/api/v1/auth/refresh`

**Corps attendu :**
```json
{
  "refresh_token": "<votre_refresh_token>"
}
```

**Réponses possibles :**
- `200 OK` :
  ```json
  {
    "token": "<nouveau_token>",
    "refresh_token": "<nouveau_refresh_token>",
    "email": "user@example.com"
  }
  ```
- `401 Unauthorized` :
  - Si le refresh token est manquant ou vide :
    ```json
    { "error": "refresh token missing or invalid" }
    ```
  - Si le refresh token est invalide ou expiré (y compris expiré) :
    ```json
    { "error": "invalid or expired refresh token" }
    ```

**Cas limite testé :**
- Un utilisateur tentant de rafraîchir un token avec un refresh_token expiré reçoit bien l'erreur ci-dessus.

**Remarque :**
Le paramètre `refresh_token` peut être transmis à la racine du corps JSON ou imbriqué dans un objet `authentication` selon le client. L'API gère les deux cas.

**Sécurité supplémentaire :**
Depuis la version actuelle, un refresh_token n'est accepté que si l'utilisateur possède au moins une session active. Si toutes les sessions de l'utilisateur ont été invalidées (par exemple via une déconnexion globale), le refresh_token est refusé même s'il n'est pas expiré.

### Déconnexion (logout)

**DELETE** `/api/v1/auth/logout`

**Headers requis :**
- `Authorization: Bearer <token>`

**Réponses possibles :**
- `200 OK` :
  ```json
  { "message": "Logged out successfully" }
  ```
- `401 Unauthorized` :
  ```json
  { "error": "No active session" }
  ```
- `401 Unauthorized` :
  ```json
  { "error": "Invalid token" }
  ```
- `422 Unprocessable Entity` :
  ```json
  { "error": "Session already expired" }
  ```

**Cas limite testé :**
- Une tentative de logout avec un token dont la session n'existe plus retourne bien l'erreur "Invalid token".

## Sécurité des tokens

- **Access token** : durée de vie de **15 minutes** (900 s).  
- **Refresh token** : durée de vie de **30 jours** (2 592 000 s).  
- Un refresh_token n'est accepté que si l'utilisateur possède au moins une session active. Si toutes les sessions sont invalidées (logout global), le refresh_token est refusé même s'il n'est pas expiré.  
- Toute tentative d'accès avec un token invalide ou expiré retourne une erreur explicite (401 ou 422). La gestion d'erreur côté API est robuste pour éviter toute fuite d'information ou plantage.  
- La logique d'authentification a été refactorisée pour séparer la gestion des access tokens (pour les endpoints protégés) et des refresh tokens (pour le renouvellement).

## Authentification : gestion des codes de retour

- **200 OK** : Succès (login, refresh, logout si la session est active)
- **401 Unauthorized** : Token invalide ou session supprimée
- **422 Unprocessable Entity** : Session expirée (mais toujours présente en base)

### Exemples de scénarios
- Si un utilisateur tente de se déconnecter avec une session expirée, l'API retourne 422.
- Si la session a été supprimée (ou n'existe pas), l'API retourne 401.
- Après un logout, si on réutilise le même token, la première requête retourne 422 (session expirée), la suivante 401 (session supprimée).

Voir les tests dans `spec/requests/api/v1/authentication_spec.rb` pour des exemples précis.
