# 01 – Core Banking

A legacy core-banking system simulated as a **PostgreSQL 17** database on EC2, exposed to downstream consumers through **logical replication (CDC)**.

The source is built from the
[Transactions Fraud Datasets](https://www.kaggle.com/datasets/computingvictor/transactions-fraud-datasets)
(customers, cards, transactions, MCC codes, fraud labels). Part of the dataset is loaded up front; the rest is replayed over time by a generator that writes to the database the way a real application would, so the CDC stream carries live inserts and updates rather than a one-off dump.

## Design goals

- **Near-production access path.** Private network, TLS `verify-full`, least-privilege roles, expiring certs and passwords, column-level restrictions on sensitive data. These controls exist so that an ingestion pipeline has to clear the same hurdles it would against a real source. They are not a threat model.
- **Deliberately imperfect data.** The schema keeps legacy traits (clear-text PAN, timezone-less timestamps, text dates, missing FKs, partitions) that a downstream pipeline must handle.
- **Reproducible ingestion incidents.** WAL bloat, lost slots, schema drift, restores, credential rotation and more can be triggered on demand (see [Incident catalog](#incident-catalog)).
- **Low cost.** Runs only during demos, on burstable Graviton instances, with everything not affecting ingestion stripped out.
- **Fully isolated.** The source owns its VPC, NAT, Terraform state key, CA, backup bucket and alerting. Nothing in this folder references another source, including the other PostgreSQL source.

## Architecture

```
VPC 10.101.0.0/16 (Core Banking only, single AZ ap-southeast-1a)
│
├── public 10.101.0.0/24   fck-nat (t4g.nano) ── Internet Gateway
├── db     10.101.10.0/24  PostgreSQL 17 (t4g.large, 10.101.10.10)
└── sim    10.101.20.0/24  Simulator (t4g.micro, 10.101.20.10)

Private routes:  0.0.0.0/0      → NAT instance ENI
                 S3             → Gateway endpoint
                 10.200.0.0/16  → VPC peering to the data-platform VPC (optional)
```

| Component | Role |
|---|---|
| PostgreSQL instance | Hosts `core_banking` (what CDC reads) and `core_banking_replay` (the replay queue, invisible to CDC). Data and WAL on separate encrypted EBS volumes |
| Simulator instance | Runs the generator that replays queued events into `core_banking` as an application client |
| NAT instance | Outbound access for patching, SSM and CloudWatch. Owned by this source only |
| S3 backup bucket | pgBackRest repository (full/diff backups + WAL archive) and the deploy prefix used to ship files to the instances |
| Parameter Store | Role passwords, TLS key/certs, pgBackRest cipher. Terraform only creates placeholders; real values are written out-of-band |
| CloudWatch / SNS | Custom metrics, alarms, pgaudit log, Session Manager logs |

- No SSH anywhere. Shell access is via SSM Session Manager; IMDSv2 is enforced.
- The PostgreSQL security group accepts 5432 only from the simulator SG and the CDC consumer CIDR. Egress is limited to 80/443.
- There is no network path to any other source's VPC.

CIDR convention across sources: source `NN` uses `10.(100+NN).0.0/16`; the data-platform (CDC consumer, separate repo) uses `10.200.0.0/16`.

## Data model

Database `core_banking`, schema `core`:

| Table | Content | Notes |
|---|---|---|
| `customers` | Customer profile, income, debt, credit score | Loaded in full |
| `cards` | Card master | Includes `card_number` and `cvv` in clear |
| `mcc_codes` | Merchant category codes | Reference data |
| `transactions` | Card transactions | Range-partitioned by month on `txn_ts` (pg_partman) |
| `txn_fraud_labels` | Fraud label per transaction | Arrives 24–168 h after the transaction |
| `card_balances` | Running balance per card | Updated on every replayed transaction, `REPLICA IDENTITY FULL` |

### Legacy traits kept on purpose

| Trait | What the pipeline has to deal with |
|---|---|
| `card_number`, `cvv` stored in clear | PCI data flows into CDC; columns must be masked or excluded |
| `expires`, `acct_open_date` are `text` in `MM/YYYY` | Cannot be cast directly to a date |
| `txn_ts` is `timestamp` without time zone | Ambiguous time zone, typical of old systems |
| No FK from `transactions` to cards/customers | Orphan rows are possible |
| Partitioned `transactions` | Partitions show up as separate streams on schema discovery; dropping a partition emits no DELETE events |
| `card_balances` with full replica identity | Every UPDATE carries before and after images; high update churn |
| Fraud labels arrive late | Late-arriving data that must be joined back to transactions |

## Seeding: 30% preloaded, 70% replayed

The dataset is split **by transaction time** at a cutoff `T_cut`, chosen so that 30% of transaction rows fall at or before it.

```
100% seed
   ├── ≤ T_cut ──► core_banking.core.*            preloaded; picked up by the initial CDC snapshot
   └── > T_cut ──► core_banking_replay.replay.*   queues; not published, not readable by CDC
                        │  generator, virtual clock starting at T_cut
                        └──► core_banking.core.*  one DB transaction per event → WAL → CDC
```

| Data | Preloaded into `core` | Replayed |
|---|---|---|
| `transactions` | `txn_ts ≤ T_cut` | `txn_ts > T_cut`; INSERT transaction + UPDATE `card_balances` |
| `cards` | Opened on or before `T_cut` | Opened later; INSERT card + balance row |
| `txn_fraud_labels` | Due on or before `T_cut` | Due later (`txn_ts` + 24–168 h, deterministic per `txn_id`) |
| `card_balances` | Sum of preloaded transactions | Accumulated per replayed transaction |
| `customers`, `mcc_codes` | 100% | — |

The generator advances a virtual clock (`replay.state.virtual_now`) at `REPLAY_SPEED` × real time (default 360×), writes every event that has become due, and persists its cursor so a stop/start never drops or duplicates events. Original timestamps from the seed are written unchanged.

## CDC contract

The intended consumer is **Airbyte** (Postgres source, CDC mode) in the data-platform repo. This source provides the publication, slot, role and TLS material; the connector itself is configured on the consumer side.

| Setting | Value |
|---|---|
| Host | `ip-10-101-10-10.ap-southeast-1.compute.internal` (port `5432`) |
| Database / schema | `core_banking` / `core` |
| User | `cdc_airbyte` (password in `/fds/core-banking/pg/cdc_airbyte`) |
| SSL | `verify-full`, CA in `/fds/core-banking/tls/ca-crt` |
| Publication | `airbyte_core_banking` (`FOR TABLES IN SCHEMA core`, `publish_via_partition_root = true`) |
| Replication slot | `airbyte_core_banking` (`pgoutput`) |

- Select `core.transactions` only; the individual partitions are listed on discovery but changes are published under the parent table.
- The slot is created **just before** the connector is set up. A slot without an active reader retains WAL until `max_slot_wal_keep_size` (8 GB) is hit and the slot is lost.
- Airbyte syncs on a schedule, so WAL accumulates between syncs. The `slot-retained` alarm fires at 4 GB.
- Deleting the Airbyte connection does not drop the slot on the source.

## Access model

| Role | Login | Can do | From |
|---|---|---|---|
| `core_owner` | No | Owns every object in `core`; DDL via `SET ROLE` only | — |
| `app_simulator` | Yes, 60 connections | Read/write `core`; read replay queues, update replay state | Simulator subnet |
| `cdc_airbyte` | Yes, 5 connections, `REPLICATION` | Read `core`, stream WAL; no writes, no access to the replay DB | Data-platform CIDR |
| `ro_analyst` | Yes, 5 connections | Read-only sessions on `core` | Simulator subnet |

All client connections require `hostssl` + `scram-sha-256`; everything else is rejected in `pg_hba.conf`. The server cert is ECDSA P-256 with a 90-day lifetime, signed by a CA private to this source. Passwords are set with `\password` so they never appear in SQL files or server logs.

## Operations

- **Demo-only.** All three instances are stopped by default. `ops/demo-start.sh` / `ops/demo-stop.sh` start and stop this source's NAT, PostgreSQL and simulator, without touching other sources. Every instance also powers itself off 12 hours after boot.
- **Backup.** pgBackRest to S3 with continuous WAL archiving. A differential (or full) backup is taken as part of `demo-stop.sh`. A restore test is part of acceptance.
- **Monitoring.** A per-minute script pushes custom metrics to CloudWatch; alarms notify via SNS email:

  | Alarm | Fires when |
  |---|---|
  | `wal-disk` | WAL volume > 80% |
  | `slot-retained` | A slot retains > 4 GB of WAL |
  | `slot-lost` | Any slot has `wal_status = lost` |
  | `archive-failing` | WAL archiving to S3 is failing |
  | `connections` | > 80 client connections |

- **Audit.** pgaudit logs DDL and role changes; only the audit log is shipped to CloudWatch Logs.
- **Recurring tasks.** Rotate the TLS cert before expiry, rotate role passwords, run `terraform plan` periodically to check for drift, and drop forgotten replication slots.

## Incident catalog

Each scenario is triggered one at a time from `chaos/` so cause and effect stay observable.

| # | Incident | What the pipeline must handle |
|---|---|---|
| 1 | Slot retains WAL and fills the disk | Slot lost, full re-snapshot |
| 2 | Low write volume but WAL keeps growing | Heartbeat into a published table |
| 3 | Source restart / maintenance | Reconnect without loss or duplicates |
| 4 | Long-running transaction | Delayed events, blocked snapshot |
| 5 | Very large transaction | Event burst, decoding memory pressure |
| 6 | Table without a primary key | Source application itself fails on UPDATE |
| 7 | Unchanged TOAST values | Missing old values in change events |
| 8 | Schema drift | Added/renamed/dropped columns, type changes |
| 9 | New table missing from an explicit publication | Silent data loss |
| 10 | `TRUNCATE` | Truncate events |
| 11 | Old partition dropped | No DELETE events downstream |
| 12 | Hard data types | Time zone and precision errors |
| 13 | Dirty and late-arriving data | Dedup, DQ checks, late joins |
| 14 | GDPR hard delete | Propagating deletes |
| 15 | Connection exhaustion | Connector cannot connect |
| 16 | Restore / PITR | Slot lost, LSN moves backwards |
| 17 | Cert expiry / password rotation | Authentication failures |
| 18 | CPU throttling (`cpu_credits = "standard"`) | Lag and timeouts |
| 19 | PCI column restriction | Permission errors on snapshot, column exclusion |
| 20 | WAL archiving failure | WAL disk fills with no lagging slot |
| 21 | Consumer loses network path | Timeouts while the slot keeps retaining WAL |

## Repository layout

```
sources/01-core-banking/
├── terraform/   AWS infrastructure for this source only (one stack, no modules, no remote state reads)
├── lib/         Shared shell helpers for laptop-side scripts
├── setup/       One-time secret, CA and server-cert setup after `terraform apply`
├── host/        PostgreSQL host: bootstrap scripts, config files mirrored under etc/, metric script
├── seed/        Fetch the dataset from S3 and convert JSON to CSV
├── sql/         Roles, schemas, staging, core tables, 30/70 split, publication, slot
├── replay/      Replay database and queues for the 70% part
├── simulator/   Generator service that replays queued events
├── ops/         Deploy push, demo start/stop, cert/password rotation, volume park/unpark
├── tests/       Acceptance checks (simulator side, CDC side, server side, restore)
└── chaos/       One file per incident in the catalog
```

Numbering conventions: scripts in `setup/`, `host/bootstrap/` and `seed/` use a three-digit `NNN-` prefix in execution order; SQL files use `NNN_` with gaps of 10; files in `chaos/` use the incident number.

## Deployment outline

1. **Account prerequisites** (once per AWS account, shared by all sources): the Terraform state bucket and the `account/` stack (default EBS encryption, IMDSv2 defaults, S3 public access block, Session Manager preferences, budget).
2. **Infrastructure:** `terraform apply` in `terraform/`. State is stored in the shared bucket under the key `sources/01-core-banking/terraform.tfstate`.
3. **Secrets and TLS** from the workstation: role passwords, the source CA and the server cert, written directly to Parameter Store. Secrets never pass through Terraform state.
4. **Host bootstrap** on the PostgreSQL instance: OS, volumes, kernel tuning, PostgreSQL install, config, start.
5. **Database:** roles, schemas, seed with the 30/70 split, replay queues, publication.
6. **Backup and monitoring:** pgBackRest stanza and first full backup, metrics, audit log shipping.
7. **Simulator:** install and start the generator.
8. **Acceptance:** connectivity and permission checks from both client sides, server-side checks, a restore test.
9. **CDC:** create the replication slot right before configuring the Airbyte connection.

Workstation tooling: Terraform ≥ 1.11, AWS CLI v2, Session Manager plugin, `jq`, `openssl`.

## Cost (ap-southeast-1, estimate)

| Scenario | Monthly |
|---|---|
| Idle (EBS, S3, CloudWatch, Parameter Store) | ~$8–9 |
| 8 demos × 12 h | ~$19–20 |

A single 12-hour demo costs about $1.3 (PostgreSQL t4g.large, NAT t4g.nano with public IPv4, simulator t4g.micro). These figures cover this source only.
