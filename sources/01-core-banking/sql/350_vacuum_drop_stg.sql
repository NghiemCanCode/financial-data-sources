VACUUM (FREEZE, ANALYZE) core.customers, core.cards, core.mcc_codes,
  core.transactions, core.txn_fraud_labels, core.card_balances;

DROP VIEW stg.transactions_typed, stg.cards_typed;
DROP TABLE stg.split_cutoff, stg.fraud_labels_due,
  stg.transactions_raw, stg.cards_raw, stg.users_raw, stg.mcc_raw, stg.fraud_labels_raw;
