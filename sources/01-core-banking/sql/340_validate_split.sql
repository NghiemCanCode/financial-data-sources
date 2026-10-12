DO $$
DECLARE
    tc timestamp; total bigint; n_core bigint; n_rest bigint;
    lab_total bigint; lab_core bigint; card_total bigint; card_core bigint;
BEGIN
    SELECT t_cut, total_txn INTO tc, total FROM stg.split_cutoff;

    SELECT count(*) INTO n_core FROM core.transactions;
    SELECT count(*) INTO n_rest FROM stg.transactions_typed WHERE txn_ts > tc;
    IF n_core + n_rest <> total THEN
        RAISE EXCEPTION 'transactions: core % + replay % <> total %', n_core, n_rest, total;
    END IF;
    IF abs(n_core::numeric / total - 0.3) > 0.01 THEN
        RAISE EXCEPTION 'core ratio = %, must be close to 0.30', round(n_core::numeric / total, 4);
    END IF;
    IF EXISTS (SELECT 1 FROM core.transactions WHERE txn_ts > tc) THEN
        RAISE EXCEPTION 'core has transactions after T_cut';
    END IF;
    IF EXISTS (SELECT 1 FROM core.transactions_default) THEN
        RAISE EXCEPTION 'transactions landed in the default partition: check 210';
    END IF;

    SELECT count(*) INTO lab_total FROM stg.fraud_labels_due;
    SELECT count(*) INTO lab_core FROM core.txn_fraud_labels;
    IF lab_core <> (SELECT count(*) FROM stg.fraud_labels_due WHERE due_ts <= tc) THEN
        RAISE EXCEPTION 'fraud label count in core does not match labels due before T_cut';
    END IF;

    IF EXISTS (SELECT 1 FROM core.txn_fraud_labels l
        WHERE NOT EXISTS (SELECT 1 FROM core.transactions t WHERE t.txn_id = l.txn_id)) THEN
        RAISE EXCEPTION 'a fraud label points to a transaction that has not happened yet';
    END IF;

    SELECT count(*) INTO card_total FROM stg.cards_typed;
    SELECT count(*) INTO card_core FROM core.cards;
    IF (SELECT count(*) FROM core.card_balances) <> card_core THEN
        RAISE EXCEPTION 'card_balances is missing cards';
    END IF;
    IF (SELECT last_value FROM core.txn_id_seq) < (SELECT max(txn_id) FROM stg.transactions_typed) THEN
        RAISE EXCEPTION 'txn_id_seq is below the max id of the replay part';
    END IF;
    
    RAISE NOTICE 'OK. T_cut = %; transactions core % (% %%) / replay %; labels core % / replay %; cards core % / replay %',
        tc, n_core, round(100.0 * n_core / total, 2), n_rest,
        lab_core, lab_total - lab_core, card_core, card_total - card_core;
    END $$;