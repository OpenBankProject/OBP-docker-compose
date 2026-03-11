#!/bin/bash

# OBP Stack Management Script
# This script provides convenient commands to manage the Docker Compose stack

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

# Helper functions
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}\n"
}

# Check if docker-compose is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! docker compose version &> /dev/null && ! docker-compose version &> /dev/null; then
        print_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi

    # Use docker compose or docker-compose
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
}

# Check if .env file exists
check_env() {
    if [ ! -f .env ]; then
        print_warning ".env file not found"
        print_info "Opey AI assistant requires API keys to function"
        read -p "Do you want to create .env from template? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [ -f env.template ]; then
                cp env.template .env
                print_success "Created .env file from template"
                print_warning "Please edit .env and add your API keys before starting Opey"
            else
                print_error "env.template not found"
            fi
        fi
    fi
}

# Start the stack
start() {
    print_header "Starting OBP Stack"
    check_env
    $COMPOSE_CMD up -d
    print_success "Stack started"
    print_info "Waiting for services to initialize..."
    echo ""
    print_info "Monitor startup progress with: $0 logs"
    echo ""
    status
}

# Stop the stack
stop() {
    print_header "Stopping OBP Stack"
    $COMPOSE_CMD down
    print_success "Stack stopped"
}

# Restart the stack
restart() {
    print_header "Restarting OBP Stack"
    stop
    start
}

# Show status
status() {
    print_header "Service Status"
    $COMPOSE_CMD ps
    echo ""
    print_info "Access URLs:"
    echo "  API Portal:    http://localhost:3000"
    echo "  API Manager:   http://localhost:3003"
    echo "  API Explorer:  http://localhost:8085"
    echo "  OBP API:       http://localhost:8080"
    echo "  Keycloak:      http://localhost:8081"
    echo "  Opey AI:       http://localhost:5000"
    echo "  OBP OIDC:      http://localhost:9009"
}

# Show logs
logs() {
    if [ -z "$2" ]; then
        print_info "Showing logs for all services (Ctrl+C to exit)"
        $COMPOSE_CMD logs -f --tail=100
    else
        print_info "Showing logs for: $2"
        $COMPOSE_CMD logs -f --tail=100 "$2"
    fi
}

# Clean everything (including volumes)
clean() {
    print_header "Cleaning OBP Stack"
    print_warning "This will remove all containers, networks, and volumes"
    print_warning "All data will be lost!"
    read -p "Are you sure? (yes/no) " -r
    echo
    if [[ $REPLY == "yes" ]]; then
        $COMPOSE_CMD down -v
        print_success "Stack cleaned (volumes removed)"
    else
        print_info "Clean cancelled"
    fi
}

# Pull latest images
update() {
    print_header "Updating Images"
    $COMPOSE_CMD pull
    print_success "Images updated"
    print_info "Restart services to use new images: $0 restart"
}

# Health check
health() {
    print_header "Health Check"

    services=("postgres" "redis" "keycloak" "obp-oidc" "obp-api" "api-explorer" "api-manager" "api-portal" "opey")

    for service in "${services[@]}"; do
        if $COMPOSE_CMD ps | grep -q "$service.*Up"; then
            health_status=$($COMPOSE_CMD ps | grep "$service" | grep -o "health.*" || echo "N/A")
            if [[ $health_status == *"healthy"* ]]; then
                print_success "$service: healthy"
            elif [[ $health_status == *"starting"* ]]; then
                print_warning "$service: starting"
            elif [[ $health_status == "N/A" ]]; then
                print_info "$service: running (no health check)"
            else
                print_warning "$service: $health_status"
            fi
        else
            print_error "$service: not running"
        fi
    done
    echo ""

    # Test key endpoints
    print_info "Testing key endpoints..."

    if curl -sf http://localhost:8080/alive.html > /dev/null 2>&1; then
        print_success "OBP API: responding"
    else
        print_warning "OBP API: not responding yet"
    fi

    if curl -sf http://localhost:8081/realms/master > /dev/null 2>&1; then
        print_success "Keycloak: responding"
    else
        print_warning "Keycloak: not responding yet"
    fi

    if curl -sf http://localhost:6379 > /dev/null 2>&1 || nc -z localhost 6379 2>&1; then
        print_success "Redis: accepting connections"
    else
        print_warning "Redis: not accepting connections yet"
    fi
}

# Monitor services and restart unhealthy ones (single check)
monitor() {
    print_header "Monitoring Services"

    services=("postgres" "redis" "keycloak" "obp-oidc" "obp-api" "api-explorer" "api-explorer-nginx" "api-manager" "api-portal" "opey")
    unhealthy_services=()

    for service in "${services[@]}"; do
        if $COMPOSE_CMD ps | grep -q "$service.*Up"; then
            health_status=$($COMPOSE_CMD ps | grep "$service" | grep -o "health.*" || echo "N/A")

            if [[ $health_status == *"unhealthy"* ]]; then
                print_error "$service: unhealthy - restarting..."
                unhealthy_services+=("$service")
                $COMPOSE_CMD restart "$service"
                print_success "$service: restarted"
            elif [[ $health_status == *"healthy"* ]]; then
                print_success "$service: healthy"
            elif [[ $health_status == *"starting"* ]]; then
                print_warning "$service: starting"
            elif [[ $health_status == "N/A" ]]; then
                print_info "$service: running (no health check)"
            else
                print_warning "$service: $health_status"
            fi
        else
            print_error "$service: not running"
        fi
    done

    echo ""
    if [ ${#unhealthy_services[@]} -eq 0 ]; then
        print_success "All services are healthy"
    else
        print_warning "Restarted ${#unhealthy_services[@]} unhealthy service(s): ${unhealthy_services[*]}"
    fi
}

# Watch services continuously and restart when unhealthy
watch() {
    print_header "Starting Service Watchdog"

    # Default interval is 60 seconds
    INTERVAL=${2:-60}

    print_info "Monitoring services every ${INTERVAL} seconds"
    print_info "Press Ctrl+C to stop"
    echo ""

    while true; do
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${BLUE}[$timestamp] Checking services...${NC}"

        services=("postgres" "redis" "keycloak" "obp-oidc" "obp-api" "api-explorer" "api-explorer-nginx" "api-manager" "api-portal" "opey")
        unhealthy_count=0
        restarted_services=()

        for service in "${services[@]}"; do
            if $COMPOSE_CMD ps | grep -q "$service.*Up"; then
                health_status=$($COMPOSE_CMD ps | grep "$service" | grep -o "health.*" || echo "N/A")

                if [[ $health_status == *"unhealthy"* ]]; then
                    print_error "$service: unhealthy - restarting..."
                    $COMPOSE_CMD restart "$service"
                    restarted_services+=("$service")
                    unhealthy_count=$((unhealthy_count + 1))
                fi
            fi
        done

        if [ $unhealthy_count -eq 0 ]; then
            echo -e "${GREEN}✓${NC} All services healthy"
        else
            print_warning "Restarted $unhealthy_count service(s): ${restarted_services[*]}"
        fi

        echo ""
        sleep "$INTERVAL"
    done
}

# Database shell
db_shell() {
    print_header "PostgreSQL Shell"
    print_info "Connecting to OBP database..."
    $COMPOSE_CMD exec postgres psql -U obp
}

# Redis shell
redis_shell() {
    print_header "Redis CLI"
    print_info "Connecting to Redis..."
    $COMPOSE_CMD exec redis redis-cli
}

# Setup Keycloak database
setup_keycloak_db() {
    print_header "Setting up Keycloak Database"
    print_info "Creating keycloak database and user..."
    print_error "this is WIP - not working yet, please create manually"

#    print_success "Keycloak database setup complete"
#    print_info "Restart Keycloak to initialize: $0 restart-service keycloak"

}

# Backup database
backup() {
    print_header "Backing up Database"
    BACKUP_FILE="backup_$(date +%Y%m%d_%H%M%S).sql"
    print_info "Creating backup: $BACKUP_FILE"
    $COMPOSE_CMD exec -T postgres pg_dump -U obp obp > "$BACKUP_FILE"
    print_success "Backup created: $BACKUP_FILE"
}

# Restore database
restore() {
    if [ -z "$2" ]; then
        print_error "Usage: $0 restore <backup_file.sql>"
        exit 1
    fi

    if [ ! -f "$2" ]; then
        print_error "Backup file not found: $2"
        exit 1
    fi

    print_header "Restoring Database"
    print_warning "This will overwrite the current database!"
    read -p "Continue? (yes/no) " -r
    echo
    if [[ $REPLY == "yes" ]]; then
        print_info "Restoring from: $2"
        $COMPOSE_CMD exec -T postgres psql -U obp obp < "$2"
        print_success "Database restored"
    else
        print_info "Restore cancelled"
    fi
}

# Start specific service
start_service() {
    if [ -z "$2" ]; then
        print_error "Usage: $0 start-service <service_name>"
        exit 1
    fi

    print_header "Starting Service: $2"
    $COMPOSE_CMD start "$2"
    print_success "Service started: $2"
    echo ""
    print_info "Check status with: $0 status"
}

# Stop specific service
stop_service() {
    if [ -z "$2" ]; then
        print_error "Usage: $0 stop-service <service_name>"
        exit 1
    fi

    print_header "Stopping Service: $2"
    $COMPOSE_CMD stop "$2"
    print_success "Service stopped: $2"
}

# Restart specific service
restart_service() {
    if [ -z "$2" ]; then
        print_error "Usage: $0 restart-service <service_name>"
        exit 1
    fi

    print_header "Restarting Service: $2"
    $COMPOSE_CMD restart "$2"
    print_success "Service restarted: $2"
}

# Up specific service (start and create if needed)
up_service() {
    if [ -z "$2" ]; then
        print_error "Usage: $0 up-service <service_name>"
        exit 1
    fi

    print_header "Starting/Creating Service: $2"
    $COMPOSE_CMD up -d "$2"
    print_success "Service is up: $2"
    echo ""
    print_info "Check status with: $0 status"
}

# Down specific service (stop and remove)
down_service() {
    if [ -z "$2" ]; then
        print_error "Usage: $0 down-service <service_name>"
        exit 1
    fi

    print_header "Stopping/Removing Service: $2"
    $COMPOSE_CMD rm -s -f "$2"
    print_success "Service removed: $2"
}

# Show resource usage
resources() {
    print_header "Resource Usage"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" \
        $(docker ps --filter "name=obp-*" --format "{{.Names}}")
}

# Show help
show_help() {
    cat << EOF
OBP Stack Management Script

Usage: $0 <command> [options]

Commands:
  start                Start all services
  stop                 Stop all services
  restart              Restart all services
  status               Show service status and URLs
  logs [service]       Show logs (all or specific service)
  health               Check health of all services
  monitor              Check services and restart unhealthy ones (single check)
  watch [interval]     Continuously monitor and restart unhealthy services (default: 60s)
  clean                Stop and remove all containers and volumes
  update               Pull latest Docker images

Service Management:
  start-service <name>    Start a specific service
  stop-service <name>     Stop a specific service
  restart-service <name>  Restart a specific service
  up-service <name>       Start/create a specific service
  down-service <name>     Stop/remove a specific service
  resources               Show resource usage

Database:
  db-shell             Open PostgreSQL shell
  redis-shell          Open Redis CLI
  setup-keycloak-db    Create Keycloak database and user
  backup               Create database backup
  restore <file>       Restore database from backup

Examples:
  $0 start                   # Start the stack
  $0 logs obp-api            # Show OBP API logs
  $0 start-service redis     # Start Redis only
  $0 stop-service opey       # Stop Opey only
  $0 restart-service obp-api # Restart OBP API
  $0 health                  # Check service health
  $0 monitor                 # Check and restart unhealthy services once
  $0 watch 120               # Monitor services every 120 seconds

Available Services:
  - postgres           PostgreSQL database
  - redis              Redis cache
  - keycloak           OAuth2/OIDC provider
  - obp-oidc           OBP OIDC provider
  - obp-api            OBP API server
  - api-explorer       API Explorer interface
  - api-manager        API Manager interface
  - api-portal         Developer portal
  - opey               AI assistant

EOF
}

# Main command handler
main() {
    check_docker

    case "${1:-help}" in
        start)
            start
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        status)
            status
            ;;
        logs)
            logs "$@"
            ;;
        health)
            health
            ;;
        monitor)
            monitor
            ;;
        watch)
            watch "$@"
            ;;
        clean)
            clean
            ;;
        update)
            update
            ;;
        db-shell)
            db_shell
            ;;
        redis-shell)
            redis_shell
            ;;
        setup-keycloak-db)
            setup_keycloak_db
            ;;
        backup)
            backup
            ;;
        restore)
            restore "$@"
            ;;
        start-service)
            start_service "$@"
            ;;
        stop-service)
            stop_service "$@"
            ;;
        restart-service)
            restart_service "$@"
            ;;
        up-service)
            up_service "$@"
            ;;
        down-service)
            down_service "$@"
            ;;
        resources)
            resources
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
