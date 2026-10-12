set -euo pipefail
SRC=/opt/fds/core-banking/host/etc/postgresql/17/main
DST=/etc/postgresql/17/main

install -d -o postgres -g postgres -m 0755 $DST/conf.d
install -o postgres -g postgres -m 0644 $SRC/conf.d/10-fds.conf $DST/conf.d/10-fds.conf
install -o postgres -g postgres -m 0640 $SRC/pg_hba.conf $DST/pg_hba.conf