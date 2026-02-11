# GitHub Actions Workflows

## 🚀 CI/CD Pipeline

Le projet utilise un workflow GitHub Actions principal : `ci.yml`

### Jobs Principaux

- **🧪 tests** - Tests RSpec et coverage
- **🔒 security** - Brakeman + Bundle audit  
- **🎨 lint** - RuboCop linting
- **📖 contracts** - RSwag API validation
- **🧪 e2e** - Tests end-to-end (PR uniquement)
- **🚀 quality-gate** - Validation finale

### Triggers

- Push vers `main` et `develop`
- Pull Request vers `main`

### Configuration

Secrets requis dans GitHub Repository Settings :
- `SECRET_KEY_BASE`
- `JWT_SECRET`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `LOCAL_GITHUB_CLIENT_ID`
- `LOCAL_GITHUB_CLIENT_SECRET`

### Monitoring

- Status des workflows : `Repository → Actions`
- Logs détaillés disponibles pour chaque exécution
- Artifacts générés automatiquement

### Architecture

Clean Architecture : 1 job = 1 responsabilité, 0 duplication

---

*Pour plus de détails, consultez la documentation technique principale du projet.*