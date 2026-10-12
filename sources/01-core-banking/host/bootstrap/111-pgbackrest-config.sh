#!/usr/bin/env bash
# Step 11.1: render /etc/pgbackrest/pgbackrest.conf from the repo template.
# Usage: sudo bash 111-pgbackrest-config.sh <backup_bucket>   (tf_out backup_bucket on the laptop)
set -euo pipefail
BACKUP_BUCKET=${1:?missing backup bucket name}
TPL=/opt/fds/core-banking/host/etc/pgbackrest/pgbackrest.conf.tpl
CONF=/etc/pgbackrest/pgbackrest.conf

install -d -o postgres -g postgres -m 0750 /var/log/pgbackrest /var/spool/pgbackrest
install -d -o root -g root -m 0755 /etc/pgbackrest
rm -f /etc/pgbackrest.conf     # stale sample file from the package, avoid confusion

cipher=$(aws ssm get-parameter --region ap-southeast-1 --name /fds/core-banking/pgbackrest/cipher-pass \
  --with-decryption --query Parameter.Value --output text)
[ "$cipher" != "set-by-script" ] || { echo "cipher-pass is still a placeholder: run setup/042 first"; exit 1; }

umask 027
sed -e "s|__BACKUP_BUCKET__|$BACKUP_BUCKET|" -e "s|__CIPHER_PASS__|$cipher|" "$TPL" > "$CONF"
chown root:postgres "$CONF"
chmod 0640 "$CONF"
unset cipher

grep -q "^repo1-s3-bucket=$BACKUP_BUCKET$" "$CONF" && echo "rendered $CONF"
