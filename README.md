# Foresy

Foresy est une application Ruby on Rails qui fournit une API RESTful pour la gestion des utilisateurs avec authentification JWT.

## Fonctionnalités

- Authentification des utilisateurs avec JWT
- Système de rafraîchissement des jetons
- Documentation API avec Swagger
- Gestion des utilisateurs (inscription, connexion)
- Invalidation de toutes les sessions actives d'un utilisateur (seules les sessions actives sont concernées)

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
```bash
rails test
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

- **Access token** : durée de vie de 1 heure (1h)
- **Refresh token** : durée de vie de 7 jours (7j)
- Un refresh_token n'est accepté que si l'utilisateur possède au moins une session active. Si toutes les sessions sont invalidées (logout global), le refresh_token est refusé même s'il n'est pas expiré.
- Toute tentative d'accès avec un token invalide ou expiré retourne une erreur explicite (401 ou 422). La gestion d'erreur côté API est robuste pour éviter toute fuite d'information ou plantage.
- La logique d'authentification a été refactorisée pour séparer la gestion des access tokens (pour les endpoints protégés) et des refresh tokens (pour le renouvellement).
