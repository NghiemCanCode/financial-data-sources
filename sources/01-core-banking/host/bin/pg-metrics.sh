#!/usr/bin/env bash
# Step 12.1: push PostgreSQL metrics to CloudWatch. Invoked every minute by /etc/cron.d/pg-metrics.
set -euo pipefail
export PATH=/usr/local/bin:/usr/bin:/bin     # cron only has /usr/bin:/bin; aws lives in /usr/local/bin
REGION=ap-southeast-1
NS=FDS/CoreBanking
DIM='Dimensions=[{Name=Source,Value=core-banking}]'

wal_pct=$(df --output=pcent /pgwal  | tail -1 | tr -dc '0-9')
data_pct=$(df --output=pcent /pgdata | tail -1 | tr -dc '0-9')

read -r retained lost conns archive_failing <<<"$(psql -XAt -F' ' -d postgres -c "
SELECT
  COALESCE((SELECT max(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn))
            FROM pg_replication_slots WHERE restart_lsn IS NOT NULL), 0)::bigint,
  (SELECT count(*) FROM pg_replication_slots WHERE wal_status = 'lost'),
  (SELECT count(*) FROM pg_stat_activity WHERE backend_type = 'client backend'),
  (SELECT CASE WHEN last_failed_time IS NOT NULL
                AND (last_archived_time IS NULL OR last_failed_time > last_archived_time)
          THEN 1 ELSE 0 END FROM pg_stat_archiver)")"

aws cloudwatch put-metric-data --region "$REGION" --namespace "$NS" --metric-data \
  "MetricName=WalDiskUsedPercent,Unit=Percent,Value=$wal_pct,$DIM" \
  "MetricName=DataDiskUsedPercent,Unit=Percent,Value=$data_pct,$DIM" \
  "MetricName=SlotRetainedWalBytes,Unit=Bytes,Value=$retained,$DIM" \
  "MetricName=SlotsLost,Unit=Count,Value=$lost,$DIM" \
  "MetricName=ClientConnections,Unit=Count,Value=$conns,$DIM" \
  "MetricName=ArchiveFailing,Unit=Count,Value=$archive_failing,$DIM"
