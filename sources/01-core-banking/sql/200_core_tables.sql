SET ROLE core_owner;

CREATE TABLE core.customers (
  customer_id        integer PRIMARY KEY,
  current_age        smallint,
  retirement_age     smallint,
  birth_year         smallint,
  birth_month        smallint,
  gender             text,
  address            text,
  latitude           numeric(9,6),
  longitude          numeric(9,6),
  per_capita_income  numeric(12,2),
  yearly_income      numeric(12,2),
  total_debt         numeric(12,2),
  credit_score       smallint,
  num_credit_cards   smallint,
  updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE core.cards (
  card_id               integer PRIMARY KEY,
  customer_id           integer NOT NULL REFERENCES core.customers,
  card_brand            text,
  card_type             text,
  card_number           text,      -- PAN stored in clear: deliberate legacy flaw
  expires               text,      -- 'MM/YYYY' kept in legacy format
  cvv                   text,      -- deliberate PCI violation
  has_chip              boolean,
  num_cards_issued      smallint,
  credit_limit          numeric(12,2),
  acct_open_date        text,      -- 'MM/YYYY'
  year_pin_last_changed smallint,
  card_on_dark_web      boolean,
  card_status           text NOT NULL DEFAULT 'ACTIVE',
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE core.mcc_codes (mcc integer PRIMARY KEY, description text NOT NULL);

-- No FK to cards/customers ("legacy dropped FKs for performance"), so orphan rows are possible
CREATE TABLE core.transactions (
  txn_id          bigint    NOT NULL,
  txn_ts          timestamp NOT NULL,   -- NO time zone: legacy trait
  customer_id     integer   NOT NULL,
  card_id         integer   NOT NULL,
  amount          numeric(12,2) NOT NULL,
  use_chip        text,
  merchant_id     integer,
  merchant_city   text,
  merchant_state  text,
  zip             text,
  mcc             integer,
  errors          text
) PARTITION BY RANGE (txn_ts);

CREATE TABLE core.txn_fraud_labels (
  txn_id     bigint PRIMARY KEY,
  is_fraud   boolean NOT NULL,
  labeled_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE core.card_balances (
  card_id          integer PRIMARY KEY REFERENCES core.cards,
  current_balance  numeric(14,2) NOT NULL DEFAULT 0,
  last_txn_id      bigint,
  updated_at       timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE core.card_balances REPLICA IDENTITY FULL;
RESET ROLE;
