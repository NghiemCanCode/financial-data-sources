H=ip-10-101-10-10.ap-southeast-1.compute.internal

# 1. Without TLS the connection is rejected
psql "host=$H dbname=core_banking user=app_simulator sslmode=disable" -c 'select 1'
#    → FATAL: pg_hba.conf rejects connection ... no encryption

# 2. TLS verify-full succeeds; inspect session details
psql "host=$H dbname=core_banking user=app_simulator sslmode=verify-full sslrootcert=ca.crt" \
  -c "select ssl, version, cipher from pg_stat_ssl where pid = pg_backend_pid()"

# 3. Connecting by IP still verifies (the SAN includes the IP)
psql "host=10.101.10.10 dbname=core_banking user=app_simulator sslmode=verify-full sslrootcert=ca.crt" -c 'select 1'

# 4. The simulator cannot run DDL
psql "host=$H dbname=core_banking user=app_simulator sslmode=verify-full sslrootcert=ca.crt" \
  -c "create table core.hack(id int)"          # → permission denied for schema core

# 5. The simulator can write data
psql "host=$H dbname=core_banking user=app_simulator sslmode=verify-full sslrootcert=ca.crt" \
  -c "update core.card_balances set current_balance = current_balance where card_id = (select min(card_id) from core.cards)"

# 6. cdc_airbyte cannot connect from the simulator subnet
psql "host=$H dbname=core_banking user=cdc_airbyte sslmode=verify-full sslrootcert=ca.crt" -c 'select 1'
#    → pg_hba.conf rejects connection

# 7. The simulator can read the replay queues
psql "host=$H dbname=core_banking_replay user=app_simulator sslmode=verify-full sslrootcert=ca.crt" \
  -c "select t_cut, virtual_now, txn_seq from replay.state"

# 8. The simulator cannot modify the queues
psql "host=$H dbname=core_banking_replay user=app_simulator sslmode=verify-full sslrootcert=ca.crt" \
  -c "delete from replay.txn_queue where false"      # → permission denied
