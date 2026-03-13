# OBP Docker Compose Environment

> **Complete local development environment for the Open Bank Project stack**

This directory contains a fully functional Docker Compose setup that replicates a Kubernetes deployment for local development and testing.

## Quick Start

```bash
# Start all services
./manage.sh start

# Monitor startup
./manage.sh logs

# Check status
./manage.sh status

# Access the portal
open http://localhost:3000
```

**That's it!** All services will start automatically.

## What's Included

### Services
- **OBP API** (8080) - Core banking API
- **API Portal** (3000) - Developer portal
- **API Manager** (3003) - Consumer management
- **API Explorer** (8085) - Interactive API docs
- **Opey AI** (5000) - AI assistant
- **Keycloak** (8081) - OAuth2/OIDC provider
- **OBP OIDC** (9009) - OAuth2/OIDC provider
- **PostgreSQL** (5432) - Database
- **Redis** (6379) - Cache

## Common Commands

```bash
# Lifecycle
./manage.sh start              # Start all services
./manage.sh stop               # Stop all services
./manage.sh restart            # Restart everything
./manage.sh clean              # Remove all data

# Monitoring
./manage.sh status             # Show service status
./manage.sh health             # Check health
./manage.sh logs [service]     # View logs
./manage.sh resources          # Resource usage
./manage.sh monitor            # Check and restart unhealthy services
./manage.sh watch [interval]   # Continuously monitor and auto-restart

# Single Service Control
./manage.sh start-service <name>    # Start specific service
./manage.sh stop-service <name>     # Stop specific service
./manage.sh up-service <name>       # Start/create specific service
./manage.sh down-service <name>     # Stop/remove specific service
./manage.sh restart-service <name>  # Restart specific service

# Database
./manage.sh db-shell           # PostgreSQL shell
./manage.sh setup-keycloak-db  # Setup Keycloak DB
./manage.sh backup             # Backup database
./manage.sh restore file.sql   # Restore database

# Help
./manage.sh help               # Show all commands
```

## Access URLs

Once started, access the applications at:

| Service | URL | Description |
|---------|-----|-------------|
| Portal | http://localhost:3000 | Main developer portal |
| Manager | http://localhost:3003 | API consumer management |
| Explorer | http://localhost:8085 | Interactive API docs |
| API | http://localhost:8080 | Core OBP API |
| Keycloak | http://localhost:8081 | OAuth2 admin console |
| OBP OIDC | http://localhost:9009 | OAuth2 
| Opey | http://localhost:5000 | AI assistant API |


## Configuration

All service configuration is managed through environment files in the `env/` directory:

```bash
# Edit OBP API settings
nano env/obp_api_env

# Edit Keycloak settings
nano env/keycloak_env

# See all available settings
cat env/README.md
```

After editing, restart the affected service:
```bash
./manage.sh restart-service <service-name>
```

## First-Time Database Setup

```bash
# Create Keycloak database
./manage.sh setup-keycloak-db

# Restart Keycloak
./manage.sh restart-service keycloak
```

## Prerequisites

- Docker (20.10+)
- Docker Compose (2.0+)
- 8GB+ RAM available
- Ports 3000, 3003, 5000, 6379, 8080, 8081, 8085 available

## Testing the Setup

```bash
# Check API health
curl http://localhost:8080/alive.html

# Get API root
curl http://localhost:8080/obp/v6.0.0/root

# Check all services
./manage.sh health
```

## Managing Individual Services

Start/stop/restart individual services as needed:

```bash
# Start a specific service
./manage.sh start-service redis

# Stop a specific service
./manage.sh stop-service opey

# Restart after config change
nano env/obp_api_env
./manage.sh restart-service obp-api

# View logs for one service
./manage.sh logs keycloak
```

**See the complete guide**: [SINGLE_SERVICE_MANAGEMENT.md](SINGLE_SERVICE_MANAGEMENT.md)

## Important Notes

### Security Warning

This setup is for local deployment. For production, a reverse proxy (e.g. NGINX) is required for TLS termination and other security enhancements, as well as considerations for the database etc.

## Automated Monitoring & Restart

The stack includes built-in monitoring to automatically restart unhealthy services.

### One-Time Check
Check all services and restart any that are unhealthy:
```bash
./manage.sh monitor
```

### Continuous Monitoring
Run a watchdog that continuously monitors services:
```bash
# Monitor every 60 seconds (default)
./manage.sh watch

# Monitor every 2 minutes
./manage.sh watch 120
```

Press `Ctrl+C` to stop the watchdog.

### Run as Background Service
For production, run the watchdog as a systemd service:
```bash
# Setup (edit paths in obp-watchdog.service first)
sudo cp obp-watchdog.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable obp-watchdog
sudo systemctl start obp-watchdog

# Check status
sudo systemctl status obp-watchdog

# View logs
sudo journalctl -u obp-watchdog -f
```

## Troubleshooting

### Services won't start
```bash
# Check port conflicts
netstat -tulpn | grep -E '(3000|3003|5000|6379|8080|8081|8085)'

# Check Docker resources
docker system df

# View logs
./manage.sh logs
```

### OBP API errors
```bash
# View detailed logs
./manage.sh logs obp-api

# Check database
./manage.sh db-shell

# Verify health
./manage.sh health
```

### Keycloak issues
```bash
# Setup database
./manage.sh setup-keycloak-db

# Check logs
./manage.sh logs keycloak

# Wait for initialization (2-3 minutes)
```

## Updating

```bash
# Pull latest images
./manage.sh update

# Restart with new images
./manage.sh restart
```
