SET ROLE core_owner;

-- Create PK and indexes AFTER loading
ALTER TABLE core.transactions ADD PRIMARY KEY (txn_id, txn_ts);
CREATE INDEX ON core.transactions (card_id, txn_ts);
CREATE INDEX ON core.transactions (customer_id, txn_ts);

-- Sequence for transactions created outside replay (chaos, tests). Starts after the max id of the WHOLE seed,
-- so it never collides with ids of the 70% that will be replayed.
CREATE SEQUENCE core.txn_id_seq;
SELECT setval('core.txn_id_seq', (SELECT max(txn_id) FROM stg.transactions_typed));
RESET ROLE;
