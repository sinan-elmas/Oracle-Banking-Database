# Entity-Relationship Diagram

This directory contains the Entity-Relationship Diagram (ERD) for the **Oracle Banking Database** project.

The diagram provides a visual representation of the database structure, including the main entities, primary and foreign key relationships, and the logical organization of the banking data model.

## ER Diagram

![Oracle Banking Database ER Diagram](oracle_banking_database_erd.png)

## Database Domains

The data model is organized around the following functional areas:

- **Customer Management** — customers, individual customers, corporate customers, addresses, contacts, and beneficiaries
- **Account Management** — accounts, account types, branches, and currencies
- **Card Management** — cards and card types
- **Transaction Management** — transactions, transaction types, transaction channels, and transaction status history
- **Corporate Structure** — companies and sectors
- **Location Management** — countries, cities, and districts
- **Exchange Rate Management** — currencies and exchange rates
- **Audit and Error Logging** — audit logs, DDL audit logs, and error logs

## Core Relationship Flow

The central banking relationship can be summarized as:

```text
CUSTOMERS
    |
    v
ACCOUNTS
    |
    v
TRANSACTIONS
```

Additional entities extend this core model:

```text
CUSTOMERS
├── INDIVIDUAL_CUSTOMERS
├── CORPORATE_CUSTOMERS
├── CUSTOMER_ADDRESSES
├── CUSTOMER_CONTACTS
└── BENEFICIARIES

ACCOUNTS
├── BRANCHES
├── ACCOUNT_TYPES
├── CURRENCIES
└── CARDS

TRANSACTIONS
├── TRANSACTION_TYPES
├── TRANSACTION_CHANNELS
└── TRANSACTION_STATUS_HISTORY
```

## Diagram Files

| File | Purpose |
|---|---|
| `oracle_banking_database.dbml` | Editable DBML source definition |
| `oracle_banking_database_erd.png` | Raster image used for GitHub preview |
| `oracle_banking_database_erd.svg` | Scalable vector version of the diagram |
| `oracle_banking_database_erd.pdf` | Standalone PDF version for documentation and sharing |

## Modeling Notes

- Primary and foreign key relationships are represented directly in the diagram.
- Customer data is separated into individual and corporate customer entities.
- Accounts form the central connection between customers and banking transactions.
- Transactions support source and target account relationships.
- Reference tables are used for reusable classifications such as account types, card types, transaction types, transaction channels, and contact types.
- Geographic data is normalized through countries, cities, and districts.
- Audit and error logging tables are visually separated from the core banking entities to keep the operational data model readable.

## Tool

The ER diagram was modeled and exported using **dbdiagram.io** with DBML as the editable source format.

---

This ERD provides a high-level visual reference for understanding the structure and relationships of the Oracle Banking Database schema.