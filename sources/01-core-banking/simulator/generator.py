"""Replays the 70% part of the Core Banking seed (step 9.9 in docs/deploy.md).

Reads the queues in database core_banking_replay and writes to core_banking like a core banking app:
every event is its own transaction. The virtual clock starts at T_cut and only advances while the generator runs.
Connection settings come from libpq environment variables (PGHOST, PGUSER, PGSSLMODE, PGSSLROOTCERT, PGPASSFILE).
"""

import logging
import os
import signal
import time

import psycopg

SPEED = float(os.environ.get("REPLAY_SPEED", "360"))  # 1 real second = SPEED virtual seconds
TICK = float(os.environ.get("TICK_SECONDS", "1"))
BATCH = int(os.environ.get("BATCH_MAX", "500"))  # max events per queue per loop
CORE_DB = os.environ.get("CORE_DB", "core_banking")
REPLAY_DB = os.environ.get("REPLAY_DB", "core_banking_replay")

log = logging.getLogger("fds-simulator")
running = True

CARD_SQL = """
INSERT INTO core.cards (card_id, customer_id, card_brand, card_type, card_number, expires, cvv, has_chip,
  num_cards_issued, credit_limit, acct_open_date, year_pin_last_changed, card_on_dark_web)
VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
ON CONFLICT (card_id) DO NOTHING
"""
BALANCE_INIT_SQL = "INSERT INTO core.card_balances (card_id) VALUES (%s) ON CONFLICT (card_id) DO NOTHING"
TXN_SQL = """
INSERT INTO core.transactions (txn_id, txn_ts, customer_id, card_id, amount, use_chip, merchant_id,
  merchant_city, merchant_state, zip, mcc, errors)
VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
ON CONFLICT DO NOTHING
"""
BALANCE_SQL = """
UPDATE core.card_balances
SET current_balance = current_balance + %s, last_txn_id = %s, updated_at = now()
WHERE card_id = %s
"""
LABEL_SQL = """
INSERT INTO core.txn_fraud_labels (txn_id, is_fraud, labeled_at) VALUES (%s, %s, %s)
ON CONFLICT (txn_id) DO NOTHING
"""


def emit_cards(core, rows):
    # Queue row: seq, open_ts, then the 13 columns of core.cards
    for row in rows:
        with core.transaction():
            core.execute(CARD_SQL, row[2:])
            core.execute(BALANCE_INIT_SQL, (row[2],))


def emit_txns(core, rows):
    # Queue row: seq, txn_ts, txn_id, customer_id, card_id, amount, use_chip, ..., errors
    for _seq, txn_ts, txn_id, customer_id, card_id, amount, *rest in rows:
        with core.transaction():
            cur = core.execute(TXN_SQL, (txn_id, txn_ts, customer_id, card_id, amount, *rest))
            # Replay after a crash: if the transaction already exists, do not add to the balance twice
            if cur.rowcount == 1:
                core.execute(BALANCE_SQL, (amount, txn_id, card_id))


def emit_labels(core, rows):
    for _seq, due_ts, txn_id, is_fraud in rows:
        with core.transaction():
            core.execute(LABEL_SQL, (txn_id, is_fraud, due_ts))


# (queue table, due-time column, cursor column in replay.state, writer). Constants, never external input.
# Cards go first so the card_balances row exists before the card's first transaction.
QUEUES = [
    ("replay.card_queue", "open_ts", "card_seq", emit_cards),
    ("replay.txn_queue", "txn_ts", "txn_seq", emit_txns),
    ("replay.label_queue", "due_ts", "label_seq", emit_labels),
]


def _stop(signum, _frame):
    global running
    running = False
    log.info("received signal %s, stopping after the current batch", signum)


def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)

    with psycopg.connect(dbname=REPLAY_DB, autocommit=True, application_name="fds-simulator-replay") as rq, \
         psycopg.connect(dbname=CORE_DB, autocommit=True, application_name="fds-simulator") as core:
        last = last_log = time.monotonic()
        emitted = 0
        backlog = False
        while running:
            now = time.monotonic()
            # While backlogged, hold the virtual clock until caught up; never skip events
            step = 0.0 if backlog else (now - last) * SPEED
            last = now
            virtual_now, *seqs = rq.execute(
                "UPDATE replay.state SET virtual_now = virtual_now + make_interval(secs => %s), updated_at = now()"
                " RETURNING virtual_now, card_seq, txn_seq, label_seq",
                (step,),
            ).fetchone()

            backlog = False
            for (table, due_col, seq_col, emit), seq in zip(QUEUES, seqs):
                if not running:
                    break
                rows = rq.execute(
                    f"SELECT * FROM {table} WHERE seq > %s AND {due_col} <= %s ORDER BY seq LIMIT %s",
                    (seq, virtual_now, BATCH),
                ).fetchall()
                if not rows:
                    continue
                # Write core first, save the cursor after. A crash in between replays this batch; ON CONFLICT drops duplicates.
                emit(core, rows)
                rq.execute(f"UPDATE replay.state SET {seq_col} = %s", (rows[-1][0],))
                emitted += len(rows)
                backlog = backlog or len(rows) == BATCH

            if now - last_log >= 60:
                log.info("virtual_now=%s events_60s=%d backlog=%s", virtual_now, emitted, backlog)
                emitted, last_log = 0, now
            if not backlog:
                time.sleep(TICK)
    log.info("stopped")


if __name__ == "__main__":
    main()
