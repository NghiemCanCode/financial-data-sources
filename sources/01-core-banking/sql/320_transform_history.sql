SET ROLE core_owner;
SET synchronous_commit = off;

-- 30% of transactions, about 4 million rows
INSERT INTO core.transactions (txn_id, txn_ts, customer_id, card_id, amount, use_chip, merchant_id,
  merchant_city, merchant_state, zip, mcc, errors)
SELECT txn_id, txn_ts, customer_id, card_id, amount, use_chip, merchant_id,
  merchant_city, merchant_state, zip, mcc, errors
FROM stg.transactions_typed
WHERE txn_ts <= (SELECT t_cut FROM stg.split_cutoff);

-- Only labels due before T_cut. Labels of transactions close to T_cut may arrive later and sit in the queue
INSERT INTO core.txn_fraud_labels (txn_id, is_fraud, labeled_at)
SELECT txn_id, is_fraud, due_ts
FROM stg.fraud_labels_due
WHERE due_ts <= (SELECT t_cut FROM stg.split_cutoff);

-- Initial balance = sum of each card's existing transactions
INSERT INTO core.card_balances (card_id, current_balance, last_txn_id)
SELECT c.card_id, coalesce(sum(t.amount), 0), max(t.txn_id)
FROM core.cards c
LEFT JOIN core.transactions t ON t.card_id = c.card_id
GROUP BY c.card_id;
RESET ROLE;
