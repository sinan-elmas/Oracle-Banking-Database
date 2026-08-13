# Database Design

This directory contains the structural database design and deployment definitions for the **Oracle Banking Database** project.

The module documents the implemented relational model, physical table definitions, constraints, independently managed indexes, application sequences, view inventory, and the Entity-Relationship Diagram (ERD).

The database design has been reviewed against the current `BANKING_DB` schema metadata so that the repository reflects the implemented database structure rather than an assumed model.

---

## Directory Structure

```text
01_Database_Design/
├── 01_ER_Diagram/
├── 02_Tables/
├── 03_Constraints/
├── 04_Indexes/
├── 05_Sequences/
├── 06_Views/
└── README.md
```

Each subdirectory contains its own README with module-specific details.

---

## Schema Overview

The current database design contains:

| Object Category | Count |
|---|---:|
| Tables | 26 |
| Primary Key Constraints | 26 |
| Unique Constraints | 26 |
| Foreign Key Constraints | 28 |
| User-Defined Check Constraints | 36 |
| Independently Managed Indexes | 29 |
| Explicitly Managed Application Sequences | 2 |
| Oracle-Managed Identity Sequences | 24 |
| User-Defined Views | 0 |

These counts reflect the validated structural inventory documented by the corresponding database design modules.

---

## 01 - ER Diagram

`01_ER_Diagram` contains the visual representation and editable DBML source of the implemented relational model.

The ERD represents the complete 26-table schema and its 28 foreign key relationships, covering:

- Customer and customer subtype relationships
- Company and sector relationships
- Geographic relationships
- Account and branch relationships
- Card relationships
- Beneficiary relationships
- Currency and exchange rate relationships
- Transaction relationships
- Audit and logging structures

The directory contains:

| File | Purpose |
|---|---|
| `oracle_banking_database.dbml` | Editable DBML source definition |
| `oracle_banking_database_erd.png` | Raster image for GitHub preview |
| `oracle_banking_database_erd.svg` | Scalable vector version |
| `oracle_banking_database_erd.pdf` | Standalone documentation version |

The diagram was modeled using **dbdiagram.io** and is maintained as documentation of the implemented database structure.

The ERD is not required for database deployment. Executable structural definitions remain in the corresponding table, constraint, index, and sequence modules.

For additional diagram details, see [`01_ER_Diagram/README.md`](01_ER_Diagram/README.md).

---

## 02 - Tables

`02_Tables` contains the physical table definitions for the banking schema.

The current schema contains **26 tables**, organized across the following functional areas.

### Reference and Location Data

- `COUNTRIES`
- `CITIES`
- `DISTRICTS`
- `SECTORS`
- `CURRENCIES`
- `ACCOUNT_TYPES`
- `CARD_TYPES`
- `CONTACT_TYPES`
- `TRANSACTION_CHANNELS`
- `TRANSACTION_TYPES`

### Customer and Company Data

- `CUSTOMERS`
- `INDIVIDUAL_CUSTOMERS`
- `CORPORATE_CUSTOMERS`
- `COMPANIES`
- `CUSTOMER_ADDRESSES`
- `CUSTOMER_CONTACTS`

### Account and Banking Data

- `BRANCHES`
- `ACCOUNTS`
- `BENEFICIARIES`
- `CARDS`
- `EXCHANGE_RATES`

### Transaction Data

- `TRANSACTIONS`
- `TRANSACTION_STATUS_HISTORY`

### Audit and Logging Data

- `AUDIT_LOGS`
- `ERROR_LOGS`
- `DDL_AUDIT_LOGS`

The table definitions are divided into four deployment scripts:

```text
01_Create_Reference_Tables.sql
02_Create_Customer_Tables.sql
03_Create_Account_And_Card_Tables.sql
04_Create_Transaction_And_Log_Tables.sql
```

Table definitions are maintained separately from the constraint and independently managed index layers to keep schema deployment organized and reviewable.

---

## 03 - Constraints

`03_Constraints` contains the relational and business-rule constraints of the schema.

The module is separated into:

```text
01_Create_Primary_Keys.sql
02_Create_Unique_Constraints.sql
03_Create_Foreign_Keys.sql
04_Create_Check_Constraints.sql
```

The validated constraint inventory includes:

| Constraint Category | Count |
|---|---:|
| Primary Keys | 26 |
| Unique Constraints | 26 |
| Foreign Keys | 28 |
| User-Defined Check Constraints | 36 |
| **Total Explicitly Managed Constraints** | **116** |

### Primary Keys

All 26 tables have the expected primary key.

Validation confirmed:

- 26 primary key constraints
- 26 enabled primary keys
- 26 validated primary keys
- No table without a primary key

### Unique Constraints

The schema contains 26 validated unique constraints.

These protect business identifiers and business-key combinations such as:

- Account numbers
- IBAN values
- Customer numbers
- Card numbers
- Reference numbers
- Country and currency codes
- Tax and registration identifiers
- Composite business keys

The expected unique constraint mappings were validated against the implemented schema.

### Foreign Keys

The schema contains 28 foreign key constraints.

Validation confirmed:

- 28 expected foreign keys
- 28 present foreign keys
- 28 enabled foreign keys
- 28 validated foreign keys
- No unexpected or unmatched foreign keys

Delete-rule distribution:

| Delete Rule | Count |
|---|---:|
| `NO ACTION` | 26 |
| `CASCADE` | 2 |

The two cascading relationships implement the customer subtype model:

```text
INDIVIDUAL_CUSTOMERS.CUSTOMER_ID
    -> CUSTOMERS.CUSTOMER_ID

CORPORATE_CUSTOMERS.CUSTOMER_ID
    -> CUSTOMERS.CUSTOMER_ID
```

### Check Constraints

The schema contains 36 explicitly managed user-defined check constraints.

Oracle-generated check constraints associated with column-level `NOT NULL` definitions are not duplicated in the constraint module because nullability is maintained directly in the table definitions.

---

## 04 - Indexes

`04_Indexes` contains indexes managed independently from primary key and unique constraint creation.

The module contains:

```text
01_Create_Supporting_Indexes.sql
02_Create_Function_Based_Indexes.sql
```

The supporting-index script contains **28 independently managed nonunique indexes**.

The function-based index module contains:

```text
UQ_CUSTOMER_PRIMARY_CONTACT
```

This unique function-based index operates on `CUSTOMER_CONTACTS` using:

```text
CUSTOMER_ID
CONTACT_TYPE_ID
CASE WHEN IS_PRIMARY = 'Y' THEN IS_PRIMARY END
```

The stored Oracle expression was verified as:

```sql
CASE WHEN "IS_PRIMARY"='Y' THEN "IS_PRIMARY" END
```

The index enforces the rule that a customer cannot have more than one primary contact for the same contact type.

It was validated as:

- `FUNCTION-BASED NORMAL`
- `UNIQUE`
- `VALID`
- `VISIBLE`

The complete independently managed index inventory therefore contains:

| Index Category | Count |
|---|---:|
| Supporting Nonunique Indexes | 28 |
| Function-Based Unique Indexes | 1 |
| **Total** | **29** |

Constraint-backed indexes are not recreated in this module because their lifecycle belongs to the corresponding primary key or unique constraint.

---

## 05 - Sequences

`05_Sequences` contains explicitly managed application sequences.

The schema contains two such sequences:

```text
CARD_SEQ
SEQ_CUSTOMER_NO
```

Both were validated with the following deployment configuration:

```text
MINVALUE     = 1
MAXVALUE     = 9999999999999999999999999999
INCREMENT BY = 1
CACHE        = 100
NOCYCLE
NOORDER
```

The deployment script intentionally uses:

```sql
START WITH 1
```

for clean schema deployment.

Runtime `LAST_NUMBER` values from the populated development database are not treated as structural schema definitions.

### Oracle-Managed Identity Sequences

The schema also contains **24 Oracle-managed identity sequences** using Oracle's internal `ISEQ$$_...` naming pattern.

These internal sequences are not manually recreated.

They are automatically created and managed by Oracle when the corresponding identity columns are created as part of the table definitions.

---

## 06 - Views

The current `BANKING_DB` schema contains no user-defined views.

Metadata validation returned:

```text
VIEW_COUNT = 0
```

For this reason, `06_Views` intentionally contains documentation only and does not include artificial `CREATE VIEW` statements.

Views may be introduced in the future only when supported by a real reporting, abstraction, or security requirement.

---

## Design Principles

The database design module follows these principles:

- Repository definitions should reflect verified database objects.
- Objects should not be added only to make the project appear larger.
- Tables, constraints, indexes, and sequences should have clearly separated responsibilities.
- Oracle-generated internal objects should not be manually recreated.
- Runtime state should not be confused with structural DDL.
- Referential integrity should be enforced through database constraints.
- Business rules should be enforced at the database level where appropriate.
- Deployment scripts should remain understandable and independently reviewable.
- Documentation should remain consistent with the implemented schema.

---

## Structural Deployment Model

At a high level, the structural objects are deployed in the following order:

```text
Tables
  ↓
Constraints
  ↓
Indexes
  ↓
Application Sequences
```

Oracle-managed identity sequences are created automatically as part of the relevant identity table definitions.

The Views module currently requires no deployment because the schema contains no user-defined views.

The ER diagram is documentation and is not part of the executable deployment sequence.

The exact execution order inside each module is documented by that module's README and script organization.

---

## Validation Approach

The database design was reviewed using Oracle data dictionary metadata rather than relying only on the original development scripts.

Validation included:

- Table existence
- Table status
- Column metadata
- Primary key mappings
- Unique constraint mappings
- Foreign key source and target mappings
- Foreign key delete rules
- User-defined check constraint inventory
- Constraint status
- Constraint validation state
- Independently managed index mappings
- Index column order
- Index status
- Index visibility
- Function-based index expressions
- Application sequence attributes
- Identity sequence separation
- View inventory

This approach helps ensure that the repository documents the database structure that is actually implemented.

---

## Related Project Modules

The database design layer provides the structural foundation for the remaining repository modules:

- [`02_Data_Deployment`](../02_Data_Deployment/) — Data Pump export/import workflow and data deployment validation
- [`03_SQL_Reports`](../03_SQL_Reports/) — Business and analytical SQL reporting
- [`04_PLSQL`](../04_PLSQL/) — PL/SQL packages and triggers
- [`05_Performance`](../05_Performance/) — SQL, index, optimizer, and PL/SQL performance assessment
- [`06_Testing`](../06_Testing/) — Schema, data integrity, SQL report, PL/SQL, integration, and regression testing
- [`07_DBA`](../07_DBA/) — Oracle DBA administration, backup, recovery, maintenance, monitoring, and performance operations
- [`08_Documentation`](../08_Documentation/) — Project architecture, object inventory, and environment documentation
- [`09_Images`](../09_Images/) — Repository images and visual assets
- [`10_Troubleshooting`](../10_Troubleshooting/) — Documented technical issues and resolutions