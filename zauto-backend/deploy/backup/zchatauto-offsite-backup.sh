#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# Upload only the already-consistent local archive. Never stop the running API.
BACKUP_DIR="${ZCHATAUTO_LOCAL_BACKUP_DIR:-/var/backups/zchatauto}"
STATE_DIR="${ZCHATAUTO_BACKUP_STATE_DIR:-/var/lib/zchatauto-backups}"
MAX_AGE_SECONDS="${ZCHATAUTO_ARCHIVE_MAX_AGE_SECONDS:-7200}"

fail() { printf '[OFFSITE_BACKUP] ERROR: %s\n' "$*" >&2; exit 1; }
[[ $(id -u) -eq 0 ]] || fail 'Must be run as root via systemd.'
command -v restic >/dev/null 2>&1 || fail 'restic executable missing.'
command -v node >/dev/null 2>&1 || fail 'node executable missing.'
[[ -n "${RESTIC_REPOSITORY:-}" && "${RESTIC_REPOSITORY}" == s3:https://* ]] || fail 'Missing or invalid RESTIC_REPOSITORY.'
[[ -n "${RESTIC_PASSWORD_FILE:-}" && -r "${RESTIC_PASSWORD_FILE}" ]] || fail 'Missing or unreadable RESTIC_PASSWORD_FILE.'
[[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]] || fail 'Missing R2 S3 credentials.'
[[ "$MAX_AGE_SECONDS" =~ ^[0-9]+$ ]] || fail 'Invalid MAX_AGE_SECONDS.'
[[ -d "$BACKUP_DIR" ]] || fail 'Local backup directory missing.'
install -d -m 0700 "$STATE_DIR"

shopt -s nullglob
archives=("$BACKUP_DIR"/backend-*.tar.gz)
(( ${#archives[@]} > 0 )) || fail 'No backend archives found.'
latest=''
latest_mtime=0
for file in "${archives[@]}"; do
  [[ -f "$file" && ! -L "$file" ]] || continue
  name="$(basename -- "$file")"
  [[ "$name" =~ ^backend-[0-9]{8}-[0-9]{6}\.tar\.gz$ ]] || continue
  mtime=$(stat -c %Y -- "$file")
  if (( mtime > latest_mtime )); then latest="$file"; latest_mtime="$mtime"; fi
done
[[ -n "$latest" ]] || fail 'No valid backend archive found.'
now_epoch=$(date +%s)
age=$(( now_epoch - latest_mtime ))
(( age >= -300 && age <= MAX_AGE_SECONDS )) || fail "Latest local backup is not fresh (${age}s)."

# Validate archive integrity and required subscription state without extraction.
tar -tzf "$latest" >/dev/null || fail 'Archive gzip/tar validation failed.'
manifest=$(mktemp)
trap 'rm -f -- "$manifest"' EXIT
tar -tzf "$latest" > "$manifest"
grep -Fxq 'data/subscriptions.json' "$manifest" || fail 'Backup missing data/subscriptions.json.'

printf '[OFFSITE_BACKUP] Uploading archive %s\n' "$(basename "$latest")"
restic backup --tag zchatauto-daily --host zchatauto-production -- "$latest"
# Extra authenticated repository check after upload; no secrets in output.
restic snapshots --json --tag zchatauto-daily --host zchatauto-production | node -e '
const fs = require("node:fs");
const path = process.argv[1];
const items = JSON.parse(fs.readFileSync(0, "utf8"));
if (!Array.isArray(items) || !items.some(s => s.paths?.includes(path))) {
  console.error("[OFFSITE_BACKUP] Uploaded archive absent from snapshot listing");
  process.exit(1);
}' "$latest"

stamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
marker_tmp=$(mktemp "$STATE_DIR/.last-offsite.XXXXXX")
trap 'rm -f -- "$manifest" "$marker_tmp"' EXIT
printf '{"version":1,"completedAt":"%s","archive":"%s","archiveMtimeEpoch":%s}\n' \
  "$stamp" "$(basename -- "$latest")" "$latest_mtime" > "$marker_tmp"
chmod 0600 "$marker_tmp"
mv -f -- "$marker_tmp" "$STATE_DIR/offsite-last-success.json"
printf '[OFFSITE_BACKUP] SUCCESS at %s\n' "$stamp"
