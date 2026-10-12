SET ROLE core_owner;

-- Monthly partitions from 2010 to now + 4 months, plus a default partition
SELECT partman.create_parent(
  p_parent_table      => 'core.transactions',
  p_control           => 'txn_ts',
  p_interval          => '1 month',
  p_premake           => 4,
  p_start_partition   => '2010-01-01'
);
RESET ROLE;

SELECT count(*) AS partitions FROM pg_inherits WHERE inhparent = 'core.transactions'::regclass;
