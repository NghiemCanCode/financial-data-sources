CREATE ROLE core_owner NOLOGIN;
CREATE ROLE app_simulator LOGIN CONNECTION LIMIT 60;
CREATE ROLE cdc_airbyte LOGIN REPLICATION CONNECTION LIMIT 5;
CREATE ROLE ro_analyst LOGIN CONNECTION LIMIT 5;

ALTER ROLE app_simulator SET statement_timeout = '30s';
ALTER ROLE ro_analyst SET statement_timeout = '5min';
ALTER ROLE ro_analyst SET default_transaction_read_only = on;
