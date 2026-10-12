#!/usr/bin/env bash
# Step 4.2: role passwords and the pgBackRest cipher. Safe to re-run: existing values are never overwritten.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
genpw() { openssl rand -base64 48 | tr -d '/+=\n' | cut -c1-32; }

for r in app_simulator cdc_airbyte ro_analyst; do
    set_if_placeholder /fds/core-banking/pg/$r "$(genpw)"
done

set_if_placeholder /fds/core-banking/pgbackrest/cipher-pass "$(openssl rand -base64 48 | tr -d '\n')"
