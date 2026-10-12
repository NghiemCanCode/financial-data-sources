SET ROLE core_owner;
SET synchronous_commit = off;

-- All customers: users_data has no creation date
INSERT INTO core.customers (customer_id, current_age, retirement_age, birth_year, birth_month, gender, address,
  latitude, longitude, per_capita_income, yearly_income, total_debt, credit_score, num_credit_cards)
SELECT id::int, current_age::smallint, retirement_age::smallint, birth_year::smallint, birth_month::smallint,
  gender, address, latitude::numeric, longitude::numeric,
  replace(per_capita_income,'$','')::numeric, replace(yearly_income,'$','')::numeric,
  replace(total_debt,'$','')::numeric, credit_score::smallint, num_credit_cards::smallint
FROM stg.users_raw;

-- Only cards opened before or during the month containing T_cut. Later cards go to the queue (9.7)
INSERT INTO core.cards (card_id, customer_id, card_brand, card_type, card_number, expires, cvv, has_chip,
  num_cards_issued, credit_limit, acct_open_date, year_pin_last_changed, card_on_dark_web)
SELECT card_id, customer_id, card_brand, card_type, card_number, expires, cvv, has_chip,
  num_cards_issued, credit_limit, acct_open_date, year_pin_last_changed, card_on_dark_web
FROM stg.cards_typed
WHERE open_ts <= (SELECT t_cut FROM stg.split_cutoff);

INSERT INTO core.mcc_codes SELECT mcc::int, description FROM stg.mcc_raw;
RESET ROLE;
