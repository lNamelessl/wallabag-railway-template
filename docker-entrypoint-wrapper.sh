#!/bin/sh
# Railway wrapper entrypoint for wallabag (official wallabag/wallabag image, unmodified).
# Adds two things before handing off to the upstream /entrypoint.sh:
#   1. sqlite dir prep - mirrors upstream's own local-folder-binding handling for
#      data/db (mkdir + chown nobody), plus data/assets which the volume mount shadows.
#   2. first-boot admin password seed - marker-guarded, runs in a background waiter.
#      The upstream provisioner installs the database and only then starts nginx,
#      so "/api/info answering" == "install complete, admin user exists".
set -u

DATA_DIR=/var/www/wallabag/data
MARKER="$DATA_DIR/.admin-seeded"
CREDS="$DATA_DIR/default-creds.txt"

# 1. dir prep (idempotent; upstream entrypoint mkdir/chowns data/db when the DB is missing)
mkdir -p "$DATA_DIR/db" "$DATA_DIR/assets"
chown nobody: "$DATA_DIR/db" "$DATA_DIR/assets" 2>/dev/null || true

cd /var/www/wallabag || exit 1

# 2. first-boot admin password seed (background waiter, marker-guarded: runs exactly once)
(
    if [ ! -f "$MARKER" ]; then
        PW="${ADMIN_PASSWORD:-}"
        if [ -z "$PW" ]; then
            PW="$(head -c 24 /dev/urandom | base64 | tr -d '\n+/=' | cut -c 1-24)"
        fi
        i=0
        while [ "$i" -lt 150 ]; do
            if curl -sf http://127.0.0.1:80/api/info >/dev/null 2>&1; then
                break
            fi
            i=$((i + 1))
            sleep 2
        done
        if curl -sf http://127.0.0.1:80/api/info >/dev/null 2>&1; then
            printf '%s' "$PW" > /tmp/.wallabag-pw
            chmod 644 /tmp/.wallabag-pw
            if su -c "php bin/console fos:user:change-password wallabag \"\$(cat /tmp/.wallabag-pw)\" --env=prod" -s /bin/sh nobody >/dev/null 2>&1; then
                printf 'username: wallabag\npassword: %s\n' "$PW" > "$CREDS"
                chmod 600 "$CREDS"
                touch "$MARKER"
                echo "[railway-wrapper] admin password seeded (read it: cat $CREDS, then delete this file)"
            else
                echo "[railway-wrapper] WARN: password seed FAILED; default wallabag/wallabag remains"
            fi
            rm -f /tmp/.wallabag-pw
        else
            echo "[railway-wrapper] WARN: app never answered /api/info; password seed skipped"
        fi
    fi
) &

echo "[railway-wrapper] handing off to upstream entrypoint: $*"
exec /entrypoint.sh "$@"
