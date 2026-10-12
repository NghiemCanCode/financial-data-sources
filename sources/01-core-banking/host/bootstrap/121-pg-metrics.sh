#!/usr/bin/env bash
# Step 12.1: install the metric script and its cron entry, then push one sample.
# Usage: sudo bash 121-pg-metrics.sh      (safe to re-run)
set -euo pipefail
SRC=/opt/fds/core-banking/host

install -o root -g root -m 0755 $SRC/bin/pg-metrics.sh        /usr/local/bin/pg-metrics.sh
install -o root -g root -m 0644 $SRC/etc/cron.d/pg-metrics    /etc/cron.d/pg-metrics

# One manual run as postgres: proves psql auth, IAM permission and the namespace condition all work
sudo -u postgres /usr/local/bin/pg-metrics.sh && echo "metrics pushed OK"
