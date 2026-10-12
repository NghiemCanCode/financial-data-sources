SET ROLE core_owner;

CREATE UNLOGGED TABLE stg.transactions_raw (id text, date text, client_id text, card_id text, amount text, use_chip text, merchant_id text, merchant_city text, merchant_state text, zip text, mcc text, errors text);

CREATE UNLOGGED TABLE stg.cards_raw (id text, client_id text, card_brand text, card_type text, card_number text, expires text, cvv text, has_chip text, num_cards_issued text, credit_limit text, acct_open_date text, year_pin_last_changed text, card_on_dark_web text);

CREATE UNLOGGED TABLE stg.users_raw (id text, current_age text, retirement_age text, birth_year text, birth_month text, gender text, address text, latitude text, longitude text, per_capita_income text, yearly_income text, total_debt text, credit_score text, num_credit_cards text);

CREATE UNLOGGED TABLE stg.mcc_raw (mcc text, description text);

CREATE UNLOGGED TABLE stg.fraud_labels_raw (txn_id text, label text);
RESET ROLE;
