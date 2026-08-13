# Constraints

This directory contains the relational integrity and business-rule constraint scripts for the Oracle Banking Database project.

The constraint layer is separated from table creation to provide a clear and controlled schema deployment process.

## Directory Contents

| Script | Purpose | Constraints |
|---|---|---:|
| `01_Create_Primary_Keys.sql` | Creates primary key constraints | 26 |
| `02_Create_Unique_Constraints.sql` | Creates unique constraints | 26 |
| `03_Create_Foreign_Keys.sql` | Creates foreign key relationships | 28 |
| `04_Create_Check_Constraints.sql` | Creates user-defined business-rule check constraints | 36 |

**Total explicitly managed constraints: 116**

## 01 - Primary Keys

`01_Create_Primary_Keys.sql` creates the primary key constraints for all 26 tables.

Each table has one primary key, providing a unique row identifier and enforcing entity integrity.

The current development schema contains a mixture of descriptive constraint names and Oracle-generated `SYS_C...` names.

For clean deployments, Oracle-generated names are not reproduced. Stable and descriptive `PK_*` names are used instead.

Examples:

- `PK_ACCOUNTS`
- `PK_CUSTOMERS`
- `PK_TRANSACTIONS`
- `PK_AUDIT_LOGS`
- `PK_DDL_AUDIT_LOGS`

All 26 primary key table and column mappings were validated against the current schema metadata.

## 02 - Unique Constraints

`02_Create_Unique_Constraints.sql` creates 26 unique constraints.

These constraints protect business identifiers and combinations that must remain unique.

Examples include:

- Account numbers
- IBAN values
- Customer numbers
- Card numbers
- Currency codes
- Branch codes
- Transaction reference numbers
- Individual national identifiers
- Corporate tax and registration numbers
- Customer/contact combinations
- Currency exchange-rate combinations

Composite unique constraints preserve the column order defined in the current schema.

Existing descriptive `UQ_*` names are retained where available. Oracle-generated `SYS_C...` names are replaced with stable descriptive names for clean deployments.

All 26 unique constraint mappings were validated against the current schema metadata.

## 03 - Foreign Keys

`03_Create_Foreign_Keys.sql` creates 28 foreign key constraints.

These relationships enforce referential integrity between the banking domains.

Major relationships include:

- Customers to accounts
- Accounts to branches
- Accounts to currencies
- Accounts to account types
- Accounts to cards
- Customers to beneficiaries
- Countries to cities
- Cities to districts
- Companies to sectors
- Customers to addresses
- Customers to contacts
- Transactions to accounts
- Transactions to currencies
- Transactions to transaction types
- Transactions to transaction channels
- Transaction status history to transactions

The schema contains:

- **28 foreign keys**
- **26 `NO ACTION` delete rules**
- **2 `ON DELETE CASCADE` relationships**

`ON DELETE CASCADE` is used for the customer subtype relationships:

- `CORPORATE_CUSTOMERS.CUSTOMER_ID` → `CUSTOMERS.CUSTOMER_ID`
- `INDIVIDUAL_CUSTOMERS.CUSTOMER_ID` → `CUSTOMERS.CUSTOMER_ID`

All foreign key source columns, referenced tables, referenced columns, and delete rules were validated against the current schema metadata.

## 04 - Check Constraints

`04_Create_Check_Constraints.sql` creates 36 user-defined check constraints across 14 tables.

These constraints enforce business rules directly at the database level.

Examples include:

- Non-negative account balances
- Account status validation
- Account opening and closing date consistency
- IBAN length rules
- Card number length
- Card status validation
- Customer type and status validation
- Corporate tax number length
- Currency code length
- Customer address type validation
- Customer contact flags and source channels
- Positive exchange rates
- Sell rate greater than or equal to buy rate
- Different base and target currencies
- Positive transaction amounts
- Different source and target transaction accounts
- Transaction status validation
- Audit action validation
- Error severity validation
- JSON validation for audit and error context data
- Transaction status-history change validation

All 36 user-defined check constraints were verified as `ENABLED` and `VALIDATED` in the current schema. The validation also confirmed that no unexpected user-defined check constraints were present.

## NOT NULL Constraints

Oracle represents `NOT NULL` rules internally as check constraints.

The current schema metadata also contains Oracle-generated check constraints associated with column-level nullability rules.

These Oracle-generated constraints are intentionally **not duplicated** in `04_Create_Check_Constraints.sql`.

`NOT NULL` definitions are maintained directly in the table definitions under:

`02_Tables`

This avoids duplicating column-level integrity rules across deployment modules.

## Constraint Naming

The deployment scripts use descriptive constraint naming conventions:

| Constraint Type | Prefix |
|---|---|
| Primary Key | `PK_` |
| Unique Constraint | `UQ_` |
| Foreign Key | `FK_` |
| Check Constraint | `CHK_` / existing `CK_` |

Existing meaningful user-defined names are preserved.

Oracle-generated `SYS_C...` names are not intentionally reproduced because they are database-generated implementation identifiers and may differ between deployments.

## Deployment Order

Run the constraint scripts after all table creation scripts.

Recommended order:

1. `01_Create_Primary_Keys.sql`
2. `02_Create_Unique_Constraints.sql`
3. `03_Create_Foreign_Keys.sql`
4. `04_Create_Check_Constraints.sql`

Primary and unique constraints are created before foreign keys so that referenced keys are already available when referential constraints are created.

## Validation

The constraint definitions were validated against the current `BANKING_DB` schema metadata.

Validation covered:

- Constraint existence
- Source tables
- Constraint columns
- Composite column order
- Referenced tables
- Referenced columns
- Foreign key delete rules
- Check constraint conditions
- Constraint status
- Validation status
- Unexpected constraint detection

Final validated inventory:

| Constraint Type | Count |
|---|---:|
| Primary Keys | 26 |
| Unique Constraints | 26 |
| Foreign Keys | 28 |
| User-Defined Check Constraints | 36 |
| **Total** | **116** |

All explicitly managed constraints included in this module were successfully accounted for during the metadata review.

## Related Modules

- `02_Tables` - Table definitions, column data types, defaults, identity columns, and nullability
- `04_Indexes` - Supporting and performance-related indexes
- `05_Sequences` - Explicit application-managed sequences