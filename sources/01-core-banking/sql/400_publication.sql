CREATE PUBLICATION airbyte_core_banking FOR TABLES IN SCHEMA core
  WITH (publish_via_partition_root = true);

SELECT * FROM pg_publication_tables WHERE pubname = 'airbyte_core_banking';
