# PL/SQL

This directory contains the PL/SQL business and infrastructure components of the **Oracle Banking Database** project.

## Target Environment

- Oracle AI Database 26ai Enterprise Edition
- Version `23.26.1.0.0`
- Schema `BANKING_DB`

## Directory Structure

```text
04_PLSQL/
├── Packages/
├── Triggers/
└── README.md
```

The module contains **9 package specifications, 9 package bodies, and 7 triggers**.

## Packages

| Package | Purpose |
|---|---|
| `PKG_ACCOUNT_MANAGEMENT` | Account creation, status management, account information, and available-balance retrieval |
| `PKG_AUDIT` | Central business audit logging |
| `PKG_BENEFICIARY_MANAGEMENT` | Beneficiary registration, update, removal, and retrieval |
| `PKG_CARD_MANAGEMENT` | Card issuance, activation, blocking, closure, and retrieval |
| `PKG_CUSTOMER_MANAGEMENT` | Individual and corporate customer registration, status management, and retrieval |
| `PKG_ERROR_LOG` | Error and diagnostic logging |
| `PKG_EXCHANGE_RATE_MANAGEMENT` | Exchange-rate maintenance, retrieval, and currency conversion |
| `PKG_LOG_MAINTENANCE` | Audit/error log summaries and controlled batch purging |
| `PKG_TRANSACTION_MANAGEMENT` | Transfers, deposits, withdrawals, and transaction-history retrieval |

Package specifications and bodies are stored separately so that public interfaces remain distinct from implementation details.

## Triggers

| Trigger | Purpose |
|---|---|
| `TRG_ACCOUNTS_NO_DELETE` | Prevents physical deletion of accounts |
| `TRG_BRANCHES_AUDIT` | Maintains branch update metadata |
| `TRG_CUSTOMERS_NO_DELETE` | Prevents physical deletion of customers |
| `TRG_EXCHANGE_RATES_AUDIT` | Maintains exchange-rate update metadata |
| `TRG_SCHEMA_DDL_AUDIT` | Records schema-level `CREATE`, `ALTER`, and `DROP` events |
| `TRG_TRANSACTION_STATUS_HISTORY` | Records transaction status changes using a compound trigger |
| `TRG_TRANSACTIONS_NO_DELETE` | Prevents physical deletion of transactions |

## Design and Transaction Model

- Business rules are centralized in packages.
- Expected business-rule violations use `RAISE_APPLICATION_ERROR`.
- Unexpected errors are logged through `PKG_ERROR_LOG`.
- Successful business operations are logged through `PKG_AUDIT` where applicable.
- Business packages do not issue `COMMIT` or `ROLLBACK`; transaction control remains with the caller.
- `PKG_ERROR_LOG` uses an autonomous transaction so diagnostic records can survive a caller rollback.
- `TRG_SCHEMA_DDL_AUDIT` also uses an autonomous transaction for schema-level DDL auditing.
- Critical lifecycle and transaction operations use row locking where required.
- Transaction processing uses deterministic lock ordering to reduce deadlock risk.

## Oracle PL/SQL Features

The module demonstrates:

- Package specifications and bodies
- Public and private procedures/functions
- Exception handling
- `RAISE_APPLICATION_ERROR`
- Autonomous transactions
- `UTL_CALL_STACK`
- `DBMS_UTILITY`
- `SYS_CONTEXT`
- `SELECT ... FOR UPDATE`
- Deterministic lock ordering
- `BULK COLLECT`
- `FORALL`
- `SAVE EXCEPTIONS`
- Compound triggers
- Schema-level DDL triggers

## Deployment

Required tables, sequences, constraints, audit tables, and history tables must exist before dependent package bodies and triggers are compiled.

A practical deployment order is:

1. `PKG_ERROR_LOG`
2. `PKG_AUDIT`
3. Business packages
4. `PKG_LOG_MAINTENANCE`
5. Triggers

Each object file uses `CREATE OR REPLACE` and a trailing `/`, so it can be executed with **Run Script (F5)** in Oracle SQL Developer.

## Verification

After deployment, object status can be checked with:

```sql
SELECT
    object_name,
    object_type,
    status
FROM user_objects
WHERE object_type IN (
    'PACKAGE',
    'PACKAGE BODY',
    'TRIGGER'
)
ORDER BY
    object_type,
    object_name;
```

Compiler errors can be reviewed with:

```sql
SELECT
    name,
    type,
    line,
    position,
    text
FROM user_errors
ORDER BY
    name,
    sequence;
```

Detailed PL/SQL tests are maintained separately under the project testing module.
