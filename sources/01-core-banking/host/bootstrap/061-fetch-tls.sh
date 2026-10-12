#!/usr/bin/env bash

set -euo pipefail
TLS=/etc/postgresql/17/main/tls
P=/fds/core-banking/tls

getp() {
    local v
    v=$(aws ssm get-parameter --name "$1" --with-decryption --query Parameter.Value --output text)
    [ "$v" != "set-by-script" ] || { echo "$1 is still a placeholder: run setup/044 on the laptop first"; exit 1; }
    printf '%s\n' "$v"
}

install -d -o postgres -g postgres -m 0700 $TLS
umask 077
getp $P/server-key > $TLS/server.key
getp $P/server-crt > $TLS/server.crt
getp $P/ca-crt > $TLS/ca.crt

chown postgres:postgres $TLS/server.key $TLS/server.crt $TLS/ca.crt
chmod 0600 $TLS/server.key
chmod 0644 $TLS/server.crt $TLS/ca.crt

openssl verify -CAfile $TLS/ca.crt $TLS/server.crt
diff <(openssl pkey -in $TLS/server.key -pubout) <(openssl x509 -in $TLS/server.crt -pubkey -noout) >/dev/null \
    || { echo "sever.key does not match server.crt"; exit 1; }
openssl x509 -enddate -noout -in $TLS/server.crt