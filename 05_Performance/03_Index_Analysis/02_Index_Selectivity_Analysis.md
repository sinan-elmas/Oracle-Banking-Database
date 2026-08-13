# Index Selectivity Analysis

## Overview

This document evaluates index selectivity using Oracle optimizer statistics.

The objective is to understand how selective each index is and how this information influences Oracle's choice between index access and full table scans.

The analysis is based on optimizer statistics collected for the current schema.

No indexes, statistics, or database objects were modified during this analysis.

---
## Analysis Method

Index statistics were collected from the Oracle data dictionary.

The following attributes were reviewed:

- Number of Rows
- Distinct Keys
- Leaf Blocks
- Clustering Factor
- Selectivity Percentage

LOB indexes generated internally by Oracle (`SYS_IL...`) were excluded from the performance evaluation because they are implementation-specific and are not part of the application indexing strategy.

---
## Environment

| Component | Value |
|---|---|
| Database | Oracle AI Database 26ai |
| Database Version | 23.26.1.0.0 |
| Schema | `BANKING_DB` |

---
## General Observations

The analysis identified three main index categories.

### High Selectivity (≈100%)

Primary keys and unique constraints provide nearly perfect selectivity because each key identifies a single row.

Typical examples include:

- Primary keys
- Unique business keys
- Customer identifiers
- Account identifiers
- Transaction identifiers

These indexes are highly efficient for point lookups and unique access paths.

---
### Medium Selectivity

Several foreign-key and business relationship indexes demonstrate moderate selectivity.

Examples include:

| Index | Selectivity |
|---|---:|
| IDX_BENEF_ACCOUNT_ID | 70.39% |
| IDX_ADDR_CUSTOMER_ID | 69.96% |
| IDX_BENEF_CUSTOMER_ID | 61.78% |
| IDX_ACCOUNTS_CUSTOMER_ID | 47.62% |
| IDX_CC_CUSTOMER_ID | 43.76% |

These indexes are well suited for join operations and customer-oriented reporting queries.

---
### Low Selectivity

Several lookup indexes naturally exhibit low selectivity because they reference columns with only a few distinct values.

Examples include:

| Index | Selectivity |
|---|---:|
| IDX_TR_CHANNEL_ID | 0.0025% |
| IDX_TR_TYPE_ID | 0.0030% |
| IDX_TR_CURRENCY_ID | 0.0040% |
| IDX_ACCOUNTS_TYPE_ID | 0.0238% |
| IDX_ACCOUNTS_CURRENCY_ID | 0.0381% |

Low selectivity does not indicate an incorrect index design. These columns intentionally contain a small number of distinct values and are primarily used in joins, grouping, and filtering.

---
## Clustering Factor Review

Most indexes exhibit clustering factors appropriate for the current data distribution.

Some customer-related indexes have relatively high clustering factors because customer rows are distributed throughout larger tables rather than being stored physically in index order.

This behavior is expected for transactional banking workloads and does not indicate an indexing problem.

---
## Optimizer Perspective

The collected statistics explain several optimizer decisions observed during the execution plan analyses.

- High-selectivity indexes are preferred for selective lookups.
- Medium-selectivity indexes are frequently used in join operations.
- Low-selectivity indexes may be bypassed in favor of Full Table Scans when large portions of a table are processed.
- Full Table Scan is often the optimal choice for analytical reports that read most rows from large tables.

---
## Optimization Decision

| Item | Decision |
|---|---|
| Index Statistics Available | Yes |
| High Selectivity Indexes | Present |
| Medium Selectivity Indexes | Present |
| Low Selectivity Indexes | Expected |
| Additional Indexes Required | No |
| Index Redesign Required | No |
| Statistics Issues Detected | No |

---
## Conclusion

The index statistics demonstrate a balanced indexing strategy across the Oracle Banking Database schema.

High-selectivity indexes efficiently support unique access paths, while medium-selectivity indexes support joins and reporting queries. Low-selectivity indexes are appropriate for reference columns with limited distinct values and do not indicate poor index design.

The optimizer statistics are consistent with the execution plans previously observed, and no index redesign or additional indexing is recommended based on the current workload.
