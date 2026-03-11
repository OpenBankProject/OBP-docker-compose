# Single Service Management Guide

Complete guide for starting, stopping, and managing individual services in the Docker Compose stack.

## Overview

The Docker Compose stack consists of 8 services that can be managed independently:

| Service | Container Name | Port | Dependencies |
|---------|----------------|------|--------------|
| `postgres` | postgres | 5432 | None |
| `redis` | redis | 6379 | None |
| `keycloak` | keycloak | 8081 | postgres |
| `obp-api` | api | 8080 | postgres, redis, keycloak |
| `api-explorer` | api-explorer | 8085 | obp-api, redis |
| `api-manager` | api-manager | 3003 | obp-api, redis |
| `api-portal` | portal | 3000 | obp-api, redis |
| `opey` | opey | 5000 | obp-api, redis |

## Quick Commands

### Using manage.sh (Recommended)

```bash
# Start a service
./manage.sh start-service <service-name>

# Stop a service
./manage.sh stop-service <service-name>

# Restart a service
./manage.sh restart-service <service-name>

# Start/create a service (if not exists)
./manage.sh up-service <service-name>

# Stop/remove a service completely
./manage.sh down-service <service-name>
```

### Using docker-compose directly

```bash
# Start an existing stopped service
docker-compose start <service-name>

# Stop a running service (keeps container)
docker-compose stop <service-name>

# Restart a service
docker-compose restart <service-name>

# Start/create service (if doesn't exist)
docker-compose up -d <service-name>

# Stop and remove service
docker-compose rm -s -f <service-name>

# View logs for specific service
docker-compose logs -f <service-name>

# Execute command in service
docker-compose exec <service-name> <command>
```

## Command Differences

### start vs up

**`start` / `start-service`**
- Starts an existing stopped container
- Container must already exist
- Fast operation
- Use when: Service was stopped but not removed

**`up` / `up-service`**
- Creates container if doesn't exist, then starts it
- Pulls image if needed
- Applies any config changes
- Use when: First time starting, or after down/rm

### stop vs down

**`stop` / `stop-service`**
- Stops the container gracefully
- Container still exists
- Can be started again quickly with `start`
- Data in volumes preserved
- Use when: Temporarily stopping service

**`down` / `down-service`**
- Stops and removes the container
- Container is deleted
- Next start requires `up` command
- Data in volumes still preserved
- Use when: Completely removing service

### restart vs stop + start

**`restart` / `restart-service`**
- Quick restart without removing container
- Does NOT reload environment variables from files
- Use when: Service is misbehaving, need quick reset

**`stop` + `start`**
- Same as restart
- Does NOT reload env vars

**`down` + `up`**
- Full recreate
- DOES reload environment variables
- Use when: Changed configuration

## Common Scenarios

### 1. Restart Service After Config Change

```bash
# Option 1: Full recreate (loads new env vars)
./manage.sh stop-service obp-api
./manage.sh up-service obp-api

# Option 2: Using docker-compose
docker-compose up -d --force-recreate obp-api

# Option 3: Quick restart (doesn't load env changes)
./manage.sh restart-service obp-api
```

**Best practice**: Use Option 1 or 2 after editing env files.

### 2. Stop Service Temporarily

```bash
# Stop the service
./manage.sh stop-service opey

# Later, restart it
./manage.sh start-service opey
```

### 3. Completely Remove and Recreate Service

```bash
# Remove service completely
./manage.sh down-service api-portal

# Recreate from scratch
./manage.sh up-service api-portal
```

### 4. Update Service Image

```bash
# Pull latest image
docker-compose pull obp-api

# Recreate with new image
docker-compose up -d --force-recreate obp-api
```

### 5. Debug a Service

```bash
# Stop the service
./manage.sh stop-service obp-api

# Start in foreground with logs
docker-compose up obp-api

# Or check logs
./manage.sh logs obp-api
```

### 6. Isolate a Service Problem

```bash
# Stop all dependent services
./manage.sh stop-service api-portal
./manage.sh stop-service api-manager
./manage.sh stop-service api-explorer
./manage.sh stop-service opey

# Restart just the API
./manage.sh restart-service obp-api

# Test API alone
curl http://localhost:8080/alive.html
```

## Service-Specific Operations

### PostgreSQL

```bash
# Restart database
./manage.sh restart-service postgres

# Access database shell
./manage.sh db-shell

# Warning: Stopping postgres affects all services!
# Stop safely:
./manage.sh stop  # Stop all services first
./manage.sh start-service postgres
./manage.sh start  # Then start others
```

### Redis

```bash
# Restart Redis
./manage.sh restart-service redis

# Access Redis CLI
./manage.sh redis-shell

# Test Redis
docker-compose exec redis redis-cli ping
```

### Keycloak

```bash
# Restart Keycloak
./manage.sh restart-service keycloak

# View Keycloak logs
./manage.sh logs keycloak

# Access Keycloak (after start)
open http://localhost:8081
```

### OBP API

```bash
# Restart API
./manage.sh restart-service obp-api

# View logs
./manage.sh logs obp-api

# Execute command in container
docker-compose exec obp-api bash

# Test API
curl http://localhost:8080/alive.html
curl http://localhost:8080/obp/v6.0.0/root
```

### Frontend Services (Explorer/Manager/Portal)

```bash
# Restart API Explorer
./manage.sh restart-service api-explorer

# Restart API Manager
./manage.sh restart-service api-manager

# Restart Portal
./manage.sh restart-service api-portal

# All frontends can be restarted independently
```

### Opey AI

```bash
# Restart Opey
./manage.sh restart-service opey

# View logs
./manage.sh logs opey

# Check status
curl http://localhost:5000/status

# Note: Needs API keys in .env file
```

## Dependency Management

### Safe Stop Order (Top to Bottom)

1. Frontend services (api-explorer, api-manager, api-portal, opey)
2. OBP API (obp-api)
3. Keycloak (keycloak)
4. Supporting services (redis, postgres)

```bash
# Safe way to stop everything
./manage.sh stop-service api-explorer
./manage.sh stop-service api-manager
./manage.sh stop-service api-portal
./manage.sh stop-service opey
./manage.sh stop-service obp-api
./manage.sh stop-service keycloak
./manage.sh stop-service redis
./manage.sh stop-service postgres
```

### Safe Start Order (Top to Bottom)

1. Supporting services (postgres, redis)
2. Keycloak (keycloak)
3. OBP API (obp-api)
4. Frontend services (api-explorer, api-manager, api-portal, opey)

```bash
# Safe way to start everything
./manage.sh start-service postgres
./manage.sh start-service redis
sleep 10  # Wait for DB to be ready
./manage.sh start-service keycloak
sleep 30  # Wait for Keycloak
./manage.sh start-service obp-api
sleep 60  # Wait for API migrations
./manage.sh start-service api-explorer
./manage.sh start-service api-manager
./manage.sh start-service api-portal
./manage.sh start-service opey
```

**Tip**: Docker Compose handles dependencies automatically with `up`!

## Advanced Operations

### Recreate Service with New Config

```bash
# Edit configuration
nano env/obp_api_env

# Stop service
docker-compose stop obp-api

# Remove container
docker-compose rm -f obp-api

# Recreate with new config
docker-compose up -d obp-api

# Or one-liner:
docker-compose up -d --force-recreate obp-api
```

### Scale a Service (Multiple Instances)

```bash
# Not all services support scaling
# Frontends can be scaled:
docker-compose up -d --scale api-explorer=2

# But services with single ports cannot:
# docker-compose up -d --scale obp-api=2  # ❌ Port conflict!
```

### Replace Service with Custom Image

```bash
# Edit docker-compose.yml
# Change: image: openbankproject/obp-api:latest
# To:     image: myregistry/obp-api:custom

# Recreate service
docker-compose up -d --force-recreate obp-api
```

### Run One-off Commands

```bash
# Run command in existing container
docker-compose exec obp-api env | grep OBP_

# Run command in new container (service doesn't need to be running)
docker-compose run --rm obp-api bash
```

### Attach to Service Console

```bash
# View live logs
docker-compose logs -f obp-api

# Attach to container (if running foreground)
docker attach api
# (Ctrl+C to detach)
```

## Troubleshooting

### Service Won't Start

```bash
# Check logs
./manage.sh logs <service-name>

# Check status
docker-compose ps <service-name>

# Check dependencies are running
docker-compose ps

# Try recreating
docker-compose up -d --force-recreate <service-name>
```

### Service Keeps Restarting

```bash
# View logs for errors
./manage.sh logs <service-name>

# Check health status
docker-compose ps

# Common issues:
# - Database not ready (wait longer)
# - Configuration error (check env files)
# - Port conflict (check ports)
# - Memory limit (increase Docker memory)
```

### Service Not Responding

```bash
# Check if running
docker-compose ps <service-name>

# Check logs
./manage.sh logs <service-name>

# Restart service
./manage.sh restart-service <service-name>

# If still not working, recreate
docker-compose up -d --force-recreate <service-name>
```

### Cannot Stop Service

```bash
# Force stop
docker-compose kill <service-name>

# Remove forcefully
docker-compose rm -f <service-name>

# Clean up and restart
docker-compose up -d <service-name>
```

### Port Already in Use

```bash
# Find what's using the port
netstat -tulpn | grep 8080
lsof -i :8080

# Stop the service using the port, or
# Change port in docker-compose.yml:
ports:
  - "8081:8080"  # Map to different external port
```

## Health Checks

### Check Service Health

```bash
# View all services health
docker-compose ps

# Or use manage.sh
./manage.sh health

# Check specific service logs
./manage.sh logs <service-name>
```

### Service-Specific Health Checks

```bash
# PostgreSQL
docker-compose exec postgres pg_isready -U obp

# Redis
docker-compose exec redis redis-cli ping

# Keycloak
curl http://localhost:8081/realms/master

# OBP API
curl http://localhost:8080/alive.html

# API Explorer
curl http://localhost:8085/

# API Manager
curl http://localhost:3003/

# API Portal
curl http://localhost:3000/

# Opey
curl http://localhost:5000/status
```

## Performance Monitoring

### Resource Usage Per Service

```bash
# All services
./manage.sh resources

# Specific service
docker stats api --no-stream

# Continuous monitoring
docker stats api postgres
```

### Service Logs

```bash
# Tail logs
./manage.sh logs <service-name>

# Last 100 lines
docker-compose logs --tail=100 <service-name>

# Since timestamp
docker-compose logs --since 2024-01-15T10:00:00 <service-name>

# Follow new logs only
docker-compose logs -f --tail=0 <service-name>
```

## Best Practices

### 1. Always Check Dependencies

Before stopping a service, check what depends on it:
- Stopping `postgres` affects ALL services
- Stopping `redis` affects API and frontends
- Stopping `obp-api` affects all frontends
- Frontends can be stopped independently

### 2. Use Restart for Quick Fixes

```bash
# Quick restart (no config reload)
./manage.sh restart-service obp-api
```

### 3. Use Down+Up for Config Changes

```bash
# After editing env files
docker-compose up -d --force-recreate obp-api
```

### 4. Monitor Logs When Starting

```bash
# Start and watch logs
./manage.sh up-service obp-api && ./manage.sh logs obp-api
```

### 5. Graceful Stops

Give services time to shutdown gracefully:
```bash
docker-compose stop -t 30 obp-api  # Wait 30 seconds before force kill
```

### 6. Use Health Checks

Wait for health checks before considering service ready:
```bash
./manage.sh up-service obp-api
sleep 10
./manage.sh health
```

## Quick Reference

| Task | Command |
|------|---------|
| Start stopped service | `./manage.sh start-service <name>` |
| Stop running service | `./manage.sh stop-service <name>` |
| Restart service | `./manage.sh restart-service <name>` |
| Create/start service | `./manage.sh up-service <name>` |
| Remove service | `./manage.sh down-service <name>` |
| View logs | `./manage.sh logs <name>` |
| Check status | `./manage.sh status` |
| Check health | `./manage.sh health` |
| Execute command | `docker-compose exec <name> <command>` |
| Recreate with new config | `docker-compose up -d --force-recreate <name>` |

## Examples

### Restart OBP API After Config Change

```bash
# Edit configuration
nano env/obp_api_env

# Recreate service to load new config
docker-compose up -d --force-recreate obp-api

# Watch logs
./manage.sh logs obp-api
```

### Troubleshoot Keycloak

```bash
# Stop Keycloak
./manage.sh stop-service keycloak

# Check logs
./manage.sh logs keycloak

# Recreate with fresh start
docker-compose up -d --force-recreate keycloak

# Monitor startup
./manage.sh logs keycloak
```

### Update Opey with New API Keys

```bash
# Edit API keys
nano .env

# Restart Opey to load new keys
./manage.sh restart-service opey

# Check it's working
curl http://localhost:5000/status
```

### Maintenance Mode (Stop Frontends)

```bash
# Stop all user-facing services
./manage.sh stop-service api-portal
./manage.sh stop-service api-manager
./manage.sh stop-service api-explorer

# Core services (API, DB) keep running

# Resume when ready
./manage.sh start-service api-portal
./manage.sh start-service api-manager
./manage.sh start-service api-explorer
```

---

**See Also**:
- [Main README](README.md)
- [Quick Start Guide](QUICKSTART.md)
- [Management Script](manage.sh)
- [Environment Files](env/README.md)