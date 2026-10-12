#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

if [ -f "$TLS_DIR/ca.key" ]; then
    echo "$TLS_DIR/ca.key already exists: not creating a new CA."
    exit 0
fi
cur=$(aws ssm get-parameter --name /fds/core-banking/admin/tls/ca-key --with-decryption --query Parameter.Value --output text)
if [ "$cur" != "set-by-script" ]; then
    echo "SSM already has a CA but $TLS_DIR does not. Restore it with:"
    echo "  mkdir -p -m 0700 $TLS_DIR"
    echo "  aws ssm get-parameter --name /fds/core-banking/admin/tls/ca-key --with-decryption --query Parameter.Value --output text > $TLS_DIR/ca.key"
    echo "  chmod 0600 $TLS_DIR/ca.key"
    echo "  and fetch ca.crt from /fds/core-banking/tls/ca-crt (after 044 has run)."
    exit 1
fi

umask 077
mkdir -p -m 0700 "$TLS_DIR"
cd "$TLS_DIR"

openssl ecparam -name prime256v1 -genkey -noout -out ca.key
openssl req -x509 -new -key ca.key -sha256 -days 3650 -subj "/CN=fds-core-banking-ca" \
    -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" \
    -out ca.crt

set_if_placeholder /fds/core-banking/admin/tls/ca-key file://ca.key
echo "CA written to $TLS_DIR"
