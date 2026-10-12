SET ROLE replay_owner;

-- Column 2 of every queue is the due time. seq increases with it.
CREATE TABLE replay.card_queue (
  seq bigint PRIMARY KEY, open_ts timestamp NOT NULL,
  card_id integer NOT NULL, customer_id integer NOT NULL, card_brand text, card_type text, card_number text,
  expires text, cvv text, has_chip boolean, num_cards_issued smallint, credit_limit numeric(12,2),
  acct_open_date text, year_pin_last_changed smallint, card_on_dark_web boolean
);

CREATE TABLE replay.txn_queue (
  seq bigint PRIMARY KEY, txn_ts timestamp NOT NULL,
  txn_id bigint NOT NULL, customer_id integer NOT NULL, card_id integer NOT NULL, amount numeric(12,2) NOT NULL,
  use_chip text, merchant_id integer, merchant_city text, merchant_state text, zip text, mcc integer, errors text
);

CREATE TABLE replay.label_queue (
  seq bigint PRIMARY KEY, due_ts timestamp NOT NULL, txn_id bigint NOT NULL, is_fraud boolean NOT NULL
);

-- Exactly one row: the virtual clock and how far each queue has been replayed
CREATE TABLE replay.state (
  id          boolean PRIMARY KEY DEFAULT true CHECK (id),
  t_cut       timestamp NOT NULL,
  virtual_now timestamp NOT NULL,
  card_seq    bigint NOT NULL DEFAULT 0,
  txn_seq     bigint NOT NULL DEFAULT 0,
  label_seq   bigint NOT NULL DEFAULT 0,
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- The generator only reads the queues and updates state; it cannot modify the queues
GRANT SELECT ON replay.card_queue, replay.txn_queue, replay.label_queue TO app_simulator;
GRANT SELECT, UPDATE ON replay.state TO app_simulator;
RESET ROLE;
