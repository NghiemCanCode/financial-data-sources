H=ip-10-101-10-10.ap-southeast-1.compute.internal
C="host=$H dbname=core_banking user=cdc_airbyte sslmode=verify-full sslrootcert=ca.crt"

# 1. Replication connection works
psql "$C replication=database" -c "IDENTIFY_SYSTEM;"

# 2. Create a test slot and DROP IT IMMEDIATELY (a forgotten slot retains WAL forever)
psql "$C" -c "select pg_create_logical_replication_slot('smoke_test', 'pgoutput')"
psql "$C" -c "select pg_drop_replication_slot('smoke_test')"

# 3. CDC cannot write
psql "$C" -c "delete from core.mcc_codes where false"   # → permission denied

# 4. CDC cannot connect to the replay database
psql "host=$H dbname=core_banking_replay user=cdc_airbyte sslmode=verify-full sslrootcert=ca.crt" -c 'select 1'
#    → pg_hba.conf rejects connection
