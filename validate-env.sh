#!/bin/bash

# Environment Files Validation Script
# Validates syntax and completeness of environment files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Counters
TOTAL_FILES=0
VALID_FILES=0
WARNINGS=0
ERRORS=0

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  Environment Files Validation${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check if env directory exists
check_env_directory() {
    if [ ! -d "env" ]; then
        print_error "env/ directory not found!"
        exit 1
    fi
    print_success "env/ directory found"
}

# Validate env file syntax
validate_file_syntax() {
    local file=$1
    local filename=$(basename "$file")
    local line_num=0
    local file_valid=true

    echo -e "\n${BLUE}Validating: ${filename}${NC}"

    # Check file exists and is readable
    if [ ! -f "$file" ]; then
        print_error "File not found: $file"
        return 1
    fi

    if [ ! -r "$file" ]; then
        print_error "File not readable: $file"
        return 1
    fi

    # Check file is not empty
    if [ ! -s "$file" ]; then
        print_warning "File is empty: $file"
        return 1
    fi

    # Validate each line
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_num++))

        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Check for spaces around equals sign
        if [[ "$line" =~ [[:space:]]=[[:space:]] ]]; then
            print_error "Line $line_num: Spaces around '=' sign: $line"
            file_valid=false
        fi

        # Check for valid KEY=VALUE format
        if [[ ! "$line" =~ ^[A-Z_][A-Z0-9_]*=.*$ ]]; then
            print_error "Line $line_num: Invalid format (should be KEY=VALUE): $line"
            file_valid=false
        fi

        # Check for empty values (warning only)
        if [[ "$line" =~ ^[A-Z_][A-Z0-9_]*=$ ]]; then
            print_warning "Line $line_num: Empty value: $line"
        fi

        # Check for unquoted values with spaces (might be intentional)
        if [[ "$line" =~ ^[A-Z_][A-Z0-9_]*=[^\"\']*[[:space:]][^\"\']*$ ]]; then
            local key="${line%%=*}"
            local value="${line#*=}"
            # Only warn if it's not a URL or path-like value
            if [[ ! "$value" =~ ^(http|https|jdbc|redis|file):// ]] && [[ ! "$value" =~ ^/ ]]; then
                print_warning "Line $line_num: Unquoted value with spaces: $line"
            fi
        fi

    done < "$file"

    if [ "$file_valid" = true ]; then
        print_success "$filename: Syntax valid"
        return 0
    else
        return 1
    fi
}

# Check for required variables in files
check_required_variables() {
    local file=$1
    local filename=$(basename "$file")

    case "$filename" in
        postgres_env)
            check_var "$file" "POSTGRES_DB"
            check_var "$file" "POSTGRES_USER"
            check_var "$file" "POSTGRES_PASSWORD"
            ;;
        keycloak_env)
            check_var "$file" "KC_BOOTSTRAP_ADMIN_USERNAME"
            check_var "$file" "KC_BOOTSTRAP_ADMIN_PASSWORD"
            check_var "$file" "KC_DB_URL"
            check_var "$file" "KC_DB_USERNAME"
            check_var "$file" "KC_DB_PASSWORD"
            ;;
        obp_api_env)
            check_var "$file" "OBP_DB_DRIVER"
            check_var "$file" "OBP_DB_URL"
            check_var "$file" "OBP_HOSTNAME"
            ;;
        api_explorer_env)
            check_var "$file" "VITE_OBP_API_HOST"
            check_var "$file" "NODE_ENV"
            ;;
        api_manager_env)
            check_var "$file" "OBP_API_URL"
            check_var "$file" "NODE_ENV"
            check_var "$file" "PORT"
            ;;
        api_portal_env)
            check_var "$file" "OBP_API_URL"
            check_var "$file" "NODE_ENV"
            check_var "$file" "SESSION_SECRET"
            ;;
        opey_env)
            check_var "$file" "OBP_BASE_URL"
            check_var "$file" "OBP_USERNAME"
            check_var "$file" "OBP_PASSWORD"
            check_var "$file" "MODEL_PROVIDER"
            ;;
    esac
}

# Check if variable exists in file
check_var() {
    local file=$1
    local var_name=$2

    if grep -q "^${var_name}=" "$file"; then
        return 0
    else
        print_error "Missing required variable: $var_name in $(basename $file)"
        return 1
    fi
}

# Check for sensitive values
check_sensitive_values() {
    local file=$1
    local filename=$(basename "$file")

    # Check for placeholder passwords
    if grep -q "CHANGE_ME\|REPLACE_ME\|YOUR_.*_HERE\|xxx\|TODO" "$file" 2>/dev/null; then
        print_warning "$filename: Contains placeholder values (CHANGE_ME, etc.)"
    fi

    # Check for default/weak passwords
    if grep -qi "password=password\|password=123\|password=admin" "$file" 2>/dev/null; then
        print_warning "$filename: Contains weak/default passwords"
    fi
}

# Check file permissions
check_permissions() {
    local file=$1
    local filename=$(basename "$file")
    local perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null)

    # Warn if file is world-readable
    if [ "${perms:2:1}" != "0" ]; then
        print_warning "$filename: World-readable (permissions: $perms). Consider: chmod 640 $file"
    fi
}

# Validate docker-compose references
check_docker_compose_references() {
    print_info "Checking docker-compose.yml references..."

    if [ ! -f "docker-compose.yml" ]; then
        print_warning "docker-compose.yml not found"
        return
    fi

    # Extract env_file references from docker-compose.yml
    local env_files=$(grep -A1 "env_file:" docker-compose.yml | grep "env/" | sed 's/.*env\//env\//' | sed 's/^[[:space:]]*//' | sed 's/-[[:space:]]*//')

    for env_file in $env_files; do
        if [ -f "$env_file" ]; then
            print_success "Referenced file exists: $env_file"
        else
            print_error "Referenced file missing: $env_file"
        fi
    done
}

# Check for .env file (for API keys)
check_root_env() {
    if [ ! -f ".env" ]; then
        print_warning ".env file not found (required for Opey AI keys)"
        print_info "Create it from template: cp env.template .env"
    else
        print_success ".env file exists"

        # Check for API keys
        if ! grep -q "^OPENAI_API_KEY=" .env && ! grep -q "^ANTHROPIC_API_KEY=" .env; then
            print_warning ".env exists but no API keys found (Opey won't work)"
        fi

        # Check for placeholder values
        if grep -q "your-.*-key-here" .env 2>/dev/null; then
            print_warning ".env contains placeholder API keys"
        fi
    fi
}

# Test docker-compose config
test_docker_compose() {
    print_info "Testing docker-compose configuration..."

    if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
        print_warning "Docker Compose not found, skipping config test"
        return
    fi

    local compose_cmd
    if docker compose version &> /dev/null; then
        compose_cmd="docker compose"
    elif docker-compose version &> /dev/null; then
        compose_cmd="docker-compose"
    else
        print_warning "Docker Compose not available"
        return
    fi

    if $compose_cmd config > /dev/null 2>&1; then
        print_success "docker-compose config valid"
    else
        print_error "docker-compose config validation failed"
        print_info "Run '$compose_cmd config' for details"
    fi
}

# Main validation
main() {
    print_header

    check_env_directory
    check_root_env
    echo ""

    # Validate each env file
    for env_file in env/*_env; do
        if [ -f "$env_file" ]; then
            ((TOTAL_FILES++))

            if validate_file_syntax "$env_file"; then
                ((VALID_FILES++))
            fi

            check_required_variables "$env_file"
            check_sensitive_values "$env_file"
            check_permissions "$env_file"
        fi
    done

    echo ""
    check_docker_compose_references
    echo ""
    test_docker_compose

    # Print summary
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  Validation Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "Total files:   $TOTAL_FILES"
    echo -e "Valid files:   ${GREEN}$VALID_FILES${NC}"
    echo -e "Warnings:      ${YELLOW}$WARNINGS${NC}"
    echo -e "Errors:        ${RED}$ERRORS${NC}"
    echo ""

    if [ $ERRORS -eq 0 ]; then
        if [ $WARNINGS -eq 0 ]; then
            print_success "All environment files are valid!"
            exit 0
        else
            print_warning "Validation complete with warnings"
            exit 0
        fi
    else
        print_error "Validation failed with errors"
        exit 1
    fi
}

# Run main function
main "$@"
