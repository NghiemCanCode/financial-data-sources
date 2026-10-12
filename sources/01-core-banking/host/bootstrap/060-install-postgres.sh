#!/usr/bin/env bash

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
mountpoint -q /pgdata && mountpoint -q /pgwal || { echo "/pgdata or /pgwal not mounted: run 052 first"; exit 1; }

# 1) Add the PGDG repository
apt-get install -y postgresql-common
/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
apt-get install -y -o Dpkg::Options::=--force-confold postgresql-common

# 2) Stop the package from creating a cluster on the root volume
sed -ri 's/^#?\s*create_main_cluster.*/create_main_cluster = false/' /etc/postgresql-common/createcluster.conf
grep create_main_cluster /etc/postgresql-common/createcluster.conf

# 3) Install and hold the version (minor upgrades are done deliberately)
apt-get install -y postgresql-17 postgresql-17-pgaudit postgresql-17-partman pgbackrest
apt-mark hold postgresql-17 postgresql-client-17 postgresql-17-pgaudit postgresql-17-partman pgbackrest

# 4) Create the cluster: data on /pgdata, WAL on /pgwal, checksums, builtin locale
if ! pg_lsclusters -h | awk '{print $1, $2}' | grep -qx "17 main"; then
    install -d -o postgres -g postgres -m 0700 /pgdata/17 /pgwal/17
    pg_createcluster 17 main --datadir=/pgdata/17/main --locale=C.UTF-8 -- \
        --data-checksums --waldir=/pgwal/17/main \
        --locale-provider=builtin --builtin-locale=C.UTF-8
fi

# 5) Never start before both volumes are mounted
install -d -m 0755 /etc/systemd/system/postgresql@17-main.service.d
install -m 0644 /opt/fds/core-banking/host/etc/systemd/system/postgresql@17-main.service.d/override.conf \
    /etc/systemd/system/postgresql@17-main.service.d/override.conf
systemctl daemon-reload

pg_lsclusters