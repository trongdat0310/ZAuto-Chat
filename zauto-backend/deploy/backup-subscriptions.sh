#!/bin/sh
set -eu
umask 077

DATA_DIR="${DATA_DIR:-/opt/zchatauto/zauto-backend/data}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/zchatauto}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$BACKUP_DIR"
# The backend uses atomic rename for subscription updates. This copies a
# consistent file snapshot, but does not replace a full disaster-recovery plan.
if [ ! -f "$DATA_DIR/subscriptions.json" ]; then
  echo "Missing subscriptions.json; refusing empty backup" >&2
  exit 1
fi
tmp="$BACKUP_DIR/.subscriptions-$STAMP.json.tmp"
trap 'rm -f "$tmp"' EXIT HUP INT TERM
cp "$DATA_DIR/subscriptions.json" "$tmp"
node -e 'JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"))' "$tmp"
mv "$tmp" "$BACKUP_DIR/subscriptions-$STAMP.json"
trap - EXIT HUP INT TERM
echo "Backup saved: $BACKUP_DIR/subscriptions-$STAMP.json"
