#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
NAT_ID=$(tf_out nat_instance_id)     # this source's own NAT
CORE_ID=$(tf_out instance_id)
SIM_ID=$(tf_out sim_instance_id)

echo ">> Start NAT + Core Banking"
aws ec2 start-instances --instance-ids "$NAT_ID" "$CORE_ID" >/dev/null
aws ec2 wait instance-running --instance-ids "$NAT_ID" "$CORE_ID"

echo ">> Waiting for the SSM agent to come online (needs the NAT running)"
wait_ssm_online "$CORE_ID"

echo ">> Health check + partition maintenance"
run_remote "$CORE_ID" '
set -e
sudo -u postgres pg_isready -t 120
# Two -c flags, not one: a procedure with COMMIT inside cannot run in the implicit
# transaction psql opens when several statements share a single -c. SET ROLE persists
# across -c flags because they run in the same session.
sudo -u postgres psql -XAt -d core_banking -c "SET ROLE core_owner" -c "CALL partman.run_maintenance_proc()"
echo "--- slots"
sudo -u postgres psql -XAt -c "SELECT slot_name, active, wal_status, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) FROM pg_replication_slots"
echo "--- archiver"
sudo -u postgres psql -XAt -c "SELECT archived_count, failed_count, last_failed_time FROM pg_stat_archiver"
echo "--- default partition (must be 0)"
sudo -u postgres psql -XAt -d core_banking -c "SELECT count(*) FROM core.transactions_default" || true
echo "--- replay: virtual_now, txn_seq"
sudo -u postgres psql -XAt -d core_banking_replay -c "SELECT virtual_now, txn_seq FROM replay.state" || true
echo "--- cert expiry"
openssl x509 -enddate -noout -in /etc/postgresql/17/main/tls/server.crt
echo "--- auto-stop"
systemctl list-timers auto-stop.timer --no-pager | head -2
'

# Start the simulator last, once PG is ready. The fds-simulator service starts on boot.
echo ">> Start simulator"
aws ec2 start-instances --instance-ids "$SIM_ID" >/dev/null
aws ec2 wait instance-running --instance-ids "$SIM_ID"
echo ">> Ready. The generator is replaying; Airbyte syncs on its own schedule."
