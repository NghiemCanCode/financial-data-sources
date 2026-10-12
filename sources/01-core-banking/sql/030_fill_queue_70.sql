SET synchronous_commit = off;
COPY replay.card_queue  FROM '/pgdata/seed/replay/card_queue.csv'  WITH (FORMAT csv);
COPY replay.txn_queue   FROM '/pgdata/seed/replay/txn_queue.csv'   WITH (FORMAT csv);
COPY replay.label_queue FROM '/pgdata/seed/replay/label_queue.csv' WITH (FORMAT csv);

CREATE TEMP TABLE cutoff (t_cut timestamp);
COPY cutoff FROM '/pgdata/seed/replay/t_cut.csv' WITH (FORMAT csv);
INSERT INTO replay.state (t_cut, virtual_now) SELECT t_cut, t_cut FROM cutoff;

VACUUM (FREEZE, ANALYZE) replay.card_queue, replay.txn_queue, replay.label_queue;

SELECT (SELECT count(*) FROM replay.card_queue)  AS cards,
       (SELECT count(*) FROM replay.txn_queue)   AS txns,
       (SELECT count(*) FROM replay.label_queue) AS labels,
       t_cut, virtual_now
FROM replay.state;