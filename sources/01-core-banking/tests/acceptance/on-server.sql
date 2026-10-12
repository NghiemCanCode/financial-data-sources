sudo -u postgres psql -d core_banking -XA <<'SQL'
SHOW data_checksums;
SELECT datname, datlocprovider, datcollate FROM pg_database WHERE datname = 'core_banking';
SHOW huge_pages_status;
SELECT count(*) AS partitions FROM pg_inherits WHERE inhparent = 'core.transactions'::regclass;
SELECT count(*) FROM core.transactions_default;
SELECT count(*) FROM pg_publication_tables WHERE pubname = 'airbyte_core_banking';
SELECT * FROM pg_replication_slots;   -- before 10.2: empty. After 10.2: only airbyte_core_banking
SELECT archived_count, failed_count FROM pg_stat_archiver;
SELECT rolname, rolsuper, rolreplication, rolconnlimit FROM pg_roles WHERE rolname NOT LIKE 'pg\_%';
\c core_banking_replay
SELECT t_cut, virtual_now, card_seq, txn_seq, label_seq FROM replay.state;
SQL
sudo -u postgres pgbackrest --stanza=core-banking info
