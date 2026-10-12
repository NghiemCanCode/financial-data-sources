COPY (SELECT t_cut FROM stg.split_cutoff)
    TO '/pgdata/seed/replay/t_cut.csv' WITH (FORMAT csv);

COPY (SELECT row_number() OVER (ORDER BY open_ts, card_id), open_ts,
            card_id, customer_id, card_brand, card_type, card_number, expires, cvv, has_chip,
            num_cards_issued, credit_limit, acct_open_date, year_pin_last_changed, card_on_dark_web
        FROM stg.cards_typed
        WHERE open_ts > (SELECT t_cut FROM stg.split_cutoff))
    TO '/pgdata/seed/replay/card_queue.csv' WITH (FORMAT csv);

COPY (SELECT row_number() OVER (ORDER BY txn_ts, txn_id), txn_ts,
            txn_id, customer_id, card_id, amount, use_chip, merchant_id,
            merchant_city, merchant_state, zip, mcc, errors
        FROM stg.transactions_typed
        WHERE txn_ts > (SELECT t_cut FROM stg.split_cutoff))
    TO '/pgdata/seed/replay/txn_queue.csv' WITH (FORMAT csv);

COPY (SELECT row_number() OVER (ORDER BY due_ts, txn_id), due_ts, txn_id, is_fraud
        FROM stg.fraud_labels_due
        WHERE due_ts > (SELECT t_cut FROM stg.split_cutoff))
    TO '/pgdata/seed/replay/label_queue.csv' WITH (FORMAT csv);