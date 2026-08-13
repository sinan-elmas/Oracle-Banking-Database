# Indexes

This directory contains the independently managed index definitions for the Oracle Banking Database project.

The index layer is separated from table and constraint creation so that supporting and function-based indexes can be deployed and maintained independently.

Indexes automatically created or reused by Oracle for primary key and unique constraints are intentionally excluded from this module.

## Directory Contents

| Script | Purpose | Indexes |
|---|---|---:|
| `01_Create_Supporting_Indexes.sql` | Creates independently managed supporting indexes | 28 |
| `02_Create_Function_Based_Indexes.sql` | Creates the function-based unique index | 1 |

**Total independently managed indexes: 29**

## 01 - Supporting Indexes

`01_Create_Supporting_Indexes.sql` creates **28 nonunique supporting indexes**.

These indexes primarily support foreign key relationships and frequently accessed columns across the banking schema.

Major indexed areas include:

- Account relationships
- Beneficiary relationships
- Branch and location relationships
- Card relationships
- Company relationships
- Customer addresses
- Customer contacts
- Exchange rates
- Transaction relationships
- Transaction status history
- DDL audit metadata

Examples include:

- `IDX_ACCOUNTS_CUSTOMER_ID`
- `IDX_ACCOUNTS_BRANCH_ID`
- `IDX_CARDS_ACCOUNT_ID`
- `IDX_ADDR_CUSTOMER_ID`
- `IDX_CC_CUSTOMER_ID`
- `IDX_RATES_CURRENCY_ID`
- `IDX_TR_SOURCE_ACCOUNT_ID`
- `IDX_TR_TARGET_ACCOUNT_ID`
- `IDX_TRX_STATUS_HIST_TRANSACTION`

The module also contains the composite index:

`IDX_DDL_AUDIT_LOGS_OBJECT`

with the following column order:

1. `OBJECT_OWNER`
2. `OBJECT_NAME`
3. `OBJECT_TYPE`

## 02 - Function-Based Index

`02_Create_Function_Based_Indexes.sql` creates the function-based unique index:

`UQ_CUSTOMER_PRIMARY_CONTACT`

The index is defined on `CUSTOMER_CONTACTS` as:

```sql
CREATE UNIQUE INDEX uq_customer_primary_contact
    ON customer_contacts
    (
        customer_id,
        contact_type_id,
        CASE
            WHEN is_primary = 'Y'
            THEN is_primary
        END
    );
```

The function-based expression returns `IS_PRIMARY` only when its value is `Y`. For other rows, the expression evaluates to `NULL`.

This design enforces a maximum of one primary contact for each customer and contact type while allowing multiple non-primary contact rows.

## Design Approach

The index module contains only indexes that are independently managed by the project.

Indexes automatically created or reused by Oracle to support primary key and unique constraints are not duplicated here.

`IDX_CORP_COMPANY_ID` is intentionally excluded because its index structure is used by the `UQ_CORPORATE_COMPANY` unique constraint.

This separation avoids redundant indexes while keeping supporting and function-based indexes explicitly documented.

## Deployment Order

Run the scripts in the following order:

1. `01_Create_Supporting_Indexes.sql`
2. `02_Create_Function_Based_Indexes.sql`

The index scripts depend on the table and constraint modules and are intended to run after:

```text
02_Tables
03_Constraints
```

The scripts are intended for a clean deployment or controlled rebuild.

## Validation

The supporting-index script validates the created indexes through `USER_INDEXES`.

Validation covers:

- Index name
- Table name
- Index type
- Uniqueness
- Status
- Visibility

The function-based index script additionally uses:

- `USER_IND_COLUMNS`
- `USER_IND_EXPRESSIONS`

to verify the indexed columns and function-based expression.

The expected inventory is:

| Index Category | Count |
|---|---:|
| Supporting nonunique indexes | 28 |
| Function-based unique indexes | 1 |
| **Total independently managed indexes** | **29** |

## Related Modules

- `02_Tables` - Base table definitions
- `03_Constraints` - Primary keys, unique constraints, foreign keys, and named check constraints
- `05_Sequences` - Explicit application-managed sequences