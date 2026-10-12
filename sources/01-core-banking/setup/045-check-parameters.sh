#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

left=$(aws ssm get-parameters-by-path --path /fds/core-banking --recursive --with-decryption \
    --query "Parameters[?Value=='set-by-script'].Name" --output text)
if [ -n "$left" ]; then
    echo "Not found: $left"
    exit 1
fi
echo "OK"
