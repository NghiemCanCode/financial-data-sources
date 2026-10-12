#!/usr/bin/env bash
set -euo pipefail
DATA_VOL=${1:?not has data_volume_serial (tf_out data_volume_serial)}
WAL_VOL=${2:?not has wal_volume_serial (tf_out wal_volume_serial)}

mount_volume() {
    local serial=$1 label=$2 dir=$3 dev uuid
    dev=/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${serial}
    [ -b "$dev" ] || { echo "$dev not found: wrong serial, or the volume is not attached"; exit 1; }

    if [ -z "$(blkid -s TYPE -o value "$dev")" ]; then
        mkfs.xfs -L "$label" "$dev"
    fi

    uuid=$(blkid -s UUID -o value "$dev")
    mkdir -p "$dir"
    grep -q "UUID=$uuid" /etc/fstab || echo "UUID=$uuid $dir xfs defaults,noatime,nofail 0 0" >> /etc/fstab
}

mount_volume "$DATA_VOL" pgdata /pgdata
mount_volume "$WAL_VOL" pgwal /pgwal

systemctl daemon-reload
mount -a
findmnt /pgdata
findmnt /pgwal
df -h /pgdata /pgwal
