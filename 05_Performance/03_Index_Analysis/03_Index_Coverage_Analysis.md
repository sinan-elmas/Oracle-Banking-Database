# Index Coverage Analysis

## Overview

This document evaluates schema-level index coverage across primary keys, unique constraints, foreign keys, function-based indexes, and application-defined indexes.

The primary objective is to verify whether foreign-key columns are covered by indexes whose leading columns match the foreign-key column order.

No index, constraint, statistics, or database object was modified during this analysis.

---
## Analysis Method

Index and constraint metadata were collected from:

- `USER_INDEXES`
- `USER_IND_COLUMNS`
- `USER_CONSTRAINTS`
- `USER_CONS_COLUMNS`

Foreign-key coverage was classified as complete only when the full foreign-key column list matched the leading columns of an index in the same order.

Oracle-managed LOB indexes were reported separately and excluded from the application index analysis.

---
## Environment

| Component | Value |
|---|---|
| Database | Oracle AI Database 26ai |
| Database Version | 23.26.1.0.0 |
| Schema | `BANKING_DB` |

---
## Index Coverage Summary

| Category | Count |
|---|---:|
| Primary Key Constraints | 26 |
| Unique Constraints | 26 |
| Foreign Key Constraints | 28 |
| Function-Based Application Indexes | 1 |
| Bitmap Application Indexes | 0 |
| Application / Constraint Indexes | 81 |
| Oracle-Managed LOB Indexes | 8 |
| All `USER_INDEXES` Rows | 89 |

The schema contains 81 indexes relevant to application and constraint analysis. The additional eight indexes are Oracle-managed LOB indexes.

---
## Foreign-Key Coverage Summary

| Metric | Value |
|---|---:|
| Foreign Keys | 28 |
| Covered Foreign Keys | 28 |
| Uncovered Foreign Keys | 0 |
| Coverage Rate | 100% |

Every foreign key is covered by an index whose leading columns match the foreign-key column list in the same order.

---
## Coverage Examples

| Table | Foreign Key | Foreign-Key Column | Covering Index |
|---|---|---|---|
| `ACCOUNTS` | `FK_ACC_CUSTOMER` | `CUSTOMER_ID` | `IDX_ACCOUNTS_CUSTOMER_ID` |
| `ACCOUNTS` | `FK_ACC_BRANCH` | `BRANCH_ID` | `IDX_ACCOUNTS_BRANCH_ID` |
| `BENEFICIARIES` | `FK_BENEF_CUSTOMER` | `CUSTOMER_ID` | `IDX_BENEF_CUSTOMER_ID` |
| `CARDS` | `FK_CARD_ACCOUNT` | `ACCOUNT_ID` | `IDX_CARDS_ACCOUNT_ID` |
| `TRANSACTIONS` | `FK_TR_SOURCE` | `SOURCE_ACCOUNT_ID` | `IDX_TR_SOURCE_ACCOUNT_ID` |
| `TRANSACTIONS` | `FK_TR_TARGET` | `TARGET_ACCOUNT_ID` | `IDX_TR_TARGET_ACCOUNT_ID` |
| `TRANSACTION_STATUS_HISTORY` | `FK_TRX_STATUS_HIST_TRANSACTION` | `TRANSACTION_ID` | `IDX_TRX_STATUS_HIST_TRANSACTION` |

Primary-key or unique indexes also provide complete foreign-key coverage where the foreign-key column is itself uniquely indexed.

---
## Index Structure Summary

| Index Width | Count |
|---|---:|
| Single-Column Indexes | 73 |
| Two-Column Indexes | 4 |
| Three-Column Indexes | 4 |
| Total | 81 |

The schema primarily uses single-column indexes for primary keys, unique keys, and foreign-key access paths.

Composite indexes are used where business uniqueness or reporting requirements involve multiple columns.

---
## Function-Based Index

The schema contains one function-based index:

```text
UQ_CUSTOMER_PRIMARY_CONTACT
```

This index contains three indexed expressions or columns and supports the business rule governing primary customer contact records.

Its presence is intentional and consistent with the schema design.

---
## Foreign-Key Indexing Assessment

Foreign-key indexes are not mandatory for Oracle constraint enforcement.

However, they can provide important operational benefits:

- Faster child-row lookup
- More efficient joins
- Improved parent-key update and delete behavior
- Reduced locking risk during parent-row modifications
- Better support for reporting and transactional queries

The 100% leading-column coverage confirms that the schema's foreign-key indexing strategy is complete.

---
## Optimization Decision

| Item | Decision |
|---|---|
| Primary-Key Coverage | Complete |
| Unique-Constraint Coverage | Complete |
| Foreign-Key Leading-Column Coverage | Complete |
| Missing Foreign-Key Indexes | None |
| Additional Foreign-Key Indexes Required | No |
| Bitmap Indexes Required | No |
| Index Redesign Required | No |
| Oracle-Managed LOB Indexes | Excluded from Application Review |

---
## Conclusion

The Oracle Banking Database schema has complete index coverage for all 28 foreign-key constraints.

Each foreign-key column list is matched by the leading columns of an existing index in the correct order. This supports efficient joins, child-row access, and safer parent-key maintenance operations.

The schema contains a balanced combination of primary-key, unique, foreign-key, composite, and function-based indexes.

No missing foreign-key index or index coverage defect was identified.
