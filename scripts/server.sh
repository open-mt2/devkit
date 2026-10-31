#!/usr/bin/env bash
# ======================================================
# OpenMT2 - local test server (old-metin2 deploy stack)
# ======================================================
#
# Runs the old-metin2 Docker Compose deployment (MySQL 5.5, web app, db/auth/
# game cores) from https://git.old-metin2.com/metin2/deploy so the packaged
# client has a server to log in to. The deploy repository is cloned into
# <root>/server (gitignored); its .env is generated on first use.
#
# The shipped client already targets 127.0.0.1 (auth 11000, CH1 13000), so a
# client on the Docker host connects without changes. For a client elsewhere,
# set SERVER_PUBLIC_IP and run `server.sh client <dist> <ip>`.
#
# Usage: server.sh <command> [args]
#
# Commands:
#   fetch                        Clone or update the deploy repository
#   configure                    Create/update server/.env (no containers)
#   up                           fetch + configure + start, wait for the ports
#   down                         Stop the stack (data stays in server/storage)
#   status                       Show the containers
#   logs [service...]            Follow the logs
#   account <login> <password>   Create a test account, or reset its password
#   client <dist> [address]      Point a packaged client at the server
#                                (default: SERVER_PUBLIC_IP)
#
# Environment:
#   SERVER_DIR          deploy checkout (default: <root>/server)
#   DEPLOY_REPO_URL     deploy repository (default: old-metin2 Gitea)
#   DEPLOY_REF          branch/tag (default: master)
#   SERVER_PUBLIC_IP    address the game cores advertise (default: 127.0.0.1)
#   SERVER_WEB_PORT     host port of the web app (default: 8080)
#   SERVER_MYSQL_PORT   host port of MySQL (default: 3306)
#   SERVER_APP_KEY      web app key; generated with the web image when unset
#   SERVER_WAIT         seconds to wait for the game ports (default: 300)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(dirname "$SCRIPT_DIR")"

ROOT="${OPENMT2_ROOT:-$DEFAULT_ROOT}"
SERVER_DIR="${SERVER_DIR:-$ROOT/server}"
DEPLOY_REPO_URL="${DEPLOY_REPO_URL:-https://git.old-metin2.com/metin2/deploy.git}"
DEPLOY_REF="${DEPLOY_REF:-master}"
SERVER_PUBLIC_IP="${SERVER_PUBLIC_IP:-127.0.0.1}"
SERVER_WEB_PORT="${SERVER_WEB_PORT:-8080}"
SERVER_MYSQL_PORT="${SERVER_MYSQL_PORT:-3306}"
SERVER_WAIT="${SERVER_WAIT:-300}"
PROJECT=openmt2-server

log()  { printf '\033[1;34m[server]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[server]\033[0m %s\n' "$*" >&2; }
die()  { warn "$*"; exit 1; }

usage() {
    awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' \
        "${BASH_SOURCE[0]}"
}

require_checkout() {
    [ -f "$SERVER_DIR/docker-compose.yml" ] \
        || die "no deploy checkout in $SERVER_DIR; run 'server.sh fetch' first"
}

compose() {
    (cd "$SERVER_DIR" && docker compose -p "$PROJECT" "$@")
}

env_get() {
    awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$SERVER_DIR/.env"
}

env_set() {
    local key="$1" value="$2" tmp
    tmp="$(mktemp)"
    awk -F= -v key="$key" -v value="$value" '
        $1 == key { print key "=" value; found = 1; next }
        { print }
        END { if (!found) print key "=" value }
    ' "$SERVER_DIR/.env" > "$tmp"
    mv "$tmp" "$SERVER_DIR/.env"
}

cmd_fetch() {
    if [ -d "$SERVER_DIR/.git" ]; then
        log "updating deploy -> $SERVER_DIR"
        git -C "$SERVER_DIR" fetch --quiet --depth 1 origin "$DEPLOY_REF"
        git -C "$SERVER_DIR" checkout --quiet FETCH_HEAD
    else
        log "cloning $DEPLOY_REPO_URL ($DEPLOY_REF) -> $SERVER_DIR"
        GIT_TERMINAL_PROMPT=0 git clone --quiet --depth 1 --branch "$DEPLOY_REF" \
            "$DEPLOY_REPO_URL" "$SERVER_DIR"
    fi
}

cmd_configure() {
    require_checkout
    if [ ! -f "$SERVER_DIR/.env" ]; then
        log "creating $SERVER_DIR/.env"
        # A Windows checkout may have CRLF line endings; keep .env plain.
        tr -d '\r' < "$SERVER_DIR/.env.example" > "$SERVER_DIR/.env"
    fi

    env_set WEB_EXTERNAL_PORT "$SERVER_WEB_PORT"
    env_set WEB_APP_URL "http://localhost:$SERVER_WEB_PORT"
    env_set MYSQL_EXTERNAL_PORT "$SERVER_MYSQL_PORT"
    env_set PUBLIC_IP "$SERVER_PUBLIC_IP"

    if [ -z "$(env_get WEB_APP_KEY)" ]; then
        local key="${SERVER_APP_KEY:-}"
        if [ -z "$key" ]; then
            log "generating the web app key"
            key="$(docker run --rm "$(env_get WEB_IMAGE)" "php artisan key:generate --show" \
                | tr -d '\r' | tail -n 1)"
        fi
        [ -n "$key" ] || die "could not generate WEB_APP_KEY"
        env_set WEB_APP_KEY "$key"
    fi
    log "configured: public IP $SERVER_PUBLIC_IP, web http://localhost:$SERVER_WEB_PORT"
}

# Docker Desktop's port proxy accepts connections before a core listens, so
# readiness comes from the core's own log line.
wait_core() {
    local service="$1" port="$2" deadline=$((SECONDS + SERVER_WAIT))
    until compose logs --no-color "$service" 2>/dev/null \
            | grep -q "TCP listening on .*:$port"; do
        [ "$SECONDS" -lt "$deadline" ] \
            || die "$service did not start listening on $port; see 'server.sh logs $service'"
        sleep 2
    done
    log "$service is listening on $port"
}

# The deploy healthcheck pings MySQL over its socket, which already answers
# while the first-start init server runs without networking; the web app then
# fails its migrations. Wait for TCP before starting the rest.
wait_mysql() {
    local deadline=$((SECONDS + SERVER_WAIT))
    until compose exec -T mysql sh -c \
            'mysqladmin ping --protocol=tcp -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD"' \
            >/dev/null 2>&1; do
        [ "$SECONDS" -lt "$deadline" ] || die "MySQL did not come up; see 'server.sh logs mysql'"
        sleep 2
    done
    log "MySQL is accepting connections"
}

cmd_up() {
    [ -f "$SERVER_DIR/docker-compose.yml" ] || cmd_fetch
    cmd_configure
    log "starting the stack (first start creates and seeds the databases)"
    compose pull --quiet
    compose up -d mysql
    wait_mysql
    compose up -d --wait web
    compose up -d
    wait_core auth 11000
    wait_core ch1_first 13000
    log "server ready; create a login with 'server.sh account <login> <password>'"
}

cmd_account() {
    local login="${1:-}" password="${2:-}"
    [ -n "$login" ] && [ -n "$password" ] || die "usage: server.sh account <login> <password>"
    # The auth core limits logins to 30 and passwords to 16 characters.
    [[ "$login" =~ ^[A-Za-z0-9_]{1,30}$ ]] \
        || die "login must be 1-30 letters, digits or underscores"
    [[ "$password" =~ ^[A-Za-z0-9_]{1,16}$ ]] \
        || die "password must be 1-16 letters, digits or underscores"
    require_checkout

    # The auth core verifies argon2id hashes (argon2id_verify), the same format
    # PHP's password_hash() produces in the web image.
    local hash
    hash="$(compose exec -T web php -r 'echo password_hash($argv[1], PASSWORD_ARGON2ID);' \
        "$password" | tr -d '\r')"
    [[ "$hash" == '$argon2id$'* ]] || die "could not hash the password: $hash"

    compose exec -T mysql sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$1"' \
        mysql "$(env_get MYSQL_DB_ACCOUNT)" <<SQL
INSERT INTO account (login, password, email, status, create_time, last_play)
VALUES ('$login', '$hash', '$login@localhost', 'OK', NOW(), NOW())
ON DUPLICATE KEY UPDATE password = VALUES(password), status = 'OK';
SQL
    log "account '$login' ready"
}

cmd_client() {
    local dist="${1:-}" address="${2:-$SERVER_PUBLIC_IP}"
    [ -n "$dist" ] || die "usage: server.sh client <dist> [address]"
    local python
    # Skip launcher stubs (the Windows python3 alias) that exist but do not run.
    for python in python3 python ""; do
        [ -n "$python" ] || die "python3 is required"
        "$python" -c '' >/dev/null 2>&1 && break
    done
    "$python" "$SCRIPT_DIR/set-server.py" "$dist" "$address"
}

case "${1:-}" in
    fetch)     shift; cmd_fetch "$@" ;;
    configure) shift; cmd_configure "$@" ;;
    up)        shift; cmd_up "$@" ;;
    down)      shift; require_checkout; compose down "$@" ;;
    status)    shift; require_checkout; compose ps "$@" ;;
    logs)      shift; require_checkout; compose logs -f "$@" ;;
    account)   shift; cmd_account "$@" ;;
    client)    shift; cmd_client "$@" ;;
    help|-h|--help|"") usage ;;
    *)         die "unknown command '$1' (see 'server.sh help')" ;;
esac
