
# Patterns de Corrections E2E - Documentation Complète

**Date:** 2026-01-10  
**Version:** 1.0  
**Auteur:** Platform Engineering Team  
**Statut:** Documentation pour Phase 1 PR15 - Template et Patterns  

---

## 🎯 Objectif

Cette documentation recense les patterns de correction identifiés lors de l'analyse des scripts E2E du projet Foresy. Elle sert de référence pour éviter les erreurs communes et améliorer la robustesse des tests bout-en-bout.

**Référentiel principal:** `bin/e2e/e2e_cra_lifecycle_fc07.sh`

---

## 📋 Table des Patterns

1. [Format de Dates](#1-format-de-dates)
2. [Parsing JSON](#2-parsing-json)
3. [Comparaison de Valeurs](#3-comparaison-de-valeurs)
4. [Gestion des UUIDs](#4-gestion-des-uuids)
5. [Gestion des Erreurs](#5-gestion-des-erreurs)
6. [Timeouts et Synchronisation](#6-timeouts-et-synchronisation)
7. [Validation de Réponses](#7-validation-de-réponses)

---

## 1. Format de Dates

### ❌ **Pattern Erroné**
```bash
# Problème: Format avec zéros de tête
current_month=$(date +%m)  # Donne "01", "02", ..., "12"
current_day=$(date +%d)    # Donne "01", "02", ..., "31"

# Utilisation dans requête JSON
{
  "month": "$current_month",
  "day": "$current_day"
}

# Résultat: "month": "01" (string avec zéro de tête)
```

### ✅ **Pattern Correct**
```bash
# Solution: Format sans zéros de tête
current_month=$(date +%-m)  # Donne 1, 2, ..., 12 (integer)
current_day=$(date +%-d)    # Donne 1, 2, ..., 31 (integer)
current_year=$(date +%Y)     # Donne 2025, 2026, etc.

# Utilisation dans requête JSON
{
  "month": $current_month,    # "month": 1 (integer)
  "day": $current_day,        # "day": 15 (integer)
  "year": $current_year       # "year": 2025 (integer)
}

# Résultat: Types corrects dans JSON
```

### 📝 **Explication**
- Les APIs REST attendent généralement des entiers pour les dates
- Les zéros de tête causent des erreurs de validation de schéma
- `%-m` et `%-d` supprimenent les zéros de tête sur les systèmes GNU
- Compatibilité: Tester sur macOS (BSD) vs Linux (GNU)

### 🔧 **Implémentation Robuste**
```bash
# Fonction portable pour obtenir le mois courant
get_current_month() {
    local month
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS (BSD)
        month=$(date +%-m)
    else
        # Linux (GNU)
        month=$(date +%-m)
    fi
    echo $month
}

# Utilisation
current_month=$(get_current_month)
```

---

## 2. Parsing JSON

### ❌ **Pattern Erroné**
```bash
# Problème: Chemins JSON incomplets
response='{"data":{"entry":{"id":"123","total":1000}}}'

# Tentatives de parsing
id=$(echo $response | jq -r '.id')                              # null
total=$(echo $response | jq -r '.total')                       # null
entry_id=$(echo $response | jq -r '.data.entry.id')            # Erreur
```

### ✅ **Pattern Correct**
```bash
# Solution: Chemins JSON complets et robustes
response='{"data":{"entry":{"id":"123","total":1000,"line_total":500}}}'

# Parsing avec chemins complets
entry_id=$(echo $response | jq -r '.data.entry.id')           # "123"
total_amount=$(echo $response | jq -r '.data.entry.total')     # "1000"
line_total=$(echo $response | jq -r '.data.entry.line_total')  # "500"

# Pour les objets complexes
cra_data=$(echo $response | jq -r '.data.cra')
entries_count=$(echo $response | jq -r '.data.cra.entries | length')

# Validation de la structure
if [[ "$entry_id" == "null" || -z "$entry_id" ]]; then
    echo "Erreur: entry_id manquant dans la réponse"
    exit 1
fi
```

### 📝 **Fonction Helper Standardisée**
```bash
# Fonction pour parser JSON de manière robuste
parse_json() {
    local response="$1"
    local path="$2"
    local default_value="${3:-}"
    
    local value
    value=$(echo "$response" | jq -r "$path")
    
    # Vérifier si la valeur est valide
    if [[ "$value" == "null" || -z "$value" ]]; then
        echo "$default_value"
        return 1
    fi
    
    echo "$value"
    return 0
}

# Utilisation
response='{"data":{"cra":{"id":"456","total_days":1.5}}}'

cra_id=$(parse_json "$response" '.data.cra.id' "")
total_days=$(parse_json "$response" '.data.cra.total_days' "0")

if [[ -z "$cra_id" ]]; then
    echo "Erreur: Impossible de récupérer l'ID du CRA"
    exit 1
fi
```

---

## 3. Comparaison de Valeurs

### ❌ **Pattern Erroné**
```bash
# Problème: Comparaison directe de chaînes pour des nombres
actual="1.5"
expected="1.5"

if [[ "$actual" == "$expected" ]]; then
    echo "Match!"  # Fonctionne pour cette valeur
else
    echo "No match!"
fi

# Problème avec les nombres décimaux
actual="1.500000"
expected="1.5"

if [[ "$actual" == "$expected" ]]; then
    echo "Match!"  # Ne fonctionne pas !
else
    echo "No match!"  # Ceci sera affiché
fi
```

### ✅ **Pattern Correct**
```bash
# Solution: Conversion en entiers pour éviter les problèmes de précision
expected_int=$((expected))
actual_int=$(echo "$actual" | cut -d'.' -f1)

if [[ "$actual_int" == "$expected_int" ]]; then
    echo "Match confirmé!"
else
    echo "Différence détectée: $actual_int vs $expected_int"
fi

# Pour les montants en centimes (précision exacte)
amount_cents=150000  # 1500.00€ en centimes
expected_cents=150000

if [[ $amount_cents -eq $expected_cents ]]; then
    echo "Montants identiques (en centimes)"
else
    echo "Différence: $amount_cents vs $expected_cents"
fi

# Fonction de comparaison robuste
compare_floats() {
    local actual="$1"
    local expected="$2"
    local tolerance="${3:-0.001}"
    
    # Convertir en nombres pour la comparaison
    actual_num=$(echo "$actual" | bc -l)
    expected_num=$(echo "$expected" | bc -l)
    
    # Calculer la différence
    diff=$(echo "$actual_num - $expected_num" | bc -l)
    abs_diff=$(echo "if ($diff < 0) -$diff else $diff" | bc -l)
    
    # Comparer avec la tolérance
    if (( $(echo "$abs_diff < $tolerance" | bc -l) )); then
        return 0  # Match
    else
        return 1  # No match
    fi
}

# Utilisation
if compare_floats "1.500001" "1.5" "0.0001"; then
    echo "Valeurs identiques dans la tolérance"
fi
```

### 📝 **Gestion des Montants en Centimes**
```bash
# Pattern spécifique pour les montants financiers
assert_amount_equals() {
    local actual_cents="$1"
    local expected_cents="$2"
    local context="$3"
    
    if [[ $actual_cents -eq $expected_cents ]]; then
        echo "✅ $context: $actual_cents centimes (correct)"
    else
        echo "❌ $context: $actual_cents vs $expected_cents centimes (erreur)"
        exit 1
    fi
}

# Utilisation
line_total=30000  # 300€ en centimes
expected_total=30000

assert_amount_equals "$line_total" "$expected_total" "Line total calculation"
```

---

## 4. Gestion des UUIDs

### ❌ **Pattern Erroné**
```bash
# Problème: Conversion d'UUID en entier
mission_id="550e8400-e29b-41d4-a716-446655440000"

# Tentative de conversion erronée
mission_id_int=$(echo $mission_id | tr -d '-')  # 550e8400e29b41d4a716446655440000
mission_id_final=$((mission_id_int))           # Erreur: nombre trop grand

# Utilisation dans requête API
curl -X POST "$API_URL/api/v1/cras/$mission_id_int/entries"  # Erreur 404
```

### ✅ **Pattern Correct**
```bash
# Solution: Conservation des UUIDs en tant que chaînes
mission_id="550e8400-e29b-41d4-a716-446655440000"

# Validation du format UUID
if [[ $mission_id =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]]; then
    echo "UUID valide: $mission_id"
else
    echo "UUID invalide: $mission_id"
    exit 1
fi

# Utilisation directe en tant que chaîne
curl -X POST "$API_URL/api/v1/cras/$mission_id/entries" \
     -H "Authorization: Bearer $token" \
     -H "Content-Type: application/json" \
     -d '{"date":"2025-01-15","quantity":0.5,"unit_price":60000}'

# Génération d'UUIDs de test
generate_test_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        # Linux/macOS
        uuidgen
    else
        # Fallback: Python
        python3 -c "import uuid; print(uuid.uuid4())"
    fi
}

# Utilisation
test_uuid=$(generate_test_uuid)
```

### 📝 **Validation et Génération Robuste**
```bash
# Fonction complète de gestion des UUIDs
validate_and_use_uuid() {
    local uuid="$1"
    local context="$2"
    
    # Validation du format
    if [[ ! $uuid =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]]; then
        echo "❌ UUID invalide dans $context: $uuid"
        exit 1
    fi
    
    echo "✅ UUID valide dans $context: $uuid"
    echo "$uuid"  # Retourner l'UUID validé
}

# Fonction pour extraire des UUIDs depuis une réponse JSON
extract_uuid_from_response() {
    local response="$1"
    local path="$2"
    local context="$3"
    
    local uuid
    uuid=$(echo "$response" | jq -r "$path")
    
    validate_and_use_uuid "$uuid" "$context"
}

# Utilisation
mission_id=$(extract_uuid_from_response "$response" '.data.mission.id' "Mission creation")
```

---

## 5. Gestion des Erreurs

### ❌ **Pattern Erroné**
```bash
# Problème: Gestion d'erreur insuffisante
response=$(curl -s -w "%{http_code}" -X POST "$API_URL/api/v1/cras" \
     -H "Authorization: Bearer $token" \
     -H "Content-Type: application/json" \
     -d '{"month":1,"year":2025}')

http_code="${response: -3}"
body="${response%???}"

if [[ "$http_code" != "201" ]]; then
    echo "Erreur HTTP: $http_code"
    echo "Réponse: $body"
    # Le script continue quand même !
fi

# Utilisation de données potentiellement invalides
cra_id=$(echo $body | jq -r '.data.cra.id')
echo "CRA ID: $cra_id"  # Peut être "null"
```

### ✅ **Pattern Correct**
```bash
# Solution: Gestion d'erreur robuste et immédiate
make_api_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local expected_status="$4"
    local context="$5"
    
    # Exécution de la requête
    local response
    local http_code
    
    response=$(curl -s -w "\n%{http_code}" -X "$method" "$endpoint" \
         -H "Authorization: Bearer $token" \
         -H "Content-Type: application/json" \
         -d "$data")
    
    # Extraction du code HTTP et du corps
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    # Validation du statut HTTP
    if [[ "$http_code" != "$expected_status" ]]; then
        echo "❌ Erreur HTTP $http_code dans $context"
        echo "Endpoint: $method $endpoint"
        echo "Data: $data"
        echo "Response: $body"
        
        # Affichage des détails d'erreur JSON si disponibles
        if [[ "$http_code" == "422" ]]; then
            local errors
            errors=$(echo "$body" | jq -r '.errors // .error.message // "No details"')
            echo "Détails: $errors"
        fi
        
        exit 1
    fi
    
    echo "✅ $context: HTTP $http_code"
    echo "$body"  # Retourner le corps de la réponse
}

# Utilisation
response=$(make_api_request "POST" "$API_URL/api/v1/cras" \
     '{"month":1,"year":2025,"currency":"EUR"}' \
     "201" \
     "CRA creation")

# Validation de la réponse JSON
cra_id=$(echo "$response" | jq -r '.data.cra.id')
if [[ "$cra_id" == "null" || -z "$cra_id" ]]; then
    echo "❌ CRA ID manquant dans la réponse"
    echo "Réponse complète: $response"
    exit 1
fi

echo "✅ CRA créé avec ID: $cra_id"
```

### 📝 **Gestion des Timeouts**
```bash
# Fonction avec timeout pour éviter les blocages
make_api_request_with_timeout() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local timeout="${4:-30}"
    local expected_status="$5"
    local context="$6"
    
    # Création d'un fichier temporaire pour la réponse
    local temp_response
    temp_response=$(mktemp)
    
    # Exécution avec timeout
    if timeout "$timeout" curl -s -w "\n%{http_code}" -X "$method" "$endpoint" \
         -H "Authorization: Bearer $token" \
         -H "Content-Type: application/json" \
         -d "$data" \
         -o "$temp_response" \
         "$API_URL"; then
        
        # Lecture de la réponse
        local http_code
        local body
        http_code=$(tail -n1 "$temp_response")
        body=$(sed '$d' "$temp_response")
        
        # Nettoyage
        rm "$temp_response"
        
        # Traitement normal
        if [[ "$http_code" != "$expected_status" ]]; then
            echo "❌ Erreur HTTP $http_code dans $context"
            echo "Response: $body"
            exit 1
        fi
        
        echo "✅ $context: HTTP $http_code"
        echo "$body"
    else
        # Timeout ou erreur curl
        rm "$temp_response"
        echo "❌ Timeout ou erreur curl dans $context (timeout: ${timeout}s)"
        exit 1
    fi
}
```

---

## 6. Timeouts et Synchronisation

### ❌ **Pattern Erroné**
```bash
# Problème: Pas de gestion des timeouts
response=$(curl -X POST "$API_URL/api/v1/cras" \
     -H "Authorization: Bearer $token" \
     -H "Content-Type: application/json" \
     -d '{"month":1,"year":2025}')

# Problème: Attente insuffisante entre les requêtes
create_cra
create_entry  # Peut échouer si le CRA n'est pas encore prêt
```

### ✅ **Pattern Correct**
```bash
# Solution: Timeouts et synchronisation appropriés

# Configuration curl avec timeouts
configure_curl() {
    local curl_opts
    curl_opts=(
        "--connect-timeout 10"      # Timeout de connexion
        "--max-time 30"             # Timeout total
        "--retry 3"                 # Nombre de retries
        "--retry-delay 1"           # Délai entre retries
    )
    echo "${curl_opts[*]}"
}

# Fonction d'attente pour la synchronisation
wait_for_cra_ready() {
    local cra_id="$1"
    local max_wait="${2:-10}"
    local wait_time=0
    
    while [[ $wait_time -lt $max_wait ]]; do
        # Vérification de l'existence du CRA
        if curl -s "$(configure_curl)" \
             -H "Authorization: Bearer $token" \
             "$API_URL/api/v1/cras/$cra_id" >/dev/null 2>&1; then
            echo "✅ CRA $cra_id est prêt"
            return 0
        fi
        
        echo "⏳ Attente de la préparation du CRA $cra_id... ($wait_time/$max_wait)s"
        sleep 1
        ((wait_time++))
    done
    
    echo "❌ Timeout: CRA $cra_id pas prêt après ${max_wait}s"
    exit 1
}

# Utilisation synchronisée
response=$(make_api_request "POST" "$API_URL/api/v1/cras" \
     '{"month":1,"year":2025,"currency":"EUR"}' \
     "201" \
     "CRA creation")

cra_id=$(echo "$response" | jq -r '.data.cra.id')

# Attendre que le CRA soit prêt avant de créer une entrée
wait_for_cra_ready "$cra_id"

# Maintenant créer l'entrée
entry_response=$(make_api_request "POST" "$API_URL/api/v1/cras/$cra_id/entries" \
     '{"date":"2025-01-15","quantity":0.5,"unit_price":60000}' \
     "201" \
     "Entry creation")
```

---

## 7. Validation de Réponses

### ❌ **Pattern Erroné**
```bash
# Problème: Validation incomplète des réponses
response=$(curl -X POST "$API_URL/api/v1/cras" \
     -H "Authorization: Bearer $token" \
     -H "Content-Type: application/json" \
     -d '{"month":1,"year":2025}')

# Validation superficielle
if echo "$response" | jq -e '.data.cra.id' >/dev/null; then
    echo "CRA créé avec succès"  # Peut être faux !
fi

# Pas de vérification des totaux ou de la cohérence
```

### ✅ **Pattern Correct**
```bash
# Solution: Validation complète et structurée

validate_cra_response() {
    local response="$1"
    local context="$2"
    
    # Vérification de la structure JSON
    if ! echo "$response" | jq -e '.data.cra' >/dev/null 2>&1; then
        echo "❌ Structure JSON invalide dans $context"
        echo "Réponse: $response"
        exit 1
    fi
    
    # Extraction et validation des champs requis
    local cra_id
    local month
    local year
    local total_days
    local total_amount
    
    cra_id=$(echo "$response" | jq -r '.data.cra.id')
    month=$(echo "$response" | jq -r '.data.cra.month')
    year=$(echo "$response" | jq -r '.data.cra.year')
    total_days=$(echo "$response" | jq -r '.data.cra.total_days')
    total_amount=$(echo "$response" | jq -r '.data.cra.total_amount')
    
    # Validation des valeurs
    local errors=0
    
    if [[ "$cra_id" == "null" || -z "$cra_id" ]]; then
        echo "❌ CRA ID manquant dans $context"
        ((errors++))
    fi
    
    if [[ "$month" != "1" ]]; then
        echo "❌ Mois incorrect dans $context: $month (attendu: 1)"
        ((errors++))
    fi
    
    if [[ "$year" != "2025" ]]; then
        echo "❌ Année incorrecte dans $context: $year (attendu: 2025)"
        ((errors++))
    fi
    
    if [[ "$total_days" != "0" ]]; then
        echo "❌ Total days incorrect dans $context: $total_days (attendu: 0)"
        ((errors++))
    fi
    
    if [[ "$total_amount" != "0" ]]; then
        echo "❌ Total amount incorrect dans $context: $total_amount (attendu: 0)"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        echo "✅ Validation $context réussie"
        echo "$response"  # Retourner la réponse validée
    else
        echo "❌ $errors erreur(s) de validation dans $context"
        exit 1
    fi
}

# Utilisation
response=$(make_api_request "POST" "$API_URL/api/v1/cras" \
     '{"month":1,"year":2025,"currency":"EUR"}' \
     "201" \
     "CRA creation")

# Validation complète
validated_response=$(validate_cra_response "$response" "CRA creation")

# Extraction des données validées
cra_id=$(echo "$validated_response" | jq -r '.data.cra.id')
echo "CRA ID validé: $cra_id"
```

---

## 🔧 Outils et Utilitaires

### Fonctions de Support Standardisées

```bash
# ==============================================================================
# UTILITAIRES E2E - FUNCTIONS DE SUPPORT
# ==============================================================================

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérification des prérequis
check_prerequisites() {
    local missing_tools=()
    
    # Vérifier jq
    if ! command -v jq >/dev/null 2>&1; then
        missing_tools+=("jq")
    fi
    
    # Vérifier curl
    if ! command -v curl >/dev/null 2>&1; then
        missing_tools+=("curl")
    fi
    
    # Vérifier bc (pour les calculs)
    if ! command -v bc >/dev/null 2>&1; then
        missing_tools+=("bc")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Outils manquants: ${missing_tools[*]}"
        log_error "Installez-les avec: brew install ${missing_tools[*]}"
        exit 1
    fi
    
    log_success "Tous les prérequis sont installés"
}

# Configuration de l'environnement
setup_environment() {
    # Vérifier les variables d'environnement
    if [[ -z "$API_URL" ]]; then
        API_URL="http://localhost:3000"
        log_warning "API_URL non défini, utilisation de: $API_URL"
    fi
    
    if [[ -z "$JWT_SECRET" ]]; then
        log_error "JWT_SECRET doit être défini"
        exit 1
    fi
    
    # Configuration des timeouts
    export CURL_CONNECT_TIMEOUT=10
    export CURL_MAX_TIME=30
    
    log_success "Environnement configuré"
}
```

---

## 📚 Références

- **Script principal:** `bin/e2e/e2e_cra_lifecycle_fc07.sh`
- **Templates de tests:** `spec/templates/`
- **Helpers de support:** `spec/support/`
- **Plan PR15:** `docs/rswag/PR15_Infrastructure_Improvement_Plan.md`
- **ADR-002:** `docs/rswag/ADR-002-rswag-vs-request-specs-boundary.md`

---

## 🚀 Utilisation

### Dans les Scripts E2E

```bash
#!/bin/bash

# Inclusion des patterns
source "$(dirname "$0")/../docs/technical/patterns/e2e_patterns_corrections.md"

# Vérification des prérequis
check_prerequisites

# Configuration de l'environnement
setup_environment

# Utilisation des patterns
current_month=$(date +%-m)
response=$(make_api_request "POST" "$API_URL/api/v1/cras" \
     "{\"month\":$current_month,\"year\":2025,\"currency\":\"EUR\"}" \
     "201" \
     "CRA creation")

# Validation avec patterns
validated_response=$(validate_cra_response "$response" "CRA creation")
```

### Dans les Tests RSpec

```ruby
# spec/support/e2e_patterns.rb

module E2EPatterns
  def self.apply_date_format_pattern(date_params)
    # Application du pattern de format de dates
    date_params[:month] = Date.current.month  # Pas de zéro de tête
    date_params[:year] = Date.current.year
    date_params
  end
  
  def self.apply_uuid_pattern(uuid_string)
    # Validation du pattern UUID
    raise ArgumentError, "UUID invalide: #{uuid_string}" unless 
      uuid_string =~ /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
    
    uuid_string
  end
end

# Utilisation dans les specs
RSpec.describe "E2E Integration" do
  it "suit les patterns E2E" do
    # Application des patterns
    date_params = E2EPatterns.apply_date_format_pattern(month: 1, year: 2025)
    
    # Test avec paramètres validés
    expect(date_params[:month]).to eq(1)  # Pas "01"
  end
end
```

---

## 📈 Métriques et Suivi

### Indicateurs de Qualité

- **Erreurs de parsing JSON:** 0 (avec patterns appliqués)
- **Échecs de validation de schéma:** 0 (avec validation complète)
- **Timeouts de requêtes:** < 1% (avec timeouts appropriés)
- **Incohérences de données:** 0 (avec validation complète)

### Checklist de Validation

- [ ] Format de dates sans zéros de tête (`date +%-m`)
- [ ] Parsing JSON avec chemins complets
- [ ] Comparaison de valeurs numériques robuste
- [ ] Conservation des UUIDs en tant que chaînes
- [ ] Gestion d'erreur avec validation de statut HTTP
- [ ] Timeouts configurés pour éviter les blocages
- [ ] Validation complète des réponses JSON

---

*Cette documentation est maintenue par l'équipe Platform Engineering et doit être mise à jour selon l'évolution des patterns identifiés dans les tests E2E.*

**Dernière mise à jour:** 2026-01-10  
**Prochaine révision:** 2026-04-10  
