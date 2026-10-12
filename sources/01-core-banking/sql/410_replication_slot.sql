-- A logical slot is bound to the connected database: must run with -d core_banking
SELECT pg_create_logical_replication_slot('airbyte_core_banking', 'pgoutput');
SELECT slot_name, plugin, database, active, wal_status FROM pg_replication_slots;
