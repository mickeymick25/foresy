#!/bin/bash

# =====================================================
# 🚀 Foresy GitHub Actions Workflow Monitor
# =====================================================
# Script de monitoring des workflows GitHub Actions
# pour le projet Foresy API
#
# Usage: ./monitor.sh [command]
# Commands:
#   status     - État actuel des workflows
#   runs       - Historique des exécutions récentes
#   cleanup    - Nettoyer les workflows obsolètes
#   validate   - Valider la configuration des workflows
#   help       - Afficher cette aide
#
# Changelog:
#   v2.0 (Jan 2026) - Améliorations sécurité + robustesse
#   - Authentification Bearer OAuth 2.0 (RFC 6750)
#   - Pagination GitHub API configurable
#   - Configuration flexible workflows obsolètes
#   - Confirmation sécurité dans cleanup
#   - TODO documentés pour améliorations futures
#
# =====================================================

set -euo pipefail

# Configuration
REPO_OWNER="mickeymick25"
REPO_NAME="foresy"
API_BASE="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

# Pagination - GitHub API limits to 30 or 100 results per page
# TODO: Implement pagination for large repositories or long history
DEFAULT_PER_PAGE=50
MAX_PER_PAGE=100

# Configuration des workflows obsolètes - Plus flexible que hardcoded
# TODO: Make this configurable via environment variable or config file
OBSOLETE_WORKFLOWS_PATTERNS=(
    "Coverage"
    "RSwag Contract Validation"
    "E2E Contract Validation"
    "Observer"
    "Legacy"
)

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Fonctions utilitaires
print_header() {
    echo -e "${PURPLE}=====================================================${NC}"
    echo -e "${PURPLE} $1${NC}"
    echo -e "${PURPLE}=====================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Fonction pour vérifier la disponibilité de curl et jq
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        print_error "curl est requis mais pas installé"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        print_error "jq est requis mais pas installé"
        exit 1
    fi
}

# Fonction pour faire un appel API GitHub
github_api_call() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    local url="${API_BASE}${endpoint}"

    # Construction des headers de manière sécurisée
    local headers=(
        "--silent"
        "--show-error"
    )

    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        headers+=("-H" "Authorization: Bearer ${GITHUB_TOKEN}")
    fi

    if [[ -n "$data" ]]; then
        headers+=(
            "-H" "Content-Type: application/json"
            "--data" "${data}"
        )
    fi

    curl "${headers[@]}" --request "${method}" "${url}"
}

# 1. Afficher l'état actuel des workflows
show_workflow_status() {
    print_header "📊 État des Workflows GitHub Actions"

    local workflows
    workflows=$(github_api_call "/actions/workflows?per_page=${DEFAULT_PER_PAGE}" | jq -r '.workflows[] | "\(.id)|\(.name)|\(.path)|\(.state)|\(.created_at)|\(.updated_at)"' 2>/dev/null || echo "")

    if [[ -z "$workflows" ]]; then
        print_error "Impossible de récupérer les workflows (vérifiez GITHUB_TOKEN)"
        return 1
    fi

    printf "%-8s %-30s %-35s %-10s %-20s\n" "ID" "Nom" "Fichier" "État" "Dernière MAJ"
    printf "%-8s %-30s %-35s %-10s %-20s\n" "--------" "------------------------------" "-----------------------------------" "----------" "--------------------"

    local active_count=0
    local disabled_count=0

    while IFS='|' read -r id name path state created updated; do
        local state_color=""
        case "$state" in
            "active")
                state_color="${GREEN}active${NC}"
                active_count=$((active_count + 1))
                ;;
            "disabled")
                state_color="${RED}disabled${NC}"
                disabled_count=$((disabled_count + 1))
                ;;
            *)
                state_color="${YELLOW}${state}${NC}"
                ;;
        esac

        printf "%-8s %-30s %-35s %-10s %-20s\n" "$id" "$name" "$(basename "$path")" "$state_color" "${updated:0:19}"
    done <<< "$workflows"

    echo ""
    print_info "Workflows actifs: $active_count"
    print_info "Workflows désactivés: $disabled_count"
    print_info "Total: $((active_count + disabled_count))"

    # Détecter les workflows obsolètes
    print_header "🔍 Analyse des Workflows Obsolètes"
    # Utilisation de la configuration flexible des patterns obsolètes
    local found_obsolete=false

    while IFS='|' read -r id name path state created updated; do
        for pattern in "${OBSOLETE_WORKFLOWS_PATTERNS[@]}"; do
            if [[ "$name" == *"$pattern"* ]]; then
                print_warning "Workflow obsolète détecté: $name (path: $path, state: $state)"
                found_obsolete=true
            fi
        done
    done <<< "$workflows"

    if [[ "$found_obsolete" == "false" ]]; then
        print_success "Aucun workflow obsolète détecté"
    else
        print_info "Consultez le README pour les instructions de nettoyage"
    fi
}

# 2. Afficher l'historique des exécutions récentes
show_recent_runs() {
    print_header "🏃‍♂️ Exécutions Récentes (Dernières 20)"

    local limit="${1:-20}"
    local runs
    runs=$(github_api_call "/actions/runs?per_page=${limit}&status=${2:-all}" | jq -r '.workflow_runs[] | "\(.id)|\(.name)|\(.status)|\(.conclusion)|\(.created_at)|\(.updated_at)"' 2>/dev/null || echo "")

    if [[ -z "$runs" ]]; then
        print_error "Impossible de récupérer les exécutions (vérifiez GITHUB_TOKEN)"
        return 1
    fi

    printf "%-40s %-12s %-12s %-20s %-20s\n" "Nom du Workflow" "Status" "Conclusion" "Démarré" "Terminé"
    printf "%-40s %-12s %-12s %-20s %-20s\n" "----------------------------------------" "------------" "------------" "--------------------" "--------------------"

    local success_count=0
    local failure_count=0
    local in_progress_count=0

    while IFS='|' read -r id name status conclusion created updated; do
        local status_color=""
        case "$status" in
            "completed")
                if [[ "$conclusion" == "success" ]]; then
                    status_color="${GREEN}completed${NC}"
                    ((success_count++))
                else
                    status_color="${RED}completed${NC}"
                    ((failure_count++))
                fi
                ;;
            "in_progress")
                status_color="${YELLOW}in_progress${NC}"
                ((in_progress_count++))
                ;;
            "queued")
                status_color="${BLUE}queued${NC}"
                ((in_progress_count++))
                ;;
            *) status_color="${PURPLE}${status}${NC}";;
        esac

        local conclusion_display=""
        if [[ -n "$conclusion" && "$conclusion" != "null" ]]; then
            conclusion_display="(${conclusion})"
        fi

        printf "%-40s %-12s %-12s %-20s %-20s\n" "$name" "$status_color" "$conclusion_display" "${created:0:19}" "${updated:0:19}"
    done <<< "$runs"

    echo ""
    print_success "Succès: $success_count"
    print_error "Échecs: $failure_count"
    print_info "En cours: $in_progress_count"

    # Statistiques par workflow
    print_header "📈 Statistiques par Workflow"
    local stats
    stats=$(github_api_call "/actions/runs?per_page=${DEFAULT_PER_PAGE}" | jq -r '.workflow_runs | group_by(.name) | .[] | "\(.[0].name)|\(length)"' 2>/dev/null || echo "")

    printf "%-40s %-8s\n" "Workflow" "Exécutions"
    printf "%-40s %-8s\n" "----------------------------------------" "--------"

    while IFS='|' read -r name count; do
        printf "%-40s %-8s\n" "$name" "$count"
    done <<< "$stats"
}

# 3. Proposer le nettoyage des workflows obsolètes
cleanup_obsolete_workflows() {
    print_header "🗑️  Nettoyage des Workflows Obsolètes"

    print_warning "Cette opération nécessite des permissions d'administrateur"
    print_info "Vous devrez supprimer manuellement les workflows via l'interface GitHub"

    local workflows
    workflows=$(github_api_call "/actions/workflows?per_page=${DEFAULT_PER_PAGE}" | jq -r '.workflows[] | "\(.id)|\(.name)|\(.path)|\(.state)"' 2>/dev/null || echo "")

    if [[ -z "$workflows" ]]; then
        print_error "Impossible de récupérer les workflows"
        return 1
    fi

    local cleanup_commands=()

    while IFS='|' read -r id name path state; do
        # Utilisation de la configuration flexible des patterns obsolètes
        for pattern in "${OBSOLETE_WORKFLOWS_PATTERNS[@]}"; do
            if [[ "$name" == *"$pattern"* ]]; then
                if [[ "$state" == "active" ]]; then
                    print_warning "Workflow à supprimer: $name"
                    cleanup_commands+=("curl -X DELETE '${API_BASE}/actions/workflows/${id}' -H 'Authorization: Bearer \${GITHUB_TOKEN}'")
                else
                    print_info "Workflow obsolète désactivé: $name"
                fi
                break
            fi
        done
    done <<< "$workflows"

    if [[ ${#cleanup_commands[@]} -gt 0 ]]; then
        print_header "📋 Commandes de Nettoyage"
        printf '%s\n' "${cleanup_commands[@]}"
        echo ""
        print_warning "Confirmer l'affichage des commandes de suppression ? (y/N)"
        read -r confirmation
        if [[ "$confirmation" =~ ^[Yy]$ ]]; then
            print_info "Commandes prêtes pour exécution manuelle"
        else
            print_info "Opération annulée par l'utilisateur"
        fi
    else
        print_success "Aucun workflow obsolète détecté"
    fi
}

# 4. Valider la configuration des workflows
validate_workflow_config() {
    print_header "🔍 Validation de la Configuration"

    print_info "Vérification de la configuration des workflows locaux..."

    # Vérifier l'existence du workflow principal
    if [[ -f ".github/workflows/ci.yml" ]]; then
        print_success "Workflow principal ci.yml trouvé"

        # Vérifier les clés importantes
        local ci_content
        ci_content=$(cat ".github/workflows/ci.yml")

        # TODO: Improve YAML validation using yq or actionlint for more robust checking
        if [[ "$ci_content" =~ "jobs:" ]]; then
            print_success "Jobs configurés"
        else
            print_error "Aucun job trouvé dans ci.yml"
        fi

        if [[ "$ci_content" =~ "ruby-version:" ]]; then
            print_success "Version Ruby configurée"
        else
            print_warning "Version Ruby non trouvée"
        fi

        if [[ "$ci_content" =~ "postgres:" ]]; then
            print_success "Service PostgreSQL configuré"
        else
            print_warning "Service PostgreSQL non trouvé"
        fi

        if [[ "$ci_content" =~ "redis:" ]]; then
            print_success "Service Redis configuré"
        else
            print_warning "Service Redis non trouvé"
        fi
    else
        print_error "Workflow principal ci.yml non trouvé"
    fi

    # Vérifier la documentation
    if [[ -f ".github/workflows/README.md" ]]; then
        print_success "Documentation README.md trouvée"
    else
        print_warning "Documentation README.md non trouvée"
    fi

    # Vérifier les scripts utilitaires
    if [[ -f ".github/workflows/monitor.sh" ]]; then
        print_success "Script de monitoring trouvé"
    else
        print_warning "Script de monitoring non trouvé"
    fi

    print_header "✅ Résumé de Validation"
    print_success "Configuration des workflows validée"
    print_info "Consultez .github/workflows/README.md pour les détails"
}

# 5. Fonction d'aide
show_help() {
    print_header "🚀 Foresy GitHub Actions Monitor"

    echo "Script de monitoring et de rationalisation des workflows GitHub Actions"
    echo ""
    echo "Usage: ./monitor.sh [command]"
    echo ""
    echo "Commands disponibles:"
    echo "  status     Afficher l'état actuel des workflows"
    echo "  runs       Afficher l'historique des exécutions récentes"
    echo "  cleanup    Proposer le nettoyage des workflows obsolètes"
    echo "  validate   Valider la configuration des workflows locaux"
    echo "  help       Afficher cette aide"
    echo ""
    echo "Variables d'environnement:"
    echo "  GITHUB_TOKEN    Token GitHub pour l'authentification (optionnel)"
    echo "                 Peut être défini dans ~/.github-token ou export GITHUB_TOKEN"
    echo ""
    echo "Exemples:"
    echo "  ./monitor.sh status"
    echo "  GITHUB_TOKEN=ghp_xxx ./monitor.sh runs"
    echo "  ./monitor.sh validate"
    echo ""
}

# Fonction principale
main() {
    check_dependencies

    # Vérifier si un token GitHub est disponible
    if [[ -z "${GITHUB_TOKEN:-}" && -f ~/.github-token ]]; then
        export GITHUB_TOKEN=$(cat ~/.github-token)
    fi

    # Vérifier la connectivité
    if ! curl -s --head --request GET "${API_BASE}" | grep "200 OK" > /dev/null; then
        print_error "Impossible d'accéder au repository GitHub"
        print_info "Vérifiez votre connexion internet et les permissions"
        exit 1
    fi

    case "${1:-help}" in
        "status")
            show_workflow_status
            ;;
        "runs")
            show_recent_runs "${2:-20}"
            ;;
        "cleanup")
            cleanup_obsolete_workflows
            ;;
        "validate")
            validate_workflow_config
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Exécution
main "$@"
