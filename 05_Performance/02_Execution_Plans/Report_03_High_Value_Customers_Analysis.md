# Report 03 – High-Value Customers Analysis

## Overview

This document evaluates the execution plan of the **High-Value Customers Analysis** report using actual runtime statistics.

The report converts account balances into a common base currency, calculates customer portfolio values, classifies customers, and ranks them according to portfolio size.

No SQL logic, index, statistics, or database object was modified during the analysis.

## Analysis Method

The query was executed with `GATHER_PLAN_STATISTICS`. Actual runtime statistics were retrieved through `DBMS_XPLAN.DISPLAY_CURSOR`.

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
| SQL ID | `6hntf773ywrsf` |
| Child Number | 0 |
| Plan Hash Value | `1384424969` |
| Executions | 1 |
| Returned Rows | 10,002 |
| Buffer Gets | 3,930 |
| Physical Reads | 2,643 |
| Elapsed Time | 0.166216 seconds |
| CPU Time | 0.131460 seconds |

## Execution Plan Highlights

- Oracle materialized a reused one-row base-currency result through `TEMP TABLE TRANSFORMATION`.
- `TRANSACTIONS` was fully scanned because the report calculates transaction metrics for the complete customer population.
- Account and card relationships were processed through index fast full scans and hash joins.
- `WINDOW SORT PUSHED RANK` efficiently selected the latest exchange rates.
- Hash aggregation produced customer-level account, card, and transaction summaries.
- `WINDOW SORT` supported final customer ranking.
- No memory spill was visible in the collected plan.

## Cardinality Review

| Operation | E-Rows | A-Rows |
|---|---:|---:|
| `TRANSACTIONS` scan | 200,000 | 200,000 |
| Account index input | 21,000 | 21,000 |
| Card input | 7,866 | 7,866 |
| Customer scan | 10,000 | 10,002 |
| Final result | 10,000 | 10,002 |

The primary table and join estimates were accurate. Some intermediate aggregation views returned fewer rows than estimated, but the differences did not alter the execution strategy or cause excessive resource usage.

## Assessment

The transaction full scan is appropriate because nearly the complete transaction history participates in the report.

Hash joins, hash aggregation, pushed-rank processing, and temporary materialization are suitable for the current analytical workload.

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
