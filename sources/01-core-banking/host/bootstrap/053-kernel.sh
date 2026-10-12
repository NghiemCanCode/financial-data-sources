#!/usr/bin/env bash
set -euo pipefail
SRC=/opt/fds/core-banking/host/etc

install -o root -g root -m 0644 $SRC/sysctl.d/90-postgresql.conf    /etc/sysctl.d/90-postgresql.conf
install -o root -g root -m 0644 $SRC/systemd/system/disable-thp.service     /etc/systemd/system/disable-thp.service

sysctl --system >/dev/null
systemctl daemon-reload
systemctl enable --now disable-thp

sysctl vm.swappiness vm.dirty_background_bytes vm.dirty_bytes
cat /sys/kernel/mm/transparent_hugepage/enabled
