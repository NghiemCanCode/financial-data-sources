#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

for f in ca.key ca.crt; do
    [ -f "$TLS_DIR/$f" ] || {
        echo "$TLS_DIR/$f: not found, run script 043 before, or get it from /fds/core-banking/admin/tls/ca-key"
        exit 1
    }
done
CORE_IP=$(tf_out private_ip)        # 10.101.10.10
CORE_DNS=$(tf_out private_dns)      # ip-10-101-10-10.ap-southeast-1.compute.internal

umask 077
cd "$TLS_DIR"

openssl ecparam -name prime256v1 -genkey -noout -out server.key
openssl req -new -key server.key -subj "/CN=core-banking-pg" -out server.csr
cat > server.ext <<EOF
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = serverAuth
subjectAltName = DNS:${CORE_DNS}, IP:${CORE_IP}
EOF
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -days 90 -sha256 -extfile server.ext -out server.crt
openssl verify -CAfile ca.crt server.crt

aws ssm put-parameter --overwrite --name /fds/core-banking/tls/server-key --value file://server.key >/dev/null
aws ssm put-parameter --overwrite --name /fds/core-banking/tls/server-crt --value file://server.crt >/dev/null
aws ssm put-parameter --overwrite --name /fds/core-banking/tls/ca-crt --value file://ca.crt >/dev/null
echo "Pushed server-key, server-crt, ca-crt"
