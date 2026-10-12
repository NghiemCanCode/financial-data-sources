CREATE ROLE replay_owner NOLOGIN;
CREATE DATABASE core_banking_replay OWNER replay_owner TEMPLATE template0;
REVOKE ALL ON DATABASE core_banking_replay FROM PUBLIC;
GRANT CONNECT ON DATABASE core_banking_replay TO app_simulator;

\c core_banking_replay
REVOKE ALL ON SCHEMA public FROM PUBLIC;
CREATE SCHEMA replay AUTHORIZATION replay_owner;
GRANT USAGE ON SCHEMA replay TO app_simulator;