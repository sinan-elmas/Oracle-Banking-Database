# Report 07 – Customer Transaction Activity Ranking

## Overview

This document evaluates the execution plan of the **Customer Transaction Activity Ranking** report using actual runtime statistics.

The report summarizes customer transaction activity, converts transaction values to the base currency, ranks customers according to transaction volume, and classifies customer activity levels.

No SQL logic, index, statistics, or database object was modified during the analysis.

## Analysis Method

The query was executed with `GATHER_PLAN_STATISTICS`, and the actual execution plan was retrieved using `DBMS_XPLAN.DISPLAY_CURSOR`.

The standard methodology is documented in `01_Execution_Plan_Methodology.md`.

## Environment

| Component | Value |
|---|---|
| Database | Oracle AI Database 26ai |
| Database Version | 23.26.1.0.0 |
| Schema | `BANKING_DB` |
| Environment | Docker on Windows |
| Client | Oracle SQL Developer 24.3.1.347 |

## Cursor Summary

| Metric | Value |
|---|---:|
| SQL ID | `5w57kp68qyh6t` |
| Child Number | 0 |
| Plan Hash Value | `4276854981` |
| Executions | 1 |
| Returned Rows | 10,002 |
| Buffer Gets | 3,131 |
| Physical Reads | 0 |
| Elapsed Time | 0.118784 seconds |
| CPU Time | 0.112872 seconds |

## Execution Plan Highlights

- Oracle materialized reusable datasets using `TEMP TABLE TRANSFORMATION`.
- The base currency was retrieved through a unique index lookup.
- `EXCHANGE_RATES` was processed with `ROW_NUMBER()` to select the latest exchange rate for each currency pair.
- `TRANSACTIONS` was fully scanned after applying the `STATUS = 'SUCCESS'` filter.
- Customer account totals were calculated through an index fast full scan on `IDX_ACCOUNTS_CUSTOMER_ID`.
- Hash joins and hash aggregation combined customer, account, exchange-rate, and transaction data.
- `DENSE_RANK()` and `CUME_DIST()` were evaluated through in-memory window sort operations.
- The final ordering processed 10,002 customer rows without physical disk reads.

## Cardinality Review

| Operation | E-Rows | A-Rows |
|---|---:|---:|
| `CUSTOMERS` scan | 10,000 | 10,002 |
| `ACCOUNTS` index scan | 21,000 | 21,000 |
| Successful transactions | 189,000 | 189,000 |
| Customer transaction summary | 10,000 | 9,961 |
| Final result | 10,000 | 10,002 |

The optimizer accurately estimated the primary table accesses. Minor differences in intermediate aggregation results did not affect join methods, memory usage, or execution time.

## Assessment

The full scan on `TRANSACTIONS` is appropriate because the report aggregates almost all successful transactions before customer-level summarization.

Temporary table transformation prevents repeated execution of reusable intermediate result sets, while the optimizer efficiently combines hash joins, hash aggregation, analytic ranking functions, and index-based account aggregation.

No excessive memory usage, unnecessary I/O, or inefficient access path was observed during execution.

## Optimization Decision

| Item | Decision |
|---|---|
| SQL Rewrite Required | No |
| Additional Index Required | No |
| Optimizer Hint Required | No |
| Statistics Collection Required | No |

## Final Status

**Performance Review:** Passed

**Optimization Required:** No
