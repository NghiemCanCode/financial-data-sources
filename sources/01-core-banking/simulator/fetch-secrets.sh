#!/usr/bin/env bash
# ExecStartPre of fds-simulator.service. Every start re-fetches the password and CA, so after a
# rotation (step 15, incident #17) just run: sudo systemctl restart fds-simulator
set -euo pipefail
umask 077
D=/run/fds-simulator
P=/fds/core-banking

pw=$(aws ssm get-parameter --name $P/pg/app_simulator --with-decryption --query Parameter.Value --output text)

aws ssm get-parameter --name $P/tls/ca-crt --query Parameter.Value --output text > $D/ca.crt

# .pgpass format: host:port:database:user:password, with \ and : escaped
printf '*:5432:*:app_simulator:%s\n' "$(printf '%s' "$pw" | sed 's/[\\:]/\\&/g')" > $D/pgpass

chown fds-sim:fds-sim $D/ca.crt $D/pgpass
chmod 0644 $D/ca.crt
