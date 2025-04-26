# Foresy

Foresy est une application Ruby on Rails qui fournit une API RESTful pour la gestion des utilisateurs avec authentification JWT.

## Fonctionnalités

- Authentification des utilisateurs avec JWT
- Système de rafraîchissement des jetons
- Documentation API avec Swagger
- Gestion des utilisateurs (inscription, connexion)

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
  - Si le refresh token est invalide ou expiré :
    ```json
    { "error": "invalid or expired refresh token" }
    ```

**Remarque :**
Le paramètre `refresh_token` peut être transmis à la racine du corps JSON ou imbriqué dans un objet `authentication` selon le client. L'API gère les deux cas.
