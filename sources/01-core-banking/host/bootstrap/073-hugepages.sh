#!/usr/bin/env bash
set -euo pipefail

need=$(sudo -u postgres /usr/lib/postgresql/17/bin/postgres -D /pgdata/17/main \
    -c config_file=/etc/postgresql/17/main/postgresql.conf -C shared_memory_size_in_huge_pages)
pages=$(( need * 102 / 100))

echo "vm.nr_hugepages = $pages" > /etc/sysctl.d/91-hugepages.conf
sysctl --system >/dev/null
grep -i hugepages_ /proc/meminfo