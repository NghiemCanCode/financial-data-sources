SET ROLE core_owner;
SET work_mem = '512MB';   -- sorts 13M timestamps for the percentile

CREATE VIEW stg.transactions_typed AS
SELECT id::bigint AS txn_id, date::timestamp AS txn_ts, client_id::int AS customer_id, card_id::int AS card_id,
  replace(amount,'$','')::numeric(12,2) AS amount, use_chip, merchant_id::int AS merchant_id, merchant_city,
  nullif(merchant_state,'') AS merchant_state, nullif(regexp_replace(zip,'\.0$',''),'') AS zip,
  mcc::int AS mcc, nullif(errors,'') AS errors
FROM stg.transactions_raw;

CREATE VIEW stg.cards_typed AS
SELECT id::int AS card_id, client_id::int AS customer_id, card_brand, card_type, card_number, expires, cvv,
  upper(has_chip) = 'YES' AS has_chip, num_cards_issued::smallint AS num_cards_issued,
  replace(credit_limit,'$','')::numeric(12,2) AS credit_limit, acct_open_date,
  year_pin_last_changed::smallint AS year_pin_last_changed, upper(card_on_dark_web) = 'YES' AS card_on_dark_web,
  to_date(acct_open_date, 'MM/YYYY')::timestamp AS open_ts          -- first day of the card's opening month
FROM stg.cards_raw;

-- T_cut: 30% of transactions have txn_ts <= T_cut
CREATE UNLOGGED TABLE stg.split_cutoff AS
SELECT percentile_disc(0.3) WITHIN GROUP (ORDER BY txn_ts) AS t_cut, count(*) AS total_txn
FROM stg.transactions_typed;

-- Fraud labels arrive 24-168 hours after the transaction. The delay is derived from a hash of txn_id, so re-runs give the same result.
CREATE UNLOGGED TABLE stg.fraud_labels_due AS
SELECT t.txn_id, l.label = 'Yes' AS is_fraud,
       t.txn_ts + make_interval(hours => 24 + (hashint8(t.txn_id) % 145 + 145) % 145) AS due_ts
FROM stg.fraud_labels_raw l
JOIN stg.transactions_typed t ON t.txn_id = l.txn_id::bigint;

SELECT t_cut, total_txn, (SELECT count(*) FROM stg.fraud_labels_due) AS labels FROM stg.split_cutoff;
RESET ROLE;
