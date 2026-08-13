# Report 02 – Account Type Portfolio Analysis

## Overview

This document evaluates the execution plan of the **Account Type Portfolio Analysis** report using actual runtime statistics.

The report calculates account, customer, and balance metrics by account type and currency. It also calculates portfolio percentages and currency-level rankings.

No SQL logic, index, statistics, or database object was modified during the analysis.

## Analysis Method

The query was executed with `GATHER_PLAN_STATISTICS`, and the actual execution plan was retrieved through `DBMS_XPLAN.DISPLAY_CURSOR`.

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
| SQL ID | `5cxf8z2mc9pgb` |
| Child Number | 0 |
| Plan Hash Value | `3574234238` |
| Executions | 1 |
| Returned Rows | 40 |
| Buffer Gets | 501 |
| Physical Reads | 14 |
| Elapsed Time | 0.054987 seconds |
| CPU Time | 0.048489 seconds |

## Execution Plan Highlights

- `ACCOUNTS` was accessed through a full table scan because the report aggregates the complete account portfolio.
- Hash joins were used to combine `ACCOUNTS` with the small reference tables.
- Oracle used index joins for `ACCOUNT_TYPES` and `CURRENCIES`.
- `SORT GROUP BY` supported the aggregate and `COUNT(DISTINCT)` calculations.
- `WINDOW BUFFER` and `WINDOW SORT` supported currency totals and portfolio ranking.
- The final sort processed only 40 rows.
- All sort and analytic operations remained in memory.

## Cardinality Review

| Operation | E-Rows | A-Rows |
|---|---:|---:|
| `ACCOUNTS` scan | 21,000 | 21,000 |
| `ACCOUNT_TYPES` index join | 5 | 5 |
| `CURRENCIES` index join | 8 | 8 |
| Aggregated result | 160 | 40 |

The optimizer overestimated the number of account-type and currency groups by a factor of four. However, the final result contains only 40 rows, and the difference did not cause an inefficient join method, memory spill, or measurable performance problem.

## Assessment

The full scan, hash joins, sort-based aggregation, and analytic operations are appropriate for this complete-portfolio report.

The grouping estimate difference should be documented but does not justify a SQL or statistics change under the current workload.

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
