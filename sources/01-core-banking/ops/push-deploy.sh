#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

aws s3 sync "$SRC_DIR/" "s3://$(tf_out backup_bucket)/deploy/" --delete \
    --exclude '*' --include 'host/*' --include 'sql/*' --include 'seed/*' \
    --include 'replay/*' --include 'simulator/*'