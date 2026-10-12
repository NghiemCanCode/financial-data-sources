# financial-data-sources

A collection of heterogeneous **upstream data source simulators** for a large financial-services ecosystem.

This repository provides realistic source systems, public datasets, synthetic extensions, and source-specific delivery mechanisms that simulate how data may originate from different teams, vendors, applications, and external providers.

The repository is intentionally separated from the downstream data pipeline / data platform.

## Purpose

The goal of this repository is to simulate a realistic upstream data landscape with:

- Multiple source systems
- Different database technologies
- Different data formats
- Batch and event-based sources
- External APIs
- Manually maintained files
- Structured, semi-structured, and unstructured data
- Different schemas and naming conventions
- Different source-specific data quality characteristics

The sources are designed to behave like independent upstream systems rather than one unified dataset.

## Source Landscape

| # | Source | Domain | Dataset / Origin | Delivery |
|---|---|---|---|---|
| 01 | Core Banking | Transactions, cards, customers | [Transactions Fraud Datasets](https://www.kaggle.com/datasets/computingvictor/transactions-fraud-datasets) | PostgreSQL |
| 02 | Payment Processor | Payment transactions and identity | [IEEE-CIS Fraud Detection](https://www.kaggle.com/competitions/ieee-fraud-detection/data) | MySQL |
| 03 | E-commerce | Web and product events | [RetailRocket Recommender System Dataset](https://www.kaggle.com/datasets/retailrocket/ecommerce-dataset) | MongoDB |
| 04 | Digital Event Platform | Device, app, and click events | [TalkingData AdTracking Fraud Detection](https://www.kaggle.com/competitions/talkingdata-adtracking-fraud-detection/data) | Kafka |
| 05 | Fraud Intelligence Provider | External fraud signals | [Credit Card Fraud Detection – ULB](https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud) | Object Storage |
| 06 | Credit Bureau | Credit profile and payment history | [Default of Credit Card Clients](https://archive.ics.uci.edu/dataset/350/default%2Bof%2Bcredit%2Bcard%2Bclients) | Excel |
| 07 | CRM | Customer profile and lifecycle | [Credit Card Customers / Bank Churners](https://www.kaggle.com/datasets/sakshigoyal7/credit-card-customers) | PostgreSQL |
| 08 | Marketing Platform | Customer engagement and campaigns | [iFood Marketing Campaign](https://www.kaggle.com/datasets/fayez7/ifood-marketing-campaigns) | MySQL |
| 09 | Geographic Provider | Geographic reference data | [GeoNames](https://www.geonames.org/export/dump/) | Object Storage |
| 10 | Insurance Claims | Claim evidence images | [CarDD – Car Damage Detection](https://cardd-ustc.github.io/) | Object Storage |
| 11 | Market Data Provider | Foreign exchange rates | FRED API | REST API |

## Scope and Safety

This repository is a **learning and demo project**, not a production system. The deployment
guides deliberately keep every resource easy to tear down and rebuild:

- No `prevent_destroy` on EBS data volumes or backup buckets, and `force_destroy = true` on the
  backup bucket, so `terraform destroy` removes everything in one command.
- No `disable_api_termination` on instances.
- Instances are expected to stay stopped and are only started for a demo (12-hour auto-stop timer).

That means **a single `terraform destroy` deletes the databases and their backups.** Snapshot the
volumes first if a dataset matters to you.

Production systems should do the opposite: enable `prevent_destroy` on data volumes and backup
buckets, enable `disable_api_termination`, drop `force_destroy`, and remove those guards only when
a deletion is genuinely intended.

The security controls in these guides (private subnets, TLS `verify-full`, least-privilege roles,
per-source CAs) exist to make the ingestion path realistic, not to defend a production estate.

## Source Characteristics

Each source intentionally represents a different type of upstream system.

### Relational databases

Some business systems are represented as relational databases:

- PostgreSQL
- MySQL

Examples include:

- Core banking
- CRM
- Credit bureau
- Payment processing
- Marketing

### NoSQL

Semi-structured application data is represented using MongoDB.

Example:

- E-commerce events

### Event streams

High-volume digital events are exposed through Kafka.

Example:

- Mobile / ad / device click events

### Object storage

Bulk datasets and reference files are represented as objects rather than database tables.

Examples:

- Fraud intelligence data
- Geographic reference data
- Insurance claim images

### Manual files

One source intentionally represents manually maintained business data.

Example:

- Credit bureau Excel file

### External APIs

Some information is exposed only through an external service interface.

Example:

- Foreign exchange rates via FRED API

## Data Sources

### 1. Core Banking

The primary source is the
[Transactions Fraud Datasets](https://www.kaggle.com/datasets/computingvictor/transactions-fraud-datasets).

The source contains data such as:

- Users
- Cards
- Transactions
- MCC codes
- Fraud labels

It is treated as a legacy relational source system.

### 2. Payment Processor

The
[IEEE-CIS Fraud Detection](https://www.kaggle.com/competitions/ieee-fraud-detection/data)
dataset represents an independent payment-processing system.

Its transaction and identity data use a schema that differs from the core banking source.

### 3. E-commerce

The
[RetailRocket Recommender System Dataset](https://www.kaggle.com/datasets/retailrocket/ecommerce-dataset)
represents digital commerce activity, including:

- User events
- Product properties
- Category information

The source is intentionally treated as semi-structured application data.

### 4. Digital Event Platform

The
[TalkingData AdTracking Fraud Detection](https://www.kaggle.com/competitions/talkingdata-adtracking-fraud-detection/data)
dataset represents high-volume digital events involving:

- IP
- Application
- Device
- Operating system
- Channel
- Event timestamp

The source is exposed as an event stream.

### 5. Fraud Intelligence Provider

The
[Credit Card Fraud Detection – ULB](https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud)
dataset represents an external fraud-intelligence provider delivering bulk transaction-level data.

The source is stored as files in object storage.

### 6. Credit Bureau

The
[Default of Credit Card Clients](https://archive.ics.uci.edu/dataset/350/default%2Bof%2Bcredit%2Bcard%2Bclients)
dataset represents a third-party credit bureau.

The original dataset is distributed as an Excel file.

This source intentionally preserves the characteristics of manually delivered business files.

### 7. CRM

The
[Credit Card Customers / Bank Churners](https://www.kaggle.com/datasets/sakshigoyal7/credit-card-customers)
dataset represents a customer relationship management system containing customer-level attributes and lifecycle information.

### 8. Marketing Platform

The
[iFood Marketing Campaign](https://www.kaggle.com/datasets/fayez7/ifood-marketing-campaigns)
dataset represents a marketing system containing customer engagement, campaign activity, and purchasing behavior.

### 9. Geographic Provider

[GeoNames](https://www.geonames.org/export/dump/)
provides geographic reference data such as:

- Countries
- Cities
- Coordinates
- Time zones
- Postal information

The source is distributed as downloadable files.

### 10. Insurance Claim Evidence

[CarDD – Car Damage Detection](https://cardd-ustc.github.io/)
provides vehicle damage images and annotations.

In this repository, the images are treated simply as **unstructured upstream objects** associated with insurance claims.

No computer-vision processing is required for the source simulator.

### 11. Market Data Provider

Foreign exchange rates are obtained from the
[FRED API](https://fred.stlouisfed.org/docs/api/fred/series_observations.html).

This source represents a third-party service that exposes data through an HTTP API.