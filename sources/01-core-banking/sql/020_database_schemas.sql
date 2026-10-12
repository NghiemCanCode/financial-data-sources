CREATE DATABASE core_banking OWNER core_owner TEMPLATE template0;
REVOKE ALL ON DATABASE core_banking FROM PUBLIC;
GRANT CONNECT ON DATABASE core_banking TO app_simulator, cdc_airbyte, ro_analyst;

\c core_banking
REVOKE ALL ON SCHEMA public FROM PUBLIC;
CREATE SCHEMA core AUTHORIZATION core_owner;
CREATE SCHEMA stg AUTHORIZATION core_owner;
CREATE SCHEMA partman AUTHORIZATION core_owner;

CREATE EXTENSION pg_stat_statements;
CREATE EXTENSION pgaudit;
CREATE EXTENSION pg_partman SCHEMA partman;