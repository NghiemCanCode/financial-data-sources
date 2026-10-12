#!/usr/bin/env bash
# Usage: ./demo-stop.sh [diff|full|none]   (default: diff)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
NAT_ID=$(tf_out nat_instance_id)     # this source's own NAT
CORE_ID=$(tf_out instance_id)
SIM_ID=$(tf_out sim_instance_id)
TYPE=${1:-diff}

# Stop the simulator first: systemd sends SIGTERM, the generator finishes its batch and saves the cursor
echo ">> Stop simulator"
aws ec2 stop-instances --instance-ids "$SIM_ID" >/dev/null
aws ec2 wait instance-stopped --instance-ids "$SIM_ID"

echo ">> For a clean shutdown, pause the Airbyte connection. Otherwise later syncs fail to connect (incident #3)"
if [ "$TYPE" != "none" ]; then
  echo ">> Backup $TYPE"
  run_remote "$CORE_ID" "sudo -u postgres pgbackrest --stanza=core-banking --type=$TYPE backup && sudo -u postgres pgbackrest --stanza=core-banking info | tail -8" 7200
fi

echo ">> Stop Core Banking + NAT"
aws ec2 stop-instances --instance-ids "$CORE_ID" "$NAT_ID" >/dev/null
aws ec2 wait instance-stopped --instance-ids "$CORE_ID" "$NAT_ID"
echo ">> Stopped."
