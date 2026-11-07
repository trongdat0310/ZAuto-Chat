# zchatauto encrypted offsite backup + email alert rollout

Keep the existing **03:00 local zchatauto-backup.timer** unchanged. The new 03:20 job uploads that already-consistent tar.gz archive to a private Cloudflare R2 bucket with restic client-side encryption. It does not stop the backend.

## 1. Cloudflare R2

1. In Cloudflare Dashboard > R2 Object Storage create a PRIVATE bucket named zchatauto-backups (billing might be required).
2. Create an R2 API token with Object Read & Write access restricted to this bucket; copy the access key, secret key and Cloudflare Account ID. Do not share these.
3. On Ubuntu:

~~~sh
sudo apt-get update
sudo apt-get install -y restic openssl
sudo install -d -m 0700 -o root -g root /etc/zchatauto
sudo sh -c 'umask 077; openssl rand -base64 48 > /etc/zchatauto/restic-password'
sudo chmod 0600 /etc/zchatauto/restic-password
sudo nano /etc/zchatauto/backup-offsite.env
~~~

Put the following into /etc/zchatauto/backup-offsite.env, replacing placeholders **locally**, NOT in GitHub:

~~~dotenv
RESTIC_REPOSITORY="s3:https://ACCOUNT_ID.r2.cloudflarestorage.com/zchatauto-backups"
RESTIC_PASSWORD_FILE=/etc/zchatauto/restic-password
AWS_ACCESS_KEY_ID="R2_ACCESS_KEY_ID"
AWS_SECRET_ACCESS_KEY="R2_SECRET_ACCESS_KEY"
AWS_DEFAULT_REGION=auto
~~~

~~~sh
sudo chown root:root /etc/zchatauto/backup-offsite.env
sudo chmod 0600 /etc/zchatauto/backup-offsite.env
sudo bash -c 'set -a; . /etc/zchatauto/backup-offsite.env; set +a; restic init'
~~~

Initialize once only. Keep a copy of the restic password **OUTSIDE** the Ubuntu laptop; without it cloud backups cannot be decrypted. Bucket jurisdiction endpoints can differ.

## 2. Install systemd

After pulling refactor/architecture, from zauto-backend:

~~~sh
npm run test:backup
sudo install -m 0700 -o root -g root deploy/backup/zchatauto-offsite-backup.sh /usr/local/sbin/zchatauto-offsite-backup.sh
sudo install -m 0644 deploy/backup/zchatauto-offsite-backup.service /etc/systemd/system/
sudo install -m 0644 deploy/backup/zchatauto-offsite-backup.timer /etc/systemd/system/
sudo install -m 0644 deploy/backup/zchatauto-backup-alert.service /etc/systemd/system/
sudo install -m 0644 deploy/backup/zchatauto-backup-alert.timer /etc/systemd/system/
sudo systemctl daemon-reload
~~~

Normal scheduled upload requires an archive created in the last 2h. For the **first daytime manual test** upload the newest valid archive, up to 26h old, without touching the running API:

~~~sh
sudo bash -c 'set -a; . /etc/zchatauto/backup-offsite.env; set +a; ZCHATAUTO_ARCHIVE_MAX_AGE_SECONDS=93600 /usr/local/sbin/zchatauto-offsite-backup.sh'
sudo bash -c 'set -a; . /etc/zchatauto/backup-offsite.env; set +a; restic snapshots --tag zchatauto-daily'
sudo test -f /var/lib/zchatauto-backups/offsite-last-success.json && echo 'OFFSITE: SUCCESS'
~~~

After successful upload enable the daily 03:20 schedule:

~~~sh
sudo systemctl enable --now zchatauto-offsite-backup.timer
systemctl list-timers --all | grep zchatauto-offsite
~~~

To rerun the normal service within 2h after the 03:00 local backup:

~~~sh
sudo systemctl start zchatauto-offsite-backup.service
sudo journalctl -u zchatauto-offsite-backup.service -n 40 --no-pager
~~~

## 3. Backup-failure and recovery email

Reuse existing SMTP_* configuration in backend .env. By default the recipient is PAYMENT_ALERT_TO. Add an optional single address BACKUP_ALERT_TO=hotro.zchatauto@gmail.com to override.

~~~sh
sudo node scripts/backup-alert.js --dry-run
sudo node scripts/backup-alert.js --test-email
sudo systemctl start zchatauto-backup-alert.service
sudo journalctl -u zchatauto-backup-alert.service -n 40 --no-pager
sudo systemctl enable --now zchatauto-backup-alert.timer
~~~

Monitor checks every 30m: local and offsite success are missing or older than 26h; remote archive has not caught up 1h after local; backup services failed. Sends one email per new incident, reminds after 24h if unresolved, and sends a recovery email when fixed. SMTP failures retry. State remains root-only in /var/lib/zchatauto-backups/backup-alert-state.json.

Add immediate OnFailure notification to the existing local backup service via a drop-in (do not replace its current commands):

~~~sh
sudo mkdir -p /etc/systemd/system/zchatauto-backup.service.d
printf '[Unit]\nOnFailure=zchatauto-backup-alert.service\n' | sudo tee /etc/systemd/system/zchatauto-backup.service.d/alert.conf > /dev/null
sudo systemctl daemon-reload
~~~

Offsite service already triggers the alert service on failure. Do not deliberately break live backups to test it.

## 4. Cloud restore drill

Verify the repository contains a snapshot. Restore to a temporary directory, never production:

~~~sh
RESTORE_DIR=$(sudo mktemp -d /var/tmp/zchatauto-r2-restore.XXXXXX)
sudo bash -c 'set -a; . /etc/zchatauto/backup-offsite.env; set +a; restic restore latest --target "$1"' _ "$RESTORE_DIR"
sudo find "$RESTORE_DIR" -type f -name 'backend-*.tar.gz' -print
sudo find "$RESTORE_DIR" -type f -name 'backend-*.tar.gz' -exec tar -tzf '{}' \; | head -n 30
~~~

After confirming extracted files, remove the temporary directory using its printed exact path. Keep a separate encrypted copy of backend .env, Tunnel credentials and the restic password, because they are NOT in the data archive. Test complete recovery on an isolated machine.

## 5. Limitations

A successful marker is not a full restore guarantee. Run restic check and test decrypting/restoring periodically. Snapshot deletion is not enabled yet; plan retention and prune only after successful recovery testing. Cloudflare R2 has usage charges. Backup alert email does not run when the laptop is powered off: maintain external monitoring.
