COPY stg.transactions_raw FROM '/pgdata/seed/transactions_data.csv' WITH (FORMAT csv, HEADER true);
COPY stg.cards_raw        FROM '/pgdata/seed/cards_data.csv'        WITH (FORMAT csv, HEADER true);
COPY stg.users_raw        FROM '/pgdata/seed/users_data.csv'        WITH (FORMAT csv, HEADER true);
COPY stg.mcc_raw          FROM '/pgdata/seed/mcc_codes.csv'         WITH (FORMAT csv);
COPY stg.fraud_labels_raw FROM '/pgdata/seed/fraud_labels.csv'      WITH (FORMAT csv);
